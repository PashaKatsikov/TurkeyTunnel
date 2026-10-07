//! Round rolls. xorshift128+, seeded through splitmix so a zero seed
//! still moves.

pub struct Roll {
    s0: u64,
    s1: u64,
}

fn mix(state: u64) -> u64 {
    let mut z = state.wrapping_add(0x9E37_79B9_7F4A_7C15);
    z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
    z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
    z ^ (z >> 31)
}

impl Roll {
    pub fn new(seed: u64) -> Self {
        let s0 = mix(seed);
        let s1 = mix(s0 ^ 0xA24B_AED4_96E3_6E38);
        if s0 == 0 && s1 == 0 {
            Self {
                s0: 0x9E37_79B9_7F4A_7C15,
                s1: 1,
            }
        } else {
            Self { s0, s1 }
        }
    }

    pub fn next_u64(&mut self) -> u64 {
        let mut s1 = self.s0;
        let s0 = self.s1;
        let result = s0.wrapping_add(s1);
        self.s0 = s0;
        s1 ^= s1 << 23;
        self.s1 = s1 ^ s0 ^ (s1 >> 18) ^ (s0 >> 5);
        result
    }

    /// Uniform in `[0, 1)`.
    pub fn unit(&mut self) -> f64 {
        (self.next_u64() >> 11) as f64 * (1.0 / (1u64 << 53) as f64)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn same_seed_same_stream() {
        let mut a = Roll::new(4);
        let mut b = Roll::new(4);
        for _ in 0..16 {
            assert_eq!(a.next_u64(), b.next_u64());
        }
    }

    #[test]
    fn unit_stays_in_range() {
        let mut roll = Roll::new(0);
        for _ in 0..1_000 {
            let u = roll.unit();
            assert!((0.0..1.0).contains(&u));
        }
    }
}
