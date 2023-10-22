use traits::{Into, TryInto};

fn roll(dice: u32) -> u32 {
    let tx = starknet::get_tx_info().unbox().transaction_hash;
    let seed: u256 = tx.into();

    (seed.low % dice.into()).try_into().unwrap() + 1
}
