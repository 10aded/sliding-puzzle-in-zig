// This is a simple sliding puzzle game. Solving the game
// typically takes less than 10 minutes.
//
// Created by 10aded throughout Feb 2025.
// Updated to use the Zig 0.14.0 compiler on 18 May 2025.
//
// The project is built with the command:
//
//     zig build -Doptimize=ReleaseFast
//
// run in the top directory of the project.
//
// Building the project requires the compiler version to be
// a at minimum 0.14.0.
// 
// The entire source code of this project is available on GitHub at:
//
// https://github.com/10aded/sliding-puzzle-in-zig
//
// and was developed (almost) entirely on the Twitch channel 10aded.
// Copies of the stream are on YouTube at the @10aded channel.
//
// This project has two Zig gamedev library dependencies:
//   * zglfw
//   * zopengl;
// these are both automatically fetched when the command "zig build run" is used
// for the first time.
//
// Both libraries are available on GitHub at:
//
//    https://github.com/zig-gamedev
//
// Both libraries have MIT licenses; see the link above for details.

// Standard Library.
const std = @import("std");

// Zig Gamedev libraries.
const glfw    = @import("zglfw");
const zopengl = @import("zopengl");

// Our own QOI image parsing library.
const qoi = @import("qoi.zig");

// Constant aliases.
const PI = std.math.pi;

// The size of the puzzle grid.
const GRID_DIMENSION = 3;

// Note: The game can be (unexpectedly) very difficult when
// GRID_DIMENSION >= 4.

// Type aliases.
const Vec2  = @Vector(2, f32);
const Vec4  = @Vector(4, f32);
const Color = @Vector(4, u8);

const VAO           = c_uint;
const VBO           = c_uint;
const Texture       = c_uint;
const ShaderProgram = c_uint;

// Images

// "The Blue Marble" is a famous photo taken by the Apollo 17 crew,
// and is in the public domain and available from:
// https://commons.wikimedia.org/wiki/File:The_Earth_seen_from_Apollo_17.jpg
const blue_marble_qoi = @embedFile("./Assets/blue-marble.qoi");
const blue_marble_header = qoi.comptime_header_parser(blue_marble_qoi);
const blue_marble_width  = blue_marble_header.image_width;
const blue_marble_height = blue_marble_header.image_height;
var blue_marble_pixel_bytes : [blue_marble_width * blue_marble_height] Color = undefined;

// The quote is from the blog "The Techno-Optimist Manifesto" by
// Andrew Kelley (published 17 Oct 2023) and is available at:
// https://andrewkelley.me/post/the-techno-optimist-manifesto.html
const quote_qoi = @embedFile("./Assets/quote.qoi");
const quote_header = qoi.comptime_header_parser(quote_qoi);
const quote_width  = quote_header.image_width;
const quote_height = quote_header.image_height;
var quote_pixel_bytes : [quote_width * quote_height] Color = undefined;

 // Shaders
const vertex_background = @embedFile("./Shaders/vertex-background.glsl");
const fragment_background = @embedFile("./Shaders/fragment-background.glsl");

const vertex_color_texture = @embedFile("./Shaders/vertex-color-texture.glsl");
const fragment_color_texture = @embedFile("./Shaders/fragment-color-texture.glsl");

// Constants.
const TILE_NUMBER = GRID_DIMENSION * GRID_DIMENSION;

// Colors
const WHITE       = Color{255,   255,  255, 255};
const MAGENTA     = Color{255,     0,  255, 255};
const GRID_BLUE   = Color{0x3e, 0x48, 0x5f, 255};
const SPACE_BLACK = Color{0x03, 0x03, 0x05, 255};

const DEBUG_COLOR       = MAGENTA;
const GRID_BACKGROUND   = WHITE;
const TILE_BORDER       = GRID_BLUE;

// Shader
const BACKGROUND_SHADER_SHAPE_CHANGE_TIME = 200;

// Grid geometry.
// NOTE: It is assumed that the window dimensions of the game
// will NOT change.
const TILE_WIDTH : f32  = 100;
const TILE_BORDER_WIDTH = 0.05 * TILE_WIDTH;
const TILE_SPACING      = 0.02 * TILE_WIDTH;

const CENTER : Vec2 = .{500, 500};

const GRID_WIDTH = GRID_DIMENSION * TILE_WIDTH + (GRID_DIMENSION + 1) * TILE_SPACING + 2 * GRID_DIMENSION * TILE_BORDER_WIDTH;

// Errors
const ShaderCompileError = error{ VertexShaderCompFail, FragmentShaderCompFail, ShaderLinkFail };

// Globals
// Game logic.
var is_won = false;

// Window
var window : *glfw.Window = undefined;

// Graphics globals
var background_vao : VAO = undefined;
var background_vbo : VBO = undefined;

var color_texture_vao : VAO = undefined;
var color_texture_vbo : VBO = undefined;

// Shaders
var background_shader    : ShaderProgram = undefined;
var color_texture_shader : ShaderProgram = undefined;

// Textures
var blue_marble_texture  : Texture = undefined;
var quote_texture        : Texture = undefined;

// Grid
// Convention: the left to right array layout represents the grid
// per row from left to right, top to bottom.
var grid : [TILE_NUMBER] u8 = undefined;

// Grid movement
const GridMovementDirection = enum (u8) {
    NONE,
    UP,
    LEFT,
    DOWN,
    RIGHT,
};

var current_tile_movement_direction : GridMovementDirection = .NONE;

// Random number generator
var global_prng : XorShiftPRNG = undefined;

// Timing
var stopwatch : std.time.Timer = undefined;

// Note: Timestamps are in nanoseconds.
var program_start_timestamp   : u64 = undefined;
var frame_timestamp           : u64 = undefined;
var animation_start_timestamp : u64 = undefined;
var won_timestamp             : u64 = undefined;

// Animation
const ANIMATION_SLIDING_TILE_TIME : f32 = 0.15;
const ANIMATION_WON_TIME          : f32 = 3;
const ANIMATION_QUOTE_TIME        : f32 = 3;

var animating_tile : u8 = 0;
var animation_direction : GridMovementDirection = undefined;

var animation_tile_fraction  : f32 = 0;
var animation_won_fraction   : f32 = 0;
var animation_quote_fraction : f32 = 0;

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
const ColorTextureVertex = extern struct {
    x  : f32,
    y  : f32,
    r  : f32,
    g  : f32,
    b  : f32,
    tx : f32,
    ty : f32,
    l  : f32, 
};

fn colorTextureVertex( x : f32, y : f32, r : f32, g : f32, b :f32, tx : f32, ty : f32, l : f32) ColorTextureVertex {
    return ColorTextureVertex{.x = x, .y = y, .r = r, .g = g, .b = b, .tx = tx, .ty = ty, .l = l};
}

// Note: The size of the vertex_buffer assumes the game will
// not have a grid larger than 6 x 6.
var vertex_buffer : [500] ColorTextureVertex = undefined;
var vertex_buffer_index : usize = 0;

const Rectangle = struct {
    center : Vec2,
    width  : f32,
    height : f32,
};

fn rectangle(pos : Vec2, width : f32, height : f32) Rectangle {
    return Rectangle{.center = pos, .width = width, .height = height};
}



pub fn main() void {
    stopwatch = std.time.Timer.start() catch unreachable;
    program_start_timestamp = stopwatch.read();

    init_grid();

    decompress_qoi_images();
    
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

        compute_grid_geometry();
        
        render();
    }

    window.destroy();
}

fn init_grid() void {
    // Initialize PRNG.
    const seed : u64 = program_start_timestamp;
    global_prng = initialize_xorshiftprng(seed);

    // NOTE: Initializing the grid with a random shuffle will produce
    // a puzzle that is IMPOSSIBLE to solve 50% of the time. (This
    // fact is left as a highly recommended exercise to the reader.)
    //
    // Additionally, from a starting solved state randomly applying
    // grid moves will not in general create a grid that is
    // "sufficiently" shuffled. See, for example:
    //
    //     https://en.wikipedia.org/wiki/Random_walk#Lattice_random_walk
    //
    // As such we apply a SMALL number of pre-generated shuffles that
    // make the grid appear "randomly" shuffled.

    // File the grid with 0, 1, 2, ... , TILE_NUMBER - 1.
    grid = std.simd.iota(u8, TILE_NUMBER);

    // Some prerecorded tile shuffles.
    const shuffle1 = [_] u8 {2, 1, 4, 1, 2, 3, 2, 1, 4, 1, 2, 3, 4, 2, 2, 1, 4, 4, 3, 2, 3, 2, 1, 4, 3, 3, 4, 1, 1, 1, 4, 3, 2, 2, 3, 4, 1, 2, 1, 4, 3, 2, 3, 4, 3, 2, 1, 2, 3, 4, 4, 1, 1, 4, 3, 2, 1, 3, 1, 4, 1, 2, 2, 2, 3, 4, 4, 3, 2, 1, 4, 4, 3, 2, 2, 2, 3, 4, 1, 1, 4, 3, 3, 4, 1, 1, 2, 2, 3, 4, 1, 4, 1, 2, 2, 3, 4, 3, 2, 1, 2, 1, 4, 3, 3, 4, 3, 2, 2, 1, 4, 3, 4, 4, 2, 2, 1, 1, 2, 1, 4, 4, 3, 3, 2, 1, 4, 3, 2, 1, 4, 3, 4, 3, 2, 3, 1, 2, 3, 4, 1, 2, 3, 4, 1, 1, 4, 3, 2, 3, 4};

    const shuffle2 = [_] u8 {2, 2, 1, 4, 4, 2, 1, 1, 2, 3, 4, 3, 2, 2, 4, 3, 4, 1, 1, 1, 4, 3, 3, 2, 1, 4, 3, 2, 2, 1, 4, 3, 2, 2, 1, 4, 1, 2, 3, 4, 4, 1, 3, 3, 2, 1, 4, 3, 3, 2, 1, 4, 3, 4, 1, 1, 2, 1, 2, 3, 4, 3, 2, 2, 3, 4, 1, 1, 4, 2, 1, 2, 3, 4, 4, 3, 4, 1, 3, 2, 3, 4, 1, 1, 2, 1, 4, 3, 2, 2, 3, 4, 1, 2, 3, 2, 1, 4, 3, 3, 4, 4, 1, 1, 1, 2, 3, 4, 2, 2, 3, 4, 1, 2, 3, 4, 4, 3, 2, 2, 2, 1, 1, 1, 4, 3, 3, 2, 3, 4, 1, 2, 1, 4, 1, 2, 3, 4, 4, 3, 4, 3};

    const shuffles = [2] [] const u8 {shuffle1[0..], shuffle2[0..]};
    // Apply these each a couple of times, randomly.
    
    const NUMBER_OF_SHUFFLES = 10;
    
    var shuffle_index : usize = 0;
    while (shuffle_index < NUMBER_OF_SHUFFLES) : (shuffle_index += 1) {
        const random_int = get_randomish_byte_up_to(2);
        const random_shuffle = shuffles[random_int];

        for (random_shuffle) |dir| {
            const move_direction : GridMovementDirection = @enumFromInt(dir);
            try_grid_update(move_direction);
        }
    }
}

fn decompress_qoi_images() void {
    qoi.qoi_to_pixels(blue_marble_qoi, blue_marble_width * blue_marble_height, &blue_marble_pixel_bytes);
    qoi.qoi_to_pixels(quote_qoi, quote_width * quote_height, &quote_pixel_bytes);
}

fn init_opengl() void {
    const gl_major = 4;
    const gl_minor = 0;
    glfw.windowHint(.context_version_major, gl_major);
    glfw.windowHint(.context_version_minor, gl_minor);
    glfw.windowHint(.opengl_profile, .opengl_core_profile);
    glfw.windowHint(.opengl_forward_compat, true);
    glfw.windowHint(.client_api, .opengl_api);
    glfw.windowHint(.doublebuffer, true);

    window = glfw.Window.create(1000, 1000, "Sliding Puzzle Game", null) catch unreachable;

    glfw.makeContextCurrent(window);

    zopengl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor) catch unreachable;

    glfw.swapInterval(1);
}

fn compile_shaders() ShaderCompileError!void {
    background_shader    = try compile_shader(vertex_background,    fragment_background);
    color_texture_shader = try compile_shader(vertex_color_texture, fragment_color_texture);
}

fn compile_shader( vertex_shader_source : [:0] const u8, fragment_shader_source : [:0] const u8 ) ShaderCompileError!ShaderProgram {

    const stderr = std.io.getStdErr().writer();

    const gl = zopengl.bindings;
    
    const vSID : c_uint = gl.createShader(gl.VERTEX_SHADER);
    const fSID : c_uint = gl.createShader(gl.FRAGMENT_SHADER);
    
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
        stderr.print("{s}\n", .{log_bytes}) catch unreachable;
        return ShaderCompileError.VertexShaderCompFail;
    } else {
        std.debug.print("DEBUG: vertex shader {} compilation: success\n", .{vSID});
    }

    if (fragment_success != gl.TRUE) {
        gl.getShaderInfoLog(fSID, 512, null, &log_bytes);
        stderr.print("{s}\n", .{log_bytes}) catch unreachable;
        return ShaderCompileError.FragmentShaderCompFail;
    } else {
        std.debug.print("DEBUG: fragment shader {} compilation: success\n", .{fSID});
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
        stderr.print("{s}\n", .{log_bytes}) catch unreachable;
        return ShaderCompileError.ShaderLinkFail;
	} else {
        std.debug.print("DEBUG: vertex and fragment shader {} linkage: success\n", .{pID});
    	gl.deleteShader(vSID);
		gl.deleteShader(fSID);
    }

    return pID;
}

fn setup_array_buffers() void {
    
    const gl = zopengl.bindings;

    // Set up background VAO / VBO.
    // Note: This assumes the window dimensions are 1000 x 1000.
    var background_vertex_buffer = [6 * 2] f32 {
        0, 0,
        0, 1000,
        1000, 1000,
        0, 0,
        1000, 0,
        1000, 1000,
    };
    
    gl.genVertexArrays(1, &background_vao);
    gl.bindVertexArray(background_vao);

    gl.genBuffers(1, &background_vbo);
    gl.bindBuffer(gl.ARRAY_BUFFER, background_vbo);

    gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(background_vertex_buffer)), &background_vertex_buffer[0], gl.STATIC_DRAW);

    gl.vertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 2 * @sizeOf(f32), @ptrFromInt(0));
    gl.enableVertexAttribArray(0);
    
    // Set up color_texture VAO / VBO.
    gl.genVertexArrays(1, &color_texture_vao);
    gl.bindVertexArray(color_texture_vao);

    gl.genBuffers(1, &color_texture_vbo);
    gl.bindBuffer(gl.ARRAY_BUFFER, color_texture_vbo);    

    gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(vertex_buffer)), null, gl.DYNAMIC_DRAW);

    gl.vertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), @ptrFromInt(0));
    gl.vertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), @ptrFromInt(2 * @sizeOf(f32)));
    gl.vertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), @ptrFromInt(5 * @sizeOf(f32)));
    gl.vertexAttribPointer(3, 1, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), @ptrFromInt(7 * @sizeOf(f32)));
    
    gl.enableVertexAttribArray(0);
    gl.enableVertexAttribArray(1);
    gl.enableVertexAttribArray(2);
    gl.enableVertexAttribArray(3);
    
    // Setup blue_marble texture.
    gl.genTextures(1, &blue_marble_texture);
    gl.bindTexture(gl.TEXTURE_2D, blue_marble_texture);

    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_BORDER);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

    // Note: The width and height have type "GLsizei"... i.e. a i32.
    const bm_width  : i32 = @intCast(blue_marble_width);
    const bm_height : i32 = @intCast(blue_marble_height);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, bm_width, bm_height, 0, gl.RGBA, gl.UNSIGNED_BYTE, &blue_marble_pixel_bytes[0]);

    // Set up quote texture.
    gl.genTextures(1, &quote_texture);
    gl.bindTexture(gl.TEXTURE_2D, quote_texture);

    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_BORDER);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

    const q_width  : i32 = @intCast(quote_width);
    const q_height : i32 = @intCast(quote_height);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, q_width, q_height, 0, gl.RGBA, gl.UNSIGNED_BYTE, &quote_pixel_bytes[0]);
}

fn process_input() void {

    keyDownLastFrame = keyDown;
    
    // Poll GLFW for whether keys are down or not.
    keyDown.w           = glfw.getKey(window, glfw.Key.w) == glfw.Action.press;
    keyDown.a           = glfw.getKey(window, glfw.Key.a) == glfw.Action.press;
    keyDown.s           = glfw.getKey(window, glfw.Key.s) == glfw.Action.press;
    keyDown.d           = glfw.getKey(window, glfw.Key.d) == glfw.Action.press;
    
    keyDown.up_arrow    = glfw.getKey(window, glfw.Key.up)     == glfw.Action.press;
    keyDown.left_arrow  = glfw.getKey(window, glfw.Key.left)   == glfw.Action.press;
    keyDown.down_arrow  = glfw.getKey(window, glfw.Key.down)   == glfw.Action.press;
    keyDown.right_arrow = glfw.getKey(window, glfw.Key.right)  == glfw.Action.press;

    keyPress = @bitCast(@as(u8, @bitCast(keyDown)) & ~ @as(u8, @bitCast(keyDownLastFrame)));
}

fn update_state() void {

    // Reset tile movement.
    current_tile_movement_direction = .NONE;
    
    // Determine if a tile movement attempt has been made. 
    if (keyPress.w or keyPress.up_arrow)    { current_tile_movement_direction = .UP; }
    if (keyPress.a or keyPress.left_arrow)  { current_tile_movement_direction = .LEFT; }
    if (keyPress.s or keyPress.down_arrow)  { current_tile_movement_direction = .DOWN; }
    if (keyPress.d or keyPress.right_arrow) { current_tile_movement_direction = .RIGHT; }

    // Reset animation if key press.
    if (@as(u8, @bitCast(keyPress)) != 0) {
        animation_start_timestamp = frame_timestamp;
    }

    // Check if animation over. Otherwise calculate animation fraction.
    const secs_since_animation_start = timestamp_delta_to_seconds(frame_timestamp, animation_start_timestamp);
    if (secs_since_animation_start > ANIMATION_SLIDING_TILE_TIME) {
        animation_direction = .NONE;
        animating_tile = 0;
        animation_tile_fraction = 0;
    } else {
        animation_tile_fraction = secs_since_animation_start / ANIMATION_SLIDING_TILE_TIME;
    }
    
    // Try a move!
    try_grid_update(current_tile_movement_direction);

    // Check if the puzzle is solved (if not already won).
    if (! is_won ) {
        is_won = @reduce(.And, grid == std.simd.iota(u8, TILE_NUMBER));
        if (is_won) {
            won_timestamp = frame_timestamp;
        }
    }

    // Calculate the animation_won_fraction.
    if (is_won) {
        const secs_since_won = timestamp_delta_to_seconds(frame_timestamp, won_timestamp);
        animation_won_fraction   = std.math.clamp(secs_since_won, 0, ANIMATION_WON_TIME) / ANIMATION_WON_TIME;
        animation_quote_fraction = std.math.clamp(secs_since_won - ANIMATION_WON_TIME + 1, 0, ANIMATION_QUOTE_TIME) / ANIMATION_QUOTE_TIME;
    }
}

// Try and move and calculate the new grid configuration (if it changes).
fn try_grid_update(tile_movement_direction : GridMovementDirection) void {
    // E.g.
    //
    // 0 1  -- LEFT -->  1 0
    // 2 3               2 3

    // 1 2               1 0
    // 3 0  -- DOWN -->  3 2
    
    // Find empty tile.
    const empty_tile_index_tilde = find_tile_index(0);
    const empty_tile_index : u8 = @intCast(empty_tile_index_tilde.?);

    const empty_tile_posx = empty_tile_index % GRID_DIMENSION;
    const empty_tile_posy = empty_tile_index / GRID_DIMENSION;

    // Determine if the grid needs to be updated.
    const no_grid_update : bool = switch(tile_movement_direction) {
        .NONE  => true,
        .UP    => empty_tile_posy == GRID_DIMENSION - 1,
        .LEFT  => empty_tile_posx == GRID_DIMENSION - 1,
        .DOWN  => empty_tile_posy == 0,
        .RIGHT => empty_tile_posx == 0,
    };

    // Cancel any existing animation if a movement key was pressed
    // but the grid cannot be updated.
    if (no_grid_update and tile_movement_direction != .NONE) {
        animating_tile = 0;
    }

    // Update the grid.
    if (! no_grid_update and ! is_won) {
        const swap_tile_index : usize = switch(tile_movement_direction) {
            .NONE  => unreachable,
            .UP    => empty_tile_index + GRID_DIMENSION,
            .LEFT  => empty_tile_index + 1,
            .DOWN  => empty_tile_index - GRID_DIMENSION,
            .RIGHT => empty_tile_index - 1,
        };

        grid[empty_tile_index] = grid[swap_tile_index];
        grid[swap_tile_index] = 0;
        animating_tile = grid[empty_tile_index];
        animation_direction = tile_movement_direction;
    }
}

fn render() void {

    const gl = zopengl.bindings;

    // Set the background, which appears during a window resize (which
    // is assumed NOT to happen) to be a dark gray.
    gl.clearColor(0.2, 0.2, 0.2, 1);
    gl.clear(gl.COLOR_BUFFER_BIT);

    // Calculate background_shader uniforms.
    const program_secs : f32 = timestamp_delta_to_seconds(frame_timestamp, program_start_timestamp);
    const lp_value = 1.5 + 0.5 * @cos(PI * program_secs / BACKGROUND_SHADER_SHAPE_CHANGE_TIME);

    const radius_value : f32 = 0.018571486 * switch(is_won) {
        false => 1,
        true  => 1 - animation_won_fraction,
    };

    // Render the background pattern.
    gl.bindVertexArray(background_vao);
    gl.bindBuffer(gl.ARRAY_BUFFER, background_vbo);
    gl.useProgram(background_shader);

    // Set uniforms.
    const lp_shader_location     = gl.getUniformLocation(background_shader, "lp");
    const radius_shader_location = gl.getUniformLocation(background_shader, "radius");
        
    gl.uniform1f(lp_shader_location,     lp_value);
    gl.uniform1f(radius_shader_location, radius_value);

    // Draw background triangles.
    gl.drawArrays(gl.TRIANGLES, 0, @as(c_int, @intCast(6)));

    // Render the grid and tiles.
    gl.bindVertexArray(color_texture_vao);
    gl.bindBuffer(gl.ARRAY_BUFFER, color_texture_vbo);
    gl.useProgram(color_texture_shader);

    // Make the blue_marble texture active.
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, blue_marble_texture);

    const texture0_location = gl.getUniformLocation(color_texture_shader, "texture0");
    gl.uniform1i(texture0_location, 0);

    // Draw the grid and tile triangles.
    gl.bufferSubData(gl.ARRAY_BUFFER,
                     0,
                     @as(c_int, @intCast(vertex_buffer_index)) * 8 * @sizeOf(f32),
                     &vertex_buffer[0]);

    gl.drawArrays(gl.TRIANGLES, 0, @as(c_int, @intCast(vertex_buffer_index)));

    // Reset the vertex_buffer.
    vertex_buffer_index = 0;
    
    // Make the quote texture active.
    gl.bindTexture(gl.TEXTURE_2D, quote_texture);

    // Note: The game window is assumed to have dimensions 1000 x 1000,
    // which informed the values below.
    const quote_width_f32  : f32 = @floatFromInt(quote_width);
    const quote_height_f32 : f32 = @floatFromInt(quote_height);
    const quote_pos : Vec2 = .{550, 825};
    const quote_rectangle = rectangle(quote_pos, quote_width_f32, quote_height_f32);

    draw_color_texture_rectangle(quote_rectangle, SPACE_BLACK, .{0,0}, .{1, 1}, animation_quote_fraction);

    // Draw the quote.
    gl.bufferSubData(gl.ARRAY_BUFFER,
                     0,
                     @as(c_int, @intCast(vertex_buffer_index)) * 8 * @sizeOf(f32),
                     &vertex_buffer[0]);

    gl.drawArrays(gl.TRIANGLES, 0, @as(c_int, @intCast(vertex_buffer_index)));    
    
    window.swapBuffers();
}

fn compute_grid_geometry() void {

    // Reset the vertex_buffer.
    vertex_buffer_index = 0;
    
    const lambda = animation_won_fraction;
        
    // Compute the tile rectangles.
    const background_grid_rectangle = rectangle(CENTER, GRID_WIDTH, GRID_WIDTH);

    var grid_tile_rectangles : [TILE_NUMBER] Rectangle = undefined;

    const TOP_LEFT_TILE_POSX = CENTER[0] - 0.5 * GRID_WIDTH + TILE_SPACING + TILE_BORDER_WIDTH + 0.5 * TILE_WIDTH;
    const TOP_LEFT_TILE_POSY = TOP_LEFT_TILE_POSX;

    for (0..GRID_DIMENSION) |j| {
        const posy = TOP_LEFT_TILE_POSX + @as(f32, @floatFromInt(j)) * (TILE_SPACING + 2 * TILE_BORDER_WIDTH + TILE_WIDTH);
        for (0..GRID_DIMENSION) |i| {
            const posx = TOP_LEFT_TILE_POSY + @as(f32, @floatFromInt(i)) * (TILE_SPACING + 2 * TILE_BORDER_WIDTH + TILE_WIDTH);
            const tile_rect = rectangle(.{posx, posy}, TILE_WIDTH, TILE_WIDTH);
            grid_tile_rectangles[j * GRID_DIMENSION + i] = tile_rect;
        }
    }

    // Draw the grid background.
    draw_color_texture_rectangle(background_grid_rectangle, GRID_BACKGROUND, .{0, 0}, .{1, 1}, lambda);

    const TILE_BORDER_RECT_WIDTH = 2 * TILE_BORDER_WIDTH + TILE_WIDTH;

    const tile_border_width_splat : Vec2 = @splat(TILE_BORDER_WIDTH);
    const tile_width_splat        : Vec2 = @splat(TILE_WIDTH);
    const grid_width_splat        : Vec2 = @splat(GRID_WIDTH);
    
    // Draw the tiles.
    for (grid, 0..) |tile, i| {
        if (tile == 0 or tile == animating_tile) { continue; }

        const rect = grid_tile_rectangles[i];
        const tile_border_rect = rectangle(rect.center, TILE_BORDER_RECT_WIDTH, TILE_BORDER_RECT_WIDTH);

        // Calculate the texture tl of the tile (that is, the thing inside the border).
        const tilex : f32 = @floatFromInt(tile % GRID_DIMENSION);
        const tiley : f32 = @floatFromInt(tile / GRID_DIMENSION);
        
        const tl_x = (2 * tilex + 1) * TILE_BORDER_WIDTH + (tilex + 1 ) * TILE_SPACING + tilex * TILE_WIDTH;
        const tl_y = (2 * tiley + 1) * TILE_BORDER_WIDTH + (tiley + 1 ) * TILE_SPACING + tiley * TILE_WIDTH;

        const tl_inner = Vec2{tl_x, tl_y};
        const tl_outer = tl_inner - tile_border_width_splat;
        const br_inner = tl_inner + tile_width_splat;
        const br_outer = br_inner + tile_border_width_splat;

        const tl_inner_st = tl_inner / grid_width_splat;
        const tl_outer_st = tl_outer / grid_width_splat;
        const br_inner_st = br_inner / grid_width_splat;
        const br_outer_st = br_outer / grid_width_splat;
        
        draw_color_texture_rectangle(tile_border_rect, TILE_BORDER, tl_outer_st, br_outer_st, lambda);
        draw_color_texture_rectangle(rect,             DEBUG_COLOR, tl_inner_st, br_inner_st, 1);
    }

    // Draw the animating tile (if non-zero).
    if (animating_tile != 0) {
        
        const animating_tile_index_tilde = find_tile_index(animating_tile);
        const animating_tile_index : u8 = @intCast(animating_tile_index_tilde.?);

        const final_tile_rect = grid_tile_rectangles[animating_tile_index];
        const final_tile_pos = final_tile_rect.center;

        const ANIMATION_DISTANCE = TILE_WIDTH + 2 * TILE_BORDER_WIDTH + TILE_SPACING;
        const AD = ANIMATION_DISTANCE;
        
        const animation_splat : Vec2 = @splat(1 - animation_tile_fraction);
        const animation_offset_vec : Vec2 = switch(animation_direction) {
            .NONE => unreachable,
            .UP   => .{0, AD},
            .LEFT => .{AD, 0},
            .DOWN => .{0, -AD},
            .RIGHT => .{-AD, 0},
        };
        const animating_tile_pos = final_tile_pos + animation_splat * animation_offset_vec;

        const animating_tile_rect        = rectangle(animating_tile_pos, final_tile_rect.width, final_tile_rect.height);
        const animating_tile_border_rect = rectangle(animating_tile_pos, TILE_BORDER_RECT_WIDTH, TILE_BORDER_RECT_WIDTH);

        // Calculate the texture tl of the tile.
        // A partial copy from above.
        const tilex : f32 = @floatFromInt(animating_tile % GRID_DIMENSION);
        const tiley : f32 = @floatFromInt(animating_tile / GRID_DIMENSION);
        
        const tl_x = (2 * tilex + 1) * TILE_BORDER_WIDTH + (tilex + 1 ) * TILE_SPACING + tilex * TILE_WIDTH;
        const tl_y = (2 * tiley + 1) * TILE_BORDER_WIDTH + (tiley + 1 ) * TILE_SPACING + tiley * TILE_WIDTH;

        const tl_inner = Vec2{tl_x, tl_y};
        const br_inner = tl_inner + tile_width_splat;
        
        const tl_inner_st    = tl_inner / grid_width_splat;
        const br_inner_st    = br_inner / grid_width_splat;

        draw_color_texture_rectangle(animating_tile_border_rect, TILE_BORDER, .{0, 0}, .{1, 1}, lambda);
        draw_color_texture_rectangle(animating_tile_rect,        DEBUG_COLOR, tl_inner_st, br_inner_st, 1);
    }
}

// Figure out and store the GPU data that will draw a rectangle
// interpolating a single specified color and a portion of a texture.
fn draw_color_texture_rectangle( rect : Rectangle , color : Color, top_left_texture_coord : Vec2, bottom_right_texture_coord : Vec2, lambda : f32 ) void {

    const tltc = top_left_texture_coord;
    const brtc = bottom_right_texture_coord;

    // Compute the rectangle corner coordinates.
    const xleft   = rect.center[0] - 0.5 * rect.width;
    const xright  = rect.center[0] + 0.5 * rect.width;
    const ytop    = rect.center[1] - 0.5 * rect.height;
    const ybottom = rect.center[1] + 0.5 * rect.height;

    const color_f32 : Vec4 = @floatFromInt(color);
    const splat255  : Vec4 = @splat(255);
    const color_norm = color_f32 / splat255;
    const r = color_norm[0];
    const g = color_norm[1];
    const b = color_norm[2];

    // Compute the coordinates of the texture.
    const sleft   = tltc[0];
    const sright  = brtc[0];
    const ttop    = tltc[1];
    const tbottom = brtc[1];
    
    // Compute nodes we will push to the GPU.
    const v0 = colorTextureVertex(xleft,  ytop,    r, g, b, sleft,  ttop,    lambda);
    const v1 = colorTextureVertex(xright, ytop,    r, g, b, sright, ttop,    lambda);
    const v2 = colorTextureVertex(xleft,  ybottom, r, g, b, sleft,  tbottom, lambda);
    const v3 = v1;
    const v4 = v2;
    const v5 = colorTextureVertex(xright, ybottom, r, g, b, sright, tbottom, lambda);

    // Set the vertex buffer with the data.
    const buffer = &vertex_buffer;
    const i      = vertex_buffer_index;

    buffer[i + 0] = v0;
    buffer[i + 1] = v1;
    buffer[i + 2] = v2;
    buffer[i + 3] = v3;
    buffer[i + 4] = v4;
    buffer[i + 5] = v5;
    
    vertex_buffer_index += 6;
}

fn find_tile_index( wanted_tile : u8) ?usize {
    for (grid, 0..) |tile, i| {
        if (tile == wanted_tile) { return i; }
    }
    return null;
}

fn timestamp_delta_to_seconds(t2 : u64, t1 : u64) f32 {
    // The stopwatch is monotonic, so the difference
    // shouldn't give an runtime underflow panic.
    const nano_diff : f32 = @floatFromInt(t2 - t1);
    const secs_diff = nano_diff / 1_000_000_000;
    return secs_diff;
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
