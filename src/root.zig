const std = @import("std");
const testing = std.testing;

pub const Interval = @import("theory/interval.zig").Interval;
pub const Note = @import("theory/note.zig").Note;
pub const Pitch = @import("theory/pitch.zig").Pitch;
pub const Scale = @import("theory/scale.zig").Scale;

test {
    // Run all unit tests.
    _ = @import("theory/interval.zig");
    _ = @import("theory/note.zig");
    _ = @import("theory/pitch.zig");
    _ = @import("theory/scale.zig");
}
