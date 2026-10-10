part of '../disassembler.dart';

final class _ZydisBackend extends _Backend {
  final zydis.Zydis engine;
  final Map<int, String> _mnemonics = {};
  final Map<int, String> _canonical = {};

  factory _ZydisBackend(DisassemblerArch architecture) {
    if (architecture != DisassemblerArch.x86 &&
        architecture != DisassemblerArch.x64) {
      throw UnsupportedError('Zydis does not support $architecture');
    }
    return _ZydisBackend._(
      zydis.Zydis(
        machineMode: architecture == DisassemblerArch.x64
            ? zy.ZydisMachineMode.ZYDIS_MACHINE_MODE_LONG_64
            : zy.ZydisMachineMode.ZYDIS_MACHINE_MODE_LEGACY_32,
        stackWidth: architecture == DisassemblerArch.x64
            ? zy.ZydisStackWidth.ZYDIS_STACK_WIDTH_64
            : zy.ZydisStackWidth.ZYDIS_STACK_WIDTH_32,
      ),
    );
  }

  _ZydisBackend._(this.engine);

  @override
  String mnemonic(int key) => _mnemonics.putIfAbsent(
    key,
    () => zy.ZydisMnemonicGetString(key).cast<Utf8>().toDartString(),
  );

  @override
  String canonicalMnemonic(int key) =>
      _canonical.putIfAbsent(key, () => _x86CanonicalMnemonic(mnemonic(key)));

  @override
  String registerName(int register) =>
      register == 0 ? '' : engine.registerName(register);

  @override
  int registerId(String name) => engine.registerId(name);

  @override
  InstructionDetails details(DecodedBatch batch, int index) =>
      ZydisInstructionDetails(
        engine
            .decode(
              batch.bytes(index),
              address: batch.address(index),
              invalid: zydis.ZydisInvalidPolicy.skipByte,
            )
            .first,
      );

  @override
  void close() => engine.close();
}

String _x86CanonicalMnemonic(String mnemonic) => switch (mnemonic) {
  'jz' => 'je',
  'jnz' => 'jne',
  'jc' || 'jnae' => 'jb',
  'jnc' || 'jnb' => 'jae',
  'jna' => 'jbe',
  'jnbe' => 'ja',
  'jpe' => 'jp',
  'jpo' => 'jnp',
  'jnge' => 'jl',
  'jnl' => 'jge',
  'jng' => 'jle',
  'jnle' => 'jg',
  'sal' => 'shl',
  _ => mnemonic,
};
