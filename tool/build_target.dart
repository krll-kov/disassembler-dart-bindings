// Copyright (c) 2026, swiftsoft
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

import '../lib/src/c_library.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2 || args[0] != 'android' || args[1] != 'arm64') {
    stderr.writeln('Usage: dart run tool/build_target.dart android arm64');
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
        packageName: 'capstone',
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
    await capstoneLibrary(root, OS.android).build(input: input, output: output);
    await File.fromUri(directory.resolve('output.json')).writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(output.json)}\n',
    );
    final Uri library = input.outputDirectory.resolve('libcapstone.so');
    if (!await File.fromUri(library).exists()) {
      throw StateError('Android arm64 library was not produced');
    }
    final Uri target = directory.resolve('libcapstone.so');
    await File.fromUri(library).copy(target.toFilePath());
    stdout.writeln('Android arm64 library: ${target.toFilePath()}');
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
