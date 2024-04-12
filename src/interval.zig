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

        std.debug.print("\n", .{});
        log.debug("semitone distance: {}", .{semitone_dist});
        log.debug("  letter distance: {}", .{letter_dist});
        log.debug("  fifths distance: {}", .{fifths_dist});

        // const quality = try Quality.fromSemitonesAndFifths(semitone_dist, letter_dist, fifths_dist);
        const quality = .Perfect;
        const number = try Number.fromInt(@intCast(letter_dist));

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

        pub fn semitoneAdjustment(self: Quality) i32 {
            return switch (self) {
                .Perfect => 0,
                .Major => 0,
                .Minor => -1,
                .Augmented => 1,
                .Diminished => -2,
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

        pub fn fromInt(value: u32) !Number {
            return std.meta.intToEnum(Number, value) catch return error.InvalidIntervalNumber;
        }

        pub fn toInt(self: Number) i32 {
            return @intFromEnum(self);
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
        // 4 2 4
        TestCase{ .note1 = "D4", .note2 = "F#4", .expected = Interval{
            .quality = .Major,
            .number = .Third,
        } },
        // 4 3 27
        TestCase{ .note1 = "D4", .note2 = "Gb4", .expected = Interval{
            .quality = .Diminished,
            .number = .Fourth,
        } },
    };

    for (test_cases) |test_case| {
        const note1 = try Note.parse(test_case.note1);
        const note2 = try Note.parse(test_case.note2);
        const result = try Interval.fromNotes(note1, note2);

        std.debug.print("Test case: from {s} to {s}, ", .{ note1, note2 });
        // if (test_case.expected != result) {
        //     std.debug.print("\nTest case: from {s} to {s}, ", .{ note1, note2 });
        // }
        try std.testing.expectEqual(test_case.expected, result);
    }
}
