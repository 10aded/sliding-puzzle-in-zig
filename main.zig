const std = @import("std");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");

const colors = @import("colors.zig");

    
const DEBUG = "DEBUG: ";

const dprint  = std.debug.print;
const dassert = std.debug.assert;

// Type aliases.
const Vec2  = @Vector(2, f32);
const Color = @Vector(4, u8);

const VAO           = c_uint;
const VBO           = c_uint;
const Texture       = c_uint;
const ShaderProgram = c_uint;

const DEBUG_COLOR = colors.DEBUG;

const GridCoord = struct {
    x : u8,
    y : u8,
};

fn gridCoord(x : u8, y : u8) GridCoord {
    return .{.x = x, .y = y};
}

// Errors
const ShaderCompileError = error{ VertexShaderCompFail, FragmentShaderCompFail, ShaderLinkFail };


// Window
var window : *glfw.Window = undefined;

// Graphics globals
var global_vao    : VAO           = undefined;
var global_vbo    : VBO           = undefined;
var global_shader : ShaderProgram = undefined;

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
var global_prng : XorShiftPRNG = undefined;

// Timing
// Note: Timestamps are in nanoseconds.
var stopwatch : std.time.Timer = undefined;
var program_start_timestamp : u64 = undefined;
var frame_timestamp : u64 = undefined;

// Animation
const ANIMATION_SLIDING_TILE_TIME : f32 = 0.15;
var animating_tile : u8 = 0;
var animation_direction : GridMovementDirection = undefined;
var animation_start_timestamp : u64 = undefined;
var animation_fraction : f32 = 0;

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

fn rectangle(pos : Vec2, w : f32, h : f32) Rectangle {
    return Rectangle{.pos = pos, .w = w, .h = h};
}

pub fn main() void {
    stopwatch = std.time.Timer.start() catch unreachable;
    program_start_timestamp = stopwatch.read();

    init_grid();

    glfw.init() catch unreachable;
    defer glfw.terminate();
    
    init_opengl();

    compile_shaders() catch unreachable;
    
    setup_array_buffers();

    while (!window.shouldClose()) {

        frame_timestamp = stopwatch.read();
        
        glfw.pollEvents();

        process_input();

        update_state();

        render();
    }

    window.destroy();
}
    
fn init_opengl() void {
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
    // Initialize PRNG.
    const seed : u64 = program_start_timestamp;
    global_prng = initialize_xorshiftprng(seed);
 
   // Generate a random shuffle of the integers 0..TILE_NUMBER - 1;
    grid = std.simd.iota(u8, TILE_NUMBER);
    grid = fisher_yates(TILE_NUMBER, grid);
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

    // Reset animation if key press.
    if (@as(u8, @bitCast(keyPress)) != 0) {
        animation_start_timestamp = frame_timestamp;
    }

    // Check if animation over. Otherwise calculate animation fraction.
    const secs_since_animation_start = timestamp_delta_to_seconds(frame_timestamp, animation_start_timestamp);
    if (secs_since_animation_start > ANIMATION_SLIDING_TILE_TIME) {
        animation_direction = .NONE;
        animating_tile = 0;
        animation_fraction = 0;
    } else {
        animation_fraction = secs_since_animation_start / ANIMATION_SLIDING_TILE_TIME;
    }
    
    // Calculate the new grid configuration (if it changes).

    // Find empty tile.
    const empty_tile_index_tilde = find_tile_index(0);
    const empty_tile_index : u8 = @intCast(empty_tile_index_tilde.?);

    const empty_tile_pos : GridCoord = gridCoord(empty_tile_index % GRID_DIMENSION, empty_tile_index / GRID_DIMENSION);

    // 0 1   -- LEFT --> 1 0
    // 2 3               2 3

    // 1 2                1 0
    // 3 0    -- DOWN --> 3 2

    // TODO: Factor this switch !!!
    
    blk: {
        switch(tile_movement_direction) {
            .NONE  => { return; },
            .UP    => {
                if (empty_tile_pos.y == GRID_DIMENSION - 1) {
                    animating_tile = 0;
                    break :blk;
                }
                const swap_tile_index = empty_tile_index + GRID_DIMENSION;
                grid[empty_tile_index] = grid[swap_tile_index];
                grid[swap_tile_index] = 0;
                animating_tile = grid[empty_tile_index];
                animation_direction = .UP;
            },
            .LEFT  => {
                if (empty_tile_pos.x == GRID_DIMENSION - 1) {
                    animating_tile = 0;
                    break :blk;
                }
                const swap_tile_index = empty_tile_index + 1;
                grid[empty_tile_index] = grid[swap_tile_index];
                grid[swap_tile_index] = 0;
                animating_tile = grid[empty_tile_index];
                animation_direction = .LEFT;
            },
            .DOWN  => {
                if (empty_tile_pos.y == 0) {
                    animating_tile = 0;
                    break :blk;
                }
                const swap_tile_index = empty_tile_index - GRID_DIMENSION;
                grid[empty_tile_index] = grid[swap_tile_index];
                grid[swap_tile_index] = 0;
                animating_tile = grid[empty_tile_index];
                animation_direction = .DOWN;
            },
            .RIGHT => {
                if (empty_tile_pos.x == 0) {
                    animating_tile = 0;
                    break :blk;
                }
                const swap_tile_index = empty_tile_index - 1;
                grid[empty_tile_index] = grid[swap_tile_index];
                grid[swap_tile_index] = 0;
                animating_tile = grid[empty_tile_index];
                animation_direction = .RIGHT;
            },
        }
    }
}

fn render() void {

    defer {
        color_vertex_buffer_index = 0;
    }
    
    // if (tile_movement_direction != .NONE) {
    //     debug_print_grid();
    // }


    draw_grid_geometry();

    // gl commands
    // @maybe: move to a separate proc 

    
    const gl = zopengl.bindings;

    gl.clearColor(0.2, 0.2, 0.2, 1);
    gl.clear(gl.COLOR_BUFFER_BIT);

    // Push color_vertex_buffer data to GPU.
    gl.bufferSubData(gl.ARRAY_BUFFER,
                     0,
                     @as(c_int, @intCast(color_vertex_buffer_index)) * 5 * @sizeOf(f32),
                     &color_vertex_buffer[0]);
    // Draw the triangles.
    gl.drawArrays(gl.TRIANGLES, 0, @as(c_int, @intCast(color_vertex_buffer_index)));

    
    window.swapBuffers();
}

fn draw_grid_geometry() void {
    const TILE_WIDTH : f32  = 100;
    const TILE_BORDER_WIDTH = 0.05 * TILE_WIDTH;
    const TILE_SPACING      = 0.02 * TILE_WIDTH;
    const GRID_BORDER_WIDTH = 0.10 * TILE_WIDTH;


    const CENTER : Vec2 = .{500, 500};

    const INNER_GRID_WIDTH = GRID_DIMENSION * TILE_WIDTH + (GRID_DIMENSION + 1) * TILE_SPACING + 2 * GRID_DIMENSION * TILE_BORDER_WIDTH;
    const OUTER_GRID_WIDTH = INNER_GRID_WIDTH + 2 * GRID_BORDER_WIDTH;

    const outer_grid_rectangle = rectangle(CENTER, OUTER_GRID_WIDTH, OUTER_GRID_WIDTH);
    const inner_grid_rectangle = rectangle(CENTER, INNER_GRID_WIDTH, INNER_GRID_WIDTH);

    var grid_tile_rectangles : [TILE_NUMBER] Rectangle = undefined;

    const TOP_LEFT_TILE_POSX = CENTER[0] - 0.5 * INNER_GRID_WIDTH + TILE_SPACING + TILE_BORDER_WIDTH + 0.5 * TILE_WIDTH;
    const TOP_LEFT_TILE_POSY = TOP_LEFT_TILE_POSX;

    for (0..GRID_DIMENSION) |j| {
        const posy = TOP_LEFT_TILE_POSX + @as(f32, @floatFromInt(j)) * (TILE_SPACING + 2 * TILE_BORDER_WIDTH + TILE_WIDTH);
        for (0..GRID_DIMENSION) |i| {
            const posx = TOP_LEFT_TILE_POSY + @as(f32, @floatFromInt(i)) * (TILE_SPACING + 2 * TILE_BORDER_WIDTH + TILE_WIDTH);
            const tile_rect = rectangle(.{posx, posy}, TILE_WIDTH, TILE_WIDTH);
            grid_tile_rectangles[j * GRID_DIMENSION + i] = tile_rect;
        }
    }

    draw_color_rectangle(outer_grid_rectangle, colors.GRID_BORDER);
    draw_color_rectangle(inner_grid_rectangle, colors.GRID_BACKGROUND);


    const TILE_BORDER_RECT_WIDTH = 2 * TILE_BORDER_WIDTH + TILE_WIDTH;
    
    for (grid, 0..) |tile, i| {
        if (tile == 0 or tile == animating_tile) { continue; }

        const tile_color = tile_to_color(tile);
        const rect = grid_tile_rectangles[i];
        const tile_border_rect = rectangle(rect.pos, TILE_BORDER_RECT_WIDTH, TILE_BORDER_RECT_WIDTH);
        draw_color_rectangle(tile_border_rect, colors.TILE_BORDER);
        draw_color_rectangle(rect, tile_color);
    }

    // Draw the animating tile (if non-zero).
    if (animating_tile != 0) {
        
        const animating_tile_index_tilde = find_tile_index(animating_tile);
        const animating_tile_index : u8 = @intCast(animating_tile_index_tilde.?);

        const final_tile_rect = grid_tile_rectangles[animating_tile_index];
        const final_tile_pos = final_tile_rect.pos;

        // TODO.. make it move in the proper direction!

        const ANIMATION_DISTANCE = TILE_WIDTH + 2 * TILE_BORDER_WIDTH + TILE_SPACING;
        const AD = ANIMATION_DISTANCE;
        
        const animation_splat : Vec2 = @splat(1 - animation_fraction);
        const animation_offset_vec : Vec2 = switch(animation_direction) {
            .NONE => unreachable,
            .UP   => .{0, AD},
            .LEFT => .{AD, 0},
            .DOWN => .{0, -AD},
            .RIGHT => .{-AD, 0},
        };
        const animating_tile_pos = final_tile_pos + animation_splat * animation_offset_vec;
        const animating_tile_color = tile_to_color(animating_tile);
        
        const animating_tile_rect = rectangle(animating_tile_pos, final_tile_rect.w, final_tile_rect.h);
        const animating_tile_border_rect = rectangle(animating_tile_rect.pos, TILE_BORDER_RECT_WIDTH, TILE_BORDER_RECT_WIDTH);
        draw_color_rectangle(animating_tile_border_rect, colors.TILE_BORDER);
        draw_color_rectangle(animating_tile_rect, animating_tile_color);
    }
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
}

fn draw_color_rectangle( rect : Rectangle , color : Color) void {
    // Compute the coordinates of the corners of the rectangle.
    const xleft   = rect.pos[0] - 0.5 * rect.w;
    const xright  = rect.pos[0] + 0.5 * rect.w;
    const ytop    = rect.pos[1] - 0.5 * rect.h;
    const ybottom = rect.pos[1] + 0.5 * rect.h;

    const r = @as(f32, @floatFromInt(color[0])) / 255;
    const g = @as(f32, @floatFromInt(color[1])) / 255;
    const b = @as(f32, @floatFromInt(color[2])) / 255;
    
    // Compute nodes we will push to the GPU.
    const v0 = colorVertex(xleft,  ytop, r, g, b);
    const v1 = colorVertex(xright, ytop, r, g, b);
    const v2 = colorVertex(xleft,  ybottom, r, g, b);
    const v3 = v1;
    const v4 = v2;
    const v5 = colorVertex(xright, ybottom, r, g, b);

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



fn compile_shaders() ShaderCompileError!void {

    const gl = zopengl.bindings;
    
    const vSID : c_uint = gl.createShader(gl.VERTEX_SHADER);
    const fSID : c_uint = gl.createShader(gl.FRAGMENT_SHADER);

    const vertex_shader_source   = @embedFile("vertex.glsl");
    const fragment_shader_source = @embedFile("fragment.glsl");
    
    const vss_location : [*c] const u8 = &vertex_shader_source[0];
    const fss_location : [*c] const u8 = &fragment_shader_source[0];

    // Add the source of the shaders to the objects.
    gl.shaderSource(vSID, 1, &vss_location, null);
    gl.shaderSource(fSID, 1, &fss_location, null);

    // Attempt to compile the shaders.
    gl.compileShader(vSID);
    gl.compileShader(fSID);

    // Check the shaders actually compiled.
    var vertex_success   : c_int = undefined;
    var fragment_success : c_int = undefined;

    gl.getShaderiv(vSID, gl.COMPILE_STATUS, &vertex_success);
    gl.getShaderiv(fSID, gl.COMPILE_STATUS, &fragment_success);

    var log_bytes : [512] u8 = undefined;

    if (vertex_success != gl.TRUE) {
        gl.getShaderInfoLog(vSID, 512, null, &log_bytes);
        dprint("{s}\n", .{log_bytes});
        return ShaderCompileError.VertexShaderCompFail;
    } else {
        dprint("DEBUG: vertex shader compilation: success\n", .{}); //@debug
    }

    if (fragment_success != gl.TRUE) {
        gl.getShaderInfoLog(fSID, 512, null, &log_bytes);
        dprint("{s}\n", .{log_bytes});
        return ShaderCompileError.FragmentShaderCompFail;
    } else {
        dprint("DEBUG: fragment shader compilation: success\n", .{}); //@debug
    }

	// Attempt to link shaders.
    const pID : c_uint = gl.createProgram();
    gl.attachShader(pID, vSID);
    gl.attachShader(pID, fSID);
    gl.linkProgram(pID);

	// Check for linking errors. If none, clean up shaders.
    var compile_success : c_int = undefined;
	gl.getProgramiv(pID, gl.LINK_STATUS, &compile_success);

	if(compile_success != gl.TRUE) {
		gl.getProgramInfoLog(pID, 512, null, &log_bytes);
        dprint("{s}\n", .{log_bytes});
        return ShaderCompileError.ShaderLinkFail;
	} else {
        dprint("DEBUG: vertex and fragment shader linkage: success\n", .{}); //@debug
    	gl.deleteShader(vSID);
		gl.deleteShader(fSID);
    }

    global_shader = pID;

    // (Finally) make the shader active.
	gl.useProgram(global_shader);
}

fn setup_array_buffers() void {
    
    const gl = zopengl.bindings;

    gl.genVertexArrays(1, &global_vao);
    gl.bindVertexArray(global_vao);

    gl.genBuffers(1, &global_vbo);
    gl.bindBuffer(gl.ARRAY_BUFFER, global_vbo);

    gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(color_vertex_buffer)), null, gl.DYNAMIC_DRAW);

    gl.vertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 5 * @sizeOf(f32), @ptrFromInt(0));
    gl.vertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 5 * @sizeOf(f32), @ptrFromInt(2 * @sizeOf(f32)));
    gl.enableVertexAttribArray(0);
    gl.enableVertexAttribArray(1);
}

fn find_tile_index( wanted_tile : u8) ?usize {
    for (grid, 0..) |tile, i| {
        if (tile == wanted_tile) {
            return i;
        }
    }
    return null;
}

fn timestamp_delta_to_seconds(t2 : u64, t1 : u64) f32 {
    // The stopwatch is monotonic, so this shouldn't give an underflow...
    const nano_diff : f32 = @floatFromInt(t2 - t1);
    const secs_diff = nano_diff / 1_000_000_000;
    return secs_diff;
}

fn tile_to_color(tile : u8) Color {
    const coord = gridCoord(tile % GRID_DIMENSION, tile / GRID_DIMENSION);
    return Color{20 + 40 * coord.x, 90, 30 + 30 * coord.y, 255};
}

// Random shuffle via Fisher-Yates and a Xorshift PRNG.

// General idea: construct list2 by picking with uniformly
// random distribution items from list1, and then removing them.
//
// NOTE: (Obvious) Picking uniformly randomly from the ordered set
// {1, 2, 3, 4, 5} is the same as picking uniformly from
// {5, 4, 3, 2, 1} ... or any other permutation.
// As such, the algorithm can be condensed into a single list
// by swapping.

fn fisher_yates(comptime N : u8, original_list : [N] u8) [N] u8 {
    var list = original_list;
    for (0..N) |i| {
        // Pick an random index from 0..N-i;
        const ii : u8 = @intCast(i);
        const back_index   = N - 1 - ii;
        const random_index = get_randomish_byte_up_to(N - ii);

        // Perform the swap.
        const random_element = list[random_index];
        const back_element   = list[back_index];
        list[back_index]     = random_element;
        list[random_index]   = back_element;
    }
    return list;
}

fn get_randomish_byte( prng : *XorShiftPRNG) u8 {
    // Pick a byte near the 'middle'.
    const byte : u8 = @truncate(prng.state >> 32);
    prng.update_state();
    return byte;
}

// Return a random number from 0..<limit <= 255.
fn get_randomish_byte_up_to(limit : u8) u8 {
    const remainder = 255 % limit;
    const modulo_limit = (255 - remainder) - 1;
    var random_byte : u8 = 0;
    while (true) {
        random_byte = get_randomish_byte(&global_prng);
        if (random_byte <= modulo_limit) {
            break;
        }
    }
    const final_byte = random_byte % limit;
    return final_byte;
}

const XorShiftPRNG = struct {
    state : u64,

    fn update_state(self : *XorShiftPRNG) void {
        const x1 = self.state; 
        const x2 = x1 ^ (x1 << 13);
        const x3 = x2 ^ (x2 >> 7);
        const x4 = x3 ^ (x3 << 17);
        self.state = x4;
    }
};

fn initialize_xorshiftprng( seed : u64 ) XorShiftPRNG {
    var xorshiftprng = XorShiftPRNG{ .state = seed };
    for (0..10) |i| {
        _ = i;
        xorshiftprng.update_state();
    }
    return xorshiftprng;
}
