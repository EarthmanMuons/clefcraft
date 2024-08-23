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

    pub fn fromString(str: []const u8) !Interval {
        if (str.len < 2) return error.InvalidStringFormat;

        const quality = try parseQuality(str[0]);
        const number = try parseNumber(str[1..]);

        if (!isValid(quality, number)) {
            return error.InvalidInterval;
        }

        return .{ .quality = quality, .number = number };
    }

    fn parseQuality(char: u8) !Quality {
        return switch (char) {
            'P' => .perfect,
            'M' => .major,
            'm' => .minor,
            'A' => .augmented,
            'd' => .diminished,
            else => error.InvalidQuality,
        };
    }

    fn parseNumber(str: []const u8) !Number {
        const num = try std.fmt.parseInt(i8, str, 10);
        return Number.fromInt(num);
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

    pub fn invert(self: Interval) Interval {
        const new_quality: Quality = switch (self.quality) {
            .perfect => .perfect,
            .major => .minor,
            .minor => .major,
            .augmented => .diminished,
            .diminished => .augmented,
        };

        const interval_number = @intFromEnum(self.number);
        const simple_number = @mod(interval_number - 1, constants.diatonic_degrees) + 1;

        // Handle unison and octave-based intervals
        if (simple_number == 1) {
            if (interval_number == 1) {
                // Unison inverts to octave
                return .{ .quality = .perfect, .number = .octave };
            } else {
                // Octave, double octave, etc. invert to unison
                return .{ .quality = .perfect, .number = .unison };
            }
        }

        // The interval number and the number of its inversion always add up to nine.
        const new_number: Number = @enumFromInt(9 - simple_number);

        return .{ .quality = new_quality, .number = new_number };
    }

    pub fn isCompound(self: Interval) bool {
        return @intFromEnum(self.number) > constants.diatonic_degrees;
    }

    pub fn isSimple(self: Interval) bool {
        return !self.isCompound();
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

test "valid string formats" {
    const test_cases = .{
        .{ "P1", Interval.perf(1) },
        .{ "M3", Interval.maj(3) },
        .{ "m6", Interval.min(6) },
        .{ "A4", Interval.aug(4) },
        .{ "d5", Interval.dim(5) },
        .{ "P8", Interval.perf(8) },
    };

    inline for (test_cases) |case| {
        const expected = case[1] catch unreachable; // force unwrap
        const result = try Interval.fromString(case[0]);
        try testing.expectEqual(expected, result);
    }
}

test "invalid string formats" {
    const test_cases = .{
        .{ "P", error.InvalidStringFormat },
        .{ "X3", error.InvalidQuality },
        .{ "M0", error.NumberOutOfRange },
        .{ "P3", error.InvalidInterval },
        .{ "m1", error.InvalidInterval },
        .{ "A16", error.NumberOutOfRange },
    };

    inline for (test_cases) |case| {
        try testing.expectError(case[1], Interval.fromString(case[0]));
    }
}

test "applying intervals" {
    const test_cases = .{
        .{
            Interval.perf(5),
            Pitch{ .note = Note.c, .octave = 4 },
            Pitch{ .note = Note.g, .octave = 4 },
        },
        .{
            Interval.maj(3),
            Pitch{ .note = Note.c, .octave = 4 },
            Pitch{ .note = Note.e, .octave = 4 },
        },
        .{
            Interval.min(7),
            Pitch{ .note = Note.c, .octave = 4 },
            Pitch{ .note = Note.b.flat(), .octave = 4 },
        },
        .{
            Interval.perf(8),
            Pitch{ .note = Note.c, .octave = 4 },
            Pitch{ .note = Note.c, .octave = 5 },
        },
        .{
            Interval.maj(3),
            Pitch{ .note = Note.d, .octave = 4 },
            Pitch{ .note = Note.f.sharp(), .octave = 4 },
        },
        .{
            Interval.dim(4),
            Pitch{ .note = Note.d, .octave = 4 },
            Pitch{ .note = Note.g.flat(), .octave = 4 },
        },
    };

    inline for (test_cases) |case| {
        const interval = case[0] catch unreachable; // force unwrap
        const result = try interval.applyToPitch(case[1]);
        try testing.expectEqual(case[2], result);
    }
}

test "interval inversion" {
    const test_cases = .{
        // Simple intervals
        .{ Interval.perf(1), Interval.perf(8) },
        .{ Interval.maj(6), Interval.min(3) },
        .{ Interval.maj(2), Interval.min(7) },
        .{ Interval.min(3), Interval.maj(6) },
        .{ Interval.perf(4), Interval.perf(5) },
        .{ Interval.aug(4), Interval.dim(5) },
        .{ Interval.dim(7), Interval.aug(2) },
        .{ Interval.perf(8), Interval.perf(1) },
        // Compound intervals
        .{ Interval.maj(13), Interval.min(3) },
        .{ Interval.maj(10), Interval.min(6) },
        .{ Interval.perf(11), Interval.perf(5) },
        .{ Interval.maj(9), Interval.min(7) },
        .{ Interval.aug(12), Interval.dim(4) },
        .{ Interval.perf(15), Interval.perf(1) },
    };

    inline for (test_cases) |case| {
        // force unwrap
        const interval = case[0] catch unreachable;
        const expected = case[1] catch unreachable;

        const inverted = interval.invert();
        try testing.expectEqual(expected, inverted);

        // For simple intervals, we expect double inversion to return to the original.
        if (interval.isSimple()) {
            const original = inverted.invert();
            try testing.expectEqual(interval, original);
        }
    }
}

test "interval formatting" {
    const test_cases = .{
        .{ Interval.perf(1), "P1", "perf1", "Perfect Unison" },
        .{ Interval.maj(3), "M3", "maj3", "Major Third" },
        .{ Interval.min(6), "m6", "min6", "Minor Sixth" },
        .{ Interval.aug(4), "A4", "aug4", "Augmented Fourth" },
        .{ Interval.dim(5), "d5", "dim5", "Diminished Fifth" },
        .{ Interval.perf(8), "P8", "perf8", "Octave" },
        .{ Interval.perf(11), "P11", "perf11", "Eleventh" },
    };

    inline for (test_cases) |case| {
        const interval = case[0] catch unreachable; // force unwrap
        const exp_default = case[1];
        const exp_short = case[2];
        const exp_desc = case[3];

        var buf: [32]u8 = undefined;

        const def = try std.fmt.bufPrint(&buf, "{}", .{interval});
        try std.testing.expectEqualStrings(exp_default, def);

        const short = try std.fmt.bufPrint(&buf, "{}", .{interval.fmtShort()});
        try std.testing.expectEqualStrings(exp_short, short);

        const desc = try std.fmt.bufPrint(&buf, "{}", .{interval.fmtDesc()});
        try std.testing.expectEqualStrings(exp_desc, desc);
    }
}
