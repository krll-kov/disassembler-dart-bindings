// Copyright (c) 2026, swiftsoft
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

import '../lib/src/c_library.dart';
import '../lib/src/rust_library.dart';

Future<void> main(List<String> args) async {
  if (args.length != 3 || args[0] != 'android' || args[1] != 'arm64') {
    stderr.writeln(
      'Usage: dart run tool/build_target.dart android arm64 <backends>',
    );
    exitCode = 64;
    return;
  }
  final Uri root = Platform.script.resolve('../');
  final Uri directory = root.resolve('build/android-arm64/');
  final Uri shared = directory.resolve('shared/');
  await Directory.fromUri(shared).create(recursive: true);
  try {
    final BuildInputBuilder builder = BuildInputBuilder()
      ..setupShared(
        packageName: 'disassembler',
        packageRoot: root,
        outputFile: directory.resolve('output.json'),
        outputDirectoryShared: shared,
      )
      ..config.setupBuild(linkingEnabled: false)
      ..addExtension(
        CodeAssetExtension(
          targetOS: OS.android,
          targetArchitecture: Architecture.arm64,
          android: AndroidCodeConfig(targetNdkApi: 21),
          linkModePreference: LinkModePreference.dynamic,
        ),
      );
    final BuildInput input = builder.build();
    final BuildOutputBuilder output = BuildOutputBuilder();
    final List<String> backends = args[2].split(',');
    final configuration = NativeConfiguration({
      'backends': {
        for (final String backend in backends)
          backend: {
            'architectures': switch (backend) {
              'zydis' => ['x86'],
              'exarmo' => ['arm', 'arm64'],
              'capstone' => ['x86', 'arm64'],
              _ => throw ArgumentError('Unknown backend: $backend'),
            },
            'features': backend == 'zydis'
                ? ['decoder', 'encoder', 'formatter']
                : ['decoder'],
          },
      },
    });
    Uri? archive;
    List<String> libraries = const [];
    if (backends.contains('exarmo')) {
      final rust = await buildExarmo(
        root,
        shared,
        input.config.code,
        decoders: configuration.exarmoDecoders,
      );
      archive = rust.archive;
      libraries = rust.libraries;
    }
    final library = disassemblerLibrary(
      root,
      OS.android,
      configuration,
      exarmoArchive: archive,
      exarmoLibraries: libraries,
    );
    await library.build(input: input, output: output);
    await File.fromUri(directory.resolve('output.json')).writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(output.json)}\n',
    );
    final String fileName = OS.android.dylibFileName(library.name);
    final Uri binary = input.outputDirectory.resolve(fileName);
    if (!await File.fromUri(binary).exists()) {
      throw StateError('Android arm64 library was not produced');
    }
    final Uri target = directory.resolve(fileName);
    await File.fromUri(binary).copy(target.toFilePath());
    stdout.writeln('Android arm64 library: ${target.toFilePath()}');
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
