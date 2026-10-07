//! One crossing. The trap mask stays here; Flutter only asks whether the
//! lane it is about to enter is hot.

use crate::roll::Roll;
use crate::table::{self, payout as pay};

pub struct Round {
    pub diff: u32,
    pub stake: f64,
    pub(crate) lane: i32,
    hits: u32,
}

pub fn open(diff: u32, stake: f64, seed: u64) -> Round {
    let n = table::lanes(diff);
    let chance = table::chance(diff);
    let mut roll = Roll::new(seed);
    let mut hits = 0u32;
    for i in 0..n {
        if roll.unit() < chance {
            hits |= 1 << i;
        }
    }
    Round {
        diff,
        stake: stake.max(0.0),
        lane: -1,
        hits,
    }
}

pub fn set_lane(round: &mut Round, lane: i32) {
    let last = table::lanes(round.diff) as i32 - 1;
    round.lane = if lane < -1 {
        -1
    } else if lane > last {
        last
    } else {
        lane
    };
}

pub fn multiplier(round: &Round) -> f64 {
    if round.lane < 0 {
        const E: u64 = crate::veil::ef(1.0);
        crate::veil::df(E)
    } else {
        table::step(round.diff, round.lane as u32)
    }
}

pub fn payout(round: &Round) -> f64 {
    pay(round.stake, multiplier(round), round.lane)
}

pub fn dies_on_next(round: &Round) -> bool {
    let to = round.lane + 1;
    let n = table::lanes(round.diff) as i32;
    if to < 0 || to >= n {
        return false;
    }
    (round.hits >> to) & 1 == 1
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn same_seed_deals_the_same_mask() {
        let a = open(3, 20.0, 4);
        let b = open(3, 20.0, 4);
        assert_eq!(a.hits, b.hits);
        assert_eq!(a.hits >> table::lanes(3), 0);
        assert_eq!(a.lane, -1);
        assert_ne!(open(3, 20.0, 4).hits, open(3, 20.0, 5).hits);
    }

    #[test]
    fn upcoming_trap_is_the_only_one_reported() {
        let mut round = Round {
            diff: 0,
            stake: 10.0,
            lane: -1,
            hits: 0b100,
        };
        assert!(!dies_on_next(&round));
        set_lane(&mut round, 1);
        assert!(dies_on_next(&round));
        set_lane(&mut round, 2);
        assert!(!dies_on_next(&round));
        set_lane(&mut round, 99);
        assert_eq!(round.lane, 17);
        assert!(!dies_on_next(&round));
    }

    #[test]
    fn first_step_payout_matches_the_table() {
        let mut round = open(0, 10.0, 1);
        assert_eq!(payout(&round), 10.0);
        set_lane(&mut round, 0);
        assert_eq!(payout(&round), 11.0);
    }
}
