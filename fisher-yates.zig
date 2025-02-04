const std = @import("std");

// "Extremely Crude O(n^2) Fisher-Yates and PRNG.
//
// Basically a sketch / draft.
//
// ABSOLUTELY NOT OKAY FOR PRODUCTION CODE OF ANY SORT.
//
// ... it may be better than the 25 years of Java's LGC though :P


// Globals
const dprint = std.debug.print;

fn fisher_yates(comptime N : u8, olist : [N] u8) [N] u8 {
    var list1 = olist;
    var list2 : [N] u8 = undefined;
    
    for (0..N) |i| {
        const ii : u8 = @intCast(i);
        const rint = get_randomish_byte_up_to(N - ii);
        dprint("rint: {}\n", .{rint}); //@debug
        const relem = list1[rint];
        list2[i] = relem;
        for (rint..N-ii-1) |j| {
            list1[j] = list1[j + 1];
        }
    }
    return list2;
}

pub fn main() void {
    const listA : [5] u8 = .{1,2,3,4,5};
    const listB = fisher_yates(5, listA);
    const listC = fisher_yates(5, listA);
    const listD = fisher_yates(5, listA);
    dprint("lists:\n{any}\n{any}\n{any}\n", .{listB, listC, listD}); //@debug
    
}

// Note: Repeated calls of this fn, if using a timestamp will
// not be very random! As such we pass it through xorshift many times.
fn get_randomish_byte() u8 {
    const nano_timestamp : i128 = std.time.microTimestamp();
    const nano_truncated : i64  = @truncate(nano_timestamp);
    const converted_timestamp : u64 = @bitCast(nano_truncated);

    var xor_input = converted_timestamp;
    const XORSHIFT_NUMBER = 10;
    for (0..XORSHIFT_NUMBER) |i| {
        _ = i;
        xor_input = xorshift(xor_input);
    }

    // Choose the last byte.
    const rbyte : u8 = @truncate(xor_input);
    return rbyte;
}

// Return a random number from 0..<limit <= 255.
fn get_randomish_byte_up_to(limit : u8) u8 {
    const remainder = 255 % limit;
    const okay_range_limit = (255 - remainder) - 1;
    var rbyte : u8 = 0;
    while (true) {
        rbyte = get_randomish_byte();
        if (rbyte <= okay_range_limit) {
            break;
        }
    }
    const rand = rbyte % limit;
    return rand;
}

// Eg. 0..=10 for limit = 2 should be 0..=9, since otherwise more even than odd!


// Xorshift example
fn xorshift( x1 : u64) u64 {
    const x2 = x1 ^ (x1 << 13);
    const x3 = x2 ^ (x2 >> 7);
    const x4 = x3 ^ (x3 << 17);
    return x4;
}
