const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.note);
const testing = std.testing;

const constants = @import("constants.zig");
const note_names = @import("note_names.zig");

pub const Note = struct {
    letter: Letter,
    accidental: ?Accidental,

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

    pub fn fromString(str: []const u8) NoteError!Note {
        if (str.len < 1) return error.InvalidStringFormat;

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

    pub fn getPitchClass(self: Note) u4 {
        const base_class: u4 = switch (self.letter) {
            .c => 0,
            .d => 2,
            .e => 4,
            .f => 5,
            .g => 7,
            .a => 9,
            .b => 11,
        };
        const adjustment: i8 = if (self.accidental) |acc| acc.getPitchAdjustment() else 0;

        const result = @mod(base_class + adjustment, constants.pitch_classes);
        return @intCast(result);
    }

    pub fn format(
        self: Note,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = options;

        // Default string options.
        var naming: NamingSystem = .latin;
        var encoding: Encoding = .unicode;

        for (fmt) |c| {
            switch (c) {
                'c' => encoding = .ascii,
                'u' => encoding = .unicode,
                'g' => naming = .german,
                'l' => naming = .latin,
                's' => naming = .solfege,
                else => return error.InvalidFormatSpecifier,
            }
        }

        try writer.writeAll(self.toStringInternal(naming, encoding));
    }

    fn toStringInternal(self: Note, naming: NamingSystem, encoding: Encoding) []const u8 {
        const note_table = switch (naming) {
            .german => &note_names.german,
            .latin => switch (encoding) {
                .ascii => &note_names.latin_ascii,
                .unicode => &note_names.latin_unicode,
            },
            // Only "fixed do" solfège is supported for now.
            .solfege => switch (encoding) {
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
};

pub const NoteError = error{
    InvalidAccidental,
    InvalidLetter,
    InvalidStringFormat,
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

pub const Letter = enum { c, d, e, f, g, a, b };

pub const Accidental = enum {
    double_flat,
    flat,
    natural,
    sharp,
    double_sharp,

    pub fn fromPitchAdjustment(adjustment: i8) !?Accidental {
        return switch (adjustment) {
            -2 => .double_flat,
            -1 => .flat,
            0 => null,
            1 => .sharp,
            2 => .double_sharp,
            else => return error.InvalidAdjustment,
        };
    }

    pub fn getPitchAdjustment(self: Accidental) i8 {
        return switch (self) {
            .double_flat => -2,
            .flat => -1,
            .natural => 0,
            .sharp => 1,
            .double_sharp => 2,
        };
    }
};

test "pitch class calculations" {
    const test_cases = .{
        .{ Note{ .letter = .c, .accidental = null }, 0 },
        .{ Note{ .letter = .d, .accidental = .sharp }, 3 },
        .{ Note{ .letter = .e, .accidental = .flat }, 3 },
        .{ Note{ .letter = .f, .accidental = .sharp }, 6 },
        .{ Note{ .letter = .a, .accidental = .flat }, 8 },
        .{ Note{ .letter = .b, .accidental = .sharp }, 0 },
        .{ Note{ .letter = .c, .accidental = .flat }, 11 },
    };

    inline for (test_cases) |case| {
        const result = case[0].getPitchClass();
        try testing.expectEqual(case[1], result);
    }
}

test "pitch class roundtrip consistency" {
    for (0..constants.pitch_classes) |pitch_class| {
        const note = Note.fromPitchClass(@intCast(pitch_class));
        try testing.expectEqual(pitch_class, note.getPitchClass());
    }
}

test "valid string formats" {
    const test_cases = .{
        .{ "C", Note{ .letter = .c, .accidental = null } },
        .{ "D#", Note{ .letter = .d, .accidental = .sharp } },
        .{ "Eb", Note{ .letter = .e, .accidental = .flat } },
        .{ "F♯", Note{ .letter = .f, .accidental = .sharp } },
        .{ "G♭", Note{ .letter = .g, .accidental = .flat } },
        .{ "A𝄫", Note{ .letter = .a, .accidental = .double_flat } },
        .{ "Bx", Note{ .letter = .b, .accidental = .double_sharp } },
    };

    inline for (test_cases) |case| {
        const result = try Note.fromString(case[0]);
        try testing.expectEqual(case[1], result);
    }
}

test "invalid string formats" {
    const test_cases = .{
        .{ "", NoteError.InvalidStringFormat },
        .{ "H", NoteError.InvalidLetter },
        .{ "C###", NoteError.InvalidAccidental },
        .{ "Dxb", NoteError.InvalidAccidental },
        .{ "E#b", NoteError.InvalidAccidental },
    };

    inline for (test_cases) |case| {
        const result = Note.fromString(case[0]);
        try testing.expectError(case[1], result);
    }
}

test "format options" {
    const note = Note{ .letter = .b, .accidental = .flat };
    const test_cases = .{
        .{ "{}", "B♭" },
        .{ "{c}", "Bb" },
        .{ "{u}", "B♭" },
        .{ "{g}", "B" },
        .{ "{l}", "B♭" },
        .{ "{s}", "Ti♭" },
        .{ "{sc}", "Tib" },
    };

    inline for (test_cases) |case| {
        try testing.expectFmt(case[1], case[0], .{note});
    }
}

test "string roundtrip consistency" {
    const test_cases = .{ "C", "D♯", "E♭", "F♯", "G♭", "A𝄫", "B𝄪" };

    inline for (test_cases) |input| {
        const note = try Note.fromString(input);
        try testing.expectFmt(input, "{}", .{note});
    }
}
