import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'environment.dart';
import 'error.dart';
import 'logging.dart';
import 'options.dart';
import 'target.dart';
import 'util.dart';

final _log = Logger('go_builder');

String _resolveCc(Target target) {
  final ndk = Environment.androidNdk;
  final prebuiltDir = Directory(
    p.join(ndk, 'toolchains', 'llvm', 'prebuilt'),
  );
  final entries = prebuiltDir
      .listSync()
      .where((e) => !p.basename(e.path).startsWith('.'))
      .toList();
  if (entries.isEmpty) {
    throw BuildException('No NDK prebuilt toolchain found in $prebuiltDir');
  }
  return p.join(entries.first.path, 'bin', target.ndkCcName);
}

class GoBuilder {
  final String rootDir;
  final BuildConfig config;

  GoBuilder({required this.rootDir, required this.config});

  String get _corePath => p.join(rootDir, config.coreDir);
  String get _outputPath => p.join(rootDir, config.outputDir);

  Future<String> build(Target target) async {
    // Desktop: output directly to libclash/{platform}/
    // Android: output to libclash/android/{abi}/
    final outDir = target.isLib
        ? p.join(_outputPath, target.platformDir, target.abi!)
        : p.join(_outputPath, target.platformDir);
    ensureDir(outDir);

    final fileName = target.isLib
        ? '${config.libName}${target.dynamicLibExtension}'
        : '${config.coreName}${target.executableExtension}';
    final outFile = p.join(outDir, fileName);

    final env = <String, String>{
      'GOOS': target.goos,
      'GOARCH': target.goarch,
    };

    if (target.isLib) {
      env['CGO_ENABLED'] = '1';
      env['CC'] = _resolveCc(target);
      env['CFLAGS'] = '-O3 -Werror';
    } else {
      env['CGO_ENABLED'] = '0';
    }

    final args = [
      'build',
      '-ldflags=${config.goLdflags}',
      '-tags=${config.tags}',
      if (target.isLib) '-buildmode=c-shared',
      '-o', outFile,
    ];

    _log.info(kDoubleSeparator);
    _log.info(
        'Building Go core: $target ${target.isLib ? "(CGO, c-shared)" : "(standalone)"}');
    _log.info(kSeparator);

    await runCommandStream('go', args,
        workingDirectory: _corePath, environment: env);

    if (target.isLib && target.abi != null) {
      await _adjustAndroidOutput(
          outDir: p.join(_outputPath, target.platformDir),
          abiDir: target.abi!,
          archName: target.abi!);
    }

    _log.info('Built: $outFile');
    return outFile;
  }

  Future<List<String>> buildAll(List<Target> targets) async {
    final results = await Future.wait(targets.map(build));
    return results;
  }

  Future<void> _adjustAndroidOutput({
    required String outDir,
    required String abiDir,
    required String archName,
  }) async {
    final includesPath = p.join(outDir, 'includes', archName);
    ensureDir(includesPath);

    final coreDir = Directory(_corePath);
    final abiDirPath = p.join(outDir, abiDir);

    for (final dir in [Directory(abiDirPath), coreDir]) {
      if (!dir.existsSync()) continue;
      for (final file in dir.listSync()) {
        if (!file.path.endsWith('.h')) continue;
        final dest = p.join(includesPath, p.basename(file.path));
        File(file.path).copySync(dest);
        if (file.path.startsWith(abiDirPath)) {
          File(file.path).deleteSync();
        }
      }
    }
  }
}
