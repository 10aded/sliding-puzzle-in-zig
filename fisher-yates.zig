const std = @import("std");

// "Extremely Crude O(n) Fisher-Yates and PRNG.
//
// Basically a sketch / draft.
//
// ABSOLUTELY NOT OKAY FOR PRODUCTION CODE OF ANY SORT.
//
// ... it may be better than the 25 years of Java's LGC though :P


// Globals
const dprint = std.debug.print;

var global_prng : XorShiftPRNG = undefined;

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

pub fn main() void {
    global_prng = initialize_xorshiftprng();

    const listA : [5] u8 = .{1,2,3,4,5};
    const listB = fisher_yates(5, listA);
    const listC = fisher_yates(5, listA);
    const listD = fisher_yates(5, listA);
       dprint("lists:\n{any}\n{any}\n{any}\n", .{listB, listC, listD}); //@debug
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

fn initialize_xorshiftprng() XorShiftPRNG {
    const nano_timestamp : i128 = std.time.microTimestamp();
    const nano_truncated : i64  = @truncate(nano_timestamp);
    const converted_timestamp : u64 = @bitCast(nano_truncated);

    var xorshiftprng = XorShiftPRNG{ .state = converted_timestamp };
    for (0..10) |i| {
        _ = i;
        xorshiftprng.update_state();
    }
    return xorshiftprng;
}
