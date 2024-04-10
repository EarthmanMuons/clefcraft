const std = @import("std");

const clefcraft = @import("root.zig");
const Note = clefcraft.Note;
const Pitch = clefcraft.Pitch;

pub fn main() !void {
    // for (0..12) |pitch| {
    //     const note = clefcraft.Note.new(@intCast(pitch), 4);
    //     std.debug.print("Note: {}\tFrequency: {d:.3} Hz\n", .{ note, note.freq() });
    // }

    var n1 = try Note.parse("C4");
    std.debug.print("{} pitch class: {}\n", .{ n1, n1.pitchClass() });

    const n2 = try Note.parse("A4");
    // std.debug.print("{} pitch class: {}\n", .{ n2, n2.pitchClass() });
    std.debug.print("frequency: {d:.3}\n", .{n2.freq()});

    std.debug.print("distance from {} to {}: {}", .{ n1, n2, n1.semitoneDistance(n2) });
}
