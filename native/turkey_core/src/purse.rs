//! Stake limits, the opening purse and the refill.

crate::veiled_f! {
    min_stake => 2.0,
    opening_balance => 1000.0,
    pocket => 200.0,
    starting_stake => 10.0,
    step_mid_at => 20.0,
    step_fast_at => 100.0,
    step_slow => 1.0,
    step_mid => 5.0,
    step_fast => 10.0,
}

pub fn non_negative(value: f64) -> f64 {
    if value < 0.0 { 0.0 } else { value }
}

pub fn is_broke(balance: f64) -> bool {
    balance < min_stake()
}

pub fn fit_stake(value: f64, balance: f64) -> f64 {
    let min = min_stake();
    let hi = if balance < min { min } else { balance };
    if value < min {
        min
    } else if value > hi {
        hi
    } else {
        value
    }
}

/// After a debit the stake drops to the remaining balance only while the
/// player can still open another round. A busted purse keeps the stake
/// where it was.
pub fn stake_after_spend(stake: f64, balance: f64) -> f64 {
    if balance >= min_stake() && stake > balance {
        balance
    } else {
        stake
    }
}

pub fn can_spend(amount: f64, balance: f64) -> bool {
    amount >= min_stake() && amount <= balance
}

pub fn debit(balance: f64, amount: f64) -> f64 {
    balance - amount
}

pub fn credit(balance: f64, amount: f64) -> f64 {
    if amount <= 0.0 {
        balance
    } else {
        balance + amount
    }
}

pub fn nudge(stake: f64, direction: f64, balance: f64) -> f64 {
    let step = if stake >= step_fast_at() {
        step_fast()
    } else if stake >= step_mid_at() {
        step_mid()
    } else {
        step_slow()
    };
    let signed = if direction > 0.0 {
        step
    } else if direction < 0.0 {
        -step
    } else {
        0.0
    };
    fit_stake(stake + signed, balance)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn constants_decode() {
        assert_eq!(min_stake(), 2.0);
        assert_eq!(opening_balance(), 1000.0);
        assert_eq!(pocket(), 200.0);
        assert_eq!(starting_stake(), 10.0);
    }

    #[test]
    fn stake_fits_the_purse() {
        assert_eq!(fit_stake(1.0, 1000.0), 2.0);
        assert_eq!(fit_stake(5000.0, 40.0), 40.0);
        assert_eq!(fit_stake(8.0, 40.0), 8.0);
        assert_eq!(fit_stake(10.0, 0.0), 2.0);
        assert_eq!(non_negative(-4.0), 0.0);
        assert_eq!(non_negative(3.0), 3.0);
    }

    #[test]
    fn spend_and_nudge() {
        assert!(can_spend(2.0, 2.0));
        assert!(!can_spend(1.0, 100.0));
        assert!(!can_spend(3.0, 2.0));
        assert!(is_broke(1.0));
        assert!(!is_broke(2.0));
        assert_eq!(debit(10.0, 2.0), 8.0);
        assert_eq!(credit(10.0, 0.0), 10.0);
        assert_eq!(credit(10.0, -5.0), 10.0);
        assert_eq!(credit(10.0, 200.0), 210.0);
        assert_eq!(stake_after_spend(10.0, 5.0), 5.0);
        assert_eq!(stake_after_spend(10.0, 1.0), 10.0);
        assert_eq!(nudge(10.0, 1.0, 1000.0), 11.0);
        assert_eq!(nudge(20.0, 1.0, 1000.0), 25.0);
        assert_eq!(nudge(100.0, -1.0, 1000.0), 90.0);
        assert_eq!(nudge(2.0, -1.0, 1000.0), 2.0);
        assert_eq!(nudge(40.0, 1.0, 42.0), 42.0);
    }
}
