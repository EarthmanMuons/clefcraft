const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.interval);
const testing = std.testing;

const c = @import("constants.zig");
const Note = @import("note.zig").Note;

pub const Interval = struct {
    qual: Quality,
    num: u7,

    pub const Quality = enum { perfect, major, minor, augmented, diminished };

    /// Creates an interval from a quality and number.
    /// Returns an error if the resulting interval is musically invalid.
    pub fn init(qual: Quality, num: u7) !Interval {
        if (!isValid(qual, num)) {
            return error.InvalidInterval;
        }
        return .{ .qual = qual, .num = num };
    }

    fn isValid(qual: Quality, num: u7) bool {
        if (isPerfect(num)) {
            return switch (qual) {
                .perfect, .augmented, .diminished => true,
                .major, .minor => false,
            };
        } else {
            return switch (qual) {
                .perfect => false,
                .major, .minor, .augmented, .diminished => true,
            };
        }
    }

    fn isPerfect(num: u7) bool {
        const simple_inter = @mod(num - 1, c.ltr_per_oct) + 1;
        return simple_inter == 1 or simple_inter == 4 or simple_inter == 5;
    }

    /// Creates an interval from the given string representation.
    /// Returns an error for invalid input.
    pub fn fromString(str: []const u8) !Interval {
        if (str.len == 0) return error.EmptyString;

        const qual = switch (str[0]) {
            'P' => .perfect,
            'M' => .major,
            'm' => .minor,
            'A' => .augmented,
            'd' => .diminished,
            else => error.InvalidQuality,
        };
        const num = std.fmt.parseInt(u7, str[1..], 10) catch return error.InvalidNumber;

        if (!isValid(qual, num)) {
            return error.InvalidInterval;
        }
        return .{ .qual = qual, .num = num };
    }

    /// Applies the interval to a given note, returning the resulting note.
    /// Returns an error if the resulting note is invalid.
    pub fn applyTo(self: Interval, note: Note) !Note {
        const new_midi = @as(i16, note.midi) + self.semitones();

        const ltr_index = @intFromEnum(note.name.ltr);
        const new_ltr_index = @mod(ltr_index + self.num - 1, c.ltr_per_oct);
        const new_ltr: Note.Letter = @enumFromInt(new_ltr_index);

        const expected_pc = new_ltr.semitones();
        const actual_pc = @mod(new_midi, c.sem_per_oct);

        const acc_diff = actual_pc - expected_pc;
        const new_acc: Note.Accidental = switch (acc_diff) {
            -2 => .double_flat,
            -1 => .flat,
            0 => .natural,
            1 => .sharp,
            2 => .double_sharp,
            else => return error.InvalidInterval,
        };

        const new_oct: i8 = @intCast(@divFloor(new_midi, c.sem_per_oct) - 1);

        return Note.init(new_ltr, new_acc, new_oct);
    }

    /// Returns the inversion of the interval.
    pub fn invert(self: Interval) Interval {
        const new_qual: Quality = switch (self.qual) {
            .perfect => .perfect,
            .major => .minor,
            .minor => .major,
            .augmented => .diminished,
            .diminished => .augmented,
        };

        const simple_inter = @mod(self.num - 1, c.ltr_per_oct) + 1;
        const oct_offset = @divFloor(self.num - 1, c.ltr_per_oct) * c.ltr_per_oct;

        var new_num: u7 = undefined;

        if (simple_inter == 1) {
            // Special handling for unison and octave-based intervals.
            if (self.num == 1) {
                // Unison inverts to octave.
                new_num = 8;
            } else {
                // Octave, double octave, etc. invert to the next lower octave.
                new_num = @intCast(oct_offset - c.ltr_per_oct + 1);
            }
        } else {
            // For all other intervals, inversion adds up to 9
            const new_simple = 9 - simple_inter;
            new_num = new_simple + oct_offset;
        }

        return .{ .qual = new_qual, .num = new_num };
    }

    /// Returns the number of semitones in the interval.
    pub fn semitones(self: Interval) u7 {
        const base_sem = baseSemitones(self.num);

        const qual_offset: i8 = switch (self.qual) {
            .perfect, .major => 0,
            .minor => -1,
            .augmented => 1,
            .diminished => if (isPerfect(self.num)) -1 else -2,
        };

        return @intCast(base_sem + qual_offset);
    }

    fn baseSemitones(num: u7) i8 {
        const simple_inter = @mod(num - 1, c.ltr_per_oct) + 1;
        const base_sem = @as(Note.Letter, @enumFromInt(simple_inter - 1)).semitones();
        const oct_offset = (num - 1) / c.ltr_per_oct * c.sem_per_oct;

        return @intCast(base_sem + oct_offset);
    }

    /// Checks if the interval is compound (larger than an octave).
    pub fn isCompound(self: Interval) bool {
        return self.semitones() > c.sem_per_oct;
    }

    /// Checks if the interval is simple (an octave or smaller).
    pub fn isSimple(self: Interval) bool {
        return !self.isCompound();
    }

    /// Calculates the interval between two notes.
    /// The interval is always calculated from the lower note to the higher note,
    /// regardless of the order of the input arguments.
    pub fn between(lhs: Note, rhs: Note) Interval {
        const ltr_steps = lhs.diatonicStepsTo(rhs);
        const num: u7 = @intCast(@abs(ltr_steps) + 1);

        const sem = lhs.semitonesTo(rhs);
        const base_sem = baseSemitones(num);
        const qual_offset = @as(i16, @abs(sem)) - base_sem;

        const qual = if (isPerfect(num))
            switch (qual_offset) {
                0 => Quality.perfect,
                1 => Quality.augmented,
                -1 => Quality.diminished,
                else => unreachable,
            }
        else switch (qual_offset) {
            0 => Quality.major,
            -1 => Quality.minor,
            1 => Quality.augmented,
            -2 => Quality.diminished,
            else => unreachable,
        };

        assert(isValid(qual, num));
        return .{ .qual = qual, .num = num };
    }

    /// Unison.
    pub const P1 = Interval{ .qual = .perfect, .num = 1 };
    /// Perfect fourth.
    pub const P4 = Interval{ .qual = .perfect, .num = 4 };
    /// Perfect fifth.
    pub const P5 = Interval{ .qual = .perfect, .num = 5 };
    /// Octave.
    pub const P8 = Interval{ .qual = .perfect, .num = 8 };
    /// Perfect eleventh.
    pub const P11 = Interval{ .qual = .perfect, .num = 11 };
    /// Perfect twelfth.
    pub const P12 = Interval{ .qual = .perfect, .num = 12 };
    /// Perfect fifteenth, double octave.
    pub const P15 = Interval{ .qual = .perfect, .num = 15 };

    /// Minor second.
    pub const m2 = Interval{ .qual = .minor, .num = 2 };
    /// Minor third.
    pub const m3 = Interval{ .qual = .minor, .num = 3 };
    /// Minor sixth.
    pub const m6 = Interval{ .qual = .minor, .num = 6 };
    /// Minor seventh.
    pub const m7 = Interval{ .qual = .minor, .num = 7 };
    /// Minor ninth.
    pub const m9 = Interval{ .qual = .minor, .num = 9 };
    /// Minor tenth.
    pub const m10 = Interval{ .qual = .minor, .num = 10 };
    /// Minor thirteenth.
    pub const m13 = Interval{ .qual = .minor, .num = 13 };
    /// Minor fourteenth.
    pub const m14 = Interval{ .qual = .minor, .num = 14 };

    /// Major second.
    pub const M2 = Interval{ .qual = .major, .num = 2 };
    /// Major third.
    pub const M3 = Interval{ .qual = .major, .num = 3 };
    /// Major sixth.
    pub const M6 = Interval{ .qual = .major, .num = 6 };
    /// Major seventh.
    pub const M7 = Interval{ .qual = .major, .num = 7 };
    /// Major ninth.
    pub const M9 = Interval{ .qual = .major, .num = 9 };
    /// Major tenth.
    pub const M10 = Interval{ .qual = .major, .num = 10 };
    /// Major thirteenth.
    pub const M13 = Interval{ .qual = .major, .num = 13 };
    /// Major fourteenth.
    pub const M14 = Interval{ .qual = .major, .num = 14 };

    /// Diminished second.
    pub const d2 = Interval{ .qual = .diminished, .num = 2 };
    /// Diminished third.
    pub const d3 = Interval{ .qual = .diminished, .num = 3 };
    /// Diminished fourth.
    pub const d4 = Interval{ .qual = .diminished, .num = 4 };
    /// Diminished fifth, tritone.
    pub const d5 = Interval{ .qual = .diminished, .num = 5 };
    /// Diminished sixth.
    pub const d6 = Interval{ .qual = .diminished, .num = 6 };
    /// Diminished seventh.
    pub const d7 = Interval{ .qual = .diminished, .num = 7 };
    /// Diminished eighth.
    pub const d8 = Interval{ .qual = .diminished, .num = 8 };
    /// Diminished ninth.
    pub const d9 = Interval{ .qual = .diminished, .num = 9 };
    /// Diminished tenth.
    pub const d10 = Interval{ .qual = .diminished, .num = 10 };
    /// Diminished eleventh.
    pub const d11 = Interval{ .qual = .diminished, .num = 11 };
    /// Diminished twelfth.
    pub const d12 = Interval{ .qual = .diminished, .num = 12 };
    /// Diminished thirteenth.
    pub const d13 = Interval{ .qual = .diminished, .num = 13 };
    /// Diminished fourteenth.
    pub const d14 = Interval{ .qual = .diminished, .num = 14 };
    /// Diminished fifteenth.
    pub const d15 = Interval{ .qual = .diminished, .num = 15 };

    /// Augmented first.
    pub const A1 = Interval{ .qual = .augmented, .num = 1 };
    /// Augmented second.
    pub const A2 = Interval{ .qual = .augmented, .num = 2 };
    /// Augmented third.
    pub const A3 = Interval{ .qual = .augmented, .num = 3 };
    /// Augmented fourth, tritone.
    pub const A4 = Interval{ .qual = .augmented, .num = 4 };
    /// Augmented fifth.
    pub const A5 = Interval{ .qual = .augmented, .num = 5 };
    /// Augmented sixth.
    pub const A6 = Interval{ .qual = .augmented, .num = 6 };
    /// Augmented seventh.
    pub const A7 = Interval{ .qual = .augmented, .num = 7 };
    /// Augmented octave.
    pub const A8 = Interval{ .qual = .augmented, .num = 8 };
    /// Augmented ninth.
    pub const A9 = Interval{ .qual = .augmented, .num = 9 };
    /// Augmented tenth.
    pub const A10 = Interval{ .qual = .augmented, .num = 10 };
    /// Augmented eleventh.
    pub const A11 = Interval{ .qual = .augmented, .num = 11 };
    /// Augmented twelfth.
    pub const A12 = Interval{ .qual = .augmented, .num = 12 };
    /// Augmented thirteenth.
    pub const A13 = Interval{ .qual = .augmented, .num = 13 };
    /// Augmented fourteenth.
    pub const A14 = Interval{ .qual = .augmented, .num = 14 };

    /// Returns a formatter for the interval's shorthand representation.
    pub fn fmtShorthand(self: Interval) std.fmt.Formatter(formatShorthand) {
        return .{ .data = self };
    }

    fn formatShorthand(
        self: Interval,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{s}{d}", .{
            switch (self.qual) {
                .perfect => "perf",
                .major => "maj",
                .minor => "min",
                .augmented => "aug",
                .diminished => "dim",
            },
            self.num,
        });
    }

    /// Formats the interval for output in standard notation.
    pub fn format(
        self: Interval,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{s}{d}", .{
            switch (self.qual) {
                .perfect => "P",
                .major => "M",
                .minor => "m",
                .augmented => "A",
                .diminished => "d",
            },
            self.num,
        });
    }
};

test "semitones" {
    try testing.expectEqual(0, Interval.P1.semitones());
    try testing.expectEqual(0, Interval.d2.semitones());
    try testing.expectEqual(1, Interval.m2.semitones());
    try testing.expectEqual(1, Interval.A1.semitones());
    try testing.expectEqual(2, Interval.M2.semitones());
    try testing.expectEqual(12, Interval.P8.semitones());
    try testing.expectEqual(14, Interval.M9.semitones());
    try testing.expectEqual(21, Interval.M13.semitones());
    try testing.expectEqual(24, Interval.P15.semitones());
}

test "calculation between notes" {
    const c4 = try Note.fromString("C4");
    const e4 = try Note.fromString("E4");
    const g4 = try Note.fromString("G4");
    const c5 = try Note.fromString("C5");
    const f5 = try Note.fromString("F5");

    try testing.expectEqual(Interval.P5, Interval.between(c4, g4));
    try testing.expectEqual(Interval.P11, Interval.between(c4, f5));
    try testing.expectEqual(Interval.m3, Interval.between(e4, g4));
    try testing.expectEqual(Interval.P8, Interval.between(c4, c5));
    // Order doesn't matter.
    try testing.expectEqual(Interval.M3, Interval.between(c4, e4));
    try testing.expectEqual(Interval.M3, Interval.between(e4, c4));
}

test "calculation between enharmonic notes" {
    const d4 = try Note.fromString("D4");
    const fs4 = try Note.fromString("F#4");
    const gf4 = try Note.fromString("Gb4");

    try testing.expect(fs4.isEnharmonic(gf4));
    try testing.expectEqual(Interval.M3, Interval.between(d4, fs4));
    try testing.expectEqual(Interval.d4, Interval.between(d4, gf4));
}

test "application to notes" {
    const c4 = try Note.fromString("C4");
    const e4 = try Note.fromString("E4");
    const g4 = try Note.fromString("G4");
    const c5 = try Note.fromString("C5");

    try testing.expectEqual(e4, try Interval.M3.applyTo(c4));
    try testing.expectEqual(g4, try Interval.P5.applyTo(c4));
    try testing.expectEqual(c5, try Interval.P8.applyTo(c4));

    const fs4 = try Note.fromString("F#4");
    const as4 = try Note.fromString("A#4");
    try testing.expectEqual(as4, try Interval.M3.applyTo(fs4));

    const bf3 = try Note.fromString("Bb3");
    const af4 = try Note.fromString("Ab4");
    try testing.expectEqual(af4, try Interval.m7.applyTo(bf3));

    const e5 = try Note.fromString("E5");
    const cx6 = try Note.fromString("Cx6");
    try testing.expectEqual(cx6, try Interval.A6.applyTo(e5));
}

test "simple inversions" {
    try testing.expectEqual(Interval.P8, Interval.P1.invert());
    try testing.expectEqual(Interval.m3, Interval.M6.invert());
    try testing.expectEqual(Interval.M6, Interval.m3.invert());
    try testing.expectEqual(Interval.m2, Interval.M7.invert());
    try testing.expectEqual(Interval.P4, Interval.P5.invert());
    try testing.expectEqual(Interval.d5, Interval.A4.invert());
    try testing.expectEqual(Interval.P1, Interval.P8.invert());
}

test "compound inversions" {
    try testing.expectEqual(Interval.m13, Interval.M10.invert());
    try testing.expectEqual(Interval.d10, Interval.A13.invert());
    try testing.expectEqual(Interval.P12, Interval.P11.invert());
    try testing.expectEqual(Interval.P8, Interval.P15.invert());
}
