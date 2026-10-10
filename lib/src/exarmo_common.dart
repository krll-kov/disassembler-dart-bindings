part of '../disassembler.dart';

final class _ExarmoBackend extends _Backend {
  final exarmo.Exarmo _decoder;
  final Map<int, String> _mnemonics = {};

  _ExarmoBackend(DisassemblerArch architecture)
    : _decoder = exarmo.Exarmo(switch (architecture) {
        .arm64 => .aarch64,
        .arm => .arm,
        .thumb => .thumb,
        _ => throw UnsupportedError('Exarmo does not decode $architecture'),
      });

  @override
  String mnemonic(int key) =>
      _mnemonics.putIfAbsent(key, () => _decoder.mnemonicName(key));

  @override
  String canonicalMnemonic(int key) => mnemonic(key);

  @override
  String registerName(int register) => _decoder.registerName(register);

  @override
  int registerId(String name) => _decoder.registerId(name);

  @override
  InstructionDetails details(DecodedBatch batch, int index) {
    final int status = batch.status(index);
    if (status != 0) return InvalidInstructionDetails(status);
    final int state = batch._itState(index);
    return ExarmoInstructionDetails(
      _decoder
          .decode(
            batch.bytes(index),
            address: batch.address(index),
            count: 1,
            itState: _decoder.mode == .thumb
                ? exarmo.ExarmoAarch32ItState(
                    kind: state & 0xff,
                    cond: (state >> 8) & 0xff,
                    mask: (state >> 16) & 0xff,
                  )
                : null,
          )
          .single,
    );
  }

  @override
  void close() => _decoder.close();
}
