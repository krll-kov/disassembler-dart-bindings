// Copyright (c) 2026, swiftsoft
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

final class NativeConfiguration {
  static const List<String> availableBackends = ['zydis', 'exarmo', 'capstone'];
  final List<String> backends;
  final List<String> capstoneDecoders;
  final List<String> exarmoDecoders;
  final List<String> zydisFeatures;

  NativeConfiguration._(
    this.backends,
    this.capstoneDecoders,
    this.exarmoDecoders,
    this.zydisFeatures,
  );

  factory NativeConfiguration.fromHook(HookInput input) {
    final Map<String, Object?> values = {};
    final Object? definitions = input.json['user_defines'];
    if (definitions is Map) {
      final Object? workspace = definitions['workspace_pubspec'];
      if (workspace is Map && workspace['defines'] is Map) {
        values.addAll((workspace['defines'] as Map).cast<String, Object?>());
      }
    }
    final configuration = NativeConfiguration(values);
    if (configuration.backends.contains('capstone')) {
      _capstoneConfiguration(input.packageRoot, configuration.capstoneDecoders);
    }
    return configuration;
  }

  factory NativeConfiguration(Map<String, Object?> values) {
    for (final String key in values.keys) {
      if (key != 'backends') {
        throw ArgumentError('Unknown disassembler setting: $key');
      }
    }
    final Object definitions = values['backends'] ?? const <String, Object?>{};
    if (definitions is! Map) throw ArgumentError('backends must be a map');
    final List<String> backends = _selection(
      definitions.keys.toList(),
      'backends',
      availableBackends,
    );
    List<String> component(String backend, String key, [List<String>? valid]) {
      if (!backends.contains(backend)) return const [];
      final Object? settings = definitions[backend];
      if (settings is! Map ||
          settings.keys.any((k) => k != 'architectures' && k != 'features')) {
        throw ArgumentError('$backend requires architectures and features');
      }
      final Object? value = settings[key];
      if (value is! List || value.isEmpty || value.any((v) => v is! String)) {
        throw ArgumentError('$backend.$key must be a nonempty list');
      }
      return _selection(value, '$backend.$key', valid ?? value.cast<String>());
    }

    component('zydis', 'architectures', ['x86']);
    component('exarmo', 'features', ['decoder']);
    component('capstone', 'features', ['decoder']);
    final List<String> zydis = component('zydis', 'features', [
      'decoder',
      'encoder',
      'formatter',
    ]);
    if (backends.contains('zydis') && !zydis.contains('decoder')) {
      throw ArgumentError('Zydis encoder and formatter require decoder');
    }
    return NativeConfiguration._(
      backends,
      component(
        'capstone',
        'architectures',
      ).map((value) => value == 'arm64' ? 'aarch64' : value).toList(),
      component('exarmo', 'architectures', [
        'arm',
        'arm64',
      ]).map((value) => value == 'arm64' ? 'aarch64' : value).toList(),
      zydis,
    );
  }
}

List<String> _selection(Object value, String name, Iterable<String> available) {
  if (value is! List ||
      value.any(
        (Object? item) => item is! String || !available.contains(item),
      )) {
    throw ArgumentError.value(
      value,
      name,
      'Expected list containing ${available.join(', ')}',
    );
  }
  return List<String>.unmodifiable(value.cast<String>().toSet());
}

Map<String, Object?> _manifest(Uri root, String name) => (jsonDecode(
  File.fromUri(root.resolve('$name.json')).readAsStringSync(),
) as Map).cast<String, Object?>();

({List<String> sources, Map<String, String?> defines, List<String> includes})
_capstoneConfiguration(Uri root, Object? decoders) {
  final Map<String, Object?> manifest = (jsonDecode(
    File.fromUri(root.resolve('capstone.json')).readAsStringSync(),
  ) as Map).cast<String, Object?>();
  final Map<String, Object?> available = (manifest['decoders'] as Map)
      .cast<String, Object?>();
  final Object selected = decoders ?? available.keys.toList();
  if (selected is! List ||
      selected.isEmpty ||
      selected.any(
        (Object? value) => value is! String || !available.containsKey(value),
      )) {
    throw ArgumentError.value(
      selected,
      'decoders',
      'Expected nonempty list containing ${available.keys.join(', ')}',
    );
  }
  final List<Map<String, Object?>> backends = [
    for (final String decoder in selected.cast<String>().toSet())
      (available[decoder] as Map).cast<String, Object?>(),
  ];
  final Uri source = root.resolve('third_party/capstone/');
  final List<String> sources = [
    root.resolve('src/abi.c').toFilePath(),
    for (final String file in (manifest['engine'] as List).cast<String>())
      source.resolve(file).toFilePath(),
    for (final Map<String, Object?> backend in backends)
      for (final String file in (backend['sources'] as List).cast<String>())
        source.resolve(file).toFilePath(),
  ]..sort();
  return (
    sources: sources,
    includes: [source.resolve('include/').toFilePath()],
    defines: {
      for (final Map<String, Object?> backend in backends)
        for (final String define in (backend['defines'] as List).cast<String>())
          define: null,
      'CAPSTONE_USE_SYS_DYN_MEM': null,
      'CAPSTONE_SHARED': null,
    },
  );
}

String libraryName(OS targetOS) {
  final String prefix = switch (targetOS) {
    OS.windows => '',
    // Flutter strips lib from Apple frameworks, so this extra prefix
    // preserves lib_ in their final filenames
    OS.macOS || OS.iOS => 'lib_',
    _ => '_',
  };
  return '${prefix}disassembler_${targetOS.name}_plugin';
}

CLibrary capstoneLibrary(Uri root, OS targetOS, {Object? decoders}) {
  final configuration = _capstoneConfiguration(root, decoders);
  return CLibrary(
    name: libraryName(targetOS),
    assetName: 'disassembler.dart',
    sources: configuration.sources,
    includes: configuration.includes,
    defines: configuration.defines,
    std: targetOS == OS.windows ? 'c11' : 'c99',
    flags: [if (targetOS == OS.windows) '/MD'],
  );
}

CLibrary disassemblerLibrary(
  Uri root,
  OS targetOS,
  NativeConfiguration configuration, {
  Uri? exarmoArchive,
  List<String> exarmoLibraries = const [],
}) {
  final List<String> sources = [
    root.resolve('src/batch.c').toFilePath(),
    root.resolve('src/disassembler.c').toFilePath(),
  ];
  final List<String> includes = [];
  final Map<String, String?> defines = {
    for (final String backend in configuration.backends)
      'DISASSEMBLER_${backend.toUpperCase()}': null,
    for (final String decoder in configuration.exarmoDecoders)
      'DISASSEMBLER_EXARMO_${decoder.toUpperCase()}': null,
    for (final String feature in configuration.zydisFeatures)
      'DISASSEMBLER_ZYDIS_${feature.toUpperCase()}': null,
  };
  if (configuration.backends.contains('capstone')) {
    final capstone = _capstoneConfiguration(
      root,
      configuration.capstoneDecoders,
    );
    sources.addAll(capstone.sources);
    includes.addAll(capstone.includes);
    defines.addAll(capstone.defines);
  }
  if (configuration.backends.contains('zydis')) {
    final manifest = _manifest(root, 'zydis');
    final Map<String, List<String>> groups = {
      for (final MapEntry entry in (manifest['sourceGroups'] as Map).entries)
        entry.key as String: (entry.value as List).cast<String>(),
    };
    final Set<String> optionalSources = groups.values
        .expand((group) => group)
        .toSet();
    final Set<String> selectedSources = configuration.zydisFeatures
        .expand((feature) => groups[feature]!)
        .toSet();
    sources.addAll([
      for (final String path in (manifest['sources'] as List).cast<String>())
        if (!optionalSources.contains(path) || selectedSources.contains(path))
          root.resolve(path).toFilePath(),
    ]);
    includes.addAll([
      for (final String path in (manifest['includes'] as List).cast<String>())
        root.resolve(path).toFilePath(),
    ]);
    for (final String name in (manifest['defines'] as List).cast<String>()) {
      defines[name] = null;
    }
    for (final String feature in groups.keys) {
      if (!configuration.zydisFeatures.contains(feature)) {
        defines['ZYDIS_DISABLE_${feature.toUpperCase()}'] = null;
      }
    }
    if (targetOS == OS.linux || targetOS == OS.android) {
      for (final String name
          in (manifest['linuxDefines'] as List).cast<String>()) {
        defines[name] = null;
      }
    }
  }
  if (configuration.backends.contains('exarmo')) {
    if (exarmoArchive == null) {
      throw ArgumentError('exarmo requires its Rust archive');
    }
    sources.add(root.resolve('src/exarmo_exports.c').toFilePath());
  }
  return CLibrary(
    name: libraryName(targetOS),
    assetName: 'disassembler.dart',
    sources: sources..sort(),
    includes: includes,
    defines: defines,
    libraries: [
      if (exarmoArchive != null) 'exarmo_combined',
      ...exarmoLibraries,
    ],
    libraryDirectories: [
      if (exarmoArchive != null) exarmoArchive.resolve('.').toFilePath(),
    ],
    flags: [if (targetOS == OS.windows) '/MD'],
    std: 'c11',
    pic: true,
  );
}

/// MSVC overwrites object files when source basenames match ignoring case
Future<List<String>> windowsCompilationSources(
  List<String> sources,
  Uri outputDirectory,
) async {
  String objectName(String path) {
    final String basename = Uri.file(path).pathSegments.last;
    final int extension = basename.lastIndexOf('.');
    return (extension < 0 ? basename : basename.substring(0, extension))
        .toLowerCase();
  }

  final Map<String, int> counts = {};
  for (final String source in sources) {
    final String name = objectName(source);
    counts[name] = (counts[name] ?? 0) + 1;
  }
  final Set<String> used = counts.keys.toSet();
  final List<String> compiled = [];
  final Uri directory = outputDirectory.resolve('windows_sources/');
  for (int index = 0; index < sources.length; index++) {
    final String source = sources[index];
    if (counts[objectName(source)] == 1) {
      compiled.add(source);
      continue;
    }
    final String basename = Uri.file(source).pathSegments.last;
    final int extension = basename.lastIndexOf('.');
    final String suffix = extension < 0 ? '.c' : basename.substring(extension);
    String name = 'disassembler_source_$index';
    int collision = 0;
    while (!used.add(name.toLowerCase())) {
      name = 'disassembler_source_${index}_${++collision}';
    }
    await Directory.fromUri(directory).create(recursive: true);
    final File wrapper = File.fromUri(directory.resolve('$name$suffix'));
    final String include = source.replaceAll(r'\', '/');
    await wrapper.writeAsString('#include "$include"\n');
    compiled.add(wrapper.path);
  }
  return compiled;
}
