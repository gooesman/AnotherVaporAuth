import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:yaml/yaml.dart';

import 'steam_acceleration_types.dart';

/// A restricted node catalog. Never pass an imported Clash document to a core.
class SteamAccelerationSubscription {
  SteamAccelerationSubscription._(this.nodes, this._configs, this.skipped);
  final List<SteamAccelerationNode> nodes;
  final Map<String, Map<String, Object?>> _configs;
  final int skipped;

  Map<String, Object?> configuration(String id) {
    final config = _configs[id];
    if (config == null) {
      throw const SteamAccelerationException(
        SteamAccelerationError.unsupportedSubscription,
      );
    }
    return Map.of(config);
  }

  /// Only sanitized nodes are persisted in platform secure storage.
  String toSecureCache() => jsonEncode({'proxies': _configs.values.toList()});

  static SteamAccelerationSubscription parse(String source) {
    if (utf8.encode(source).length > 2 * 1024 * 1024) {
      throw const SteamAccelerationException(
        SteamAccelerationError.invalidSubscription,
      );
    }
    try {
      final document = loadYaml(source);
      if (document is! Map || document['proxies'] is! List) {
        throw const FormatException();
      }
      final input = document['proxies'] as List;
      if (input.isEmpty || input.length > 512) throw const FormatException();
      final nodes = <SteamAccelerationNode>[];
      final configs = <String, Map<String, Object?>>{};
      var skipped = 0;
      for (final raw in input) {
        try {
          final config = _sanitize(raw);
          final name = config['name'] as String;
          final type = config['type'] as String;
          final id = sha256
              .convert(
                utf8.encode(
                  jsonEncode([name, type, config['server'], config['port']]),
                ),
              )
              .toString();
          if (configs.containsKey(id)) {
            skipped++;
            continue;
          }
          configs[id] = config;
          nodes.add(SteamAccelerationNode(id: id, name: name, type: type));
        } catch (_) {
          skipped++;
        }
      }
      if (nodes.isEmpty) {
        throw const SteamAccelerationException(
          SteamAccelerationError.unsupportedSubscription,
        );
      }
      return SteamAccelerationSubscription._(
        List.unmodifiable(nodes),
        configs,
        skipped,
      );
    } on SteamAccelerationException {
      rethrow;
    } catch (_) {
      // YAML diagnostics may contain a complete token-bearing input line.
      throw const SteamAccelerationException(
        SteamAccelerationError.invalidSubscription,
      );
    }
  }

  static const _strings = {
    'password',
    'cipher',
    'uuid',
    'username',
    'servername',
    'sni',
    'client-fingerprint',
    'fingerprint',
    'flow',
    'network',
    'obfs',
    'obfs-password',
    'token',
    'congestion-controller',
  };
  static const _numbers = {'alterId', 'up', 'down', 'heartbeat-interval'};
  static const _booleans = {'tls', 'udp', 'udp-over-tcp'};
  static const _nested = {
    'reality-opts': {'public-key', 'short-id'},
    'grpc-opts': {'grpc-service-name'},
    'ws-opts': {'path', 'headers', 'max-early-data', 'early-data-header-name'},
    'h2-opts': {'host', 'path'},
  };
  static const _supported = {
    'ss',
    'vmess',
    'vless',
    'trojan',
    'http',
    'socks5',
    'hysteria2',
    'tuic',
  };

  static Map<String, Object?> _sanitize(dynamic raw) {
    if (raw is! Map || !_supported.contains(raw['type'])) {
      throw const FormatException();
    }
    // These options can open files, launch plugins, chain to outside policies,
    // or suppress the upstream TLS identity check. Reject instead of guessing.
    if (raw['skip-cert-verify'] == true ||
        [
          'plugin',
          'plugin-opts',
          'dialer-proxy',
          'certificate',
          'private-key',
          'interface-name',
          'routing-mark',
        ].any(raw.containsKey)) {
      throw const FormatException();
    }
    final name = _string(raw['name'], 120);
    final server = _string(raw['server'], 253);
    if (server.contains(RegExp(r'[\s/\\@]')) ||
        server == 'localhost' ||
        server == '127.0.0.1' ||
        server == '::1') {
      throw const FormatException();
    }
    final port = raw['port'];
    if (port is! int || port < 1 || port > 65535) {
      throw const FormatException();
    }
    final result = <String, Object?>{
      'name': name,
      'type': raw['type'],
      'server': server,
      'port': port,
    };
    for (final key in _strings) {
      if (raw.containsKey(key)) result[key] = _string(raw[key], 2048);
    }
    for (final key in _numbers) {
      if (raw.containsKey(key)) {
        final value = raw[key];
        if (value is! num || !value.isFinite || value < 0 || value > 1000000) {
          throw const FormatException();
        }
        result[key] = value;
      }
    }
    for (final key in _booleans) {
      if (raw.containsKey(key)) {
        if (raw[key] is! bool) throw const FormatException();
        result[key] = raw[key];
      }
    }
    if (raw.containsKey('alpn')) result['alpn'] = _stringsList(raw['alpn']);
    for (final entry in _nested.entries) {
      if (!raw.containsKey(entry.key)) continue;
      final values = raw[entry.key];
      if (values is! Map) throw const FormatException();
      final nested = <String, Object?>{};
      for (final key in entry.value) {
        if (!values.containsKey(key)) continue;
        if (key == 'headers') {
          final headers = values[key];
          if (headers is! Map || headers.length > 16) {
            throw const FormatException();
          }
          nested[key] = {
            for (final e in headers.entries)
              _string(e.key, 80): _string(e.value, 2048),
          };
        } else if (key == 'host') {
          nested[key] = _stringsList(values[key]);
        } else if (key == 'max-early-data') {
          final value = values[key];
          if (value is! int || value < 0 || value > 65536) {
            throw const FormatException();
          }
          nested[key] = value;
        } else {
          nested[key] = _string(
            values[key],
            2048,
            allowEmpty: key == 'short-id',
          );
        }
      }
      result[entry.key] = nested;
    }
    if (result['network'] != null &&
        !['tcp', 'ws', 'grpc', 'h2'].contains(result['network'])) {
      throw const FormatException();
    }
    final type = result['type'];
    if (['ss', 'trojan', 'hysteria2'].contains(type) &&
            result['password'] == null ||
        ['vmess', 'vless', 'tuic'].contains(type) && result['uuid'] == null ||
        type == 'ss' && result['cipher'] == null) {
      throw const FormatException();
    }
    result['skip-cert-verify'] = false;
    return result;
  }

  static String _string(dynamic value, int max, {bool allowEmpty = false}) {
    if (value is! String ||
        (!allowEmpty && value.isEmpty) ||
        value.length > max ||
        value.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
      throw const FormatException();
    }
    return value;
  }

  static List<String> _stringsList(dynamic value) {
    if (value is! List || value.length > 16) throw const FormatException();
    return value.map((e) => _string(e, 253)).toList();
  }
}

/// All routing is owned by AVA; subscription rules, scripts, DNS, listeners,
/// providers, controller, update URLs and files are never inherited.
String buildSteamCoreConfiguration(
  Map<String, Object?> node,
  SteamProxyEndpoint endpoint,
) => jsonEncode({
  'mixed-port': endpoint.port,
  'bind-address': '127.0.0.1',
  'allow-lan': false,
  'authentication': ['${endpoint.username}:${endpoint.password}'],
  'skip-auth-prefixes': <String>[],
  'mode': 'rule',
  'log-level': 'silent',
  'ipv6': false,
  'find-process-mode': 'off',
  'external-controller': '',
  'external-controller-unix': '',
  'external-controller-pipe': '',
  'external-controller-tls': '',
  'geo-auto-update': false,
  'tun': {'enable': false},
  'dns': {'enable': false},
  'profile': {'store-selected': false, 'store-fake-ip': false},
  'proxies': [
    {...node, 'name': 'AVA-selected'},
  ],
  'rules': ['MATCH,AVA-selected'],
});
