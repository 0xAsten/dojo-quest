use array::ArrayTrait;
use starknet::ContractAddress;
use dojo::database::schema::{
    Enum, Member, Ty, Struct, SchemaIntrospection, serialize_member, serialize_member_type
};
use core::debug::PrintTrait;

#[derive(Model, Copy, Drop, Serde)]
struct Attributes {
    #[key]
    player: ContractAddress,
    #[key]
    quest_id: u32,
    #[key]
    entity_id: u32,
    points: u32,
    str: u32, //Strength
    dex: u32, //Dexterity
    con: u32, //Constitution
    int: u32, //Intelligence
    wis: u32, //Wisdom
    cha: u32, //Charisma
    str_modifier: u32,
    dex_modifier: u32,
    con_modifier: u32,
    int_modifier: u32,
    wis_modifier: u32,
    cha_modifier: u32
}

#[derive(Model, Copy, Drop, Serde)]
struct Stats {
    #[key]
    player: ContractAddress,
    #[key]
    quest_id: u32,
    #[key]
    entity_id: u32,
    ac: u32,
    damage_dice: u32,
    hp: u32
}

#[derive(Model, Copy, Drop, Serde)]
struct Position {
    #[key]
    player: ContractAddress,
    #[key]
    quest_id: u32,
    #[key]
    entity_id: u32,
    x: u32,
    y: u32
}

#[derive(Model, Copy, Drop, Serde)]
struct Counter {
    #[key]
    player: ContractAddress,
    count: u32,
}

#[derive(Model, Copy, Drop, Serde)]
struct Quest {
    #[key]
    player: ContractAddress,
    #[key]
    quest_id: u32,
    // 0 - GameInit, 1 - GameRunning, 2 - GameOver
    quest_state: u32,
}

trait PositionTrait {
    fn is_zero(self: Position) -> bool;
    fn is_equal(self: Position, b: Position) -> bool;
    fn is_neighbor(self: Position, b: Option<(u32, u32)>) -> bool;
    fn move_steps(self: Position, b: Option<(u32, u32)>) -> u32;
    fn neighbors(self: Position, grid_width: u32, grid_height: u32) -> Array<(u32, u32)>;
    fn neighbors_xy(x: u32, y: u32, grid_width: u32, grid_height: u32) -> Array<(u32, u32)>;
}

impl PositionImpl of PositionTrait {
    fn is_zero(self: Position) -> bool {
        if self.x - self.y == 0 {
            return true;
        }
        false
    }

    fn is_equal(self: Position, b: Position) -> bool {
        self.x == b.x && self.y == b.y
    }

    fn is_neighbor(self: Position, b: Option<(u32, u32)>) -> bool {
        let mut near = false;

        match b {
            Option::Some((
                x, y
            )) => {
                if self.x == x {
                    if self.y == y + 1 {
                        near = true;
                    }
                    if y > 0 && self.y == y - 1 {
                        near = true;
                    }
                } else if self.y == y {
                    if self.x == x + 1 {
                        near = true;
                    }
                    if x > 0 && self.x == x - 1 {
                        near = true;
                    }
                }
            },
            Option::None(_) => panic(array!['None exists'])
        }

        near
    }

    fn move_steps(self: Position, b: Option<(u32, u32)>) -> u32 {
        let (x, y) = b.unwrap();
        let steps_x = {
            if self.x > x {
                self.x - x
            } else if self.x < x {
                x - self.x
            } else {
                0
            }
        };
        let steps_y = {
            if self.y > y {
                self.y - y
            } else if self.y < y {
                y - self.y
            } else {
                0
            }
        };
        let steps = steps_x + steps_y;

        steps
    }

    fn neighbors(self: Position, grid_width: usize, grid_height: usize) -> Array<(u32, u32)> {
        let mut neighbors = ArrayTrait::<(u32, u32)>::new();

        if self.x > 0 {
            neighbors.append((self.x - 1, self.y));
        }
        if self.x < grid_width - 1 {
            neighbors.append((self.x + 1, self.y));
        }
        if self.y > 0 {
            neighbors.append((self.x, self.y - 1));
        }
        if self.y < grid_height - 1 {
            neighbors.append((self.x, self.y + 1));
        }

        neighbors
    }

    fn neighbors_xy(x: u32, y: u32, grid_width: usize, grid_height: usize) -> Array<(u32, u32)> {
        let mut neighbors = ArrayTrait::<(u32, u32)>::new();

        if x > 0 {
            neighbors.append((x - 1, y));
        }
        if x < grid_width - 1 {
            neighbors.append((x + 1, y));
        }
        if y > 0 {
            neighbors.append((x, y - 1));
        }
        if y < grid_height - 1 {
            neighbors.append((x, y + 1));
        }

        neighbors
    }
}
