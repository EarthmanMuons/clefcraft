const std = @import("std");
const testing = std.testing;

pub const Interval = @import("note.zig").Interval;
pub const Note = @import("note.zig").Note;
pub const Pitch = @import("note.zig").Pitch;
pub const Scale = @import("note.zig").Scale;

test {
    // Run all unit tests.
    _ = @import("interval.zig");
    _ = @import("note.zig");
    _ = @import("pitch.zig");
    _ = @import("scale.zig");
}
