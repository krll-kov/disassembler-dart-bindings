// Copyright (c) 2026, swiftsoft
// SPDX-License-Identifier: BSD-3-Clause

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

import '../lib/src/c_library.dart';

Future<void> main(List<String> args) async {
  await build(args, (BuildInput input, BuildOutputBuilder output) async {
    if (!input.config.buildCodeAssets) return;
    output.dependencies.add(input.packageRoot.resolve('capstone.json'));
    await capstoneLibrary(
      input.packageRoot,
      input.config.code.targetOS,
      decoders: input.userDefines['decoders'],
    ).build(input: input, output: output);
  });
}
