// Copyright (c) 2026, swiftsoft
// SPDX-License-Identifier: BSD-3-Clause

#![no_std]

#[cfg(feature = "arm")]
pub use exarmo_aarch32_capi as aarch32;
#[cfg(feature = "aarch64")]
pub use exarmo_aarch64_capi as aarch64;

/// Precompiled `core` references it even with `panic = "abort"`, and nothing
/// unwinds through Rust frames, since a panic leaves by `longjmp`
#[cfg(not(target_env = "msvc"))]
#[unsafe(no_mangle)]
extern "C" fn rust_eh_personality() {}

/// Returns 1 when `fail` panics inside `guarded`, so tests can check that a
/// panic returns to the C API instead of ending the process
#[unsafe(no_mangle)]
pub extern "C" fn disassembler_exarmo_guard_probe(fail: bool) -> u32 {
    exarmo_core::capi::guarded(1, || if fail { panic!() } else { 2 })
}
