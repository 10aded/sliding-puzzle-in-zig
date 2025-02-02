const std = @import("std");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");

const DEBUG = "DEBUG: ";

const dprint  = std.debug.print;
const dassert = std.debug.assert;

// Type aliases.
const Vec2  = @Vector(2, f32);
const Color = @Vector(4, u8);

const MAGENTA = Color{255, 0, 255, 255};
const DEBUG_COLOR = MAGENTA;

const GridCoord = struct {
    x : u8,
    y : u8,
};

fn gridCoord(x : u8, y : u8) GridCoord {
    return .{.x = x, .y = y};
}

// Window
var window : *glfw.Window = undefined;

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
var prng : std.Random.Xoshiro256 = undefined;

// Timing
var stopwatch : std.time.Timer = undefined;
var program_start_timestamp : u64 = undefined;
var frame_timestamp : u64 = undefined;
    
// Keyboard
const KeyState = packed struct (u8) {
    w           : bool,
    a           : bool,
    s           : bool,
    d           : bool,
    up_arrow    : bool,
    left_arrow  : bool,
    down_arrow  : bool,
    right_arrow : bool,
};

var keyDownLastFrame : KeyState = @bitCast(@as(u8, 0));
var keyDown          : KeyState = @bitCast(@as(u8, 0));
var keyPress         : KeyState = @bitCast(@as(u8, 0));

// Geometry
const ColorVertex = struct {
    x : f32,
    y : f32,
    r : f32,
    g : f32,
    b : f32,
};

fn colorVertex( x : f32, y : f32, r : f32, g : f32, b : f32) ColorVertex{
    return ColorVertex{.x = x, .y = y, .r = r, .g = g, .b = b};
}

// TODO:
// This game is a rare instance where the number of triangles drawn
// each frame is the same, so we can specify the number of them precisely.
// ... update 1000 to three times this number!

var color_vertex_buffer : [1000] ColorVertex = undefined;
var color_vertex_buffer_index : usize = 0;

// Here pos represents the center of the rectangle.
const Rectangle = struct {
    pos : Vec2,
    w   : f32,
    h   : f32,
};

pub fn main() void {
    stopwatch = std.time.Timer.start() catch unreachable;
    program_start_timestamp = stopwatch.read();

    glfw.init() catch unreachable;
    defer glfw.terminate();
    
    init_program();

    init_grid();

    while (!window.shouldClose()) {
        glfw.pollEvents();

        process_input();

        update_state();

        render();
    }

    window.destroy();
}
    
fn init_program() void {
    // set up rng.
    const seed  = program_start_timestamp;
    prng        = std.Random.DefaultPrng.init(@bitCast(seed));

    // Setup OpenGL.
    const gl_major = 4;
    const gl_minor = 0;
    glfw.windowHint(.context_version_major, gl_major);
    glfw.windowHint(.context_version_minor, gl_minor);
    glfw.windowHint(.opengl_profile, .opengl_core_profile);
    glfw.windowHint(.opengl_forward_compat, true);
    glfw.windowHint(.client_api, .opengl_api);
    glfw.windowHint(.doublebuffer, true);

    window = glfw.Window.create(1000, 1000, "Sliding Puzzle", null) catch unreachable;

    glfw.makeContextCurrent(window);

    zopengl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor) catch unreachable;

    glfw.swapInterval(1);
}

fn init_grid() void {
    const random = prng.random();
    
    grid = std.simd.iota(u8, TILE_NUMBER);

    random.shuffle(u8, &grid);
}


fn process_input() void {
    keyDownLastFrame = keyDown;

    // Reset keyDown.
    keyDown = @bitCast(@as(u8, 0));
    
    // Poll GLFW for whether keys are down or not.
    const w_down = glfw.getKey(window, glfw.Key.w) == glfw.Action.press;
    const a_down = glfw.getKey(window, glfw.Key.a) == glfw.Action.press;
    const s_down = glfw.getKey(window, glfw.Key.s) == glfw.Action.press;
    const d_down = glfw.getKey(window, glfw.Key.d) == glfw.Action.press;

    const up_arrow_down    = glfw.getKey(window, glfw.Key.up) == glfw.Action.press;
    const left_arrow_down  = glfw.getKey(window, glfw.Key.left)  == glfw.Action.press;
    const down_arrow_down  = glfw.getKey(window, glfw.Key.down)  == glfw.Action.press;
    const right_arrow_down = glfw.getKey(window, glfw.Key.right)  == glfw.Action.press;
    
    if (w_down) { keyDown.w = true; }
    if (a_down) { keyDown.a = true; }
    if (s_down) { keyDown.s = true; }
    if (d_down) { keyDown.d = true; }
    
    if (up_arrow_down)    { keyDown.up_arrow    = true; }
    if (left_arrow_down)  { keyDown.left_arrow  = true; }
    if (down_arrow_down)  { keyDown.down_arrow  = true; }
    if (right_arrow_down) { keyDown.right_arrow = true; }

    keyPress = @bitCast(@as(u8, @bitCast(keyDown)) & ~ @as(u8, @bitCast(keyDownLastFrame)));
}

fn update_state() void {

    // Reset tile movement.
    tile_movement_direction = .NONE;
    
    // Determine if a tile movement attempt has been made. 
    if (keyPress.w or keyPress.up_arrow)    { tile_movement_direction = .UP; }
    if (keyPress.a or keyPress.left_arrow)  { tile_movement_direction = .LEFT; }
    if (keyPress.s or keyPress.down_arrow)  { tile_movement_direction = .DOWN; }
    if (keyPress.d or keyPress.right_arrow) { tile_movement_direction = .RIGHT; }

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

    if (tile_movement_direction != .NONE) {
        debug_print_grid();
    }
    
    const gl = zopengl.bindings;
    
    gl.clearColor(0.1, 0, 0.1, 1);
    gl.clear(gl.COLOR_BUFFER_BIT);

    window.swapBuffers();
}

fn debug_print_grid() void {
    for (0..GRID_DIMENSION) |i| {
        for (0..GRID_DIMENSION) |j| {
            const index = i * GRID_DIMENSION + j;
            dprint("{: >4}", .{grid[index]});
        }
        dprint("\n", .{});
    }
    dprint("\n", .{});
    //     try expectFmt("u8: '0100'", "u8: '{:0^4}'", .{@as(u8, 1)});
    // try expectFmt("i8: '-1  '", "i8: '{:<4}'", .{@as(i8, -1)});
}

fn draw_color_rect( rect : Rectangle , color : Color) void {
    // Compute the coordinates of the corners of the rectangle.
    const xleft   = rect.pos[0] - 0.5 * rect.w;
    const xright  = rect.pos[0] + 0.5 * rect.w;
    const ytop    = rect.pos[1] - 0.5 * rect.h;
    const ybottom = rect.pos[1] + 0.5 * rect.h;

    // Compute nodes we will push to the GPU.
    const v0 = colorVertex(xleft,  ytop, color.r, color.g, color.b);
    const v1 = colorVertex(xright, ytop, color.r, color.g, color.b);
    const v2 = colorVertex(xleft,  ybottom, color.r, color.g, color.b);
    const v3 = v1;
    const v4 = v2;
    const v5 = colorVertex(xright, ybottom, color.r, color.g, color.b);

    // Set the color_buffer with the data.
    const buffer = &color_vertex_buffer;
    const i      = color_vertex_buffer_index;

    buffer[i + 0] = v0;
    buffer[i + 1] = v1;
    buffer[i + 2] = v2;
    buffer[i + 3] = v3;
    buffer[i + 4] = v4;
    buffer[i + 5] = v5;
    
    color_vertex_buffer_index += 6;
}
