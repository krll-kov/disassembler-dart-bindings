# Capstone for Dart

Native instruction decoding with every backend from Capstone 6.0.0-Alpha11. The package builds Capstone through Dart code asset hooks and includes generated FFI bindings and typed instruction details. Decoded files are data. Their code is never executed by the decoder.

Add the package as a Git dependency:

```yaml
dependencies:
  capstone:
    git:
      url: https://github.com/krll-kov/capstone-dart-bindings
```

The native library must match the Dart process architecture. Decoder backends decode instructions independently of that process architecture. For example, a macOS arm64 process can decode x64 Windows instructions.

## Decoder selection

All 23 backends are enabled by default. Select backends in the consuming project's `pubspec.yaml`:

```yaml
hooks:
  user_defines:
    capstone:
      decoders: [x86, aarch64]
```

Available values are `arm`, `aarch64`, `m68k`, `mips`, `ppc`, `sparc`, `systemz`, `xcore`, `x86`, `tms320c64x`, `m680x`, `evm`, `mos65xx`, `wasm`, `bpf`, `riscv`, `sh`, `tricore`, `alpha`, `hppa`, `loongarch`, `xtensa` and `arc`. `x86` includes 16-bit, 32-bit and 64-bit decoding. Select `[x86]` to compile only that backend. The list must be nonempty and contain valid backend values. Trying to open an excluded architecture throws `CapstoneException`.

## Decode bytes

```dart
import 'dart:typed_data';

import 'package:capstone/capstone.dart';
import 'package:capstone/constants.dart' as native;

void main() {
  final Capstone decoder = Capstone(Architecture.x86, mode: Mode.mode64);
  try {
    final Uint8List bytes = Uint8List.fromList([0x48, 0x8b, 0x43, 0x08, 0xc3]);
    decoder.visit(bytes, (Instruction instruction) {
      print('${instruction.address.toRadixString(16)}: '
          '${instruction.mnemonic} ${instruction.operandsText}');
      final ArchitectureDetails? details = instruction.details;
      if (details is X86Details) {
        for (final CsX86Op operand in details.operands.take(details.op_count)) {
          if (operand.type == native.x86_op_type.X86_OP_MEM) {
            print('Displacement: ${operand.unnamed.mem.disp}');
          }
        }
      }
      return instruction.mnemonic != 'ret';
    }, address: 0x1000);
  } finally {
    decoder.close();
  }
}
```

`visit` stops when the callback returns `false` and does not retain an instruction list. `decode` returns a list of all decoded instructions. Both methods copy the input bytes into native memory for the duration of decoding. Call `close` when finished to release decoder resources.

`Instruction.details` contains an architecture-specific model such as `X86Details`, `Aarch64Details` or `ArmDetails`. Models preserve every field from the corresponding C detail structure. For operand arrays, use `op_count` to select populated entries. Returned values retain no native pointers and remain valid after `close`. Models retain C field identifiers and ffigen's anonymous union accessors.

For repeated ranges, create `CapstoneBuffer` once and reuse `decoder.reader(buffer)`. Each `visit` accepts byte offsets `start` and `end`, plus the virtual `address` of the first instruction. Separate decoders can share one buffer. Close readers before closing the buffer and decoders.

```dart
final CapstoneBuffer buffer = CapstoneBuffer(bytes);
try {
  final CapstoneReader reader = decoder.reader(buffer);
  try {
    reader.visit((NativeInstructionView instruction) {
      print(instruction.id);
      print(instruction.registersWritten);
      return true;
    }, start: 0, end: bytes.length, address: 0x1000);
  } finally {
    reader.close();
  }
} finally {
  buffer.close();
}
```

`NativeInstructionView.value` and `details` expose generated C structures without copying every architecture field. These structures and register lists are valid only during the callback. Use `instruction.copy()` for an owned `Instruction` that remains valid afterwards. Accessing an expired view throws `StateError`. `registersRead` and `registersWritten` are `null` when details are disabled or the backend does not support register access analysis.

`package:capstone/native.dart` exports the complete generated C API. `package:capstone/constants.dart` exports generated enums and macros. `package:capstone/instructions.dart` exports the same constants for instruction comparisons. FFI allocation and resource release are explicit when using `native.dart` directly.

Capstone Alpha11 reports `access = 0` and `avx_bcast = 0` for masked broadcast `VADDPS` bytes `62 f1 5c db 58 10`, and no groups for `VXORPS` bytes `62 f1 7c c9 57 c0`. This package preserves those native values. Upstream instruction details can be incomplete.

## Build requirements

Dart 3.13 or later and a native C toolchain are required. Use Xcode Command Line Tools on macOS, Visual Studio C++ Build Tools on Windows, and the Android NDK for Android builds. Normal Dart or Flutter build commands run the hooks.

iOS builds require full Xcode with the iOS SDK. Linux builds require GCC or Clang.

Flutter bundles the native library for the selected target platform:

| Platform | Library in the application | Location |
| --- | --- | --- |
| Windows | `lib_capstone_windows_plugin.dll` | Beside the application `.exe` |
| Linux | `lib_capstone_linux_plugin.so` | Application bundle's `lib/` directory |
| Android | `lib_capstone_android_plugin.so` | APK's `lib/<ABI>/` directory |
| macOS | `lib_capstone_macos_plugin.framework` | Application's `Contents/Frameworks/` directory |
| iOS | `lib_capstone_ios_plugin.framework` | Application's `Frameworks/` directory |

On Apple platforms, the compiler produces `liblib_capstone_macos_plugin.dylib` or `liblib_capstone_ios_plugin.dylib`. Flutter removes the compiler's leading `lib` when creating the framework, preserving `lib_` in the final framework name. Dart CLI bundles retain the `.dylib` filename. FFI asset identifiers remain unchanged, so application code does not need platform-specific library paths.

Windows builds use `/MD`, with the dynamic Microsoft C runtime. `/MT` is not used. The x64 `/MD` build imports `VCRUNTIME140.dll`, `KERNEL32.dll` and these Universal C Runtime contracts:

- `api-ms-win-crt-heap-l1-1-0.dll`
- `api-ms-win-crt-stdio-l1-1-0.dll`
- `api-ms-win-crt-string-l1-1-0.dll`
- `api-ms-win-crt-convert-l1-1-0.dll`
- `api-ms-win-crt-runtime-l1-1-0.dll`

Windows 10 and 11 provide Universal C Runtime and `KERNEL32.dll` through the operating system. [Microsoft documents UCRT deployment](https://learn.microsoft.com/en-us/cpp/windows/universal-crt-deployment). Install the [Microsoft Visual C++ Redistributable](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist) matching the x64 library and a version at least as recent as the MSVC build tools to provide `VCRUNTIME140.dll`. This C library does not require `MSVCP140.dll` or `VCRUNTIME140_1.dll`. These imports were confirmed in the packaged x64 library.

Flutter Windows apps already require the same Visual C++ runtime family. [Flutter's deployment guidance](https://docs.flutter.dev/platform-integration/windows/building#distributing-windows-apps) lists `msvcp140.dll`, `vcruntime140.dll` and `vcruntime140_1.dll`. Capstone's C build uses `vcruntime140.dll` from that set. The installed runtime must still match the compiler version and library architecture.

Generated bindings are included in the repository. Consumers do not run ffigen or need libclang. Maintainers need Git and LLVM/libclang to regenerate bindings.

## Source version

Capstone is pinned to upstream tag `6.0.0-Alpha11`, commit `b2bf6327b5c7dc43829130b7ccdb02ef9a65a990`. Update metadata is stored in `capstone.json`. It also contains exact engine and backend C source lists and compiler definitions from upstream CMake. Vendored source retains upstream license notices and line endings. Backend builds keep instruction detail support enabled.

## Validation targets

| Native library target | Validation status |
| --- | --- |
| macOS arm64 | 100 tests passed with all 23 backends, AOT build and link passed |
| Windows x64 | 100 tests passed with all 23 backends on Windows 11 ARM64 VM, x64 runtime imports confirmed |
| Android arm64 | All 23 backends compiled with NDK r28c for API 21, runtime not tested |
| iOS arm64 | All 23 backends compiled with iOS 27 SDK for iOS 15 or later, Flutter framework packaging and ad-hoc signature verified, runtime not tested |

The earlier x86/AArch64 build passed 43 tests before all-backend integration.

ABI tests compare generated Dart struct sizes with sizes from the C compiler. Native compile assertions also check enum widths. Decoder tests use instruction bytes as input and do not load or execute PE files. The 284 expectations in `test/_data/universal_upstream_oracles.json` derive from pinned upstream `tests/details/*.yaml` across all 23 backends and retain Capstone's existing licenses.

Compile the Android arm64 library with an installed Android NDK:

```sh
dart run tool/build_target.dart android arm64
```

This produces `build/android-arm64/lib_capstone_android_plugin.so` for Android API 21 or later. The command compiles the library and does not run it. CI runs native tests on macOS arm64 and Windows x64 and checks Android arm64 compilation on Ubuntu.

## Update Capstone

From the package directory, resolve development dependencies and select an exact upstream tag:

```sh
dart pub get
dart run tool/update_capstone.dart 6.0.0-Alpha11
```

The updater clones the official repository at that tag, checks its commit, validates the selected C files against upstream CMake lists, replaces vendored source and records the tag and commit. It then regenerates bindings, runs analysis and runs tests. A failed check returns a nonzero exit code. Review source and generated changes before releasing an update. Native tests on the other targets must also pass before declaring them validated.

## Licenses

The Dart wrapper, hooks and maintenance tools use the BSD 3-Clause license in `LICENSE`, copyright 2026 swiftsoft. Capstone and its LLVM-derived code retain their original notices and the complete files in `third_party/capstone/LICENSES`. Include those notices with binary distributions.
