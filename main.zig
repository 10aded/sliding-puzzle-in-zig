const std = @import("std");

const DEBUG = "DEBUG: ";
const dprint = std.debug.print;

// Grid structure.
const GRID_SIZE = 2;
const TILE_NUMBER = GRID_SIZE * GRID_SIZE;
var grid : [TILE_NUMBER] u8 = undefined;

// Random number generator
var prng : std.rand.Xoshiro256 = undefined;

// Timing
var stopwatch : std.time.Timer = undefined;
var program_start_timestamp : u64 = undefined;
var frame_timestamp : u64 = undefined;
    
pub fn main() void {
    stopwatch = std.time.Timer.start() catch unreachable;
    program_start_timestamp = stopwatch.read();
    init_program();
    init_grid();

    dprint(DEBUG ++ "grid:\n{any}\n", .{grid}); //@debug
}

fn init_program() void {
    // Set up RNG.
    const seed  = program_start_timestamp;
    prng        = std.rand.DefaultPrng.init(@intCast(seed));
}

fn init_grid() void {
    const random = prng.random();
    
    grid = std.simd.iota(u8, TILE_NUMBER);

    random.shuffle(u8, &grid);
}
