import 'dart:convert';
import 'dart:io';

const String _repository = 'https://github.com/zyantific/zydis.git';

Future<void> main(List<String> arguments) async {
  if (arguments.length == 1 && arguments.single == '--help') {
    stdout.writeln('Usage: dart run tool/update_zydis.dart <stable-tag>');
    return;
  }
  if (arguments.length != 1 ||
      !RegExp(r'^v\d+\.\d+\.\d+$').hasMatch(arguments.single)) {
    stderr.writeln('Usage: dart run tool/update_zydis.dart <stable-tag>');
    exitCode = 64;
    return;
  }
  final Uri root = Platform.script.resolve('../');
  final Directory temporary = await Directory.systemTemp.createTemp(
    'zydis-update-',
  );
  try {
    final Uri checkout = temporary.uri.resolve('checkout/');
    final String tag = arguments.single;
    await _run('git', [
      'clone',
      '--quiet',
      '--depth',
      '1',
      '--branch',
      tag,
      _repository,
      Directory.fromUri(checkout).path,
    ], root);
    final String commit = await _run('git', ['rev-parse', 'HEAD'], checkout);
    final String tagCommit = await _run('git', [
      'rev-parse',
      'refs/tags/$tag^{commit}',
    ], checkout);
    if (commit != tagCommit || !RegExp(r'^[a-f0-9]{40}$').hasMatch(commit)) {
      throw StateError('Zydis checkout differs from stable tag $tag');
    }
    await _run('git', [
      'submodule',
      'update',
      '--init',
      '--depth',
      '1',
      'dependencies/zycore',
    ], checkout);
    final Uri core = checkout.resolve('dependencies/zycore/');
    final String coreCommit = await _run('git', ['rev-parse', 'HEAD'], core);
    final String coreCmake = await File.fromUri(core.resolve('CMakeLists.txt'))
        .readAsString();
    final String coreVersion = RegExp(
      r'project\(Zycore VERSION (\d+\.\d+\.\d+)\.',
    ).firstMatch(coreCmake)!.group(1)!;
    final String zydisCmake = await File.fromUri(
      checkout.resolve('CMakeLists.txt'),
    ).readAsString();
    final List<String> sources = [
      ..._sources(zydisCmake, 'third_party/zydis/'),
      ..._sources(coreCmake, 'third_party/zycore/'),
    ];
    for (final String relative in sources) {
      final bool zycore = relative.startsWith('third_party/zycore/');
      final Uri owner = zycore ? core : checkout;
      final String prefix = zycore
          ? 'third_party/zycore/'
          : 'third_party/zydis/';
      if (!await File.fromUri(owner.resolve(relative.substring(prefix.length)))
          .exists()) {
        throw StateError('Missing source $relative');
      }
    }
    await _vendor(checkout, root.resolve('third_party/zydis/'));
    await _vendor(core, root.resolve('third_party/zycore/'));
    final Map<String, Object> manifest = {
      'repository': _repository,
      'tag': tag,
      'commit': commit,
      'zycore': {
        'repository': 'https://github.com/zyantific/zycore-c.git',
        'version': coreVersion,
        'commit': coreCommit,
      },
      'includes': [
        'third_party/zydis/include',
        'third_party/zydis/src',
        'third_party/zycore/include',
      ],
      'defines': ['ZYDIS_SHOULD_EXPORT', 'ZYCORE_STATIC_BUILD'],
      'linuxDefines': ['_GNU_SOURCE'],
      'sources': sources,
      'sourceGroups': {
        for (final String feature in ['decoder', 'encoder', 'formatter'])
          feature: _featureSources(zydisCmake, feature),
      },
      'features': {
        'decoder': true,
        'encoder': true,
        'formatter': true,
        'avx512': true,
        'knc': true,
        'segment': true,
        'minimalMode': false,
      },
      'licenses': ['third_party/zydis/LICENSE', 'third_party/zycore/LICENSE'],
    };
    await File.fromUri(root.resolve('zydis.json')).writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
    );
    await _run(Platform.resolvedExecutable, [
      '--disable-dart-dev',
      'tool/ffigen_zydis.dart',
    ], root);
    stdout.writeln('Zydis $tag $commit with Zycore $coreVersion $coreCommit');
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  } finally {
    await temporary.delete(recursive: true);
  }
}

List<String> _sources(String cmake, String prefix) => [
  for (final String source in RegExp(
    r'"(src/[^"\r\n]+\.c)"',
  ).allMatches(cmake).map((match) => match.group(1)!).toSet())
    '$prefix$source',
];

List<String> _featureSources(String cmake, String feature) {
  final match = RegExp(
    'if \\(ZYDIS_FEATURE_${feature.toUpperCase()}[^\\r\\n]*\\)\\s+'
    r'target_sources\("Zydis"\s+PRIVATE([\s\S]*?)\)',
  ).firstMatch(cmake);
  if (match == null) throw StateError('Missing Zydis feature $feature');
  return _sources(match.group(1)!, 'third_party/zydis/');
}

Future<void> _vendor(Uri source, Uri destination) async {
  final Directory directory = Directory.fromUri(destination);
  if (await directory.exists()) await directory.delete(recursive: true);
  await directory.create(recursive: true);
  Future<void> copyDirectory(Directory from, String prefix) async {
    await for (final FileSystemEntity entity in from.list(followLinks: false)) {
      final String name = entity.uri.pathSegments
          .where((part) => part.isNotEmpty)
          .last;
      if (name == '.git' || name == 'dependencies') continue;
      final String relative = '$prefix$name';
      if (entity is Directory) {
        await copyDirectory(entity, '$relative/');
      } else if (entity is File) {
        final File target = File.fromUri(destination.resolve(relative));
        await target.parent.create(recursive: true);
        await entity.copy(target.path);
      }
    }
  }

  await copyDirectory(Directory.fromUri(source), '');
}

Future<String> _run(
  String executable,
  List<String> arguments,
  Uri working,
) async {
  final ProcessResult result = await Process.run(
    executable,
    arguments,
    workingDirectory: Directory.fromUri(working).path,
    environment: {
      'GIT_TERMINAL_PROMPT': '0',
      'GCM_INTERACTIVE': 'Never',
      'DART_SUPPRESS_ANALYTICS': 'true',
    },
  );
  if (result.exitCode != 0) {
    throw ProcessException(
      executable,
      arguments,
      '${result.stdout}${result.stderr}',
      result.exitCode,
    );
  }
  return '${result.stdout}'.trim();
}
