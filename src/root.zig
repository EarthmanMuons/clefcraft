const std = @import("std");
const testing = std.testing;

pub const Accidental = @import("note.zig").Accidental;
pub const Note = @import("note.zig").Note;
pub const Pitch = @import("note.zig").Pitch;

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);
}
