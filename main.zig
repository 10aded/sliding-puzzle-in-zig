const std = @import("std");

const DEBUG = "DEBUG: ";

const dprint  = std.debug.print;
const dassert = std.debug.assert;

// Type aliases.
const GridCoord = struct {
    x : u8,
    y : u8,
};

fn gridCoord(x : u8, y : u8) GridCoord {
    return .{.x = x, .y = y};
}
    
// Grid structure.
const GRID_DIMENSION = 4;
const TILE_NUMBER = GRID_DIMENSION * GRID_DIMENSION;

// Grid is per row, left to right, top to bottom.
var grid : [TILE_NUMBER] u8 = undefined;

// Grid movement
const GridMovementDirection = enum (u8) {
    NONE,
    UP,
    LEFT,
    DOWN,
    RIGHT,
};

var tile_movement_direction : GridMovementDirection = .NONE;

// Random number generator
var prng : std.rand.Xoshiro256 = undefined;

// Timing
var stopwatch : std.time.Timer = undefined;
var program_start_timestamp : u64 = undefined;
var frame_timestamp : u64 = undefined;
    
// Keyboard
const KeyState = packed struct (u8) {
    up_arrow    : bool,
    left_arrow  : bool,
    down_arrow  : bool,
    right_arrow : bool,
    _padding    : u4,
};

var keyPress : KeyState = undefined;

pub fn main() void {

    
    stopwatch = std.time.Timer.start() catch unreachable;
    program_start_timestamp = stopwatch.read();
    init_program();
    init_grid();

    while(true) {
        process_input();
        update_state();
        render();
        //dprint(DEBUG ++ "grid:\n{any}\n", .{grid}); //@debug
        debug_print_grid();
    }
}
    
fn init_program() void {
    // set up rng.
    const seed  = program_start_timestamp;
    prng        = std.rand.DefaultPrng.init(@bitCast(seed));
}

fn init_grid() void {
    const random = prng.random();
    
    grid = std.simd.iota(u8, TILE_NUMBER);

    random.shuffle(u8, &grid);
}


fn process_input() void {
    // TODO...
    // Do actual keyboard processing once glfw (or whatever we use)
    // is spawing a window.

    // Reset keyPress.

    keyPress = @bitCast(@as(u8, 0));

    const stdin = std.io.getStdIn().reader();
    var stdin_buffer: [16]u8 = undefined;
    
    @memset(stdin_buffer[0..], 0);
    
    _ = stdin.readUntilDelimiterOrEof(stdin_buffer[0..], '\n') catch unreachable;
    const first_char = stdin_buffer[0];

    // Using DVORAK keyboard.
    // Qwerty is for mortals.
    switch (first_char) {
        ',' => { keyPress.up_arrow    = true; },
        'a' => { keyPress.left_arrow  = true; },
        'o' => { keyPress.down_arrow  = true; },
        'e' => { keyPress.right_arrow = true; },
        else => {
            dprint("Error, press one of: ,aoe\n", .{});
        },
    }
}

fn update_state() void {
    // Determine if a tile movement attempt has been made. 
    if (keyPress.up_arrow)    { tile_movement_direction = .UP; }
    if (keyPress.left_arrow)  { tile_movement_direction = .LEFT; }
    if (keyPress.down_arrow)  { tile_movement_direction = .DOWN; }
    if (keyPress.right_arrow) { tile_movement_direction = .RIGHT; }

    // Calculate the new grid configuration (if it changes).

    // Find empty tile.
    var empty_tile_index_tilde : ?usize = null;
    for (grid, 0..) |tile, i| {
        if (tile == 0) {
            empty_tile_index_tilde = i;
            break;
        }
    }
    
    const empty_tile_index : u8 = @intCast(empty_tile_index_tilde.?);

    const empty_tile_pos : GridCoord = gridCoord(empty_tile_index % GRID_DIMENSION, empty_tile_index / GRID_DIMENSION);

    // 0 1   -- LEFT --> 1 0
    // 2 3               2 3

    // 1 2                1 0
    // 3 0    -- DOWN --> 3 2


    blk: {
        switch(tile_movement_direction) {
            .NONE  => { return; },
            .UP    => {
                if (empty_tile_pos.y == GRID_DIMENSION - 1) { break :blk; }
                const swap_tile_index = empty_tile_index + GRID_DIMENSION;
                grid[empty_tile_index] = grid[swap_tile_index];
                grid[swap_tile_index] = 0;
            },
            .LEFT  => {
                if (empty_tile_pos.x == GRID_DIMENSION - 1) { break :blk; }
                const swap_tile_index = empty_tile_index + 1;
                grid[empty_tile_index] = grid[swap_tile_index];
                grid[swap_tile_index] = 0;
            },
            .DOWN  => {
                if (empty_tile_pos.y == 0) { break :blk; }
                const swap_tile_index = empty_tile_index - GRID_DIMENSION;
                grid[empty_tile_index] = grid[swap_tile_index];
                grid[swap_tile_index] = 0;
            },
            .RIGHT => {
                if (empty_tile_pos.x == 0) { break :blk; }
                const swap_tile_index = empty_tile_index - 1;
                grid[empty_tile_index] = grid[swap_tile_index];
                grid[swap_tile_index] = 0;
            },
        }
    }
}

fn render() void {
    // TODO... once the grid logic is solid.
}

fn debug_print_grid() void {
    for (0..GRID_DIMENSION) |i| {
        for (0..GRID_DIMENSION) |j| {
            const index = i * GRID_DIMENSION + j;
            dprint("{: >4}", .{grid[index]});
        }
        dprint("\n", .{});
    }
    //     try expectFmt("u8: '0100'", "u8: '{:0^4}'", .{@as(u8, 1)});
    // try expectFmt("i8: '-1  '", "i8: '{:<4}'", .{@as(i8, -1)});
}
