//! Game numbers are stored as masked bit patterns and unmasked only while
//! a call is running, so a scan of the shipped library does not see the
//! ladders or the hit chances as plain floats.

use core::hint::black_box;

const MASK: u64 = 0xC37A_91E4_6B08_D52F;

pub const fn ef(value: f64) -> u64 {
    value.to_bits() ^ MASK
}

#[inline(never)]
pub fn df(enc: u64) -> f64 {
    f64::from_bits(black_box(enc) ^ black_box(MASK))
}

#[macro_export]
macro_rules! veiled_f {
    ($($name:ident => $value:expr),* $(,)?) => {
        $(
            #[inline]
            pub fn $name() -> f64 {
                const E: u64 = $crate::veil::ef($value);
                $crate::veil::df(E)
            }
        )*
    };
}
