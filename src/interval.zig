const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.interval);

pub const Interval = struct {
    quantity: Quantity,
    quality: Quality,

    pub const Quantity = enum {
        Unison,
        Second,
        Third,
        Fourth,
        Fifth,
        Sixth,
        Seventh,
        Octave,
    };

    pub const Quality = enum {
        Perfect,
        Major,
        Minor,
        Augmented,
        Diminished,
    };

    // // Converts the Interval to a semitone distance.
    // pub fn toSemitones(self: Interval) i32 {
    //     // TODO
    // }
};
