const std = @import("std");
const testing = std.testing;

pub const Interval = @import("theory.old/interval.zig").Interval;
pub const Note = @import("theory.old/note.zig").Note;
pub const Pitch = @import("theory.old/pitch.zig").Pitch;
pub const Scale = @import("theory.old/scale.zig").Scale;

test {
    // Run all unit tests.
    // _ = @import("theory.old/interval.zig");
    // _ = @import("theory.old/key_signature.zig");
    // _ = @import("theory.old/note.zig");
    // _ = @import("theory.old/pitch.zig");
    // _ = @import("theory.old/scale.zig");
    _ = @import("theory/note.zig");
    _ = @import("theory/pitch.zig");
}
