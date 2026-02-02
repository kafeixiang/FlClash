import 'environment.dart';

class Target {
  final String goos;
  final String goarch;
  final String? abi;
  final bool isLib;
  final String? flutterPlatform;

  const Target({
    required this.goos,
    required this.goarch,
    this.abi,
    this.isLib = false,
    this.flutterPlatform,
  });

  // --- Android (c-shared library) ---
  static const androidArm = Target(
    goos: 'android', goarch: 'arm', abi: 'armeabi-v7a',
    isLib: true, flutterPlatform: 'android-arm',
  );
  static const androidArm64 = Target(
    goos: 'android', goarch: 'arm64', abi: 'arm64-v8a',
    isLib: true, flutterPlatform: 'android-arm64',
  );
  static const androidAmd64 = Target(
    goos: 'android', goarch: 'amd64', abi: 'x86_64',
    isLib: true, flutterPlatform: 'android-x64',
  );

  // --- macOS (executable) ---
  static const macosArm64 = Target(goos: 'darwin', goarch: 'arm64');
  static const macosAmd64 = Target(goos: 'darwin', goarch: 'amd64');

  // --- Linux (executable) ---
  static const linuxArm64 = Target(goos: 'linux', goarch: 'arm64');
  static const linuxAmd64 = Target(goos: 'linux', goarch: 'amd64');

  // --- Windows (executable) ---
  static const windowsAmd64 = Target(goos: 'windows', goarch: 'amd64');
  static const windowsArm64 = Target(goos: 'windows', goarch: 'arm64');

  static final List<Target> all = [
    androidArm, androidArm64, androidAmd64,
    macosArm64, macosAmd64,
    linuxArm64, linuxAmd64,
    windowsAmd64, windowsArm64,
  ];

  static List<Target> forPlatform(String platformName) {
    return all.where((t) => t.goos == platformName).toList();
  }

  String get dynamicLibExtension {
    switch (goos) {
      case 'android':
      case 'linux':
        return '.so';
      case 'windows':
        return '.dll';
      case 'darwin':
        return '.dylib';
      default:
        throw Exception('Unknown GOOS: $goos');
    }
  }

  String get executableExtension => goos == 'windows' ? '.exe' : '';

  /// Platform build directory name (maps goos to what platform builds expect).
  /// darwin → macos, others stay as-is.
  String get platformDir => goos == 'darwin' ? 'macos' : goos;

  bool get canBuildOnHost {
    final hostOs = Environment.hostOs;
    if (isLib) return true;
    return goos == hostOs;
  }

  String get ndkCcName {
    if (abi == null) throw Exception('Not an Android target');
    switch (abi) {
      case 'armeabi-v7a':
        return 'armv7a-linux-androideabi21-clang';
      case 'arm64-v8a':
        return 'aarch64-linux-android21-clang';
      case 'x86_64':
        return 'x86_64-linux-android21-clang';
      default:
        throw Exception('Unknown ABI: $abi');
    }
  }

  @override
  String toString() => '$goos/$goarch${abi != null ? ' ($abi)' : ''}';
}
