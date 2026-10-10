import 'dart:io';

import 'package:ffigen/ffigen.dart';

Future<void> main() async {
  final Uri root = Platform.script.resolve('../');
  await FfiGenerator(
    input: Input(entryPoints: [root.resolve('src/disassembler.h')]),
    output: Output(
      dart: DartOutput(
        path: root.resolve('lib/src/third_party/disassembler.g.dart'),
      ),
      recordUseMapping: root.resolve(
        'lib/src/third_party/disassembler.record_use_mapping.g.dart',
      ),
      style: const NativeExternalBindings(
        assetId: 'package:disassembler/disassembler.dart',
      ),
      commentType: const CommentType.none(),
    ),
    visitors: [
      Visitor(
        func: (Func node) {
          node.isIncluded = node.originalName.startsWith('disassembler_');
          node.recordUse = node.isIncluded;
        },
        struct: (Struct node) {
          node.isIncluded = node.originalName.startsWith('disassembler_');
          node.dependencies = CompoundDependencies.full;
        },
        macroConstant: (MacroConstant node) {
          node.isIncluded = node.originalName.startsWith('DISASSEMBLER_');
        },
      ),
    ],
  ).generate();
}
