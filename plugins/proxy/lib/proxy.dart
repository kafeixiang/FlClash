import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';

import 'proxy_platform_interface.dart';

enum ProxyTypes { http, https, socks }

typedef ProxyProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  bool runInShell,
});

@immutable
class ProxyCommand {
  final String executable;
  final List<String> args;
  final bool runInShell;

  const ProxyCommand(
    this.executable,
    this.args, {
    this.runInShell = false,
  });
}

class Proxy extends ProxyPlatform {
  static String url = '127.0.0.1';

  final ProxyProcessRunner _processRunner;

  Proxy({
    ProxyProcessRunner? processRunner,
  }) : _processRunner = processRunner ?? Process.run;

  @override
  Future<bool?> startProxy(
    int port, [
    List<String> bypassDomain = const [],
  ]) async {
    return switch (Platform.operatingSystem) {
      'macos' => await _startProxyWithMacos(port, bypassDomain),
      'linux' => await _startProxyWithLinux(port, bypassDomain),
      'windows' => await ProxyPlatform.instance.startProxy(port, bypassDomain),
      String() => false,
    };
  }

  @override
  Future<bool?> stopProxy() async {
    return switch (Platform.operatingSystem) {
      'macos' => await _stopProxyWithMacos(),
      'linux' => await _stopProxyWithLinux(),
      'windows' => await ProxyPlatform.instance.stopProxy(),
      String() => false,
    };
  }

  Future<bool> _startProxyWithLinux(int port, List<String> bypassDomain) async {
    final homeDir = Platform.environment['HOME'];
    if (homeDir == null || homeDir.isEmpty) {
      return false;
    }
    final commands = _buildLinuxStartCommands(
      port: port,
      bypassDomain: bypassDomain,
      desktop: Platform.environment['XDG_CURRENT_DESKTOP'],
      homeDir: homeDir,
    );
    return _runCommands(commands);
  }

  Future<bool> _stopProxyWithLinux() async {
    final homeDir = Platform.environment['HOME'];
    if (homeDir == null || homeDir.isEmpty) {
      return false;
    }
    final commands = _buildLinuxStopCommands(
      desktop: Platform.environment['XDG_CURRENT_DESKTOP'],
      homeDir: homeDir,
    );
    return _runCommands(commands);
  }

  Future<bool> _startProxyWithMacos(int port, List<String> bypassDomain) async {
    final devices = await _getNetworkDeviceListWithMacos();
    final commands = devices.expand(
      (dev) => _buildMacosStartCommands(
        dev,
        port,
        bypassDomain,
      ),
    );
    return _runCommands(commands);
  }

  Future<bool> _stopProxyWithMacos() async {
    final devices = await _getNetworkDeviceListWithMacos();
    final commands = devices.expand(_buildMacosStopCommands);
    return _runCommands(commands);
  }

  Future<List<String>> _getNetworkDeviceListWithMacos() async {
    final res = await _processRunner(
      '/usr/sbin/networksetup',
      ['-listallnetworkservices'],
    );
    if (res.exitCode != 0) {
      return [];
    }
    return _parseMacosNetworkServices(res.stdout.toString());
  }

  Future<bool> _runCommands(Iterable<ProxyCommand> commands) async {
    try {
      for (final command in commands) {
        final result = await _processRunner(
          command.executable,
          command.args,
          runInShell: command.runInShell,
        );
        if (result.exitCode != 0) {
          return false;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static bool _isKDE(String? desktop) {
    return desktop?.split(':').contains('KDE') ?? false;
  }

  static List<ProxyCommand> _buildLinuxStartCommands({
    required int port,
    required List<String> bypassDomain,
    required String? desktop,
    required String homeDir,
  }) {
    final configDir = join(homeDir, '.config');
    final commands = <ProxyCommand>[];
    final isKDE = _isKDE(desktop);
    if (isKDE) {
      commands.addAll([
        ProxyCommand(
          'kwriteconfig5',
          [
            '--file',
            join(configDir, 'kioslaverc'),
            '--group',
            'Proxy Settings',
            '--key',
            'ProxyType',
            '1',
          ],
        ),
        ProxyCommand(
          'kwriteconfig5',
          [
            '--file',
            join(configDir, 'kioslaverc'),
            '--group',
            'Proxy Settings',
            '--key',
            'NoProxyFor',
            bypassDomain.join(','),
          ],
        ),
      ]);
    } else {
      commands.addAll([
        const ProxyCommand(
          'gsettings',
          ['set', 'org.gnome.system.proxy', 'mode', 'manual'],
        ),
        ProxyCommand(
          'gsettings',
          [
            'set',
            'org.gnome.system.proxy',
            'ignore-hosts',
            _formatGSettingsStringList(bypassDomain),
          ],
        ),
      ]);
    }
    for (final type in ProxyTypes.values) {
      if (isKDE) {
        commands.add(
          ProxyCommand(
            'kwriteconfig5',
            [
              '--file',
              join(configDir, 'kioslaverc'),
              '--group',
              'Proxy Settings',
              '--key',
              '${type.name}Proxy',
              '${type.name}://$url:$port',
            ],
          ),
        );
      } else {
        commands.addAll([
          ProxyCommand(
            'gsettings',
            [
              'set',
              'org.gnome.system.proxy.${type.name}',
              'host',
              url,
            ],
          ),
          ProxyCommand(
            'gsettings',
            [
              'set',
              'org.gnome.system.proxy.${type.name}',
              'port',
              '$port',
            ],
          ),
        ]);
      }
    }
    return commands;
  }

  static List<ProxyCommand> _buildLinuxStopCommands({
    required String? desktop,
    required String homeDir,
  }) {
    final isKDE = _isKDE(desktop);
    if (isKDE) {
      return [
        ProxyCommand(
          'kwriteconfig5',
          [
            '--file',
            join(homeDir, '.config', 'kioslaverc'),
            '--group',
            'Proxy Settings',
            '--key',
            'ProxyType',
            '0',
          ],
        ),
      ];
    }
    return const [
      ProxyCommand(
        'gsettings',
        ['set', 'org.gnome.system.proxy', 'mode', 'none'],
      ),
    ];
  }

  static String _formatGSettingsStringList(List<String> values) {
    if (values.isEmpty) {
      return '[]';
    }
    final escaped = values.map((value) => "'${value.replaceAll("'", "\\'")}'");
    return '[${escaped.join(', ')}]';
  }

  static List<ProxyCommand> _buildMacosStartCommands(
    String dev,
    int port,
    List<String> bypassDomain,
  ) {
    return [
      ProxyCommand(
        '/usr/sbin/networksetup',
        ['-setwebproxy', dev, url, '$port'],
      ),
      ProxyCommand(
        '/usr/sbin/networksetup',
        ['-setwebproxystate', dev, 'on'],
      ),
      ProxyCommand(
        '/usr/sbin/networksetup',
        ['-setsecurewebproxy', dev, url, '$port'],
      ),
      ProxyCommand(
        '/usr/sbin/networksetup',
        ['-setsecurewebproxystate', dev, 'on'],
      ),
      ProxyCommand(
        '/usr/sbin/networksetup',
        ['-setsocksfirewallproxy', dev, url, '$port'],
      ),
      ProxyCommand(
        '/usr/sbin/networksetup',
        ['-setsocksfirewallproxystate', dev, 'on'],
      ),
      _buildMacosProxyBypassCommand(dev, bypassDomain),
    ];
  }

  static List<ProxyCommand> _buildMacosStopCommands(String dev) {
    return [
      ProxyCommand(
        '/usr/sbin/networksetup',
        ['-setautoproxystate', dev, 'off'],
      ),
      ProxyCommand(
        '/usr/sbin/networksetup',
        ['-setwebproxystate', dev, 'off'],
      ),
      ProxyCommand(
        '/usr/sbin/networksetup',
        ['-setsecurewebproxystate', dev, 'off'],
      ),
      ProxyCommand(
        '/usr/sbin/networksetup',
        ['-setsocksfirewallproxystate', dev, 'off'],
      ),
      _buildMacosProxyBypassCommand(dev, const []),
    ];
  }

  static ProxyCommand _buildMacosProxyBypassCommand(
    String dev,
    List<String> bypassDomain,
  ) {
    return ProxyCommand(
      '/usr/sbin/networksetup',
      [
        '-setproxybypassdomains',
        dev,
        if (bypassDomain.isEmpty) 'Empty' else ...bypassDomain,
      ],
    );
  }

  static List<String> _parseMacosNetworkServices(String stdout) {
    return stdout
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where((line) => !line.startsWith('*'))
        .where((line) => !line.startsWith('An asterisk '))
        .toList();
  }

  @visibleForTesting
  static List<ProxyCommand> buildLinuxStartCommandsForTest({
    required int port,
    required List<String> bypassDomain,
    required String? desktop,
    required String homeDir,
  }) {
    return _buildLinuxStartCommands(
      port: port,
      bypassDomain: bypassDomain,
      desktop: desktop,
      homeDir: homeDir,
    );
  }

  @visibleForTesting
  static List<String> parseMacosNetworkServicesForTest(String stdout) {
    return _parseMacosNetworkServices(stdout);
  }

  @visibleForTesting
  static ProxyCommand buildMacosProxyBypassCommandForTest(
    String dev,
    List<String> bypassDomain,
  ) {
    return _buildMacosProxyBypassCommand(dev, bypassDomain);
  }
}
