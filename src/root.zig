const std = @import("std");
const testing = std.testing;

pub const Interval = @import("interval.zig").Interval;
pub const Note = @import("note.zig").Note;
pub const Pitch = @import("pitch.zig").Pitch;
pub const Scale = @import("scale.zig").Scale;

test {
    // Run all unit tests.
    _ = @import("interval.zig");
    _ = @import("note.zig");
    _ = @import("pitch.zig");
    _ = @import("scale.zig");
}
