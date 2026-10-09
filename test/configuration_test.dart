// Copyright (c) 2026, swiftsoft
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:test/test.dart';

import '../lib/src/c_library.dart';

void main() {
  final Uri root = Uri.base;
  final Map<String, Object?> manifest = (jsonDecode(
    File.fromUri(root.resolve('capstone.json')).readAsStringSync(),
  ) as Map).cast<String, Object?>();
  final Map<String, Object?> backends = (manifest['decoders'] as Map)
      .cast<String, Object?>();
  test('Defaults include every upstream backend', () {
    final library = capstoneLibrary(root, OS.macOS);
    final Set<String> expected = {
      ...(manifest['engine'] as List).cast<String>(),
      for (final Object? value in backends.values)
        ...(((value as Map)['sources']) as List).cast<String>(),
    };
    expect(library.sources.length, expected.length + 1);
    for (final String file in expected) {
      expect(
        library.sources,
        contains(root.resolve('third_party/capstone/$file').toFilePath()),
      );
    }
  });
  for (final String decoder in backends.keys) {
    test('$decoder excludes other decoder sources', () {
      final library = capstoneLibrary(root, OS.macOS, decoders: [decoder]);
      final Map backend = backends[decoder] as Map;
      final List<String> defines = (backend['defines'] as List).cast<String>();
      expect(
        library.defines.keys.where(
          (String define) => define.startsWith('CAPSTONE_HAS_'),
        ),
        defines.where((String define) => define.startsWith('CAPSTONE_HAS_')),
      );
      expect(
        library.sources.length,
        (manifest['engine'] as List).length +
            (backend['sources'] as List).length +
            1,
      );
      for (final String file in (backend['sources'] as List).cast<String>()) {
        expect(
          library.sources,
          contains(root.resolve('third_party/capstone/$file').toFilePath()),
        );
      }
    });
  }
  for (final Object value in [
    [],
    ['arm64'],
    ['x86', null],
    'x86',
    7,
    {},
  ]) {
    test('Rejects decoder configuration $value', () {
      expect(
        () => capstoneLibrary(root, OS.macOS, decoders: value),
        throwsArgumentError,
      );
    });
  }
  test('Windows uses dynamic C runtime', () {
    expect(capstoneLibrary(root, OS.windows).flags, ['/MD']);
  });
}
