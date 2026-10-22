# Changelog

## 1.0.0

First release

- Zydis for x86 and x64, exarmo for ARM32, Thumb and ARM64, Capstone for 23 architectures, built by the build hooks into one native library with the engines, architectures and features chosen in `pubspec.yaml`
- `Disassembler.decode` returns instruction objects. `DisassemblerBuffer`, `DisassemblerReader` and `DecodedBatch` fill typed arrays in one native call, read by index and by operand row
- `reader.visit` and `reader.decode` with `stopAfter`, `stopAfterInvalid`, `limit` and Thumb IT state across batches
- `DecodeSelection` by control flow and engine id, with brief records or `skipOthers`. `DecodeSelection.arm64Pattern` returns the fixed bits of 4665 of 4746 AArch64 encodings
- `reader.callTargets` returns direct call targets of a range in one native call
- Register ids and names, canonical x86 mnemonics, condition codes and register access per instruction. exarmo register access comes from a table generated from Arm A64 ISA XML
- Link hook on `record_use` strips engine entry points the program does not reference
