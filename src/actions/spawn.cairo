#[system]
mod spawn_system {
    use array::ArrayTrait;
    use box::BoxTrait;
    use traits::{Into, TryInto};
    use option::OptionTrait;
    use dojo::world::Context;
    use starknet::ContractAddress;
    use debug::PrintTrait;

    use dojo_xyz::components::{Attributes, Position, Stats, Quest, Counter};

    fn modifier(attribute: u32) -> u32 {
        let modifier = (attribute - 8) / 2;

        modifier
    }

    fn execute(ctx: Context, str: u32, dex: u32, con: u32, int: u32, wis: u32, cha: u32) {
        let total = str + dex + con + int + wis + cha;
        assert(total <= 7, 'Points too large');

        let str = 8 + str;
        let dex = 8 + dex;
        let con = 8 + con;
        let int = 8 + int;
        let wis = 8 + wis;
        let cha = 8 + cha;

        let str_modifier = modifier(str);
        let dex_modifier = modifier(dex);
        let con_modifier = modifier(con);
        let int_modifier = modifier(int);
        let wis_modifier = modifier(wis);
        let cha_modifier = modifier(cha);

        let mut counter = get!(ctx.world, ctx.origin, (Counter));
        let quest_id = counter.count + 1;
        counter.count = quest_id;
        counter.player = ctx.origin;

        set!(
            ctx.world,
            (Attributes {
                player: ctx.origin,
                quest_id: quest_id,
                entity_id: 0,
                points: 7 - total,
                str: str,
                dex: dex,
                con: con,
                int: int,
                wis: wis,
                cha: cha,
                str_modifier: str_modifier,
                dex_modifier: dex_modifier,
                con_modifier: con_modifier,
                int_modifier: int_modifier,
                wis_modifier: wis_modifier,
                cha_modifier: cha_modifier,
            })
        );
        set!(
            ctx.world,
            (Stats {
                player: ctx.origin,
                quest_id: quest_id,
                entity_id: 0,
                ac: 10 + dex_modifier,
                hp: 1010 + con_modifier,
                damage_dice: 4,
            })
        );
        set!(
            ctx.world,
            (Position { player: ctx.origin, quest_id: quest_id, entity_id: 0, x: 0, y: 0 })
        );
        set!(ctx.world, (Quest { player: ctx.origin, quest_id: quest_id, quest_state: 1 }));
        set!(ctx.world, (counter));

        set!(
            ctx.world,
            (
                Attributes {
                    player: ctx.origin,
                    quest_id: quest_id,
                    entity_id: 1,
                    points: 0,
                    str: 10,
                    dex: 10,
                    con: 10,
                    int: 8,
                    wis: 9,
                    cha: 8,
                    str_modifier: 1,
                    dex_modifier: 1,
                    con_modifier: 1,
                    int_modifier: 0,
                    wis_modifier: 0,
                    cha_modifier: 0,
                },
                Stats {
                    player: ctx.origin,
                    quest_id: quest_id,
                    entity_id: 1,
                    ac: 11,
                    hp: 1011,
                    damage_dice: 4,
                },
                Position { player: ctx.origin, quest_id: quest_id, entity_id: 1, x: 10, y: 10 },
            )
        );
        return ();
    }
}

#[cfg(test)]
mod tests {
    use starknet::ContractAddress;
    use dojo::test_utils::spawn_test_world;
    use dojo_xyz::components::{
        Attributes, attributes, Position, position, Stats, stats, Quest, quest, Counter, counter
    };
    use super::spawn_system;
    use debug::PrintTrait;
    use array::ArrayTrait;
    use core::traits::Into;
    use dojo::world::IWorldDispatcherTrait;
    use core::array::SpanTrait;

    #[test]
    #[available_gas(3000000000000000)]
    fn test_initiate() {
        let palyer = starknet::contract_address_const::<0x0>();

        // components
        let mut components = array::ArrayTrait::new();
        components.append(attributes::TEST_CLASS_HASH);
        components.append(position::TEST_CLASS_HASH);
        components.append(stats::TEST_CLASS_HASH);
        components.append(quest::TEST_CLASS_HASH);
        components.append(counter::TEST_CLASS_HASH);

        //systems
        let mut systems = ArrayTrait::new();
        systems.append(spawn_system::TEST_CLASS_HASH);
        let world = spawn_test_world(components, systems);

        let mut calldata = ArrayTrait::<core::felt252>::new();
        let str = 2;
        let dex = 2;
        let con = 2;
        let int = 1;
        let wis = 0;
        let cha = 0;
        calldata.append(str.into());
        calldata.append(dex.into());
        calldata.append(con.into());
        calldata.append(int.into());
        calldata.append(wis.into());
        calldata.append(cha.into());
        world.execute('spawn_system'.into(), calldata);

        let counter = get!(world, palyer, (Counter));
        let count = counter.count;

        //get quest
        let quest = get!(world, (palyer, count), (Quest));

        assert(quest.quest_state == 1, 'quest state is incorrect');
        assert(quest.quest_id == 1, 'quest id is incorrect');

        let position_player = get!(world, (palyer, count, 0), (Position));
        let position_goblin = get!(world, (palyer, count, 1), (Position));

        assert(position_player.x == 0, 'player x is incorrect');
        assert(position_player.y == 0, 'player y is incorrect');
        assert(position_goblin.x == 10, 'goblin x is incorrect');
        assert(position_goblin.y == 10, 'goblin y is incorrect');
    }
}
