// Copyright (c) 2026, swiftsoft
// SPDX-License-Identifier: BSD-3-Clause

#[cfg(feature = "arm")]
pub use exarmo_aarch32_capi as aarch32;
#[cfg(feature = "aarch64")]
pub use exarmo_aarch64_capi as aarch64;
