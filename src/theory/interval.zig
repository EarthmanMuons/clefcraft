const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.interval);
const testing = std.testing;

const constants = @import("constants.zig");
const Pitch = @import("pitch.zig").Pitch;
const Note = @import("note.zig").Note;

pub const Interval = struct {
    quality: Quality,
    number: Number,

    pub const Quality = enum {
        perfect,
        major,
        minor,
        augmented,
        diminished,
    };

    pub const Number = enum(i8) {
        unison = 1,
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

        pub fn fromInt(int: i8) !Number {
            const minimum = 1;
            const maximum = @typeInfo(Number).Enum.fields.len;

            if (int < minimum or maximum < int) {
                return error.NumberOutOfRange;
            }

            return @enumFromInt(int);
        }

        pub fn isPerfect(self: Number) bool {
            return switch (self) {
                .unison, .fourth, .fifth, .octave, .eleventh, .twelfth, .double_octave => true,
                else => false,
            };
        }
    };

    // Convenience constructors.
    pub fn perf(number: i8) !Interval {
        return try create(.perfect, number);
    }

    pub fn maj(number: i8) !Interval {
        return try create(.major, number);
    }

    pub fn min(number: i8) !Interval {
        return try create(.minor, number);
    }

    pub fn aug(number: i8) !Interval {
        return try create(.augmented, number);
    }

    pub fn dim(number: i8) !Interval {
        return try create(.diminished, number);
    }

    fn create(quality: Quality, diatonic_steps: i8) !Interval {
        const number = try Number.fromInt(diatonic_steps);

        if (!isValid(quality, number)) {
            return error.InvalidInterval;
        }

        return .{ .quality = quality, .number = number };
    }

    pub fn getSemitones(self: Interval) i8 {
        const base_semitones = baseSemitones(self.number);

        const quality_offset: i8 = switch (self.quality) {
            .perfect, .major => 0,
            .minor => -1,
            .augmented => 1,
            .diminished => if (self.number.isPerfect()) -1 else -2,
        };

        return base_semitones + quality_offset;
    }

    fn baseSemitones(number: Number) i8 {
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

    pub fn betweenPitches(from: Pitch, to: Pitch) !Interval {
        const diatonic_steps = from.diatonicStepsTo(to);
        const semitones = from.semitonesTo(to);

        const number = try Number.fromInt(diatonic_steps);
        const quality = try calcQuality(semitones, number);

        assert(isValid(quality, number));
        return .{ .quality = quality, .number = number };
    }

    fn calcQuality(semitones: i8, number: Number) !Quality {
        const base_semitones = baseSemitones(number);
        const quality_offset = semitones - base_semitones;

        if (number.isPerfect()) {
            return switch (quality_offset) {
                0 => .perfect,
                1 => .augmented,
                -1 => .diminished,
                else => error.InvalidQualityOffset,
            };
        } else {
            return switch (quality_offset) {
                0 => .major,
                -1 => .minor,
                1 => .augmented,
                -2 => .diminished,
                else => error.InvalidQualityOffset,
            };
        }
    }

    pub fn applyToPitch(self: Interval, pitch: Pitch) !Pitch {
        const start_letter = @intFromEnum(pitch.note.letter);
        const steps = @intFromEnum(self.number) - 1;
        const end_letter = @mod(start_letter + steps, constants.diatonic_degrees);
        const octave_change = @divFloor(start_letter + steps, constants.diatonic_degrees);

        var new_note = Note{ .letter = @enumFromInt(end_letter), .accidental = null };
        const new_pitch = Pitch{
            .note = new_note,
            .octave = pitch.octave + octave_change,
        };

        const expected_semitones = self.getSemitones();
        const actual_semitones = pitch.semitonesTo(new_pitch);
        const semitone_diff = expected_semitones - actual_semitones;

        new_note.accidental = try Note.Accidental.fromSemitoneOffset(@intCast(semitone_diff));

        return .{ .note = new_note, .octave = new_pitch.octave };
    }

    // Checks if the given combination of quality and number would make a valid interval.
    pub fn isValid(quality: Quality, number: Number) bool {
        if (number.isPerfect()) {
            return switch (quality) {
                .perfect, .augmented, .diminished => true,
                .major, .minor => false,
            };
        } else {
            return switch (quality) {
                .perfect => false,
                .major, .minor, .augmented, .diminished => true,
            };
        }
    }

    pub fn format(
        self: Interval,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        const quality_str = switch (self.quality) {
            .perfect => "P",
            .major => "M",
            .minor => "m",
            .augmented => "A",
            .diminished => "d",
        };

        try writer.print("{s}{d}", .{ quality_str, @intFromEnum(self.number) });
    }

    // shorthand
    pub fn fmtShort(self: Interval) std.fmt.Formatter(formatShort) {
        return .{ .data = self };
    }

    fn formatShort(
        self: Interval,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        const quality_str = switch (self.quality) {
            .perfect => "perf",
            .major => "maj",
            .minor => "min",
            .augmented => "aug",
            .diminished => "dim",
        };

        try writer.print("{s}{d}", .{ quality_str, @intFromEnum(self.number) });
    }

    // description
    pub fn fmtDesc(self: Interval) std.fmt.Formatter(formatDesc) {
        return .{ .data = self };
    }

    fn formatDesc(
        self: Interval,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        const quality_str = switch (self.quality) {
            .perfect => switch (self.number) {
                .unison, .fourth, .fifth => "Perfect",
                else => "",
            },
            .major => "Major",
            .minor => "Minor",
            .augmented => "Augmented",
            .diminished => "Diminished",
        };

        const number_str = switch (self.number) {
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

        if (quality_str.len > 0) {
            try writer.print("{s} {s}", .{ quality_str, number_str });
        } else {
            try writer.print("{s}", .{number_str});
        }
    }
};

test "invalid intervals" {
    try testing.expectError(error.NumberOutOfRange, Interval.perf(0));
    try testing.expectError(error.NumberOutOfRange, Interval.maj(16));
    try testing.expectError(error.InvalidInterval, Interval.perf(6));
    try testing.expectError(error.InvalidInterval, Interval.maj(4));
}

test "applying intervals" {
    const test_cases = .{
        .{
            Interval.perf(5) catch unreachable,
            Pitch{ .note = Note.c, .octave = 4 },
            Pitch{ .note = Note.g, .octave = 4 },
        },
        .{
            Interval.maj(3) catch unreachable,
            Pitch{ .note = Note.c, .octave = 4 },
            Pitch{ .note = Note.e, .octave = 4 },
        },
        .{
            Interval.min(7) catch unreachable,
            Pitch{ .note = Note.c, .octave = 4 },
            Pitch{ .note = Note.b.flat(), .octave = 4 },
        },
        .{
            Interval.perf(8) catch unreachable,
            Pitch{ .note = Note.c, .octave = 4 },
            Pitch{ .note = Note.c, .octave = 5 },
        },
        .{
            Interval.maj(3) catch unreachable,
            Pitch{ .note = Note.d, .octave = 4 },
            Pitch{ .note = Note.f.sharp(), .octave = 4 },
        },
        .{
            Interval.dim(4) catch unreachable,
            Pitch{ .note = Note.d, .octave = 4 },
            Pitch{ .note = Note.g.flat(), .octave = 4 },
        },
    };

    inline for (test_cases) |case| {
        const result = try case[0].applyToPitch(case[1]);
        try testing.expectEqual(case[2], result);
    }
}

test "interval formatting" {
    const intervals = [_]Interval{
        Interval.perf(1) catch unreachable,
        Interval.maj(3) catch unreachable,
        Interval.min(6) catch unreachable,
        Interval.aug(4) catch unreachable,
        Interval.dim(5) catch unreachable,
        Interval.perf(8) catch unreachable,
        Interval.perf(11) catch unreachable,
    };

    const exp_default = [_][]const u8{ "P1", "M3", "m6", "A4", "d5", "P8", "P11" };

    const exp_short = [_][]const u8{ "perf1", "maj3", "min6", "aug4", "dim5", "perf8", "perf11" };

    const exp_desc = [_][]const u8{
        "Perfect Unison",
        "Major Third",
        "Minor Sixth",
        "Augmented Fourth",
        "Diminished Fifth",
        "Octave",
        "Eleventh",
    };

    for (intervals, exp_default, exp_short, exp_desc) |interval, e_def, e_short, e_desc| {
        var buf: [32]u8 = undefined;

        const def = try std.fmt.bufPrint(&buf, "{}", .{interval});
        try std.testing.expectEqualStrings(e_def, def);

        const short = try std.fmt.bufPrint(&buf, "{}", .{interval.fmtShort()});
        try std.testing.expectEqualStrings(e_short, short);

        const desc = try std.fmt.bufPrint(&buf, "{}", .{interval.fmtDesc()});
        try std.testing.expectEqualStrings(e_desc, desc);
    }
}
