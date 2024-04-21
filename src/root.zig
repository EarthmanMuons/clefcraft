const std = @import("std");
const testing = std.testing;

pub const Note = @import("note.zig").Note;

test {
    // Run all unit tests.
    _ = @import("interval.zig");
    _ = @import("note.zig");
    _ = @import("pitch.zig");
    _ = @import("scale.zig");
}
