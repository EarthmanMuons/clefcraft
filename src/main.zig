const std = @import("std");

const clefcraft = @import("root.zig");
const Note = clefcraft.Note;
const Pitch = clefcraft.Pitch;

pub fn main() !void {
    // for (0..12) |pitch| {
    //     const note = clefcraft.Note.new(@intCast(pitch), 4);
    //     std.debug.print("Note: {}\tFrequency: {d:.3} Hz\n", .{ note, note.freq() });
    // }

    var n = try Note.parse("A-4");
    std.debug.print("{} pitch class: {}\n", .{ n, n.pitchClass() });

    const p = Pitch.new(3);
    std.debug.print("{} pitch class: {}\n", .{ p, p.pitchClass() });
}
