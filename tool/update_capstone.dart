// Copyright (c) 2026, swiftsoft
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';
import 'dart:io';

const String _repository = 'https://github.com/capstone-engine/capstone.git';
const String _usage = 'Usage: dart run tool/update_capstone.dart <exact-tag>';

Future<void> main(List<String> args) async {
  if (args.length == 1 && args.single == '--help') {
    stdout.writeln(_usage);
    return;
  }
  if (args.length != 1 ||
      !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._/-]*$').hasMatch(args.single)) {
    stderr.writeln(_usage);
    exitCode = 64;
    return;
  }

  final Uri root = Platform.script.resolve('../');
  final Directory temporary = await Directory.systemTemp.createTemp(
    'capstone-update-',
  );
  try {
    final String tag = args.single;
    final Directory checkout = Directory.fromUri(
      temporary.uri.resolve('checkout/'),
    );
    await _run('git', [
      'clone',
      '--quiet',
      '--depth',
      '1',
      '--branch',
      tag,
      _repository,
      checkout.path,
    ], root);
    final String commit = await _run('git', [
      'rev-parse',
      'HEAD',
    ], checkout.uri);
    final String tagCommit = await _run('git', [
      'rev-parse',
      'refs/tags/$tag^{commit}',
    ], checkout.uri);
    if (commit != tagCommit || !RegExp(r'^[a-f0-9]{40}$').hasMatch(commit)) {
      throw StateError('Checkout does not match exact tag $tag');
    }

    final Map<String, File> files = await _sources(checkout.uri);
    final Map<String, Object> manifest = sourceManifest(
      await File.fromUri(checkout.uri.resolve('CMakeLists.txt')).readAsString(),
    );
    final Directory staged = Directory.fromUri(
      temporary.uri.resolve('vendor/'),
    );
    for (final MapEntry<String, File> entry in files.entries) {
      final File target = File.fromUri(staged.uri.resolve(entry.key));
      await target.parent.create(recursive: true);
      await entry.value.copy(target.path);
    }
    final Directory vendor = Directory.fromUri(
      root.resolve('third_party/capstone/'),
    );
    if (await vendor.exists()) await vendor.delete(recursive: true);
    await vendor.create(recursive: true);
    for (final String relative in files.keys) {
      final File target = File.fromUri(vendor.uri.resolve(relative));
      await target.parent.create(recursive: true);
      await File.fromUri(staged.uri.resolve(relative)).copy(target.path);
    }
    await File.fromUri(root.resolve('capstone.json')).writeAsString(
      '${const JsonEncoder.withIndent('  ').convert({'repository': _repository, 'tag': tag, 'commit': commit, ...manifest})}\n',
    );
    stdout.writeln('Capstone $tag at $commit, ${files.length} source files');
    for (final List<String> command in [
      ['run', 'tool/ffigen.dart'],
      ['analyze'],
      ['test', '--concurrency=2'],
    ]) {
      await _run(Platform.resolvedExecutable, [
        '--suppress-analytics',
        ...command,
      ], root);
    }
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  } finally {
    await temporary.delete(recursive: true);
  }
}

Future<String> _run(String executable, List<String> args, Uri working) async {
  final ProcessResult result = await Process.run(
    executable,
    args,
    workingDirectory: Directory.fromUri(working).path,
    environment: {
      'GIT_TERMINAL_PROMPT': '0',
      'GCM_INTERACTIVE': 'Never',
      'DASH__SUPPRESS_ANALYTICS': 'true',
    },
  );
  if (result.exitCode != 0) {
    throw ProcessException(
      executable,
      args,
      '${result.stdout}${result.stderr}',
      result.exitCode,
    );
  }
  if (executable != 'git') {
    stdout.write(result.stdout);
    stderr.write(result.stderr);
  }
  return '${result.stdout}'.trim();
}

Future<Map<String, File>> _sources(Uri source) async {
  final Map<String, File> files = {};
  void add(File file) {
    final String relative = file.uri.path.substring(source.path.length);
    files[relative] = file;
  }

  for (final FileSystemEntity file in await Directory.fromUri(
    source,
  ).list(followLinks: false).toList()) {
    if (file is File && (file.path.endsWith('.c') || file.path.endsWith('.h')))
      add(file);
  }
  for (final String folder in ['include/', 'arch/', 'LICENSES/']) {
    await for (final FileSystemEntity file in Directory.fromUri(
      source.resolve(folder),
    ).list(recursive: true, followLinks: false)) {
      if (file is File) add(file);
    }
  }
  final String cmake = await File.fromUri(source.resolve('CMakeLists.txt'))
      .readAsString();
  final Map<String, Object> manifest = sourceManifest(cmake);
  final Set<String> expected = {
    ...(manifest['engine'] as List<String>),
    for (final Map<String, Object> backend
        in (manifest['decoders'] as Map<String, Map<String, Object>>).values)
      ...(backend['sources'] as List<String>),
  };
  final Set<String> actual = files.keys
      .where((file) => file.endsWith('.c'))
      .toSet();
  if (expected.isEmpty ||
      actual.difference(expected).isNotEmpty ||
      expected.difference(actual).isNotEmpty) {
    throw StateError(
      'Selected C files differ from upstream CMake source lists',
    );
  }
  if (!files.containsKey('LICENSES/LICENSE.TXT')) {
    throw StateError('Upstream Capstone license is missing');
  }
  return files;
}

Map<String, Object> sourceManifest(String cmake) {
  final RegExpMatch? supported = RegExp(
    r'set\(SUPPORTED_ARCHITECTURES\s+([^)]*)\)',
  ).firstMatch(cmake);
  if (supported == null) {
    throw StateError('Upstream supported architectures list is missing');
  }
  final List<String> architectures = supported
      .group(1)!
      .trim()
      .split(RegExp(r'\s+'));
  final Map<String, Set<String>> sources = {};
  for (final RegExpMatch group in RegExp(
    r'set\(SOURCES_([A-Z0-9]+)\s+([^)]*)\)',
    dotAll: true,
  ).allMatches(cmake)) {
    final Set<String> files = sources.putIfAbsent(group.group(1)!, () => {});
    files.addAll(
      group
          .group(2)!
          .split(RegExp(r'\s+'))
          .where((file) => file.endsWith('.c')),
    );
  }
  final Map<String, String> defines = {
    for (final RegExpMatch match in RegExp(
      r'if\s*\(\s*CAPSTONE_([A-Z0-9]+)_SUPPORT\s*\)\s*'
      r'add_definitions\s*\(\s*-D(CAPSTONE_HAS_[A-Z0-9_]+)\s*\)',
    ).allMatches(cmake))
      match.group(1)!: match.group(2)!,
  };
  if (sources['ENGINE'] == null || sources['ENGINE']!.isEmpty) {
    throw StateError('Upstream engine source list is missing');
  }
  final Map<String, Map<String, Object>> decoders = {};
  for (final String architecture in architectures) {
    if (sources[architecture] == null ||
        sources[architecture]!.isEmpty ||
        defines[architecture] == null) {
      throw StateError('Upstream sources or defines missing for $architecture');
    }
    decoders[architecture.toLowerCase()] = {
      'defines': ['CAPSTONE_${architecture}_SUPPORT', defines[architecture]!],
      'sources': sources[architecture]!.toList()..sort(),
    };
  }
  return {'engine': sources['ENGINE']!.toList()..sort(), 'decoders': decoders};
}
