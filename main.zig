const std = @import("std");

const DEBUG = "DEBUG: ";
const dprint = std.debug.print;

// Grid structure.
const GRID_SIZE = 2;
const TILE_NUMBER = GRID_SIZE * GRID_SIZE;
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
    }

    dprint(DEBUG ++ "grid:\n{any}\n", .{grid}); //@debug
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

    if (tile_movement_direction == .NONE) { return; }

    // Calculate the new grid configuration (if it changes).
    // ...


    dprint(DEBUG ++ "tile_movement_direction: {}\n", .{tile_movement_direction}); //@debug
}

fn render() void {
    // TODO... once the grid logic is solid.
}
    
