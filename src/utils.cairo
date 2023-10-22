use traits::{Into, TryInto};

fn roll(dice: u32) -> u32 {
    let tx = starknet::get_tx_info().unbox().transaction_hash;
    let seed: u256 = tx.into();

    (seed.low % dice.into()).try_into().unwrap() + 1
}

fn modifier(attribute: u32) -> u32 {
    let modifier = (attribute - 8) / 2;

    modifier
}

fn is_hit(attacker_modifier: u32, defender_ac: u32) -> (bool, u32) {
    let roll = roll(20);
    let attack_roll = roll + attacker_modifier;
    (attack_roll >= defender_ac, roll)
}
