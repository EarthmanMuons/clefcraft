const std = @import("std");

const clefcraft = @import("root.zig");
const Note = clefcraft.Note;

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    try stdout.print("Enter a note: ", .{});

    var buffer: [8]u8 = undefined;
    const input = (try nextLine(stdin, &buffer)).?;

    const note = try Note.parse(input);
    try stdout.print("Your note is: Note({s})\n", .{note});
}

fn nextLine(reader: anytype, buffer: []u8) !?[]const u8 {
    const line = (try reader.readUntilDelimiterOrEof(buffer, '\n')) orelse return null;

    // trim windows-specific carriage return character
    if (@import("builtin").os.tag == .windows) {
        return std.mem.trimRight(u8, line, "\r");
    } else {
        return line;
    }
}
