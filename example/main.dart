import 'dart:typed_data';

import 'package:disassembler/disassembler.dart';

void main() {
  final Disassembler decoder = Disassembler(
    DisassemblerArch.x64,
    backend: DisassemblerBackend.zydis,
  );
  try {
    final Uint8List bytes = Uint8List.fromList([0x48, 0x89, 0xd8, 0xc3]);
    for (final Instruction instruction in decoder.decode(
      bytes,
      address: 0x1000,
    )) {
      print(
        '${instruction.address.toRadixString(16)}: ${instruction.mnemonic}',
      );
    }
  } finally {
    decoder.close();
  }
}
