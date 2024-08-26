const std = @import("std");
const testing = std.testing;

pub const Interval = @import("theory_v1/interval.zig").Interval;
pub const Note = @import("theory_v1/note.zig").Note;
pub const Pitch = @import("theory_v1/pitch.zig").Pitch;
pub const Scale = @import("theory_v1/scale.zig").Scale;

test {
    // Run all unit tests.
    // _ = @import("theory_v1/interval.zig");
    // _ = @import("theory_v1/key_signature.zig");
    // _ = @import("theory_v1/note.zig");
    // _ = @import("theory_v1/pitch.zig");
    // _ = @import("theory_v1/scale.zig");
    _ = @import("theory_v2/interval.zig");
    _ = @import("theory_v2/note.zig");
    _ = @import("theory_v2/pitch.zig");
    _ = @import("theory_v2/scale.zig");
}
