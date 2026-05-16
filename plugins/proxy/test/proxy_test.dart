import 'package:flutter_test/flutter_test.dart';
import 'package:proxy/proxy.dart';

void main() {
  group('Linux proxy command builders', () {
    test('builds GNOME commands without duplicate port writes', () {
      final commands = Proxy.buildLinuxStartCommandsForTest(
        port: 7890,
        bypassDomain: ['localhost', '127.0.0.1'],
        desktop: 'GNOME',
        homeDir: '/home/user',
      );

      final portCommands = commands.where(
        (command) => command.args.length == 4 && command.args[2] == 'port',
      );
      final hostCommands = commands.where(
        (command) => command.args.length == 4 && command.args[2] == 'host',
      );

      expect(portCommands, hasLength(3));
      expect(hostCommands, hasLength(3));
      expect(
        commands
            .singleWhere(
              (command) =>
                  command.args.contains('org.gnome.system.proxy') &&
                  command.args.contains('ignore-hosts'),
            )
            .args
            .last,
        "['localhost', '127.0.0.1']",
      );
    });

    test('builds empty GNOME ignore-hosts as an empty list', () {
      final commands = Proxy.buildLinuxStartCommandsForTest(
        port: 7890,
        bypassDomain: const [],
        desktop: 'GNOME',
        homeDir: '/home/user',
      );

      expect(
        commands
            .singleWhere(
              (command) =>
                  command.args.contains('org.gnome.system.proxy') &&
                  command.args.contains('ignore-hosts'),
            )
            .args
            .last,
        '[]',
      );
    });
  });

  group('macOS proxy command builders', () {
    test(
        'filters networksetup service list headers, disabled services, and blanks',
        () {
      final services = Proxy.parseMacosNetworkServicesForTest('''
An asterisk (*) denotes that a network service is disabled.
Wi-Fi
*Thunderbolt Bridge
USB 10/100/1000 LAN

''');

      expect(services, ['Wi-Fi', 'USB 10/100/1000 LAN']);
    });

    test('passes bypass domains as separate networksetup arguments', () {
      final command = Proxy.buildMacosProxyBypassCommandForTest(
        'Wi-Fi',
        ['localhost', '127.0.0.1'],
      );

      expect(command.executable, '/usr/sbin/networksetup');
      expect(command.args, [
        '-setproxybypassdomains',
        'Wi-Fi',
        'localhost',
        '127.0.0.1',
      ]);
    });

    test('uses Empty when clearing bypass domains', () {
      final command = Proxy.buildMacosProxyBypassCommandForTest(
        'Wi-Fi',
        const [],
      );

      expect(command.args, ['-setproxybypassdomains', 'Wi-Fi', 'Empty']);
    });
  });
}
