#[dojo::contract]
mod move_system {
    use core::option::OptionTrait;
    use array::ArrayTrait;
    use box::BoxTrait;
    use traits::Into;
    use dojo::world::Context;
    use debug::PrintTrait;
    use starknet::ContractAddress;

    use dojo_xyz::components::{Attributes, Position, Stats, Quest, PositionTrait, Counter};

    fn execute(ctx: Context, x: u32, y: u32) {
        let counter = get!(ctx.world, ctx.origin, (Counter));
        let count = counter.count;

        let mut quest = get!(ctx.world, (ctx.origin, count), (Quest));
        let quest_id = count;
        let quest_state = quest.quest_state;
        assert(quest_state == 1, 'Quest stats error');

        let mut position_player = get!(ctx.world, (ctx.origin, quest_id, 0), (Position));
        let mut position_goblin = get!(ctx.world, (ctx.origin, quest_id, 1), (Position));

        assert(position_player.x != x || position_player.y != y, 'No movement');
        assert(x != position_goblin.x || y != position_goblin.y, 'Collision');
        assert(x < 25, 'Out of bounds');
        assert(y < 20, 'Out of bounds');
        // calculate steps
        let steps = position_player.move_steps(Option::Some((x, y)));
        assert(steps <= 5, 'Too many steps');

        position_player.x = x;
        position_player.y = y;

        set!(ctx.world, (position_player));

        // Is Goblin near Player?
        // if not near, determin Goblin's new x and y that to close in the palyer and totoal steps must less than 4
        if !position_player.is_neighbor(Option::Some((position_goblin.x, position_goblin.y))) {
            // move closer
            let new_position = best_goblin_move(position_player, position_goblin, 25, 20);
            match new_position {
                Option::Some((
                    bx, by
                )) => {
                    position_goblin.x = bx;
                    position_goblin.y = by;
                    set!(ctx.world, (position_goblin));
                },
                Option::None(_) => assert(false, 'should have new position'),
            };
        } else {
            // atack
            let mut stats_player = get!(ctx.world, (ctx.origin, quest_id, 0), (Stats));
            let stats_goblin = get!(ctx.world, (ctx.origin, quest_id, 1), (Stats));
            let attributes_player = get!(ctx.world, (ctx.origin, quest_id, 0), (Attributes));
            let attributes_goblin = get!(ctx.world, (ctx.origin, quest_id, 1), (Attributes));

            let (is_hit, roll) = is_hit(attributes_goblin.str_modifier, stats_player.ac);
            if is_hit {
                let mut damage = roll(stats_goblin.damage_dice) + attributes_goblin.str_modifier;
                if roll == 20 {
                    damage += roll(stats_goblin.damage_dice) + attributes_goblin.str_modifier;
                }
                stats_player.hp -= damage;
                set!(ctx.world, (stats_player));

                if stats_player.hp <= 1000 {
                    // player dead
                    quest.quest_state = 2;
                    set!(ctx.world, (quest));
                    return ();
                }
            }
        }

        return ();
    }

    fn best_goblin_move(
        player: Position, goblin: Position, grid_width: u32, grid_height: u32
    ) -> Option<(u32, u32)> {
        let mut steps: u32 = 0;
        let mut best_position: Option<(u32, u32)> = Option::Some((goblin.x, goblin.y));
        loop {
            if steps >= 4 {
                break;
            }
            steps += 1;

            let (x, y) = best_position.unwrap();
            let mut neighbors: Array<(u32, u32)> = PositionTrait::neighbors_xy(
                x, y, grid_width, grid_height
            );

            let mut tmp_position: Option<(u32, u32)> = Option::None(());
            loop {
                if neighbors.len() == 0 {
                    break;
                };
                tmp_position = ArrayTrait::pop_front(ref neighbors);
                let (xt, yt) = tmp_position.unwrap();

                let tmp_steps = player.move_steps(tmp_position);
                let best_steps = player.move_steps(best_position);

                if tmp_steps < best_steps {
                    best_position = tmp_position;
                };
            };

            if player.is_neighbor(best_position) {
                break;
            };
        };

        best_position
    }

    fn is_hit(attacker_modifier: u32, defender_ac: u32) -> (bool, u32) {
        let roll = roll(20);
        let attack_roll = roll + attacker_modifier;
        (attack_roll >= defender_ac, roll)
    }

    fn roll(dice: u32) -> u32 {
        dice
    }
}

#[cfg(test)]
mod tests {
    use starknet::ContractAddress;
    use dojo::test_utils::spawn_test_world;
    use dojo_xyz::components::{
        Attributes, attributes, Position, position, Stats, stats, Quest, quest, Counter, counter
    };
    use super::move_system;
    use dojo_xyz::systems::spawn_system;
    use debug::PrintTrait;
    use array::ArrayTrait;
    use core::traits::Into;
    use dojo::world::IWorldDispatcherTrait;
    use dojo::world::IWorldDispatcher;
    use core::array::SpanTrait;

    #[test]
    #[available_gas(3000000000000000)]
    fn spawn() -> IWorldDispatcher {
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
        systems.append(move_system::TEST_CLASS_HASH);
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

        world
    }

    #[test]
    #[should_panic]
    fn test_out_bounds() {
        let palyer = starknet::contract_address_const::<0x0>();

        let world = spawn();

        let mut move_calldata = array::ArrayTrait::<core::felt252>::new();
        move_calldata.append(25);
        move_calldata.append(20);
        world.execute('move_system'.into(), move_calldata);
    }

    #[test]
    #[should_panic]
    fn test_exceed_steps() {
        let palyer = starknet::contract_address_const::<0x0>();

        let world = spawn();

        let mut move_calldata = array::ArrayTrait::<core::felt252>::new();
        move_calldata.append(6);
        move_calldata.append(0);
        world.execute('move_system'.into(), move_calldata);
    }

    #[test]
    #[should_panic]
    fn test_not_move() {
        let palyer = starknet::contract_address_const::<0x0>();

        let world = spawn();

        let mut move_calldata = array::ArrayTrait::<core::felt252>::new();
        move_calldata.append(0);
        move_calldata.append(0);
        world.execute('move_system'.into(), move_calldata);
    }

    #[test]
    #[should_panic]
    fn test_collision() {
        let palyer = starknet::contract_address_const::<0x0>();

        let world = spawn();

        let mut move_calldata = array::ArrayTrait::<core::felt252>::new();
        move_calldata.append(0);
        move_calldata.append(5);
        world.execute('move_system'.into(), move_calldata);

        let counter = get!(world, palyer, (Counter));
        let count = counter.count;

        //get quest
        let position_player = get!(world, (palyer, count, 0), (Position));
        assert(position_player.x == 0, 'move error');
        assert(position_player.y == 5, 'move error');

        let mut move_calldata_2 = array::ArrayTrait::<core::felt252>::new();
        move_calldata_2.append(5);
        move_calldata_2.append(5);
        world.execute('move_system'.into(), move_calldata_2);

        let mut move_calldata_3 = array::ArrayTrait::<core::felt252>::new();
        move_calldata_3.append(5);
        move_calldata_3.append(7);
        world.execute('move_system'.into(), move_calldata_3);
    }

    #[test]
    #[available_gas(3000000000000000)]
    fn test_move() {
        let palyer = starknet::contract_address_const::<0x0>();

        let world = spawn();

        let mut move_calldata = array::ArrayTrait::<core::felt252>::new();
        move_calldata.append(0);
        move_calldata.append(5);
        world.execute('move_system'.into(), move_calldata);

        let counter = get!(world, palyer, (Counter));
        let count = counter.count;

        let stats = get!(world, (palyer, count, 0), (Stats));
        stats.hp.print();

        //get quest
        let position_player = get!(world, (palyer, count, 0), (Position));
        assert(position_player.x == 0, 'move error');
        assert(position_player.y == 5, 'move error');

        let position_goblin = get!(world, (palyer, count, 1), (Position));
        position_goblin.x.print();
        position_goblin.y.print();

        let mut move_calldata_2 = array::ArrayTrait::<core::felt252>::new();
        move_calldata_2.append(5);
        move_calldata_2.append(5);
        world.execute('move_system'.into(), move_calldata_2);

        let position_goblin = get!(world, (palyer, count, 1), (Position));
        position_goblin.x.print();
        position_goblin.y.print();

        let mut move_calldata_3 = array::ArrayTrait::<core::felt252>::new();
        move_calldata_3.append(5);
        move_calldata_3.append(8);
        world.execute('move_system'.into(), move_calldata_3);

        let position_goblin = get!(world, (palyer, count, 1), (Position));
        position_goblin.x.print();
        position_goblin.y.print();

        let stats = get!(world, (palyer, count, 0), (Stats));
        stats.hp.print();
    }
}
