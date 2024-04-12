const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.interval);

const Note = @import("note.zig").Note;

const semitones_per_octave = @import("note.zig").semitones_per_octave;

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

        pub fn fromSemitoneDistance(distance: i32) !Quality {
            const wrapped_semitone = @mod(distance, semitones_per_octave);
            const abs_distance = @abs(distance);

            return switch (wrapped_semitone) {
                0 => .Perfect,
                1 => .Augmented,
                2 => .Major,
                3 => .Minor,
                4 => .Major,
                5 => .Perfect,
                6 => {
                    if (abs_distance <= semitones_per_octave * 4) {
                        return .Augmented;
                    } else {
                        return .Diminished;
                    }
                },
                7 => .Perfect,
                8 => .Augmented,
                9 => .Major,
                10 => .Minor,
                11 => .Major,
                else => error.InvalidSemitoneDistance,
            };
        }

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
        pub fn format(self: Quality, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = fmt;
            _ = options;
            const representation = self.asAbbreviation();
            try writer.print("{s}", .{representation});
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

        pub fn fromSemitoneDistance(distance: i32) !Number {
            const wrapped_semitone = @mod(distance, semitones_per_octave);
            const abs_distance = @abs(distance);

            return switch (wrapped_semitone) {
                0 => .Unison,
                1 => .Second,
                2 => .Second,
                3 => .Third,
                4 => .Third,
                5 => .Fourth,
                6 => {
                    if (abs_distance <= semitones_per_octave * 4) {
                        return .Fourth;
                    } else {
                        return .Fifth;
                    }
                },
                7 => .Fifth,
                8 => .Sixth,
                9 => .Sixth,
                10 => .Seventh,
                11 => .Seventh,
                12 => .Octave,
                else => error.InvalidSemitoneDistance,
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

        pub fn asAbbreviation(self: Number) []const u8 {
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
        pub fn format(self: Number, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = fmt;
            _ = options;
            const representation = self.asAbbreviation();
            try writer.print("{s}", .{representation});
        }
    };

    // Creates an Interval from two Notes.
    pub fn fromNotes(note1: Note, note2: Note) !Self {
        const distance = note2.semitoneDistance(note1);
        const quality = try Quality.fromSemitoneDistance(distance);
        const number = try Number.fromSemitoneDistance(distance);

        std.debug.print("\n", .{});
        log.debug("distance: {}", .{distance});
        log.debug("quality: {}", .{quality});
        log.debug("number: {}", .{number});

        return Self{
            .quality = quality,
            .number = number,
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
        _ = fmt;
        _ = options;
        const quality = self.quality.asText();
        const number = self.number.asText();
        try writer.print("{s} {s}", .{ quality, number });
    }
};

// D to F♯ is a major third, while D to G♭ is a diminished fourth
test "create from notes" {
    std.testing.log_level = .debug;

    const note1 = try Note.parse("D4");
    const note2 = try Note.parse("F#4");
    const result = try Interval.fromNotes(note1, note2);

    log.debug("Test case: from {} to {} = {}", .{ note1, note2, result });

    try std.testing.expectEqual(4, result.number.toInt());
}
