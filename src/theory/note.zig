const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.note);
const testing = std.testing;

const constants = @import("constants.zig");
const note_names = @import("note_names.zig");

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
        const base_class: u4 = switch (self.letter) {
            .c => 0,
            .d => 2,
            .e => 4,
            .f => 5,
            .g => 7,
            .a => 9,
            .b => 11,
        };
        const adjustment: i8 = if (self.accidental) |acc| acc.pitchAdjustment() else 0;

        const result = @mod(base_class + adjustment, constants.pitch_classes);
        return @intCast(result);
    }

    /// Returns a `Note` based on the given pitch class, using the default mapping.
    ///
    /// 0:C, 1:C♯, 2:D, 3:D♯, 4:E, 5:F, 6:F♯, 7:G, 8:G♯, 9:A, 10:A♯, 11:B
    pub fn fromPitchClass(pitch_class: u4) Note {
        assert(0 <= pitch_class and pitch_class < constants.pitch_classes);

        const letter = switch (pitch_class) {
            0, 1 => Letter.c,
            2, 3 => Letter.d,
            4 => Letter.e,
            5, 6 => Letter.f,
            7, 8 => Letter.g,
            9, 10 => Letter.a,
            11 => Letter.b,
            else => unreachable,
        };

        const accidental = switch (pitch_class) {
            1, 3, 6, 8, 10 => Accidental.sharp,
            else => null,
        };

        return Note{ .letter = letter, .accidental = accidental };
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

test "Note.pitchClass calculations" {
    const test_cases = [_]struct {
        note: Note,
        expected: u4,
    }{
        // Natural notes
        .{ .note = .{ .letter = .c, .accidental = null }, .expected = 0 },
        .{ .note = .{ .letter = .d, .accidental = null }, .expected = 2 },
        .{ .note = .{ .letter = .e, .accidental = null }, .expected = 4 },
        .{ .note = .{ .letter = .f, .accidental = null }, .expected = 5 },
        .{ .note = .{ .letter = .g, .accidental = null }, .expected = 7 },
        .{ .note = .{ .letter = .a, .accidental = null }, .expected = 9 },
        .{ .note = .{ .letter = .b, .accidental = null }, .expected = 11 },

        // Sharp notes
        .{ .note = .{ .letter = .c, .accidental = .sharp }, .expected = 1 },
        .{ .note = .{ .letter = .d, .accidental = .sharp }, .expected = 3 },
        .{ .note = .{ .letter = .f, .accidental = .sharp }, .expected = 6 },
        .{ .note = .{ .letter = .g, .accidental = .sharp }, .expected = 8 },
        .{ .note = .{ .letter = .a, .accidental = .sharp }, .expected = 10 },

        // Flat notes
        .{ .note = .{ .letter = .d, .accidental = .flat }, .expected = 1 },
        .{ .note = .{ .letter = .e, .accidental = .flat }, .expected = 3 },
        .{ .note = .{ .letter = .g, .accidental = .flat }, .expected = 6 },
        .{ .note = .{ .letter = .a, .accidental = .flat }, .expected = 8 },
        .{ .note = .{ .letter = .b, .accidental = .flat }, .expected = 10 },

        // Double sharp notes
        .{ .note = .{ .letter = .c, .accidental = .double_sharp }, .expected = 2 },
        .{ .note = .{ .letter = .f, .accidental = .double_sharp }, .expected = 7 },

        // Double flat notes
        .{ .note = .{ .letter = .d, .accidental = .double_flat }, .expected = 0 },
        .{ .note = .{ .letter = .e, .accidental = .double_flat }, .expected = 2 },

        // Edge cases
        .{ .note = .{ .letter = .b, .accidental = .sharp }, .expected = 0 },
        .{ .note = .{ .letter = .c, .accidental = .flat }, .expected = 11 },
        .{ .note = .{ .letter = .e, .accidental = .sharp }, .expected = 5 },
        .{ .note = .{ .letter = .f, .accidental = .flat }, .expected = 4 },
    };

    for (test_cases) |case| {
        try std.testing.expectEqual(case.expected, case.note.pitchClass());
    }
}

test "Note.fromPitchClass and Note.pitchClass roundtrip" {
    var pitch_class: u4 = 0;
    while (pitch_class < constants.pitch_classes) : (pitch_class += 1) {
        const note = Note.fromPitchClass(pitch_class);
        try std.testing.expectEqual(pitch_class, note.pitchClass());
    }
}
