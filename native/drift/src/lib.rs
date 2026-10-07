//! Gray-part geometry ledger.
//!
//! Learns, per screen orientation, the camera-cutout inset
//! (top / left / right — never the hidden navigation bar) and hands that
//! cached target back to Dart. A rotation can therefore apply its final
//! geometry in a single frame instead of chasing the system animation.
//!
//! State lives here, in native memory, so it survives WebView widget
//! re-creation (e.g. an offline → retry cycle rebuilds the Dart state
//! but the learned geometry is still warm).
//!
//! This is NOT the crypto guard and NOT the game-math crate — it owns
//! no secrets and does no I/O, so it never shares a fingerprint with
//! `burrow` or `turkey_core`.

use std::sync::Mutex;

#[derive(Clone, Copy)]
struct Slot {
    known: bool,
    top: f64,
    left: f64,
    right: f64,
}

const EMPTY: Slot = Slot {
    known: false,
    top: 0.0,
    left: 0.0,
    right: 0.0,
};

// Slot 0 = portrait, slot 1 = landscape. Only ever touched from the
// UI isolate, so the mutex is uncontended.
static SLOTS: Mutex<[Slot; 2]> = Mutex::new([EMPTY; 2]);

#[inline]
fn idx(orient: u32) -> Option<usize> {
    match orient {
        0 => Some(0),
        1 => Some(1),
        _ => None,
    }
}

/// Records the cutout for `orient` the first time it is seen. Later
/// calls are ignored, so a nav bar that the IME transiently forces on
/// can never churn the cached inset.
#[unsafe(no_mangle)]
pub extern "C" fn df_learn(orient: u32, top: f64, left: f64, right: f64) {
    let Some(i) = idx(orient) else { return };
    if let Ok(mut g) = SLOTS.lock() {
        if !g[i].known {
            g[i].top = top;
            g[i].left = left;
            g[i].right = right;
            g[i].known = true;
        }
    }
}

/// 1 once the cutout for `orient` has been learned, else 0.
#[unsafe(no_mangle)]
pub extern "C" fn df_known(orient: u32) -> i32 {
    let Some(i) = idx(orient) else { return 0 };
    match SLOTS.lock() {
        Ok(g) if g[i].known => 1,
        _ => 0,
    }
}

/// Returns a cutout field for `orient`: 0 = top, 1 = left, 2 = right.
#[unsafe(no_mangle)]
pub extern "C" fn df_cut(orient: u32, field: u32) -> f64 {
    let Some(i) = idx(orient) else { return 0.0 };
    let Ok(g) = SLOTS.lock() else { return 0.0 };
    match field {
        0 => g[i].top,
        1 => g[i].left,
        2 => g[i].right,
        _ => 0.0,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn learns_cutout_once_per_orientation() {
        df_learn(0, 44.0, 0.0, 0.0);
        // A second learn for the same orientation is ignored.
        df_learn(0, 99.0, 9.0, 9.0);
        assert_eq!(df_known(0), 1);
        assert_eq!(df_cut(0, 0), 44.0);
        assert_eq!(df_cut(0, 1), 0.0);
        assert_eq!(df_cut(0, 2), 0.0);

        // An out-of-range orientation is a no-op.
        df_learn(7, 1.0, 1.0, 1.0);
        assert_eq!(df_known(7), 0);
    }
}
