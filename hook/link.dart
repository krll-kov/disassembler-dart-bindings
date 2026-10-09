// Copyright (c) 2026, swiftsoft
// SPDX-License-Identifier: BSD-3-Clause

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:record_use/record_use.dart';

import '../lib/src/c_library.dart';
import '../lib/src/third_party/capstone.record_use_mapping.g.dart';

Future<void> main(List<String> args) async {
  await link(args, (LinkInput input, LinkOutputBuilder output) async {
    if (!input.config.buildCodeAssets) return;
    output.dependencies.add(input.packageRoot.resolve('capstone.json'));
    await capstoneLibrary(
      input.packageRoot,
      input.config.code.targetOS,
      decoders: input.userDefines['decoders'],
    ).link(
      input: input,
      output: output,
      linkerOptions: LinkerOptions.treeshake(
        symbolsToKeep: input.recordedUses?.calls.keys.cast<Method>().map(
          (Method method) => recordUseMapping[method.name]!,
        ),
      ),
    );
  });
}
