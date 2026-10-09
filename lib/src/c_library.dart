// Copyright (c) 2026, swiftsoft
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

CLibrary capstoneLibrary(Uri root, OS targetOS, {Object? decoders}) {
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
  final String prefix = switch (targetOS) {
    OS.windows => 'lib_',
    // Flutter strips lib from Apple frameworks, so this extra prefix
    // preserves lib_ in their final filenames
    OS.macOS || OS.iOS => 'lib_',
    _ => '_',
  };
  return CLibrary(
    name: '${prefix}capstone_${targetOS.name}_plugin',
    assetName: 'src/third_party/capstone.g.dart',
    sources: sources,
    includes: [source.resolve('include/').toFilePath()],
    defines: {
      for (final Map<String, Object?> backend in backends)
        for (final String define in (backend['defines'] as List).cast<String>())
          define: null,
      'CAPSTONE_USE_SYS_DYN_MEM': null,
      'CAPSTONE_SHARED': null,
    },
    std: targetOS == OS.windows ? 'c11' : 'c99',
    flags: [if (targetOS == OS.windows) '/MD'],
  );
}
