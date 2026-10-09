// Copyright (c) 2026, swiftsoft
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:io';

import 'package:ffigen/ffigen.dart';

import 'generate_models.dart';

Future<void> main() async {
  final Uri root = Platform.script.resolve('../');
  final Uri include = root.resolve('third_party/capstone/include/');
  await FfiGenerator(
    input: Input(
      entryPoints: [
        include.resolve('capstone/capstone.h'),
        root.resolve('src/abi.h'),
      ],
      include: (Uri header) =>
          header.path.startsWith(include.path) ||
          header == root.resolve('src/abi.h'),
      compilerOptions: ['-I${include.toFilePath()}'],
      appendCompilerOptions: true,
    ),
    output: Output(
      dart: DartOutput(
        path: root.resolve('lib/src/third_party/capstone.g.dart'),
      ),
      recordUseMapping: root.resolve(
        'lib/src/third_party/capstone.record_use_mapping.g.dart',
      ),
      style: const NativeExternalBindings(
        assetId: 'package:capstone/src/third_party/capstone.g.dart',
      ),
      commentType: const CommentType.none(),
      preamble: '''
// By Nguyen Anh Quynh <aquynh@gmail.com>, 2013-2016
// SPDX-License-Identifier: BSD-3-Clause
// Changes to generated bindings are overwritten by tool/ffigen.dart
''',
    ),
    visitors: [
      Visitor(
        func: (Func node) {
          node.isIncluded =
              node.originalName.startsWith('cs_') ||
              node.originalName.startsWith('capstone_');
          node.recordUse = node.isIncluded;
        },
        enumClass: (EnumClass node) {
          node.style = EnumStyle.intConstants;
          node.isIncluded = true;
        },
        struct: (Struct node) {
          node.isIncluded = true;
          node.dependencies = CompoundDependencies.full;
        },
        union: (Union node) {
          node.dependencies = CompoundDependencies.full;
        },
        macroConstant: (MacroConstant node) {
          node.isIncluded = true;
        },
      ),
    ],
  ).generate();
  await generateModels(root);
}
