const std = @import("std");
const testing = std.testing;

pub const Interval = @import("theory/interval.zig").Interval;
pub const Note = @import("theory/note.zig").Note;
pub const Scale = @import("theory/scale.zig").Scale;
pub const Tonality = @import("theory/tonality.zig").Tonality;

test {
    // Run all unit tests.
    _ = @import("theory/interval.zig");
    _ = @import("theory/note.zig");
    _ = @import("theory/scale.zig");
    _ = @import("theory/tonality.zig");
}
