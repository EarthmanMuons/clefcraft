const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.note);
const testing = std.testing;

const constants = @import("constants.zig");
const note_names = @import("note_names.zig");

pub const Note = struct {
    letter: Letter,
    accidental: ?Accidental,

    pub const Letter = enum { c, d, e, f, g, a, b };

    pub const Accidental = enum {
        double_flat,
        flat,
        natural,
        sharp,
        double_sharp,

        pub fn fromSemitoneOffset(semitones: i8) !?Accidental {
            return switch (semitones) {
                -2 => .double_flat,
                -1 => .flat,
                0 => null,
                1 => .sharp,
                2 => .double_sharp,
                else => return error.InvalidSemitoneOffset,
            };
        }

        pub fn getSemitoneOffset(self: Accidental) i8 {
            return switch (self) {
                .double_flat => -2,
                .flat => -1,
                .natural => 0,
                .sharp => 1,
                .double_sharp => 2,
            };
        }
    };

    // Helpers for creating notes and modifying accidentals.
    pub const c = Note{ .letter = .c, .accidental = null };
    pub const d = Note{ .letter = .d, .accidental = null };
    pub const e = Note{ .letter = .e, .accidental = null };
    pub const f = Note{ .letter = .f, .accidental = null };
    pub const g = Note{ .letter = .g, .accidental = null };
    pub const a = Note{ .letter = .a, .accidental = null };
    pub const b = Note{ .letter = .b, .accidental = null };

    pub fn doubleFlat(self: Note) Note {
        return .{ .letter = self.letter, .accidental = .double_flat };
    }

    pub fn flat(self: Note) Note {
        return .{ .letter = self.letter, .accidental = .flat };
    }

    pub fn natural(self: Note) Note {
        return .{ .letter = self.letter, .accidental = .natural };
    }

    pub fn sharp(self: Note) Note {
        return .{ .letter = self.letter, .accidental = .sharp };
    }

    pub fn doubleSharp(self: Note) Note {
        return .{ .letter = self.letter, .accidental = .double_sharp };
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

        return .{ .letter = letter, .accidental = accidental };
    }

    pub fn fromString(str: []const u8) !Note {
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

        return .{ .letter = letter, .accidental = accidental };
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
        const semitone_offset = if (self.accidental) |acc| acc.getSemitoneOffset() else 0;

        const result = @mod(base_class + semitone_offset, constants.pitch_classes);
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

        for (fmt) |char| {
            switch (char) {
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

        const letter_index = @as(usize, @intFromEnum(self.letter));

        const row_offset: usize = if (self.accidental) |acc| switch (acc) {
            .double_flat => 7,
            .flat => 14,
            .natural => 21,
            .sharp => 28,
            .double_sharp => 35,
        } else 0; // no accidental

        return note_table[letter_index + row_offset];
    }
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

test "pitch class calculations" {
    const test_cases = .{
        .{ Note.c, 0 },
        .{ Note.d.sharp(), 3 },
        .{ Note.e.flat(), 3 },
        .{ Note.f.sharp(), 6 },
        .{ Note.a.flat(), 8 },
        .{ Note.b.sharp(), 0 },
        .{ Note.c.flat(), 11 },
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
        .{ "C", Note.c },
        .{ "D#", Note.d.sharp() },
        .{ "Eb", Note.e.flat() },
        .{ "F♯", Note.f.sharp() },
        .{ "G♭", Note.g.flat() },
        .{ "A𝄫", Note.a.doubleFlat() },
        .{ "Bx", Note.b.doubleSharp() },
    };

    inline for (test_cases) |case| {
        const result = try Note.fromString(case[0]);
        try testing.expectEqual(case[1], result);
    }
}

test "invalid string formats" {
    const test_cases = .{
        .{ "", error.InvalidStringFormat },
        .{ "H", error.InvalidLetter },
        .{ "C###", error.InvalidAccidental },
        .{ "Dxb", error.InvalidAccidental },
        .{ "E#b", error.InvalidAccidental },
    };

    inline for (test_cases) |case| {
        const result = Note.fromString(case[0]);
        try testing.expectError(case[1], result);
    }
}

test "format options" {
    const note = Note.b.flat();
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
