package pro.dotslash.ava

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Base64
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.io.File

/** Only the dedicated updates cache is exposed by this provider's XML paths. */
class AppUpdateFileProvider : FileProvider()

/** Opens Android's installer after checking that an APK can update this app. */
object AppUpdateChannel {
    fun register(activity: Activity, engine: FlutterEngine) {
        val messenger = engine.dartExecutor.binaryMessenger
        // APK parsing can read a large file. Keep it off the platform/UI thread.
        MethodChannel(
            messenger,
            "ava/app_update",
            StandardMethodCodec.INSTANCE,
            messenger.makeBackgroundTaskQueue(),
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canInstall" -> result.success(canInstall(activity))
                "openInstallPermissionSettings" -> openPermissionSettings(activity, result)
                "install" -> {
                    val arguments = call.arguments as? Map<*, *>
                    val path = arguments?.get("path") as? String
                    val expectedVersion = arguments?.get("version") as? String
                    val expectedBuild = when (val value = arguments?.get("buildNumber")) {
                        is Int -> value.toLong()
                        is Long -> value
                        else -> null
                    }
                    try {
                        val apk = validateApk(activity, path, expectedVersion, expectedBuild)
                        if (!canInstall(activity)) {
                            throw UpdateFailure(
                                "install_permission_required",
                                "Allow app installs from AVA in Android settings first.",
                            )
                        }
                        openInstaller(activity, apk, result)
                    } catch (error: UpdateFailure) {
                        result.error(error.code, error.message, null)
                    } catch (_: Exception) {
                        result.error("invalid_apk", "Unable to verify the update package.", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun canInstall(activity: Activity): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || try {
            activity.packageManager.canRequestPackageInstalls()
        } catch (_: SecurityException) {
            false
        }

    private fun openPermissionSettings(activity: Activity, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.success(null)
            return
        }
        activity.runOnUiThread {
            try {
                checkActivity(activity)
                activity.startActivity(
                    Intent(
                        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:${activity.packageName}"),
                    ),
                )
                result.success(null)
            } catch (_: Exception) {
                result.error("settings_unavailable", "Unable to open install permission settings.", null)
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun validateApk(
        activity: Activity,
        path: String?,
        expectedVersion: String?,
        expectedBuild: Long?,
    ): File {
        if (expectedVersion == null || expectedVersion.length > 64 ||
            !Regex("^(0|[1-9]\\d*)\\.(0|[1-9]\\d*)\\.(0|[1-9]\\d*)$").matches(expectedVersion) ||
            expectedBuild == null || expectedBuild !in 1L..2100000000L
        ) {
            throw UpdateFailure("update_metadata_mismatch", "The expected update version is invalid.")
        }
        val apk = try {
            val cache = activity.cacheDir.canonicalFile
            val updates = File(cache, "updates")
            val input = path?.takeIf { it.isNotBlank() }?.let { File(it) }
            // Also reject an updates directory redirected outside the cache by
            // a symlink. A bare string prefix would accept updates-other/.
            if (updates.canonicalFile != updates || input == null || !input.isAbsolute) {
                throw IllegalArgumentException()
            }
            input.canonicalFile.also {
                if (!it.path.startsWith(updates.path + File.separator) ||
                    !it.name.endsWith(".apk", ignoreCase = true) ||
                    !it.isFile || !it.canRead() || it.length() == 0L
                ) {
                    throw IllegalArgumentException()
                }
            }
        } catch (_: Exception) {
            throw UpdateFailure("invalid_update_path", "The APK must be in AVA's update cache.")
        }

        val manager = activity.packageManager
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            PackageManager.GET_SIGNATURES
        }
        val archive = manager.getPackageArchiveInfo(apk.path, flags)
            ?: throw UpdateFailure("invalid_apk", "The update is not a readable Android package.")
        val current = manager.getPackageInfo(activity.packageName, flags)
        if (archive.packageName != activity.packageName) {
            throw UpdateFailure("wrong_package", "This update belongs to a different app.")
        }
        // Bind the actual package to the release shown in the confirmation
        // screen, including this fork's deliberately suffixed preview name.
        if (versionCode(archive) != expectedBuild ||
            archive.versionName !in setOf(expectedVersion, "$expectedVersion-fork")
        ) {
            throw UpdateFailure("update_metadata_mismatch", "The APK version does not match the selected release.")
        }
        if (expectedBuild <= versionCode(current)) {
            throw UpdateFailure("downgrade_not_allowed", "The update must have a newer app build.")
        }
        // Compare current signing certificates, not certificate history: key
        // rotation or a different release/debug key must not be silently trusted.
        val installedSigners = signers(current)
        val updateSigners = signers(archive)
        if (installedSigners.isEmpty() || installedSigners != updateSigners) {
            throw UpdateFailure("signature_mismatch", "The update signing certificate does not match AVA.")
        }
        return apk
    }

    @Suppress("DEPRECATION")
    private fun versionCode(info: PackageInfo): Long =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) info.longVersionCode
        else info.versionCode.toLong()

    @Suppress("DEPRECATION")
    private fun signers(info: PackageInfo): Set<String> {
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.signingInfo?.apkContentsSigners
        } else {
            info.signatures
        }
        return signatures?.map { Base64.encodeToString(it.toByteArray(), Base64.NO_WRAP) }
            ?.toSet().orEmpty()
    }

    private fun openInstaller(activity: Activity, apk: File, result: MethodChannel.Result) {
        activity.runOnUiThread {
            try {
                checkActivity(activity)
                if (!canInstall(activity)) {
                    throw UpdateFailure("install_permission_required", "Android install permission is required.")
                }
                val uri = FileProvider.getUriForFile(
                    activity,
                    "${activity.packageName}.app_update_files",
                    apk,
                )
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, "application/vnd.android.package-archive")
                    clipData = ClipData.newRawUri("AVA update", uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                activity.startActivity(intent)
                // Success only means the system confirmation screen opened.
                // Android still requires the user's confirmation to install.
                result.success(null)
            } catch (error: UpdateFailure) {
                result.error(error.code, error.message, null)
            } catch (_: ActivityNotFoundException) {
                result.error("installer_unavailable", "No Android package installer is available.", null)
            } catch (_: Exception) {
                result.error("install_failed", "Unable to open the Android package installer.", null)
            }
        }
    }

    private fun checkActivity(activity: Activity) {
        check(!activity.isFinishing && !activity.isDestroyed)
    }

    private class UpdateFailure(val code: String, message: String) : Exception(message)
}
