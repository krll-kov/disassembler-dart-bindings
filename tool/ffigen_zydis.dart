import 'dart:io';

import 'package:ffigen/ffigen.dart';

import 'generate_models_zydis.dart';

Future<void> main() async {
  final Uri root = Platform.script.resolve('../');
  final Uri include = root.resolve('third_party/zydis/include/');
  final Uri coreInclude = root.resolve('third_party/zycore/include/');
  await FfiGenerator(
    input: Input(
      entryPoints: [include.resolve('Zydis/Zydis.h')],
      include: (Uri header) =>
          header.path.startsWith(include.path) ||
          header.path.startsWith(coreInclude.path),
      compilerOptions: [
        '-I${include.toFilePath()}',
        '-I${coreInclude.toFilePath()}',
        '-DZYDIS_STATIC_BUILD',
        '-DZYCORE_STATIC_BUILD',
      ],
      appendCompilerOptions: true,
    ),
    output: Output(
      dart: DartOutput(path: root.resolve('lib/src/third_party/zydis.g.dart')),
      recordUseMapping: root.resolve(
        'lib/src/third_party/zydis.record_use_mapping.g.dart',
      ),
      style: const NativeExternalBindings(
        assetId: 'package:disassembler/disassembler.dart',
      ),
      commentType: const CommentType.none(),
      preamble: '''
// Copyright (c) 2014-2024 Florian Bernd
// Copyright (c) 2014-2024 Joel Höner
// SPDX-License-Identifier: MIT
// Changes to generated bindings are overwritten by tool/ffigen_zydis.dart
''',
    ),
    visitors: [
      Visitor(
        func: (Func node) {
          node.isIncluded = node.originalName.startsWith('Zydis');
          node.recordUse = node.isIncluded;
        },
        enumClass: (EnumClass node) {
          node.isIncluded = node.originalName.startsWith('Zydis');
          node.style = EnumStyle.intConstants;
          node.name = node.originalName.replaceFirst(RegExp(r'_$'), '');
        },
        struct: (Struct node) {
          node.isIncluded = node.originalName.startsWith('Zydis');
          node.dependencies = CompoundDependencies.full;
          if (node.isIncluded) {
            node.name = node.originalName.replaceFirst(RegExp(r'_$'), '');
          }
        },
        union: (Union node) {
          node.dependencies = CompoundDependencies.full;
          if (node.originalName.startsWith('Zydis')) {
            node.name = node.originalName.replaceFirst(RegExp(r'_$'), '');
          }
        },
        macroConstant: (MacroConstant node) {
          node.isIncluded = node.originalName.startsWith('ZYDIS_');
        },
      ),
    ],
  ).generate();
  await generateZydisModels(root);
}
