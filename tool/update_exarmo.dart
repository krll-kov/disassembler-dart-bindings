// Copyright (c) 2026, swiftsoft
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';
import 'dart:io';

const String _repository = 'https://github.com/Vector35/exarmo.git';
const String _usage = 'Usage: dart run tool/update_exarmo.dart <exact-tag>';

Future<void> main(List<String> arguments) async {
  if (arguments.length == 1 && arguments.single == '--help') {
    stdout.writeln(_usage);
    return;
  }
  if (arguments.length != 1 ||
      !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._/-]*$').hasMatch(arguments.single)) {
    stderr.writeln(_usage);
    exitCode = 64;
    return;
  }
  final Uri root = Platform.script.resolve('../');
  final Directory temporary = await Directory.systemTemp.createTemp(
    'exarmo-update-',
  );
  try {
    final String tag = arguments.single;
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
    final String taggedCommit = await _run('git', [
      'rev-parse',
      'refs/tags/$tag^{commit}',
    ], checkout.uri);
    if (commit != taggedCommit || !RegExp(r'^[a-f0-9]{40}$').hasMatch(commit))
      throw StateError('Exarmo checkout differs from exact tag $tag');
    final String tracked = await _run('git', ['ls-files', '-z'], checkout.uri);
    final Directory vendor = Directory.fromUri(
      root.resolve('third_party/exarmo/'),
    );
    final Directory staged = Directory.fromUri(
      temporary.uri.resolve('vendor/'),
    );
    final List<String> paths = tracked
        .split('\u0000')
        .where((String value) => value.isNotEmpty)
        .toList();
    for (final String path in paths) {
      final File source = File.fromUri(checkout.uri.resolve(path));
      final File target = File.fromUri(staged.uri.resolve(path));
      await target.parent.create(recursive: true);
      await source.copy(target.path);
    }
    if (await vendor.exists()) await vendor.delete(recursive: true);
    for (final String path in paths) {
      final File target = File.fromUri(vendor.uri.resolve(path));
      await target.parent.create(recursive: true);
      await File.fromUri(staged.uri.resolve(path)).copy(target.path);
    }
    await File.fromUri(root.resolve('exarmo.json')).writeAsString(
      '${const JsonEncoder.withIndent('  ').convert({'repository': _repository, 'tag': tag, 'commit': commit, 'version': tag.startsWith('v') ? tag.substring(1) : tag, 'license': 'Apache-2.0'})}\n',
    );
    await _run('cargo', [
      'generate-lockfile',
      '--offline',
      '--manifest-path',
      'src/exarmo/Cargo.toml',
    ], root);
    for (final List<String> command in [
      ['run', 'tool/ffigen_exarmo.dart'],
      ['analyze'],
      ['test', 'test/exarmo_test.dart', '--concurrency=1'],
    ]) {
      await _run(Platform.resolvedExecutable, [
        '--suppress-analytics',
        ...command,
      ], root);
    }
    stdout.writeln('Exarmo $tag at $commit, ${paths.length} source files');
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  } finally {
    await temporary.delete(recursive: true);
  }
}

Future<String> _run(String executable, List<String> arguments, Uri root) async {
  final ProcessResult result = await Process.run(
    executable,
    arguments,
    workingDirectory: Directory.fromUri(root).path,
    environment: {'GIT_TERMINAL_PROMPT': '0', 'GCM_INTERACTIVE': 'Never'},
  );
  if (result.exitCode != 0)
    throw ProcessException(
      executable,
      arguments,
      '${result.stdout}${result.stderr}',
      result.exitCode,
    );
  if (executable != 'git') {
    stdout.write(result.stdout);
    stderr.write(result.stderr);
  }
  return '${result.stdout}'.trim();
}
