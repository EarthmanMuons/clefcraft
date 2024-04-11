const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.interval);

const Note = @import("note.zig").Note;

const semitones_per_octave = @import("note").semitones_per_octave;

pub const Interval = struct {
    const Self = @This();

    quality: Quality,
    number: Number,

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

        pub fn asAbbreviation(self: Quality) []const u8 {
            return switch (self) {
                .Perfect => "perf",
                .Major => "maj",
                .Minor => "min",
                .Augmented => "aug",
                .Diminished => "dim",
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
        pub fn format(self: Quality, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = fmt;
            _ = options;
            try writer.print("{s}", .{self.asAbbreviation});
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
            return std.meta.intToEnum(Number, value) catch |err| switch (err) {
                error.InvalidEnumTag => error.InvalidIntervalNumber,
                else => |e| e,
            };
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

        pub fn asAbbreviation(self: Quality) []const u8 {
            const numeral = switch (self) {
                .Unison => "1",
                .Second => "2",
                .Third => "3",
                .Fourth => "4",
                .Fifth => "5",
                .Sixth => "6",
                .Seventh => "7",
                .Octave => "8",
            };
            const suffix = self.ordinalIndicator();
            return numeral ++ suffix;
        }

        fn ordinalIndicator(self: Number) []const u8 {
            const lastDigit = self.toInt() % 10;
            return switch (lastDigit) {
                1 => "st",
                2 => "nd",
                3 => "rd",
                else => "th",
            };
        }

        pub fn asShorthand(self: Quality) []const u8 {
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
    };

    // Creates an Interval from two Notes.
    pub fn fromNotes(note1: Note, note2: Note) !Self {
        const semitone_distance = note2.semitoneDistance(note1);
        const interval_number_int = @abs(semitone_distance) / semitones_per_octave + 1;
        const interval_number = try Number.fromInt(interval_number_int);
        const quality = try Quality.fromSemitones(semitone_distance);

        return Self{
            .quality = quality,
            .number = interval_number,
        };
    }

    // Returns the number of semitones in the Interval.
    pub fn semitones(self: Self) i32 {
        const quality_adjustment = self.quality.semitoneAdjustment();
        const number_int = self.number.toInt();
        return (number_int - 1) * semitones_per_octave + quality_adjustment;
    }

    // Formats the Interval as a string.
    pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        try self.quality.format(fmt, options, writer);
        try writer.print(" {s}", .{self.number.asText()});
    }
};
