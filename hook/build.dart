import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

// Compiles native/turkey_core for the architecture Flutter asks for and
// bundles the dynamic library. Android links through the NDK clang
// Flutter provides; `flutter test` builds the host library.

const String _crate = 'turkey_core';
const String _gnuToolchain = 'stable-x86_64-pc-windows-gnu';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    final CodeConfig code = input.config.code;
    final Uri crateDir = input.packageRoot.resolve('native/$_crate/');
    final Uri targetDir = input.outputDirectoryShared.resolve('cargo/');
    final _Plan plan = _plan(code);

    final ProcessResult result = await Process.run(_cargo(), <String>[
      if (plan.toolchain != null) '+${plan.toolchain}',
      'build',
      '--release',
      '--target',
      plan.triple,
      '--manifest-path',
      crateDir.resolve('Cargo.toml').toFilePath(),
      '--target-dir',
      targetDir.toFilePath(),
    ], environment: plan.environment);
    if (result.exitCode != 0) {
      throw BuildError(
        message:
            'cargo build for ${plan.triple} failed '
            '(exit ${result.exitCode}).\n${result.stdout}\n${result.stderr}'
            '${plan.hint}',
      );
    }

    final Uri library = targetDir.resolve(
      '${plan.triple}/release/${code.targetOS.dylibFileName(_crate)}',
    );
    if (!File.fromUri(library).existsSync()) {
      throw BuildError(message: 'cargo finished but $library is missing.');
    }

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: _crate,
        linkMode: DynamicLoadingBundled(),
        file: library,
      ),
    );
    output.dependencies.addAll(_sources(crateDir));
  });
}

final class _Plan {
  const _Plan(
    this.triple, {
    this.toolchain,
    this.environment = const {},
    this.hint = '',
  });

  final String triple;
  final String? toolchain;
  final Map<String, String> environment;
  final String hint;
}

_Plan _plan(CodeConfig code) {
  final Architecture arch = code.targetArchitecture;
  switch (code.targetOS) {
    case OS.android:
      final (String triple, String clangTriple) = switch (arch) {
        Architecture.arm64 => (
          'aarch64-linux-android',
          'aarch64-linux-android',
        ),
        Architecture.arm => (
          'armv7-linux-androideabi',
          'armv7a-linux-androideabi',
        ),
        Architecture.x64 => ('x86_64-linux-android', 'x86_64-linux-android'),
        Architecture.ia32 => ('i686-linux-android', 'i686-linux-android'),
        _ => throw BuildError(
          message: 'Unsupported Android architecture $arch.',
        ),
      };
      final CCompilerConfig? cc = code.cCompiler;
      if (cc == null) {
        throw BuildError(
          message:
              'Android builds need the NDK clang; Flutter did not provide one.',
        );
      }
      final String key = triple.toUpperCase().replaceAll('-', '_');
      final int api = code.android.targetNdkApi;
      return _Plan(
        triple,
        environment: <String, String>{
          'CARGO_TARGET_${key}_LINKER': cc.compiler.toFilePath(),
          'CARGO_TARGET_${key}_RUSTFLAGS': <String>[
            '-C',
            'link-arg=--target=$clangTriple$api',
            '-C',
            'link-arg=-Wl,-z,max-page-size=16384',
          ].join(' '),
        },
        hint: '\nInstall the target with: rustup target add $triple',
      );
    case OS.windows:
      if (arch != Architecture.x64) {
        throw BuildError(message: 'Unsupported Windows architecture $arch.');
      }
      if (_hasMsvc(code)) return const _Plan('x86_64-pc-windows-msvc');
      return const _Plan(
        'x86_64-pc-windows-gnu',
        toolchain: _gnuToolchain,
        hint:
            '\nNo MSVC linker found. Install the self-contained GNU toolchain '
            'with: rustup toolchain install $_gnuToolchain --profile minimal',
      );
    case OS.linux:
      return switch (arch) {
        Architecture.x64 => const _Plan('x86_64-unknown-linux-gnu'),
        Architecture.arm64 => const _Plan('aarch64-unknown-linux-gnu'),
        _ => throw BuildError(message: 'Unsupported Linux architecture $arch.'),
      };
    case OS.macOS:
      return switch (arch) {
        Architecture.arm64 => const _Plan('aarch64-apple-darwin'),
        Architecture.x64 => const _Plan('x86_64-apple-darwin'),
        _ => throw BuildError(message: 'Unsupported macOS architecture $arch.'),
      };
    default:
      throw BuildError(
        message: 'turkey_core does not support ${code.targetOS}.',
      );
  }
}

bool _hasMsvc(CodeConfig code) {
  final CCompilerConfig? cc = code.cCompiler;
  if (cc == null) return false;
  return cc.windows.developerCommandPrompt != null;
}

String _cargo() {
  final String? home =
      Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  if (home != null) {
    final String exe = Platform.isWindows ? 'cargo.exe' : 'cargo';
    final File installed = File(
      '$home${Platform.pathSeparator}.cargo'
      '${Platform.pathSeparator}bin${Platform.pathSeparator}$exe',
    );
    if (installed.existsSync()) return installed.path;
  }
  return 'cargo';
}

Iterable<Uri> _sources(Uri crateDir) sync* {
  yield crateDir.resolve('Cargo.toml');
  final File lock = File.fromUri(crateDir.resolve('Cargo.lock'));
  if (lock.existsSync()) yield lock.uri;
  final Directory src = Directory.fromUri(crateDir.resolve('src/'));
  for (final FileSystemEntity entity in src.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.rs')) yield entity.uri;
  }
}
