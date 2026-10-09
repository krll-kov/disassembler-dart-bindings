# Third-party notices

The Dart package uses BSD-3-Clause in [LICENSE](LICENSE), copyright 2026 swiftsoft. Selected native backends retain their own licenses and copyright notices. The complete upstream license texts are included in this repository.

| Component | License and notices |
| --- | --- |
| Zydis | MIT, [LICENSE](third_party/zydis/LICENSE) |
| Zycore | MIT, [LICENSE](third_party/zycore/LICENSE) |
| exarmo | Apache-2.0, [LICENSE](third_party/exarmo/LICENSE) and [Arm ACLE attribution](third_party/exarmo/aarch64/NOTICE) |
| Capstone | [Capstone license](third_party/capstone/LICENSES/LICENSE.TXT), [BSD-3-Clause](third_party/capstone/LICENSES/LICENSE_BSD_3_CLAUSE.txt), and [LLVM license](third_party/capstone/LICENSES/LICENSE_LLVM.TXT) |
| Rust standard library | [MIT](third_party/rust_runtime/LICENSE-MIT) or [Apache-2.0](third_party/rust_runtime/LICENSE-APACHE), with [complete runtime notices](third_party/rust_runtime/COPYRIGHT-library.html) |
| compiler_builtins 0.1.160 | MIT AND Apache-2.0 WITH LLVM-exception, [complete license](third_party/rust_runtime/compiler_builtins/LICENSE.txt) and [compiler-rt credits](third_party/rust_runtime/compiler_builtins/CREDITS.TXT) |
| libm in compiler_builtins | MIT, [complete license and copyrights](third_party/rust_runtime/libm/LICENSE.txt) |

Zycore is part of Zydis builds. exarmo's generated AArch64 intrinsic tables include Arm ACLE data covered by the attribution in its NOTICE. Capstone includes LLVM-derived source with its original notices.

Rust runtime notices match the validated Rust 1.93.0 builds. exarmo builds use the installed Rust toolchain, so builds with another Rust version need matching runtime notices, including `COPYRIGHT-library.html`, compiler_builtins licenses, and its dependency attribution. Exact notice sources and revisions are recorded in [sources.json](third_party/rust_runtime/sources.json).

Include this file and the applicable complete license texts and notices when distributing a native library or an application containing it. Keep upstream source notices when redistributing source. Exact source revisions are recorded in `zydis.json`, `exarmo.json`, and `capstone.json`.
