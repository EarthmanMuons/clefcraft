const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.interval);

const Note = @import("note.zig").Note;

const semitones_per_octave = @import("note.zig").semitones_per_octave;

pub const Interval = struct {
    quality: Quality,
    number: Number,

    // Creates an Interval from two Notes.
    pub fn fromNotes(note1: Note, note2: Note) !Interval {
        const semitone_dist = note1.semitoneDistance(note2);
        const letter_dist = note1.letterDistance(note2);
        const fifths_dist = note1.fifthsDistance(note2);
        const octave_dist = note1.octaveDistance(note2);

        const quality = Quality.fromDistances(semitone_dist, fifths_dist);
        const number = Number.fromDistances(letter_dist, octave_dist);

        return Interval{ .quality = quality, .number = number };
    }

    // Formats the Interval as a string.
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

    pub const Quality = enum {
        Perfect,
        Major,
        Minor,
        Augmented,
        Diminished,

        // Returns the Quality based on the semitone and fifths distances.
        pub fn fromDistances(semitone_dist: i32, fifths_dist: i32) Quality {
            const semitone_dist_mod12 = @mod(semitone_dist, 12);
            const fifths_dist_mod7 = @mod(fifths_dist, 7);

            std.debug.print("\n", .{});
            log.debug("semitone distance:       {}", .{semitone_dist});
            log.debug("semitone distance mod12: {}", .{semitone_dist_mod12});
            log.debug("  fifths distance:       {}", .{fifths_dist});
            log.debug("  fifths distance mod7:  {}", .{fifths_dist_mod7});

            return switch (semitone_dist_mod12) {
                0 => if (fifths_dist_mod7 == 0) .Perfect else .Diminished,
                1 => .Minor,
                2 => .Major,
                3 => .Minor,
                4 => if (fifths_dist_mod7 == 4) .Major else .Diminished,
                5 => .Perfect,
                6 => .Augmented,
                7 => if (fifths_dist_mod7 == 1) .Perfect else .Diminished,
                8 => .Minor,
                9 => .Major,
                10 => .Minor,
                11 => .Major,
                else => unreachable,
            };
        }

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

        // Formats the Quality as a string.
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

        pub fn fromInt(value: i32) !Number {
            assert(value >= 0);
            return try std.meta.intToEnum(Number, value);
        }

        pub fn toInt(self: Number) i32 {
            return @intFromEnum(self);
        }

        // Returns the Number based on the letter and octave distances.
        pub fn fromDistances(letter_dist: i32, octave_dist: i32) Number {
            log.debug("letter distance: {}", .{letter_dist});
            log.debug("octave distance: {}", .{octave_dist});

            return switch (letter_dist) {
                0 => if (octave_dist == 0) .Unison else .Octave,
                1 => .Second,
                2 => .Third,
                3 => .Fourth,
                4 => .Fifth,
                5 => .Sixth,
                6 => .Seventh,
                else => unreachable,
            };
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

        // Formats the Number as a string.
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
};

test "create from notes" {
    std.testing.log_level = .debug;

    const TestCase = struct {
        note1: []const u8,
        note2: []const u8,
        expected: Interval,
    };

    // D to F♯ is a major third, while D to G♭ is a diminished fourth
    const test_cases = [_]TestCase{
        TestCase{ .note1 = "D4", .note2 = "F#4", .expected = Interval{
            .quality = .Major,
            .number = .Third,
        } },
        TestCase{ .note1 = "D4", .note2 = "Gb4", .expected = Interval{
            .quality = .Diminished,
            .number = .Fourth,
        } },
        TestCase{ .note1 = "D4", .note2 = "D4", .expected = Interval{
            .quality = .Perfect,
            .number = .Unison,
        } },
        TestCase{ .note1 = "D4", .note2 = "D5", .expected = Interval{
            .quality = .Perfect,
            .number = .Octave,
        } },
        TestCase{ .note1 = "E4", .note2 = "B4", .expected = Interval{
            .quality = .Perfect,
            .number = .Fifth,
        } },
    };

    for (test_cases) |test_case| {
        const note1 = try Note.parse(test_case.note1);
        const note2 = try Note.parse(test_case.note2);
        const result = try Interval.fromNotes(note1, note2);

        if (!std.meta.eql(test_case.expected, result)) {
            std.debug.print("\nTest case: from {s} to {s}, result: {}\n", .{ note1, note2, result });
        }
        try std.testing.expectEqual(test_case.expected, result);
    }
}
