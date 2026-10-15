package pro.dotslash.ava

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import org.json.JSONObject
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.TimeUnit

/** App-only loopback proxy. Never registers a VPN, changes routes or trusts a CA. */
class SteamAccelerationChannel(private val context: Context) {
    private var process: Process? = null
    private var runtimeDirectory: File? = null

    fun register(engine: FlutterEngine) {
        val messenger = engine.dartExecutor.binaryMessenger
        MethodChannel(messenger, "ava/steam_acceleration", StandardMethodCodec.INSTANCE,
            messenger.makeBackgroundTaskQueue()).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "environment" -> result.success(environment())
                    "isRunning" -> result.success(isRunning())
                    "stop" -> { stop(); result.success(null) }
                    "start" -> {
                        val configuration = call.argument<String>("configuration")
                        if (configuration == null || configuration.length > 2 * 1024 * 1024) {
                            result.error("invalid_configuration", "Invalid core configuration", null)
                        } else {
                            start(configuration)
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (e: CoreFailure) {
                result.error(e.code, "Steam acceleration component unavailable", null)
            } catch (_: Exception) {
                // Never return config, subscription, native stdout or exception text.
                result.error("start_failed", "Steam acceleration operation failed", null)
            }
        }
    }

    private fun environment(): Map<String, Any?> {
        val manager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = manager.activeNetwork
        val capabilities = manager.getNetworkCapabilities(network)
        val proxy = manager.defaultProxy
        val pac = proxy?.pacFileUrl?.toString()?.isNotBlank() == true
        val host = proxy?.host
        val port = proxy?.port ?: -1
        val endpoint = if (!pac && !host.isNullOrBlank() && port in 1..65535) {
            if (host.contains(':')) "[$host]:$port" else "$host:$port"
        } else null
        return mapOf(
            "available" to true,
            "systemProxy" to (proxy != null),
            "httpProxy" to endpoint,
            "pac" to pac,
            "vpnOrTunnel" to (capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true)
        )
    }

    @Synchronized
    private fun isRunning(): Boolean {
        val value = process ?: return false
        return try { value.exitValue(); false } catch (_: IllegalThreadStateException) { true }
    }

    @Synchronized
    private fun start(configuration: String) {
        stop()
        if (!Build.SUPPORTED_ABIS.contains("arm64-v8a")) throw CoreFailure("core_unavailable")
        // The package manager installs this verified executable in a read-only
        // native library directory. Executing a downloaded writable file is forbidden.
        val nativeDirectory = File(context.applicationInfo.nativeLibraryDir).canonicalFile
        val executable = File(nativeDirectory, "libava_steam_core.so").canonicalFile
        if (executable.parentFile != nativeDirectory || !executable.isFile ||
            !executable.canExecute()) throw CoreFailure("core_unavailable")
        val expected = try {
            context.assets.open("steam_core_sha256.txt").bufferedReader().use { it.readText().trim() }
        } catch (_: Exception) { throw CoreFailure("core_unavailable") }
        if (!Regex("[0-9a-f]{64}").matches(expected)) throw CoreFailure("core_integrity")
        val digest = MessageDigest.getInstance("SHA-256")
        executable.inputStream().use { input ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val size = input.read(buffer)
                if (size < 0) break
                digest.update(buffer, 0, size)
            }
        }
        val actual = digest.digest().joinToString("") { "%02x".format(it.toInt() and 0xff) }
        if (actual != expected) throw CoreFailure("core_integrity")
        val config = JSONObject(configuration)
        val port = config.optInt("mixed-port", 0)
        if (port !in 1..65535 || config.optString("bind-address") != "127.0.0.1" ||
            config.optBoolean("allow-lan", true) ||
            config.optJSONObject("tun")?.optBoolean("enable", true) != false ||
            config.optJSONObject("dns")?.optBoolean("enable", true) != false ||
            config.optString("external-controller", "invalid").isNotEmpty() ||
            config.optJSONArray("authentication")?.length() != 1) {
            throw CoreFailure("invalid_configuration")
        }
        val folder = File(context.cacheDir, "steam-acceleration-runtime")
        folder.mkdirs()
        // cacheDir already belongs solely to this app; remove any stale private
        // runtime left by a killed app process before materializing credentials.
        val runtime = File(folder, "active")
        if (runtime.exists()) runtime.deleteRecursively()
        runtime.mkdirs()
        runtimeDirectory = runtime
        try {
            val builder = ProcessBuilder(executable.path, "-d", runtime.path, "-f", "-")
                .directory(runtime).redirectErrorStream(true)
            builder.environment().clear()
            builder.environment()["PATH"] = "/system/bin"
            builder.environment()["HOME"] = runtime.path
            builder.environment()["TMPDIR"] = context.cacheDir.path
            val child = builder.start()
            process = child
            // -f - reads the sanitized config from stdin: node credentials
            // never become a command-line argument or a plaintext runtime file.
            child.outputStream.bufferedWriter().use { it.write(configuration) }
            // Discard every byte, never persist/forward provider credentials.
            Thread {
                try { child.inputStream.use { stream ->
                    val buffer = ByteArray(4096)
                    while (stream.read(buffer) >= 0) { /* discard */ }
                } } catch (_: Exception) { }
            }.apply { isDaemon = true; name = "ava-core-output"; start() }
        } catch (_: Exception) {
            stop()
            throw CoreFailure("start_failed")
        }
    }

    @Synchronized
    fun stop() {
        val child = process
        process = null
        if (child != null) {
            child.destroy()
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                    !child.waitFor(2, TimeUnit.SECONDS)) child.destroyForcibly()
            } catch (_: Exception) { }
        }
        runtimeDirectory?.deleteRecursively()
        runtimeDirectory = null
    }

    private class CoreFailure(val code: String) : Exception()
}
