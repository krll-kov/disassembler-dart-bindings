import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';

const String _rustToolchain = '1.91.1';
const String _rustupVersion = '1.29.1';

const Map<Abi, ({String triple, String sha256})> _rustupInit = {
  Abi.windowsX64: (
    triple: 'x86_64-pc-windows-msvc',
    sha256: '6f4bef66261261fcb43131be8720bab817d403a09edec7455c371974b90bdb7e',
  ),
  Abi.windowsArm64: (
    triple: 'aarch64-pc-windows-msvc',
    sha256: '01aa49cf9574a8bd0ae52005d7de2590e8f27181ded6748236e702c92aef826d',
  ),
  Abi.windowsIA32: (
    triple: 'i686-pc-windows-msvc',
    sha256: 'c036fd639f3a1df5ba673e5f5c2decc685c3881dfb3ea8dbd21c439f9ed643a0',
  ),
  Abi.macosX64: (
    triple: 'x86_64-apple-darwin',
    sha256: '259e2b84274434085163fe8d556510571772cda2aa6d87ca6aa664f57bc644e3',
  ),
  Abi.macosArm64: (
    triple: 'aarch64-apple-darwin',
    sha256: 'ec1b9233e7f72990ecd8e62063fa7f6c3dfc2bec8e97f88bff165f9100ac696a',
  ),
  Abi.linuxX64: (
    triple: 'x86_64-unknown-linux-gnu',
    sha256: 'dda7234360b7f578ca8b0ddcb80145646fa61a67c1720a5abc7051b35c9fcb71',
  ),
  Abi.linuxArm64: (
    triple: 'aarch64-unknown-linux-gnu',
    sha256: '15f6e4ce9f583b929c996c91562bad6d4454f3281de858b02cdfdef615fac433',
  ),
};

typedef _Cargo = ({
  String cargo,
  String? rustup,
  Map<String, String> environment,
});

String get _executable => Platform.isWindows ? '.exe' : '';

String get _pathSeparator => Platform.isWindows ? ';' : ':';

Future<bool> _runs(String command, Map<String, String> environment) async {
  try {
    return (await Process.run(command, const [
          '--version',
        ], environment: environment)).exitCode ==
        0;
  } on ProcessException {
    return false;
  }
}

_Cargo _privateToolchain(Uri home) {
  final String bin = home.resolve('cargo/bin/').toFilePath();
  return (
    cargo: '${bin}cargo$_executable',
    rustup: '${bin}rustup$_executable',
    environment: {
      'RUSTUP_HOME': home.resolve('rustup/').toFilePath(),
      'CARGO_HOME': home.resolve('cargo/').toFilePath(),
      'PATH': '$bin$_pathSeparator${Platform.environment['PATH'] ?? ''}',
    },
  );
}

Future<String?> _which(
  String rustup,
  String tool,
  Uri root,
  Map<String, String> environment,
) async {
  try {
    final ProcessResult result = await Process.run(
      rustup,
      ['which', tool],
      workingDirectory: root.toFilePath(),
      environment: environment,
    );
    final String path = '${result.stdout}'.trim();
    return result.exitCode == 0 && path.isNotEmpty ? path : null;
  } on ProcessException {
    return null;
  }
}

// Dart cannot follow rustup's cargo.exe symlink on Windows (errno 448,
// untrusted mount point), so we run toolchain binaries from `rustup which`
// and set RUSTC
Future<_Cargo?> _rustupCargo(
  String rustup,
  Uri root,
  Map<String, String> environment,
) async {
  final String? cargo = await _which(rustup, 'cargo', root, environment);
  final String? rustc = await _which(rustup, 'rustc', root, environment);
  if (cargo == null || rustc == null) return null;
  return (
    cargo: cargo,
    rustup: rustup,
    environment: {
      ...environment,
      'RUSTC': rustc,
      'PATH':
          '${File(cargo).parent.path}$_pathSeparator'
          '${environment['PATH'] ?? Platform.environment['PATH'] ?? ''}',
    },
  );
}

Future<_Cargo> _findCargo(Uri root, Uri outputDirectory, String target) async {
  // Homebrew installs cargo without rustup and with the host target only, and
  // an Android build on such a machine failed with "can't find crate for core".
  // A cross build takes a rustup toolchain, the private one if no other exists
  final bool cross = target != _rustupInit[Abi.current()]?.triple;
  if (!cross && await _runs('cargo', const {})) {
    return (
      cargo: 'cargo',
      rustup: await _runs('rustup', const {}) ? 'rustup' : null,
      environment: const <String, String>{},
    );
  }
  // IDE started before Rust install keeps PATH without .cargo/bin
  final String? profile =
      Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'];
  final String? bin = profile == null
      ? null
      : '$profile${Platform.pathSeparator}.cargo${Platform.pathSeparator}bin'
            '${Platform.pathSeparator}';
  for (final String rustup in [
    'rustup',
    if (bin != null) '${bin}rustup$_executable',
  ]) {
    final _Cargo? cargo = await _rustupCargo(rustup, root, const {});
    if (cargo != null) return cargo;
  }
  if (!cross &&
      bin != null &&
      await _runs('${bin}cargo$_executable', const {})) {
    return (
      cargo: '${bin}cargo$_executable',
      rustup: null,
      environment: const <String, String>{},
    );
  }
  final Uri home = outputDirectory.resolve('rust_toolchain/');
  final _Cargo private = _privateToolchain(home);
  if (await File(private.rustup!).exists()) {
    await _removeDownloads(home);
  } else {
    await _installRust(home, target);
  }
  return await _rustupCargo(private.rustup!, root, private.environment) ??
      private;
}

Future<void> _removeDownloads(Uri home) async {
  final String base = home.toFilePath().replaceFirst(RegExp(r'[\\/]$'), '');
  await for (final FileSystemEntity entry in Directory(base).parent.list()) {
    if (entry is Directory && entry.path.startsWith('$base.download.')) {
      try {
        await entry.delete(recursive: true);
      } on FileSystemException {
        continue;
      }
    }
  }
}

Future<void> _installRust(Uri home, String target) async {
  final ({String triple, String sha256})? host = _rustupInit[Abi.current()];
  if (host == null) {
    throw StateError(
      'exarmo requires Cargo and Rust $_rustToolchain or later, and rustup '
      'has no installer for ${Abi.current()}',
    );
  }
  final String base = home.toFilePath().replaceFirst(RegExp(r'[\\/]$'), '');
  final Directory staging = Directory('$base.$pid');
  // Windows keeps rustup-init.exe locked after it exits, so a copy inside
  // staging would make its rename to rust_toolchain fail
  final Directory download = Directory('$base.download.$pid');
  for (final Directory directory in [staging, download]) {
    if (await directory.exists()) await directory.delete(recursive: true);
    await directory.create(recursive: true);
  }
  try {
    final File installer = File(
      '${download.path}${Platform.pathSeparator}rustup-init$_executable',
    );
    final Uri url = Uri.https(
      'static.rust-lang.org',
      '/rustup/archive/$_rustupVersion/${host.triple}/rustup-init$_executable',
    );
    final HttpClient client = HttpClient();
    try {
      final HttpClientResponse response = await (await client.getUrl(url))
          .close();
      if (response.statusCode != HttpStatus.ok) {
        throw StateError('Downloading $url failed: ${response.statusCode}');
      }
      await response.pipe(installer.openWrite());
    } finally {
      client.close();
    }
    final String digest = sha256
        .convert(await installer.readAsBytes())
        .toString();
    if (digest != host.sha256) {
      throw StateError('$url has SHA-256 $digest, expected ${host.sha256}');
    }
    if (!Platform.isWindows) {
      final ProcessResult mode = await Process.run('chmod', [
        '+x',
        installer.path,
      ]);
      if (mode.exitCode != 0) {
        throw StateError('chmod failed for ${installer.path}: ${mode.stderr}');
      }
    }
    final Uri stagingHome = Directory(staging.path).uri.resolve('./');
    final List<String> arguments = [
      '-y',
      '--no-modify-path',
      '--profile',
      'minimal',
      '--default-toolchain',
      _rustToolchain,
      '--target',
      target,
    ];
    final ProcessResult result = await Process.run(
      installer.path,
      arguments,
      environment: _privateToolchain(stagingHome).environment,
    );
    if (result.exitCode != 0) {
      throw ProcessException(
        installer.path,
        arguments,
        '${result.stdout}${result.stderr}',
        result.exitCode,
      );
    }
    try {
      await staging.rename(home.toFilePath());
    } on FileSystemException {
      if (!await File(_privateToolchain(home).rustup!).exists()) rethrow;
    }
  } finally {
    for (final Directory directory in [staging, download]) {
      try {
        if (await directory.exists()) await directory.delete(recursive: true);
      } on FileSystemException {
        continue;
      }
    }
  }
}

Future<void> _addTarget(_Cargo cargo, Uri root, String target) async {
  final String? rustup = cargo.rustup;
  if (rustup == null) return;
  final ProcessResult installed = await Process.run(
    rustup,
    const ['target', 'list', '--installed'],
    workingDirectory: root.toFilePath(),
    environment: cargo.environment,
  );
  if (installed.exitCode == 0 &&
      LineSplitter.split('${installed.stdout}')
          .any((String line) => line.trim() == target)) {
    return;
  }
  final List<String> arguments = ['target', 'add', target];
  final ProcessResult result = await Process.run(
    rustup,
    arguments,
    workingDirectory: root.toFilePath(),
    environment: cargo.environment,
  );
  if (result.exitCode != 0) {
    throw ProcessException(
      rustup,
      arguments,
      '${result.stdout}${result.stderr}',
      result.exitCode,
    );
  }
}

String rustTarget(CodeConfig config) => switch ((
  config.targetOS,
  config.targetArchitecture,
)) {
  (OS.windows, Architecture.x64) => 'x86_64-pc-windows-msvc',
  (OS.windows, Architecture.ia32) => 'i686-pc-windows-msvc',
  (OS.windows, Architecture.arm64) => 'aarch64-pc-windows-msvc',
  (OS.macOS, Architecture.x64) => 'x86_64-apple-darwin',
  (OS.macOS, Architecture.arm64) => 'aarch64-apple-darwin',
  (OS.android, Architecture.x64) => 'x86_64-linux-android',
  (OS.android, Architecture.ia32) => 'i686-linux-android',
  (OS.android, Architecture.arm64) => 'aarch64-linux-android',
  (OS.android, Architecture.arm) => 'armv7-linux-androideabi',
  (OS.linux, Architecture.x64) => 'x86_64-unknown-linux-gnu',
  (OS.linux, Architecture.ia32) => 'i686-unknown-linux-gnu',
  (OS.linux, Architecture.arm64) => 'aarch64-unknown-linux-gnu',
  (OS.linux, Architecture.arm) => 'armv7-unknown-linux-gnueabihf',
  (OS.iOS, Architecture.x64) => 'x86_64-apple-ios',
  (OS.iOS, Architecture.arm64) =>
    config.iOS.targetSdk == IOSSdk.iPhoneOS
        ? 'aarch64-apple-ios'
        : 'aarch64-apple-ios-sim',
  _ => throw UnsupportedError(
    'exarmo cannot build for ${config.targetOS}/${config.targetArchitecture}',
  ),
};

String _exarmoSelection(List<String> decoders) {
  final List<String> selected = decoders.toSet().toList()..sort();
  if (selected.isEmpty ||
      selected.any((String value) => value != 'arm' && value != 'aarch64')) {
    throw ArgumentError.value(decoders, 'decoders', 'Select arm or aarch64');
  }
  return selected.join('_');
}

Uri exarmoArchive(
  Uri outputDirectory,
  CodeConfig config, {
  required List<String> decoders,
}) {
  final String name = config.targetOS == OS.windows
      ? 'exarmo_combined.lib'
      : 'libexarmo_combined.a';
  return outputDirectory.resolve(
    'rust/${_exarmoSelection(decoders)}/${rustTarget(config)}/release/$name',
  );
}

Future<({Uri archive, List<String> libraries})> buildExarmo(
  Uri root,
  Uri outputDirectory,
  CodeConfig config, {
  required List<String> decoders,
}) async {
  final String target = rustTarget(config);
  final Uri directory = outputDirectory.resolve(
    'rust/${_exarmoSelection(decoders)}/',
  );
  final _Cargo cargo = await _findCargo(root, outputDirectory, target);
  await _addTarget(cargo, root, target);
  final ProcessResult result;
  final List<String> arguments = [
    'rustc',
    '--release',
    '--locked',
    '--offline',
    '--no-default-features',
    '--features',
    decoders.toSet().join(','),
    '--manifest-path',
    root.resolve('src/exarmo/Cargo.toml').toFilePath(),
    '--target',
    target,
    '--target-dir',
    directory.toFilePath(),
    '--',
    '-C',
    'relocation-model=pic',
    if (config.targetOS == OS.windows) ...['-C', 'target-feature=-crt-static'],
    '--print',
    'native-static-libs',
  ];
  try {
    result = await Process.run(
      cargo.cargo,
      arguments,
      workingDirectory: root.toFilePath(),
      environment: cargo.environment,
    );
  } on ProcessException catch (error) {
    throw StateError(
      'exarmo requires Cargo and Rust $_rustToolchain or later: $error',
    );
  }
  if (result.exitCode != 0) {
    throw ProcessException(
      cargo.cargo,
      arguments,
      '${result.stdout}${result.stderr}',
      result.exitCode,
    );
  }
  final Uri archive = exarmoArchive(
    outputDirectory,
    config,
    decoders: decoders,
  );
  if (!await File.fromUri(archive).exists()) {
    throw StateError('Cargo did not produce exarmo archive for $target');
  }
  final File metadata = File.fromUri(archive.resolve('native_libraries.json'));
  final RegExpMatch? match = RegExp(r'native-static-libs:\s*([^\r\n]+)')
      .firstMatch('${result.stdout}${result.stderr}');
  final List<String> libraries;
  if (match != null) {
    libraries = [
      for (final String value in match.group(1)!.trim().split(RegExp(r'\s+')))
        if (value.startsWith('-l'))
          value.substring(2)
        else if (value.endsWith('.lib'))
          value.substring(0, value.length - 4),
    ].toSet().toList();
    if (config.targetOS == OS.windows &&
        libraries.any(
          (String value) => value.toLowerCase().contains('libcmt'),
        )) {
      throw StateError('exarmo linked static CRT despite -crt-static');
    }
    await metadata.writeAsString(jsonEncode(libraries));
  } else if (await metadata.exists()) {
    libraries = (jsonDecode(await metadata.readAsString()) as List)
        .cast<String>();
  } else {
    throw StateError('Cargo did not report native libraries for $target');
  }
  return (archive: archive, libraries: libraries);
}

Future<List<Uri>> rustDependencies(Uri root) async {
  final List<Uri> files = [root.resolve('exarmo.json')];
  for (final String path in ['src/exarmo/', 'third_party/exarmo/']) {
    await for (final FileSystemEntity entry in Directory.fromUri(
      root.resolve(path),
    ).list(recursive: true, followLinks: false)) {
      if (entry is File &&
          (entry.path.endsWith('.rs') ||
              entry.path.endsWith('.toml') ||
              entry.path.endsWith('Cargo.lock'))) {
        files.add(entry.uri);
      }
    }
  }
  return files;
}
