const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.interval);

const Note = @import("note.zig").Note;

const notes_per_octave = @import("constants.zig").music_theory.notes_per_octave;
const semitones_per_octave = @import("constants.zig").music_theory.semitones_per_octave;

pub const Interval = struct {
    quality: Quality,
    number: Number,

    // Creates an interval from a shorthand string representation.
    pub fn parse(text: []const u8) !Interval {
        if (text.len < 2) return error.InvalidIntervalFormat;

        const quality: Quality = switch (text[0]) {
            'P' => .perfect,
            'M' => .major,
            'm' => .minor,
            'A' => .augmented,
            'd' => .diminished,
            else => return error.InvalidQuality,
        };

        const number_str = text[1..];
        const number_max = @typeInfo(Number).Enum.fields.len;
        const parsed_num = std.fmt.parseInt(u8, number_str, 10) catch return error.InvalidNumber;

        // bounds check
        if (parsed_num == 0 or parsed_num > number_max) {
            return error.InvalidNumber;
        }
        const number: Number = @enumFromInt(parsed_num - 1);

        if (!isValidInterval(quality, number)) {
            return error.InvalidInterval;
        }

        return Interval{ .quality = quality, .number = number };
    }

    // Returns the number of semitones covered by the current interval.
    pub fn semitoneCount(self: Interval) i32 {
        const base_semitones = baseSemitones(self.number);

        const quality_adjustment: i32 = switch (self.quality) {
            .perfect, .major => 0,
            .minor => -1,
            .augmented => 1,
            .diminished => if (self.number.is_perfect()) -1 else -2,
        };

        return base_semitones + quality_adjustment;
    }

    // Formats the interval as a string.
    pub fn format(
        self: Interval,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        const quality = self.quality.asShorthand();
        const number = self.number.asShorthand();
        try writer.print("Interval({s}{s})", .{ quality, number });
    }
};

pub const Quality = enum {
    perfect,
    major,
    minor,
    augmented,
    diminished,

    pub fn asText(self: Quality) []const u8 {
        return switch (self) {
            .perfect => "Perfect",
            .major => "Major",
            .minor => "Minor",
            .augmented => "Augmented",
            .diminished => "Diminished",
        };
    }

    pub fn asAbbrev(self: Quality) []const u8 {
        return switch (self) {
            .perfect => "Perf",
            .major => "Maj",
            .minor => "Min",
            .augmented => "Aug",
            .diminished => "Dim",
        };
    }

    pub fn asShorthand(self: Quality) []const u8 {
        return switch (self) {
            .perfect => "P",
            .major => "M",
            .minor => "m",
            .augmented => "A",
            .diminished => "d",
        };
    }

    // Formats the quality as a string.
    pub fn format(
        self: Quality,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        const output = self.asText();
        try writer.print("Quality({s})", .{output});
    }
};

pub const Number = enum(u8) {
    unison,
    second,
    third,
    fourth,
    fifth,
    sixth,
    seventh,
    octave,
    ninth,
    tenth,
    eleventh,
    twelfth,
    thirteenth,
    fourteenth,
    double_octave,

    fn is_perfect(self: Number) bool {
        return switch (self) {
            .unison, .fourth, .fifth, .octave, .eleventh, .twelfth, .double_octave => true,
            else => false,
        };
    }

    pub fn asText(self: Number) []const u8 {
        return switch (self) {
            .unison => "Unison",
            .second => "Second",
            .third => "Third",
            .fourth => "Fourth",
            .fifth => "Fifth",
            .sixth => "Sixth",
            .seventh => "Seventh",
            .octave => "Octave",
            .ninth => "Ninth",
            .tenth => "Tenth",
            .eleventh => "Eleventh",
            .twelfth => "Twelfth",
            .thirteenth => "Thirteenth",
            .fourteenth => "Fourteenth",
            .double_octave => "Double Octave",
        };
    }

    pub fn asAbbrev(self: Number) []const u8 {
        return switch (self) {
            .unison => "1st",
            .second => "2nd",
            .third => "3rd",
            .fourth => "4th",
            .fifth => "5th",
            .sixth => "6th",
            .seventh => "7th",
            .octave => "8th",
            .ninth => "9th",
            .tenth => "10th",
            .eleventh => "11th",
            .twelfth => "12th",
            .thirteenth => "13th",
            .fourteenth => "14th",
            .double_octave => "15th",
        };
    }

    pub fn asShorthand(self: Number) []const u8 {
        return switch (self) {
            .unison => "1",
            .second => "2",
            .third => "3",
            .fourth => "4",
            .fifth => "5",
            .sixth => "6",
            .seventh => "7",
            .octave => "8",
            .ninth => "9",
            .tenth => "10",
            .eleventh => "11",
            .twelfth => "12",
            .thirteenth => "13",
            .fourteenth => "14",
            .double_octave => "15",
        };
    }

    // Formats the number as a string.
    pub fn format(
        self: Number,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        const output = self.asText();
        try writer.print("Number({s})", .{output});
    }
};

// Checks if the given combination of quality and number would make a valid interval.
pub fn isValidInterval(quality: Quality, number: Number) bool {
    return blk: {
        if (number.is_perfect()) {
            break :blk switch (quality) {
                .perfect => true,
                .major => false,
                .minor => false,
                .augmented => true,
                .diminished => true,
            };
        } else {
            break :blk switch (quality) {
                .perfect => false,
                .major => true,
                .minor => true,
                .augmented => true,
                .diminished => true,
            };
        }
    };
}

// Returns the calculated interval between two notes.
pub fn intervalBetween(note1: Note, note2: Note) !Interval {
    const letter_dist = note1.letterDistance(note2);
    const octave_diff = note1.octaveDifference(note2);
    const semitones = note1.semitoneDifference(note2);

    const is_compound = semitones > semitones_per_octave;

    const number: Number = blk: {
        const base_number: Number = switch (letter_dist + 1) {
            1 => .unison,
            2 => .second,
            3 => .third,
            4 => .fourth,
            5 => .fifth,
            6 => .sixth,
            7 => .seventh,
            else => unreachable,
        };

        break :blk switch (base_number) {
            .unison => switch (octave_diff) {
                1 => .octave,
                2 => .double_octave,
                else => base_number,
            },
            .second => if (is_compound) .ninth else base_number,
            .third => if (is_compound) .tenth else base_number,
            .fourth => if (is_compound) .eleventh else base_number,
            .fifth => if (is_compound) .twelfth else base_number,
            .sixth => if (is_compound) .thirteenth else base_number,
            .seventh => if (is_compound) .fourteenth else base_number,
            else => unreachable,
        };
    };

    const quality = try calcQuality(semitones, number);

    assert(isValidInterval(quality, number));
    return Interval{ .quality = quality, .number = number };
}

fn calcQuality(semitones: i32, number: Number) !Quality {
    const base_semitones = baseSemitones(number);
    const semitone_diff = semitones - base_semitones;

    const quality: Quality = blk: {
        if (number.is_perfect()) {
            break :blk switch (semitone_diff) {
                0 => .perfect,
                1 => .augmented,
                -1 => .diminished,
                else => return error.InvalidInterval,
            };
        } else {
            break :blk switch (semitone_diff) {
                0 => .major,
                -1 => .minor,
                1 => .augmented,
                -2 => .diminished,
                else => return error.InvalidInterval,
            };
        }
    };

    return quality;
}

fn baseSemitones(number: Number) i32 {
    return switch (number) {
        .unison => 0,
        .second => 2,
        .third => 4,
        .fourth => 5,
        .fifth => 7,
        .sixth => 9,
        .seventh => 11,
        .octave => 12,
        .ninth => 14,
        .tenth => 16,
        .eleventh => 17,
        .twelfth => 19,
        .thirteenth => 21,
        .fourteenth => 22,
        .double_octave => 24,
    };
}

test "intervalBetween()" {
    const TestCase = struct {
        note1: []const u8,
        note2: []const u8,
        expected: []const u8,
    };

    const test_cases = [_]TestCase{
        // Enharmonic equivalents...
        // D to F♯ is a major third, D to G♭ is a diminished fourth
        TestCase{ .note1 = "D4", .note2 = "F#4", .expected = "M3" },
        TestCase{ .note1 = "D4", .note2 = "Gb4", .expected = "d4" },
        // Exhaustive C Major simple intervals...
        // https://en.wikipedia.org/wiki/File:Diatonic_intervals.png
        TestCase{ .note1 = "C4", .note2 = "C4", .expected = "P1" },
        TestCase{ .note1 = "C4", .note2 = "D4", .expected = "M2" },
        TestCase{ .note1 = "C4", .note2 = "E4", .expected = "M3" },
        TestCase{ .note1 = "C4", .note2 = "F4", .expected = "P4" },
        TestCase{ .note1 = "C4", .note2 = "G4", .expected = "P5" },
        TestCase{ .note1 = "C4", .note2 = "A4", .expected = "M6" },
        TestCase{ .note1 = "C4", .note2 = "B4", .expected = "M7" },
        TestCase{ .note1 = "C4", .note2 = "c5", .expected = "P8" },
        //
        TestCase{ .note1 = "D4", .note2 = "D4", .expected = "P1" },
        TestCase{ .note1 = "D4", .note2 = "E4", .expected = "M2" },
        TestCase{ .note1 = "D4", .note2 = "F4", .expected = "m3" },
        TestCase{ .note1 = "D4", .note2 = "G4", .expected = "P4" },
        TestCase{ .note1 = "D4", .note2 = "A4", .expected = "P5" },
        TestCase{ .note1 = "D4", .note2 = "B4", .expected = "M6" },
        TestCase{ .note1 = "D4", .note2 = "c5", .expected = "m7" },
        TestCase{ .note1 = "D4", .note2 = "d5", .expected = "P8" },
        //
        TestCase{ .note1 = "E4", .note2 = "E4", .expected = "P1" },
        TestCase{ .note1 = "E4", .note2 = "F4", .expected = "m2" },
        TestCase{ .note1 = "E4", .note2 = "G4", .expected = "m3" },
        TestCase{ .note1 = "E4", .note2 = "A4", .expected = "P4" },
        TestCase{ .note1 = "E4", .note2 = "B4", .expected = "P5" },
        TestCase{ .note1 = "E4", .note2 = "c5", .expected = "m6" },
        TestCase{ .note1 = "E4", .note2 = "d5", .expected = "m7" },
        TestCase{ .note1 = "E4", .note2 = "e5", .expected = "P8" },
        //
        TestCase{ .note1 = "F4", .note2 = "F4", .expected = "P1" },
        TestCase{ .note1 = "F4", .note2 = "G4", .expected = "M2" },
        TestCase{ .note1 = "F4", .note2 = "A4", .expected = "M3" },
        TestCase{ .note1 = "F4", .note2 = "B4", .expected = "A4" }, // tritone
        TestCase{ .note1 = "F4", .note2 = "c5", .expected = "P5" },
        TestCase{ .note1 = "F4", .note2 = "d5", .expected = "M6" },
        TestCase{ .note1 = "F4", .note2 = "e5", .expected = "M7" },
        TestCase{ .note1 = "F4", .note2 = "f5", .expected = "P8" },
        //
        TestCase{ .note1 = "G4", .note2 = "G4", .expected = "P1" },
        TestCase{ .note1 = "G4", .note2 = "A4", .expected = "M2" },
        TestCase{ .note1 = "G4", .note2 = "B4", .expected = "M3" },
        TestCase{ .note1 = "G4", .note2 = "c5", .expected = "P4" },
        TestCase{ .note1 = "G4", .note2 = "d5", .expected = "P5" },
        TestCase{ .note1 = "G4", .note2 = "e5", .expected = "M6" },
        TestCase{ .note1 = "G4", .note2 = "f5", .expected = "m7" },
        TestCase{ .note1 = "G4", .note2 = "g5", .expected = "P8" },
        //
        TestCase{ .note1 = "A4", .note2 = "A4", .expected = "P1" },
        TestCase{ .note1 = "A4", .note2 = "B4", .expected = "M2" },
        TestCase{ .note1 = "A4", .note2 = "c5", .expected = "m3" },
        TestCase{ .note1 = "A4", .note2 = "d5", .expected = "P4" },
        TestCase{ .note1 = "A4", .note2 = "e5", .expected = "P5" },
        TestCase{ .note1 = "A4", .note2 = "f5", .expected = "m6" },
        TestCase{ .note1 = "A4", .note2 = "g5", .expected = "m7" },
        TestCase{ .note1 = "A4", .note2 = "a5", .expected = "P8" },
        //
        TestCase{ .note1 = "B4", .note2 = "B4", .expected = "P1" },
        TestCase{ .note1 = "B4", .note2 = "c5", .expected = "m2" },
        TestCase{ .note1 = "B4", .note2 = "d5", .expected = "m3" },
        TestCase{ .note1 = "B4", .note2 = "e5", .expected = "P4" },
        TestCase{ .note1 = "B4", .note2 = "f5", .expected = "d5" }, // tritone
        TestCase{ .note1 = "B4", .note2 = "g5", .expected = "m6" },
        TestCase{ .note1 = "B4", .note2 = "a5", .expected = "m7" },
        TestCase{ .note1 = "B4", .note2 = "b5", .expected = "P8" },
        // Compound intervals...
        TestCase{ .note1 = "C4", .note2 = "d5", .expected = "M9" },
        TestCase{ .note1 = "C4", .note2 = "c6", .expected = "P15" },
    };

    for (test_cases) |test_case| {
        const note1 = try Note.parse(test_case.note1);
        const note2 = try Note.parse(test_case.note2);
        const expected = try Interval.parse(test_case.expected);
        const result = try intervalBetween(note1, note2);

        if (!std.meta.eql(expected, result)) {
            std.debug.print("\nTestCase: Note({s}), Note({s})\n", .{ note1, note2 });
        }
        try std.testing.expectEqual(expected, result);
    }
}
