import 'dart:convert';
import 'dart:io';

import 'package:code_assets/code_assets.dart';

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
      'cargo',
      arguments,
      workingDirectory: root.toFilePath(),
    );
  } on ProcessException catch (error) {
    throw StateError('exarmo requires Cargo and Rust 1.91.1 or later: $error');
  }
  if (result.exitCode != 0) {
    throw ProcessException(
      'cargo',
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
