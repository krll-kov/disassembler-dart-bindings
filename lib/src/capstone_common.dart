part of '../disassembler.dart';

final class _CapstoneBackend extends _Backend {
  final DisassemblerArch architecture;
  final capstone.Capstone engine;
  final List<String?> _mnemonics = [];
  final Map<int, String> _canonical = {};
  Map<String, int>? _registerIds;
  Pointer<Void> _context = nullptr;

  _CapstoneBackend(this.architecture)
    : engine = capstone.Capstone(
        switch (architecture) {
          DisassemblerArch.x86 ||
          DisassemblerArch.x64 => capstone.Architecture.x86,
          DisassemblerArch.arm ||
          DisassemblerArch.thumb => capstone.Architecture.arm,
          DisassemblerArch.arm64 => capstone.Architecture.aarch64,
        },
        mode: switch (architecture) {
          DisassemblerArch.x86 => capstone.Mode.mode32,
          DisassemblerArch.x64 => capstone.Mode.mode64,
          DisassemblerArch.thumb => capstone.Mode.thumb,
          _ => 0,
        },
      );

  @override
  String mnemonic(int key) {
    while (_mnemonics.length <= key) {
      _mnemonics.add(null);
    }
    return _mnemonics[key] ??= native
        .disassembler_mnemonic(_context, key)
        .cast<Utf8>()
        .toDartString();
  }

  @override
  String canonicalMnemonic(int key) => _canonical.putIfAbsent(
    key,
    () => engine.instructionName(key).toLowerCase(),
  );

  @override
  String registerName(int register) => engine.registerName(register);

  @override
  int registerId(String name) {
    final int end = switch (architecture) {
      DisassemblerArch.x86 || DisassemblerArch.x64 => cs.x86_reg.X86_REG_ENDING,
      DisassemblerArch.arm ||
      DisassemblerArch.thumb => cs.arm_reg.ARM_REG_ENDING,
      DisassemblerArch.arm64 => cs.aarch64_reg.AARCH64_REG_ENDING,
    };
    _registerIds ??= {
      for (int id = 1; id < end; id++)
        if (engine.registerName(id).isNotEmpty) engine.registerName(id): id,
    };
    return _registerIds![name.toLowerCase()] ?? 0;
  }

  @override
  InstructionDetails details(DecodedBatch batch, int index) {
    final List<capstone.Instruction> decoded = engine.decode(
      batch.bytes(index),
      address: batch.address(index),
    );
    return CapstoneInstructionDetails(
      decoded.isNotEmpty && decoded.first.size == batch.size(index)
          ? decoded.first
          : capstone.Instruction(
              address: batch.address(index),
              size: batch.size(index),
              id: 0,
              aliasId: 0,
              isAlias: false,
              usesAliasDetails: false,
              illegal: false,
              mnemonic: '.byte',
              operandsText: '',
              bytes: batch.bytes(index),
              implicitRegistersRead: const [],
              implicitRegistersWritten: const [],
              groups: const [],
              writeback: false,
              registerAccess: null,
              details: null,
            ),
    );
  }

  @override
  void close() => engine.close();
}
