//! C ABI used by lib/core/turkey_core.dart.
//!
//! Stateless math goes through `k7`, keyed by a selector, so the export
//! table does not name the ladders. A live round is an opaque pointer
//! from `r0`. Keep the selector numbers in sync with the Dart side.

use core::ffi::c_void;

use crate::round::Round;
use crate::{purse, round, table};

fn flag(value: bool) -> f64 {
    if value { 1.0 } else { 0.0 }
}

#[unsafe(no_mangle)]
pub extern "C" fn k7(sel: u32, a: f64, b: f64, c: f64, _d: f64, _e: f64) -> f64 {
    match sel {
        1 => table::lanes(a as u32) as f64,
        2 => table::chance(a as u32),
        3 => table::step(a as u32, b as u32),
        4 => table::payout(a, b, c as i32),
        5 => purse::min_stake(),
        6 => purse::opening_balance(),
        7 => purse::pocket(),
        8 => purse::starting_stake(),
        9 => purse::fit_stake(a, b),
        10 => purse::nudge(a, b, c),
        11 => flag(purse::can_spend(a, b)),
        12 => purse::debit(a, b),
        13 => purse::credit(a, b),
        14 => purse::stake_after_spend(a, b),
        15 => purse::non_negative(a),
        16 => flag(purse::is_broke(a)),
        _ => 0.0,
    }
}

fn with_round<T>(handle: *mut c_void, fallback: T, f: impl FnOnce(&mut Round) -> T) -> T {
    if handle.is_null() {
        return fallback;
    }
    // SAFETY: non-null handles only come from `r0` and are freed once by `r1`.
    let round = unsafe { &mut *(handle as *mut Round) };
    f(round)
}

#[unsafe(no_mangle)]
pub extern "C" fn r0(diff: u32, stake: f64, seed: u64) -> *mut c_void {
    Box::into_raw(Box::new(round::open(diff, stake, seed))) as *mut c_void
}

#[unsafe(no_mangle)]
pub extern "C" fn r1(handle: *mut c_void) {
    if handle.is_null() {
        return;
    }
    // SAFETY: the pointer was produced by `r0` and this is the single free.
    unsafe {
        drop(Box::from_raw(handle as *mut Round));
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn r2(handle: *mut c_void, sel: u32, a: f64) -> f64 {
    with_round(handle, 0.0, |round| match sel {
        1 => round.lane as f64,
        2 => {
            round::set_lane(round, a as i32);
            round.lane as f64
        }
        3 => round::multiplier(round),
        4 => round::payout(round),
        5 => flag(round::dies_on_next(round)),
        6 => table::lanes(round.diff) as f64,
        7 => round.stake,
        _ => 0.0,
    })
}
