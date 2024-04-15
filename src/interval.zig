const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.interval);

const Accidental = @import("pitch.zig").Accidental;
const Letter = @import("pitch.zig").Letter;
const Note = @import("note.zig").Note;
const utils = @import("utils.zig");

const constants = @import("constants.zig");
const letter_count = constants.letter_count;
const semitones_per_octave = constants.semitones_per_octave;

pub const Interval = struct {
    quality: Quality,
    number: Number,

    // Creates an interval from a shorthand string representation.
    pub fn parse(chars: []const u8) !Interval {
        if (chars.len < 2) return error.InvalidIntervalFormat;

        const quality = switch (chars[0]) {
            'P' => Quality.Perfect,
            'M' => Quality.Major,
            'm' => Quality.Minor,
            'A' => Quality.Augmented,
            'd' => Quality.Diminished,
            else => return error.InvalidQuality,
        };

        const number = switch (chars[1]) {
            '1' => Number.Unison,
            '2' => Number.Second,
            '3' => Number.Third,
            '4' => Number.Fourth,
            '5' => Number.Fifth,
            '6' => Number.Sixth,
            '7' => Number.Seventh,
            '8' => Number.Octave,
            else => return error.InvalidNumber,
        };

        return Interval{ .quality = quality, .number = number };
    }

    // Returns the number of semitones covered by the current interval.
    pub fn semitoneCount(self: Interval) i32 {
        const base_semitones = baseSemitones(self.number);

        const is_perfect = switch (self.number) {
            .Unison, .Fourth, .Fifth, .Octave => true,
            else => false,
        };
        const quality_adjustment: i32 = switch (self.quality) {
            .Perfect, .Major => 0,
            .Minor => -1,
            .Augmented => 1,
            .Diminished => if (is_perfect) -1 else -2,
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
    Perfect,
    Major,
    Minor,
    Augmented,
    Diminished,

    pub fn asText(self: Quality) []const u8 {
        return switch (self) {
            .Perfect => "Perfect",
            .Major => "Major",
            .Minor => "Minor",
            .Augmented => "Augmented",
            .Diminished => "Diminished",
        };
    }

    pub fn asAbbrev(self: Quality) []const u8 {
        return switch (self) {
            .Perfect => "Perf",
            .Major => "Maj",
            .Minor => "Min",
            .Augmented => "Aug",
            .Diminished => "Dim",
        };
    }

    pub fn asShorthand(self: Quality) []const u8 {
        return switch (self) {
            .Perfect => "P",
            .Major => "M",
            .Minor => "m",
            .Augmented => "A",
            .Diminished => "d",
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

pub const Number = enum {
    Unison,
    Second,
    Third,
    Fourth,
    Fifth,
    Sixth,
    Seventh,
    Octave,

    // Creates a number from a conventional positive integer representation.
    pub fn fromInt(value: i32) !Number {
        assert(1 <= value and value <= 8);
        return try std.meta.intToEnum(Number, value - 1);
    }

    // Returns the conventional positive integer representation of the number.
    pub fn toInt(self: Number) i32 {
        // We must cast to prevent integer overflow when adding 1,
        // as the compiler optimizes the enum into a `u3` type.
        return @as(i32, @intCast(@intFromEnum(self))) + 1;
    }

    pub fn asText(self: Number) []const u8 {
        return switch (self) {
            .Unison => "Unison",
            .Second => "Second",
            .Third => "Third",
            .Fourth => "Fourth",
            .Fifth => "Fifth",
            .Sixth => "Sixth",
            .Seventh => "Seventh",
            .Octave => "Octave",
        };
    }

    pub fn asAbbrev(self: Number) []const u8 {
        return switch (self) {
            .Unison => "1st",
            .Second => "2nd",
            .Third => "3rd",
            .Fourth => "4th",
            .Fifth => "5th",
            .Sixth => "6th",
            .Seventh => "7th",
            .Octave => "8th",
        };
    }

    pub fn asShorthand(self: Number) []const u8 {
        return switch (self) {
            .Unison => "1",
            .Second => "2",
            .Third => "3",
            .Fourth => "4",
            .Fifth => "5",
            .Sixth => "6",
            .Seventh => "7",
            .Octave => "8",
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

// Returns the calculated interval between two notes.
pub fn intervalBetween(note1: Note, note2: Note) !Interval {
    const letter_dist = note1.letterDistance(note2);
    const octave_diff = note1.octaveDifference(note2);

    const number_dist = letter_dist + 1;
    const number: Number = switch (number_dist) {
        1 => if (octave_diff == 0) .Unison else .Octave,
        2 => .Second,
        3 => .Third,
        4 => .Fourth,
        5 => .Fifth,
        6 => .Sixth,
        7 => .Seventh,
        else => unreachable,
    };

    const semitones = note1.semitoneDifference(note2);
    const quality = try calcQuality(semitones, number);

    return Interval{ .quality = quality, .number = number };
}

fn calcQuality(semitones: i32, number: Number) !Quality {
    const base_semitones = baseSemitones(number);
    const semitone_diff = semitones - base_semitones;

    return switch (number) {
        .Unison, .Fourth, .Fifth, .Octave => switch (semitone_diff) {
            0 => .Perfect,
            1 => .Augmented,
            -1 => .Diminished,
            else => error.InvalidInterval,
        },
        .Second, .Third, .Sixth, .Seventh => switch (semitone_diff) {
            -1 => .Minor,
            0 => .Major,
            1 => .Augmented,
            -2 => .Diminished,
            else => error.InvalidInterval,
        },
    };
}

fn baseSemitones(number: Number) i32 {
    return switch (number) {
        .Unison => 0,
        .Second => 2,
        .Third => 4,
        .Fourth => 5,
        .Fifth => 7,
        .Sixth => 9,
        .Seventh => 11,
        .Octave => 12,
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
