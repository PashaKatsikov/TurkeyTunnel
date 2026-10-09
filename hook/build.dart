import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

// Compiles native/turkey_core (white game math), native/burrow (gray
// string vault) and native/drift (gray geometry ledger) for the
// architecture Flutter asks for and bundles each dynamic library as its
// own code asset. Android links through the NDK clang Flutter provides;
// `flutter test` builds the host libraries.

const List<String> _crates = <String>['turkey_core'];
const String _gnuToolchain = 'stable-x86_64-pc-windows-gnu';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    final CodeConfig code = input.config.code;
    final _Plan plan = _plan(code);

    Future<void> buildCrate(String crate) async {
      final Uri crateDir = input.packageRoot.resolve('native/$crate/');
      final Uri targetDir =
          input.outputDirectoryShared.resolve('cargo/$crate/');

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
              'cargo build for $crate (${plan.triple}) failed '
              '(exit ${result.exitCode}).\n${result.stdout}\n${result.stderr}'
              '${plan.hint}',
        );
      }

      final Uri library = targetDir.resolve(
        '${plan.triple}/release/${code.targetOS.dylibFileName(crate)}',
      );
      if (!File.fromUri(library).existsSync()) {
        throw BuildError(message: 'cargo finished but $library is missing.');
      }

      output.assets.code.add(
        CodeAsset(
          package: input.packageName,
          name: crate,
          linkMode: DynamicLoadingBundled(),
          file: library,
        ),
      );
      output.dependencies.addAll(_sources(crateDir));
    }

    for (final String crate in _crates) {
      await buildCrate(crate);
    }
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
      final String ccKey = triple.replaceAll('-', '_');
      final int api = code.android.targetNdkApi;

      // burrow links BoringSSL (via wreq) for the browser-grade TLS
      // fingerprint. Cross-building it from a host to the NDK needs the
      // SDK's CMake 3.x (the NDK toolchain file is incompatible with
      // CMake 4), the NDK toolchain, a libclang for bindgen and the
      // compiler's own builtin headers. _boringEnv locates all of them.
      final Map<String, String> env = <String, String>{
        // The NDK clang the Rust linker uses for every crate.
        'CARGO_TARGET_${key}_LINKER': cc.compiler.toFilePath(),
        'CARGO_TARGET_${key}_RUSTFLAGS': <String>[
          '-C',
          'link-arg=--target=$clangTriple$api',
          '-C',
          'link-arg=-Wl,-z,max-page-size=16384',
        ].join(' '),
      }..addAll(_boringEnv(cc, ccKey, clangTriple, api));

      return _Plan(
        triple,
        environment: env,
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

String _fwd(String p) => p.replaceAll(r'\', '/');

// Collects the environment burrow needs to cross-compile BoringSSL (via
// wreq) for the NDK. Everything is derived from the clang Flutter hands
// us, so there is nothing machine-specific hard-coded except the
// libclang fallback.
Map<String, String> _boringEnv(
  CCompilerConfig cc,
  String ccKey,
  String clangTriple,
  int api,
) {
  final String exe = Platform.isWindows ? '.exe' : '';
  final Uri binDir = cc.compiler.resolve('.'); // …/prebuilt/<host>/bin/
  final String ar = _fwd(File.fromUri(binDir.resolve('llvm-ar$exe')).path);

  final Uri ndkRoot = binDir.resolve('../../../../../');
  final Uri sdkRoot = ndkRoot.resolve('../../');
  final String ndkPath = _fwd(Directory.fromUri(ndkRoot).path);

  final String cmakeBin = _sdkCmakeBin(sdkRoot);
  final String cmake = _fwd('$cmakeBin${Platform.pathSeparator}cmake$exe');
  final String ninja = _fwd('$cmakeBin${Platform.pathSeparator}ninja$exe');

  final String libclang = _libclangDir();
  final String builtinInc = _fwd(_builtinIncludeDir(binDir));

  // Native PATH (back-slashes on Windows) so the OS process spawner and the
  // `cc` crate can find the NDK toolchain binaries.
  final String ndkBin = Directory.fromUri(binDir).path;
  final String sep = Platform.isWindows ? ';' : ':';
  final String oldPath =
      Platform.environment['PATH'] ?? Platform.environment['Path'] ?? '';

  return <String, String>{
    'ANDROID_NDK_HOME': ndkPath,
    'ANDROID_NDK_ROOT': ndkPath,
    'CMAKE': cmake,
    'CMAKE_GENERATOR': 'Ninja',
    'CMAKE_MAKE_PROGRAM': ninja,
    'LIBCLANG_PATH': libclang,
    // The NDK toolchain bin goes on PATH so the `cc` crate (zstd-sys and
    // other C deps of wreq) locates clang on its own.
    //
    // We deliberately do NOT set CC_<target>/CXX_<target>. btls-sys reads
    // CC_<target> and, when present, forces CMAKE_C_COMPILER, which fights
    // android.toolchain.cmake. btls builds BoringSSL in two passes (ssl
    // then crypto); with the forced plain compiler the first pass compiled
    // libssl.a for the *host* (COFF x86-64) instead of Android (ELF
    // aarch64), so the linker silently dropped it and dlopen failed with
    // "cannot locate symbol SSL_CTX_free". Leaving CC unset lets the NDK
    // toolchain file own the compiler for both passes → deterministic ELF.
    'PATH': '$ndkBin$sep$oldPath',
    'AR_$ccKey': ar,
    // Read by the `cc` crate for zstd-sys et al. so they cross-compile to
    // Android ELF. btls-sys ignores these (it has no CFLAGS field).
    'CFLAGS_$ccKey': '--target=$clangTriple$api',
    'CXXFLAGS_$ccKey': '--target=$clangTriple$api',
    // bindgen uses the system libclang, which needs the target and the
    // compiler's builtin headers (stddef.h et al.) spelled out.
    'BINDGEN_EXTRA_CLANG_ARGS_$ccKey':
        '--target=$clangTriple$api -I"$builtinInc"',
  };
}

// Picks the newest Android SDK CMake whose major version is < 4; the NDK
// toolchain file does not configure correctly under CMake 4.
String _sdkCmakeBin(Uri sdkRoot) {
  final Directory cmakeHome = Directory.fromUri(sdkRoot.resolve('cmake/'));
  if (cmakeHome.existsSync()) {
    final List<Directory> versions = cmakeHome
        .listSync()
        .whereType<Directory>()
        .where((Directory d) {
          final List<String> parts = d.uri.pathSegments
              .where((String s) => s.isNotEmpty)
              .toList();
          final int? major = int.tryParse(
            (parts.isEmpty ? '' : parts.last).split('.').first,
          );
          return major != null && major < 4;
        })
        .toList()
      ..sort((Directory a, Directory b) => _cmp(_tail(b.uri), _tail(a.uri)));
    if (versions.isNotEmpty) {
      return '${versions.first.path}${Platform.pathSeparator}bin';
    }
  }
  throw BuildError(
    message:
        'No Android SDK CMake (<4) found under ${cmakeHome.path}. Install '
        'one from Android Studio → SDK Manager → SDK Tools → CMake (3.22.x).',
  );
}

// Compiler builtin headers (…/lib/clang/<ver>/include) that bindgen must
// see so it can resolve stddef.h and friends.
String _builtinIncludeDir(Uri binDir) {
  final Directory clangLib = Directory.fromUri(binDir.resolve('../lib/clang/'));
  if (clangLib.existsSync()) {
    final List<Directory> versions = clangLib.listSync().whereType<Directory>().toList()
      ..sort((Directory a, Directory b) => _cmp(_tail(b.uri), _tail(a.uri)));
    if (versions.isNotEmpty) {
      return '${versions.first.path}${Platform.pathSeparator}include';
    }
  }
  throw BuildError(
    message: 'Could not locate the NDK clang builtin headers under '
        '${clangLib.path}.',
  );
}

// Directory holding libclang for bindgen. Honours LIBCLANG_PATH, then
// falls back to the standard LLVM install location.
String _libclangDir() {
  final List<String> names = Platform.isWindows
      ? <String>['libclang.dll']
      : Platform.isMacOS
      ? <String>['libclang.dylib']
      : <String>['libclang.so'];
  final String? fromEnv = Platform.environment['LIBCLANG_PATH'];
  final List<String> candidates = <String>[
    if (fromEnv != null) fromEnv,
    if (Platform.isWindows) r'C:\Program Files\LLVM\bin',
    if (Platform.isMacOS) '/opt/homebrew/opt/llvm/lib',
    if (Platform.isMacOS) '/usr/local/opt/llvm/lib',
    if (Platform.isLinux) '/usr/lib/llvm-19/lib',
    if (Platform.isLinux) '/usr/lib',
  ];
  for (final String dir in candidates) {
    for (final String name in names) {
      if (File('$dir${Platform.pathSeparator}$name').existsSync()) return dir;
    }
  }
  throw BuildError(
    message:
        'libclang not found (needed by bindgen for BoringSSL). Install LLVM '
        '(Windows: `winget install LLVM.LLVM`) or set LIBCLANG_PATH to the '
        'directory containing ${names.first}.',
  );
}

String _tail(Uri u) {
  final List<String> parts = u.pathSegments
      .where((String s) => s.isNotEmpty)
      .toList();
  return parts.isEmpty ? '' : parts.last;
}

// Compares dotted version strings numerically (e.g. 3.22.1 vs 3.6).
int _cmp(String a, String b) {
  final List<int> pa = a.split('.').map((String s) => int.tryParse(s) ?? 0).toList();
  final List<int> pb = b.split('.').map((String s) => int.tryParse(s) ?? 0).toList();
  for (int i = 0; i < pa.length || i < pb.length; i++) {
    final int x = i < pa.length ? pa[i] : 0;
    final int y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
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
