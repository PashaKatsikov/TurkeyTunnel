//! Difficulty ladders and the cash-out formula.

use crate::veil::{self, df};

const EASY: [u64; 18] = [
    veil::ef(1.01),
    veil::ef(1.03),
    veil::ef(1.06),
    veil::ef(1.10),
    veil::ef(1.15),
    veil::ef(1.21),
    veil::ef(1.28),
    veil::ef(1.36),
    veil::ef(1.46),
    veil::ef(1.58),
    veil::ef(1.72),
    veil::ef(1.89),
    veil::ef(2.09),
    veil::ef(2.34),
    veil::ef(2.64),
    veil::ef(3.02),
    veil::ef(3.48),
    veil::ef(4.05),
];

const MEDIUM: [u64; 15] = [
    veil::ef(1.18),
    veil::ef(1.46),
    veil::ef(1.83),
    veil::ef(2.31),
    veil::ef(2.95),
    veil::ef(3.82),
    veil::ef(5.02),
    veil::ef(6.68),
    veil::ef(9.04),
    veil::ef(12.40),
    veil::ef(17.30),
    veil::ef(24.60),
    veil::ef(35.60),
    veil::ef(52.40),
    veil::ef(78.80),
];

const HARD: [u64; 12] = [
    veil::ef(1.44),
    veil::ef(2.21),
    veil::ef(3.45),
    veil::ef(5.53),
    veil::ef(9.09),
    veil::ef(15.30),
    veil::ef(26.78),
    veil::ef(48.70),
    veil::ef(92.54),
    veil::ef(185.08),
    veil::ef(392.0),
    veil::ef(880.0),
];

const HARDCORE: [u64; 10] = [
    veil::ef(2.10),
    veil::ef(4.40),
    veil::ef(9.60),
    veil::ef(21.50),
    veil::ef(50.0),
    veil::ef(122.0),
    veil::ef(310.0),
    veil::ef(840.0),
    veil::ef(2400.0),
    veil::ef(7200.0),
];

const CHANCES: [u64; 4] = [
    veil::ef(0.08),
    veil::ef(0.15),
    veil::ef(0.22),
    veil::ef(0.36),
];

fn rows(diff: u32) -> &'static [u64] {
    match diff {
        0 => &EASY,
        1 => &MEDIUM,
        2 => &HARD,
        3 => &HARDCORE,
        _ => &[],
    }
}

fn coin() -> f64 {
    const E: u64 = veil::ef(1.0);
    df(E)
}

pub fn lanes(diff: u32) -> u32 {
    rows(diff).len() as u32
}

pub fn chance(diff: u32) -> f64 {
    match diff {
        0..=3 => df(CHANCES[diff as usize]),
        _ => 0.0,
    }
}

pub fn step(diff: u32, index: u32) -> f64 {
    match rows(diff).get(index as usize) {
        Some(enc) => df(*enc),
        None => 0.0,
    }
}

/// `(stake * multiplier)` rounded to a coin. A step that rounds back down
/// to the stake still pays one coin more, so the first easy hatch is not
/// a wash. Before the first step the multiplier is 1 and the result is
/// the stake itself.
pub fn payout(stake: f64, multiplier: f64, lane: i32) -> f64 {
    let raw = (stake * multiplier).round();
    if lane >= 0 && raw <= stake {
        stake + coin()
    } else {
        raw
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ladders_climb() {
        for diff in 0..4 {
            let n = lanes(diff);
            assert!(n > 0);
            assert!(step(diff, 0) > 1.0);
            for i in 1..n {
                assert!(step(diff, i) > step(diff, i - 1));
            }
            assert_eq!(step(diff, n), 0.0);
        }
        assert_eq!(lanes(9), 0);
        assert_eq!(chance(9), 0.0);
    }

    #[test]
    fn known_ends_decode() {
        assert_eq!(chance(0), 0.08);
        assert_eq!(chance(1), 0.15);
        assert_eq!(chance(2), 0.22);
        assert_eq!(chance(3), 0.36);
        assert_eq!(lanes(0), 18);
        assert_eq!(lanes(1), 15);
        assert_eq!(lanes(2), 12);
        assert_eq!(lanes(3), 10);
        assert_eq!(step(0, 0), 1.01);
        assert_eq!(step(0, 17), 4.05);
        assert_eq!(step(1, 14), 78.80);
        assert_eq!(step(2, 11), 880.0);
        assert_eq!(step(3, 8), 2400.0);
        assert_eq!(step(3, 9), 7200.0);
    }

    #[test]
    fn flat_step_pays_a_coin_and_idle_refunds() {
        assert_eq!(payout(10.0, step(0, 0), 0), 11.0);
        assert_eq!(payout(2.0, step(0, 0), 0), 3.0);
        assert_eq!(payout(10.0, step(1, 0), 0), 12.0);
        assert_eq!(payout(10.0, 1.0, -1), 10.0);
        assert_eq!(payout(20.0, step(3, 9), 9), 144_000.0);
    }

    #[test]
    fn stored_bits_are_not_the_plain_value() {
        assert_ne!(veil::ef(7200.0), 7200.0f64.to_bits());
        assert_eq!(veil::df(veil::ef(7200.0)), 7200.0);
        assert_ne!(veil::ef(0.08), 0.08f64.to_bits());
    }
}
