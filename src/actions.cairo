#[starknet::interface]
trait IActions<TContractState> {
    fn spawn(self: @TContractState, str: u32, dex: u32, con: u32, int: u32, wis: u32, cha: u32);
    fn move(self: @TContractState, x: u32, y: u32);
    fn attack(self: @TContractState);
}

#[dojo::contract]
mod actions {
    use starknet::{ContractAddress, get_caller_address};
    use dojo_xyz::models::{Attributes, Position, Stats, Quest, PositionTrait, Counter};
    use super::IActions;
    use array::ArrayTrait;
    use dojo_xyz::utils::roll;

    fn modifier(attribute: u32) -> u32 {
        let modifier = (attribute - 8) / 2;

        modifier
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

    // impl: implement functions specified in trait
    #[external(v0)]
    impl ActionsImpl of IActions<ContractState> {
        // ContractState is defined by system decorator expansion
        fn spawn(self: @ContractState, str: u32, dex: u32, con: u32, int: u32, wis: u32, cha: u32) {
            // Access the world dispatcher for reading.
            let world = self.world_dispatcher.read();

            // Get the address of the current caller, possibly the player's address.
            let player = get_caller_address();

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

            let mut counter = get!(world, player, (Counter));
            let quest_id = counter.count + 1;
            counter.count = quest_id;
            counter.player = player;

            set!(
                world,
                (Attributes {
                    player: player,
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
                world,
                (Stats {
                    player: player,
                    quest_id: quest_id,
                    entity_id: 0,
                    ac: 10 + dex_modifier,
                    hp: 1010 + con_modifier,
                    damage_dice: 4,
                })
            );
            set!(
                world, (Position { player: player, quest_id: quest_id, entity_id: 0, x: 0, y: 0 })
            );
            set!(world, (Quest { player: player, quest_id: quest_id, quest_state: 1 }));
            set!(world, (counter));

            set!(
                world,
                (
                    Attributes {
                        player: player,
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
                        player: player,
                        quest_id: quest_id,
                        entity_id: 1,
                        ac: 11,
                        hp: 1011,
                        damage_dice: 4,
                    },
                    Position { player: player, quest_id: quest_id, entity_id: 1, x: 10, y: 10 },
                )
            );
        }

        fn move(self: @ContractState, x: u32, y: u32) {
            let world = self.world_dispatcher.read();

            let player = get_caller_address();

            let counter = get!(world, player, (Counter));
            let count = counter.count;

            let mut quest = get!(world, (player, count), (Quest));
            let quest_id = count;
            let quest_state = quest.quest_state;
            assert(quest_state == 1, 'Quest stats error');

            let mut position_player = get!(world, (player, quest_id, 0), (Position));
            let mut position_goblin = get!(world, (player, quest_id, 1), (Position));

            assert(position_player.x != x || position_player.y != y, 'No movement');
            assert(x != position_goblin.x || y != position_goblin.y, 'Collision');
            assert(x < 25, 'Out of bounds');
            assert(y < 20, 'Out of bounds');
            // calculate steps
            let steps = position_player.move_steps(Option::Some((x, y)));
            assert(steps <= 5, 'Too many steps');

            position_player.x = x;
            position_player.y = y;

            set!(world, (position_player));

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
                        set!(world, (position_goblin));
                    },
                    Option::None(_) => assert(false, 'should have new position'),
                };
            } else {
                // atack
                let mut stats_player = get!(world, (player, quest_id, 0), (Stats));
                let stats_goblin = get!(world, (player, quest_id, 1), (Stats));
                let attributes_player = get!(world, (player, quest_id, 0), (Attributes));
                let attributes_goblin = get!(world, (player, quest_id, 1), (Attributes));

                let (is_hit, roll) = is_hit(attributes_goblin.str_modifier, stats_player.ac);
                if is_hit {
                    let mut damage = roll(stats_goblin.damage_dice)
                        + attributes_goblin.str_modifier;
                    if roll == 20 {
                        damage += roll(stats_goblin.damage_dice) + attributes_goblin.str_modifier;
                    }
                    stats_player.hp -= damage;
                    set!(world, (stats_player));

                    if stats_player.hp <= 1000 {
                        // player dead
                        quest.quest_state = 2;
                        set!(world, (quest));
                        return ();
                    }
                }
            }
        }

        fn attack(self: @ContractState) {
            let world = self.world_dispatcher.read();

            let player = get_caller_address();

            let counter = get!(world, player, (Counter));
            let count = counter.count;

            let mut quest = get!(world, (player, count), (Quest));
            let quest_id = count;
            let quest_state = quest.quest_state;
            assert(quest_state == 1, 'Quest stats error');

            let mut position_player = get!(world, (player, quest_id, 0), (Position));
            let mut position_goblin = get!(world, (player, quest_id, 1), (Position));

            assert(
                position_player.is_neighbor(Option::Some((position_goblin.x, position_goblin.y))),
                'Not near'
            );

            // atack
            let mut stats_player = get!(world, (player, quest_id, 0), (Stats));
            let mut stats_goblin = get!(world, (player, quest_id, 1), (Stats));
            let attributes_player = get!(world, (player, quest_id, 0), (Attributes));
            let attributes_goblin = get!(world, (player, quest_id, 1), (Attributes));

            let (is_hit, roll) = is_hit(attributes_player.str_modifier, stats_goblin.ac);
            if is_hit {
                let mut damage = roll(stats_player.damage_dice) + attributes_player.str_modifier;
                if roll == 20 {
                    damage += roll(stats_player.damage_dice) + attributes_player.str_modifier;
                }
                stats_goblin.hp -= damage;
                set!(world, (stats_goblin));

                if stats_goblin.hp <= 1000 {
                    // goblin dead
                    quest.quest_state = 2;
                    set!(world, (quest));
                    return ();
                }
            }

            let (is_hit, roll) = is_hit(attributes_goblin.str_modifier, stats_player.ac);
            if is_hit {
                let mut damage = roll(stats_goblin.damage_dice) + attributes_goblin.str_modifier;
                if roll == 20 {
                    damage += roll(stats_goblin.damage_dice) + attributes_goblin.str_modifier;
                }
                stats_player.hp -= damage;
                set!(world, (stats_player));

                if stats_player.hp <= 1000 {
                    // player dead
                    quest.quest_state = 2;
                    set!(world, (quest));
                    return ();
                }
            }
        }
    }
}


#[cfg(test)]
mod tests {
    use starknet::class_hash::Felt252TryIntoClassHash;

    // import world dispatcher
    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

    // import test utils
    use dojo::test_utils::{spawn_test_world, deploy_contract};

    // import models
    use dojo_xyz::models::{attributes, position, stats, quest, counter};
    use dojo_xyz::models::{Attributes, Position, Stats, Quest, Counter};

    // import actions
    use super::{actions, IActionsDispatcher, IActionsDispatcherTrait};

    use debug::PrintTrait;

    #[test]
    #[available_gas(3000000000000000)]
    fn test_spawn() {
        let palyer = starknet::contract_address_const::<0x0>();

        let mut models = array![
            attributes::TEST_CLASS_HASH,
            position::TEST_CLASS_HASH,
            stats::TEST_CLASS_HASH,
            quest::TEST_CLASS_HASH,
            counter::TEST_CLASS_HASH,
        ];

        let world = spawn_test_world(models);

        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let actions_system = IActionsDispatcher { contract_address };

        let str = 2;
        let dex = 2;
        let con = 2;
        let int = 1;
        let wis = 0;
        let cha = 0;

        actions_system.spawn(str, dex, con, int, wis, cha);

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

    #[test]
    #[available_gas(3000000000000000)]
    fn spawn() -> (IWorldDispatcher, IActionsDispatcher) {
        let palyer = starknet::contract_address_const::<0x0>();

        let mut models = array![
            attributes::TEST_CLASS_HASH,
            position::TEST_CLASS_HASH,
            stats::TEST_CLASS_HASH,
            quest::TEST_CLASS_HASH,
            counter::TEST_CLASS_HASH,
        ];

        let world = spawn_test_world(models);

        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let actions_system = IActionsDispatcher { contract_address };

        let str = 2;
        let dex = 2;
        let con = 2;
        let int = 1;
        let wis = 0;
        let cha = 0;

        actions_system.spawn(str, dex, con, int, wis, cha);

        (world, actions_system)
    }

    #[test]
    #[should_panic]
    fn test_out_bounds() {
        let palyer = starknet::contract_address_const::<0x0>();

        let (_, actions_system) = spawn();

        actions_system.move(25, 20);
    }

    #[test]
    #[should_panic]
    fn test_exceed_steps() {
        let palyer = starknet::contract_address_const::<0x0>();

        let (_, actions_system) = spawn();

        actions_system.move(6, 0);
    }

    #[test]
    #[should_panic]
    fn test_not_move() {
        let palyer = starknet::contract_address_const::<0x0>();

        let (_, actions_system) = spawn();

        actions_system.move(0, 0);
    }

    #[test]
    #[should_panic]
    fn test_collision() {
        let palyer = starknet::contract_address_const::<0x0>();

        let (world, actions_system) = spawn();

        actions_system.move(0, 5);

        let counter = get!(world, palyer, (Counter));
        let count = counter.count;

        //get quest
        let position_player = get!(world, (palyer, count, 0), (Position));
        assert(position_player.x == 0, 'move error');
        assert(position_player.y == 5, 'move error');

        actions_system.move(5, 5);

        actions_system.move(5, 7);
    }

    #[test]
    #[available_gas(3000000000000000)]
    fn test_move() {
        let palyer = starknet::contract_address_const::<0x0>();

        let (world, actions_system) = spawn();

        actions_system.move(0, 5);

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

        actions_system.move(5, 5);

        let position_goblin = get!(world, (palyer, count, 1), (Position));
        position_goblin.x.print();
        position_goblin.y.print();

        actions_system.move(5, 8);

        let position_goblin = get!(world, (palyer, count, 1), (Position));
        position_goblin.x.print();
        position_goblin.y.print();

        let stats = get!(world, (palyer, count, 0), (Stats));
        stats.hp.print();
    }

    #[test]
    #[should_panic]
    fn test_not_near() {
        let palyer = starknet::contract_address_const::<0x0>();

        let (world, actions_system) = spawn();

        actions_system.move(0, 5);

        actions_system.attack();
    }

    #[test]
    #[should_panic]
    fn test_not_start() {
        let palyer = starknet::contract_address_const::<0x0>();

        let mut models = array![
            attributes::TEST_CLASS_HASH,
            position::TEST_CLASS_HASH,
            stats::TEST_CLASS_HASH,
            quest::TEST_CLASS_HASH,
            counter::TEST_CLASS_HASH,
        ];

        let world = spawn_test_world(models);

        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let actions_system = IActionsDispatcher { contract_address };

        actions_system.attack();
    }

    #[test]
    #[available_gas(3000000000000000)]
    fn test_attack() {
        let palyer = starknet::contract_address_const::<0x0>();

        let (world, actions_system) = spawn();

        let counter = get!(world, palyer, (Counter));
        let count = counter.count;

        let player_stats = get!(world, (palyer, count, 0), (Stats));
        player_stats.hp.print();

        let goblin_stats = get!(world, (palyer, count, 1), (Stats));
        goblin_stats.hp.print();

        actions_system.move(0, 5);
        actions_system.move(5, 5);
        actions_system.move(5, 8);

        let position_player = get!(world, (palyer, count, 0), (Position));

        let position_goblin = get!(world, (palyer, count, 1), (Position));

        actions_system.attack();

        let player_stats = get!(world, (palyer, count, 0), (Stats));
        player_stats.hp.print();

        let goblin_stats = get!(world, (palyer, count, 1), (Stats));
        goblin_stats.hp.print();
    }
}
