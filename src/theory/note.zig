const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.note);
const testing = std.testing;

const note_names = @import("note_names.zig");

// The number of semitones per octave.
const pitch_classes = 12;

pub const Note = struct {
    letter: Letter,
    accidental: ?Accidental,

    pub fn fromString(str: []const u8) !Note {
        if (str.len < 1) return error.InvalidNoteString;

        const first_char = std.ascii.toUpper(str[0]);
        const letter = switch (first_char) {
            'C' => Letter.c,
            'D' => Letter.d,
            'E' => Letter.e,
            'F' => Letter.f,
            'G' => Letter.g,
            'A' => Letter.a,
            'B' => Letter.b,
            else => return error.InvalidLetter,
        };

        const accidental = if (str.len > 1) try parseAccidental(str[1..]) else null;

        return Note{ .letter = letter, .accidental = accidental };
    }

    fn parseAccidental(str: []const u8) !Accidental {
        const AccidentalMapping = struct {
            symbol: []const u8,
            accidental: Accidental,
        };

        const mappings = [_]AccidentalMapping{
            .{ .symbol = "𝄫", .accidental = .double_flat },
            .{ .symbol = "bb", .accidental = .double_flat },
            .{ .symbol = "♭", .accidental = .flat },
            .{ .symbol = "b", .accidental = .flat },
            .{ .symbol = "♮", .accidental = .natural },
            .{ .symbol = "n", .accidental = .natural },
            .{ .symbol = "♯", .accidental = .sharp },
            .{ .symbol = "#", .accidental = .sharp },
            .{ .symbol = "𝄪", .accidental = .double_sharp },
            .{ .symbol = "x", .accidental = .double_sharp },
            .{ .symbol = "##", .accidental = .double_sharp },
        };

        for (mappings) |mapping| {
            if (std.mem.eql(u8, str, mapping.symbol)) {
                return mapping.accidental;
            }
        }

        return error.InvalidAccidental;
    }

    pub fn pitchClass(self: Note) u4 {
        const base_class = switch (self.letter) {
            .c => 0,
            .d => 2,
            .e => 4,
            .f => 5,
            .g => 7,
            .a => 9,
            .b => 11,
        };
        const adjustment = if (self.accidental) |acc| acc.pitchAdjustment() else 0;

        const result = @mod(base_class + adjustment, pitch_classes);
        return @intCast(result);
    }

    pub fn toString(self: Note) []const u8 {
        return self.toCustomString(.{});
    }

    pub fn toCustomString(self: Note, options: StringOptions) []const u8 {
        const note_table = switch (options.naming) {
            .german => &note_names.german,
            .latin => switch (options.encoding) {
                .ascii => &note_names.latin_ascii,
                .unicode => &note_names.latin_unicode,
            },
            // Only "fixed do" solfège is supported for now.
            .solfege => switch (options.encoding) {
                .ascii => &note_names.solfege_ascii,
                .unicode => &note_names.solfege_unicode,
            },
        };

        const base_index = @as(usize, @intFromEnum(self.letter));

        const adjustment: usize = if (self.accidental) |acc| switch (acc) {
            .double_flat => 7,
            .flat => 14,
            .natural => 21,
            .sharp => 28,
            .double_sharp => 35,
        } else 0; // no accidental

        return note_table[base_index + adjustment];
    }

    pub fn format(
        self: Note,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        const str = self.toString();
        try writer.print("Note({s})", .{str});
    }
};

pub const Letter = enum { c, d, e, f, g, a, b };

pub const Accidental = enum {
    double_flat,
    flat,
    natural,
    sharp,
    double_sharp,

    pub fn pitchAdjustment(self: Accidental) i8 {
        return switch (self) {
            .double_flat => -2,
            .flat => -1,
            .natural => 0,
            .sharp => 1,
            .double_sharp => 2,
        };
    }
};

pub const StringOptions = struct {
    naming: NamingSystem = .latin,
    encoding: Encoding = .unicode,
};

pub const NamingSystem = enum {
    german,
    latin,
    solfege,
};

pub const Encoding = enum {
    ascii,
    unicode,
};

test "Note.fromString - valid inputs" {
    const test_cases = [_]struct {
        input: []const u8,
        expected: Note,
    }{
        .{ .input = "C", .expected = .{ .letter = .c, .accidental = null } },
        .{ .input = "d#", .expected = .{ .letter = .d, .accidental = .sharp } },
        .{ .input = "Eb", .expected = .{ .letter = .e, .accidental = .flat } },
        .{ .input = "f♯", .expected = .{ .letter = .f, .accidental = .sharp } },
        .{ .input = "G♭", .expected = .{ .letter = .g, .accidental = .flat } },
        .{ .input = "a𝄫", .expected = .{ .letter = .a, .accidental = .double_flat } },
        .{ .input = "Bx", .expected = .{ .letter = .b, .accidental = .double_sharp } },
        .{ .input = "cn", .expected = .{ .letter = .c, .accidental = .natural } },
        .{ .input = "Dbb", .expected = .{ .letter = .d, .accidental = .double_flat } },
        .{ .input = "e##", .expected = .{ .letter = .e, .accidental = .double_sharp } },
    };

    for (test_cases) |case| {
        const result = try Note.fromString(case.input);
        try testing.expectEqual(case.expected.letter, result.letter);
        try testing.expectEqual(case.expected.accidental, result.accidental);
    }
}

test "Note.fromString - invalid inputs" {
    const invalid_inputs = [_][]const u8{
        "",
        "H",
        "C###",
        "Dxb",
        "E#b",
    };

    for (invalid_inputs) |input| {
        const result = Note.fromString(input);
        try testing.expect(result == error.InvalidNoteString or
            result == error.InvalidLetter or
            result == error.InvalidAccidental);
    }
}

test "Note.fromString and Note.toString roundtrip" {
    const test_cases = [_][]const u8{
        "C", "D♯", "E♭", "F♯", "G♭", "A𝄫", "B𝄪", "C♮",
    };

    for (test_cases) |case| {
        const note = try Note.fromString(case);
        const result = note.toString();
        try testing.expectEqualStrings(case, result);
    }
}

test "Note.toString - default options" {
    const note1 = Note{ .letter = .a, .accidental = null };
    const note2 = Note{ .letter = .b, .accidental = .flat };
    const note3 = Note{ .letter = .c, .accidental = .sharp };
    const note4 = Note{ .letter = .d, .accidental = .natural };

    try testing.expectEqualStrings("A", note1.toString());
    try testing.expectEqualStrings("B♭", note2.toString());
    try testing.expectEqualStrings("C♯", note3.toString());
    try testing.expectEqualStrings("D♮", note4.toString());
}

test "Note.toCustomString - with custom options" {
    const note1 = Note{ .letter = .a, .accidental = null };
    const note2 = Note{ .letter = .b, .accidental = .flat };
    const note3 = Note{ .letter = .c, .accidental = .sharp };
    const note4 = Note{ .letter = .d, .accidental = .natural };

    try testing.expectEqualStrings("La", note1.toCustomString(.{ .naming = .solfege }));
    try testing.expectEqualStrings("B", note2.toCustomString(.{ .naming = .german }));
    try testing.expectEqualStrings("C#", note3.toCustomString(.{ .encoding = .ascii }));
    try testing.expectEqualStrings("D", note4.toCustomString(.{ .encoding = .ascii }));
}
