const std = @import("std");
const clefcraft = @import("root.zig");

pub fn main() !void {
    for (0..12) |pitch| {
        const note = clefcraft.Note.new(@intCast(pitch), 4);
        std.debug.print("Note: {}\tFrequency: {d:.3} Hz\n", .{ note, note.freq() });
    }
}
