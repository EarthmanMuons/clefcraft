const std = @import("std");
const testing = std.testing;

const c = @import("constants.zig");

pub const Note = struct {
    midi: u7,

    pub const Letter = enum { c, d, e, f, g, a, b };
    pub const Accidental = enum { double_flat, flat, natural, sharp, double_sharp };

    pub fn init(let: Letter, acc: Accidental, oct: i8) !Note {
        const base: i16 = baseSemitones(let);
        const offset: i4 = switch (acc) {
            .double_flat => -2,
            .flat => -1,
            .natural => 0,
            .sharp => 1,
            .double_sharp => 2,
        };
        const midi = base + offset + (oct + 1) * c.semis_per_oct;
        if (midi < 0 or c.midi_max < midi) {
            return error.NoteOutOfRange;
        }
        return .{ .midi = @intCast(midi) };
    }

    fn baseSemitones(let: Letter) u4 {
        return switch (let) {
            .c => 0,
            .d => 2,
            .e => 4,
            .f => 5,
            .g => 7,
            .a => 9,
            .b => 11,
        };
    }

    pub fn letter(self: Note) Letter {
        const pc = self.pitchClass();
        return switch (pc) {
            0, 1 => .c,
            2, 3 => .d,
            4 => .e,
            5, 6 => .f,
            7, 8 => .g,
            9, 10 => .a,
            11 => .b,
            else => unreachable,
        };
    }

    pub fn accidental(self: Note) Accidental {
        const pc: i8 = self.pitchClass();
        const let = self.letter();
        const base = baseSemitones(let);
        const diff = @mod(pc - base + c.semis_per_oct, c.semis_per_oct);
        return switch (diff) {
            10 => .double_flat,
            11 => .flat,
            0 => .natural,
            1 => .sharp,
            2 => .double_sharp,
            else => unreachable,
        };
    }

    pub fn octave(self: Note) i8 {
        return @divFloor(@as(i8, self.midi), c.semis_per_oct) - 1;
    }

    pub fn pitchClass(self: Note) u4 {
        return @intCast(@mod(self.midi, c.semis_per_oct));
    }

    pub fn format(
        self: Note,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        const let = self.letter();
        const acc = self.accidental();
        const oct = self.octave();
        try writer.print("{c}{s}{d}", .{
            std.ascii.toUpper(@tagName(let)[0]),
            switch (acc) {
                .double_flat => "𝄫",
                .flat => "♭",
                .natural => "",
                .sharp => "♯",
                .double_sharp => "𝄪",
            },
            oct,
        });
    }
};

test "Note initialization" {
    try testing.expectError(error.NoteOutOfRange, Note.init(.c, .flat, -1));
    try testing.expectEqual(0, (try Note.init(.c, .natural, -1)).midi);
    try testing.expectEqual(58, (try Note.init(.c, .double_flat, 4)).midi);
    try testing.expectEqual(59, (try Note.init(.c, .flat, 4)).midi);
    try testing.expectEqual(60, (try Note.init(.c, .natural, 4)).midi);
    try testing.expectEqual(61, (try Note.init(.c, .sharp, 4)).midi);
    try testing.expectEqual(62, (try Note.init(.c, .double_sharp, 4)).midi);
    try testing.expectEqual(69, (try Note.init(.a, .natural, 4)).midi);
    try testing.expectEqual(127, (try Note.init(.g, .natural, 9)).midi);
    try testing.expectError(error.NoteOutOfRange, Note.init(.g, .sharp, 9));
}

test "Note properties" {
    const c4 = try Note.init(.c, .natural, 4);
    try testing.expectEqual(Note.Letter.c, c4.letter());
    try testing.expectEqual(Note.Accidental.natural, c4.accidental());
    try testing.expectEqual(4, c4.octave());
    try testing.expectEqual(0, c4.pitchClass());

    const cs4 = try Note.init(.c, .sharp, 4);
    try testing.expectEqual(Note.Letter.c, cs4.letter());
    try testing.expectEqual(Note.Accidental.sharp, cs4.accidental());
    try testing.expectEqual(4, cs4.octave());
    try testing.expectEqual(1, cs4.pitchClass());

    // There's currently no naming persistence.
    const df4 = try Note.init(.d, .flat, 4);
    try testing.expectEqual(Note.Letter.c, df4.letter());
    try testing.expectEqual(Note.Accidental.sharp, df4.accidental());
    try testing.expectEqual(4, df4.octave());
    try testing.expectEqual(1, df4.pitchClass());
}

test "Note formatting" {
    // There's currently no naming persistence.
    try testing.expectFmt("A♯3", "{}", .{try Note.init(.c, .double_flat, 4)});
    try testing.expectFmt("B3", "{}", .{try Note.init(.c, .flat, 4)});
    try testing.expectFmt("C4", "{}", .{try Note.init(.c, .natural, 4)});
    try testing.expectFmt("C♯4", "{}", .{try Note.init(.c, .sharp, 4)});
    try testing.expectFmt("D4", "{}", .{try Note.init(.c, .double_sharp, 4)});
}
