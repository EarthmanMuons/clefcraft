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

    pub const Number = enum(u8) {
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

        fn isPerfect(self: Number) bool {
            return switch (self) {
                .unison, .fourth, .fifth, .octave, .eleventh, .twelfth, .double_octave => true,
                else => false,
            };
        }
    };

    pub fn getSemitones(self: Interval) u8 {
        const base_semitones = baseSemitones(self.number);

        const quality_offset = switch (self.quality) {
            .perfect, .major => 0,
            .minor => -1,
            .augmented => 1,
            .diminished => if (self.number.isPerfect()) -1 else -2,
        };

        return base_semitones + quality_offset;
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

    pub fn betweenPitches(from: Pitch, to: Pitch) !Interval {
        const letter_span = letterSpan(from, to);
        const octaves = to.getEffectiveOctave() - from.getEffectiveOctave();
        const semitones = to.semitonesFrom(from);
        const is_compound = semitones > constants.pitch_classes;

        // std.debug.print("letter_span: {}\n", .{letter_span});
        // std.debug.print("octaves: {}\n", .{octaves});
        // std.debug.print("semitones: {}\n", .{semitones});
        // std.debug.print("is_compound: {}\n", .{is_compound});

        const base_number: Number = switch (letter_span) {
            1 => .unison,
            2 => .second,
            3 => .third,
            4 => .fourth,
            5 => .fifth,
            6 => .sixth,
            7 => .seventh,
            else => unreachable,
        };

        const number: Number = switch (base_number) {
            .unison => switch (octaves) {
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

        const quality = try calcQuality(semitones, number);

        assert(isValid(quality, number));
        return .{ .quality = quality, .number = number };
    }

    fn letterSpan(from: Pitch, to: Pitch) u8 {
        const from_letter = @as(i8, @intFromEnum(from.note.letter));
        const to_letter = @as(i8, @intFromEnum(to.note.letter));
        const result = @mod((to_letter - from_letter), constants.diatonic_scale_degrees) + 1;
        return @intCast(result);
    }

    fn calcQuality(semitones: i32, number: Number) !Quality {
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

    // pub fn applyToPitch(self: Interval, pitch: Pitch) Pitch {}

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

    // Helper functions for named intervals.
    pub const P1 = Interval{ .quality = .perfect, .number = .unison };

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
};

test "intervals between pitches" {
    const d = Pitch{ .note = Note{ .letter = .d, .accidental = null }, .octave = 4 };
    const f_sharp = Pitch{ .note = Note{ .letter = .f, .accidental = .sharp }, .octave = 4 };
    const g_flat = Pitch{ .note = Note{ .letter = .g, .accidental = .flat }, .octave = 4 };

    const r1 = try Interval.betweenPitches(d, f_sharp);
    const r2 = try Interval.betweenPitches(d, g_flat);

    std.debug.print("Interval between {} and {} (expect M3): {?}\n", .{ d, f_sharp, r1 });
    std.debug.print("Interval between {} and {} (expect d4): {?}\n", .{ d, g_flat, r2 });
}

// pub fn applyToPitch(self: Interval, pitch: Pitch) Pitch {
//     var result = pitch;
//     result.octave += @divFloor(self.degree() - 1, constants.diatonic_scale_degrees);
//     const target_letter_index = (@intFromEnum(pitch.note.letter) + self.degree() - 1) % constants.diatonic_scale_degrees;
//     result.note.letter = @enumFromInt(target_letter_index);

//     const target_semitones = pitch.semitonesFrom(result) + self.semitones();
//     const octave_adjustment = @divFloor(target_semitones, constants.pitch_classes);
//     result.octave += @intCast(i8, octave_adjustment);

//     const remaining_semitones = @mod(target_semitones, constants.pitch_classes);
//     const natural_note = Note{ .letter = result.note.letter, .accidental = null };
//     const natural_semitones = natural_note.getPitchClass();
//     const accidental_adjustment = @intCast(i8, remaining_semitones) - @intCast(i8, natural_semitones);

//     result.note.accidental = Accidental.fromPitchAdjustment(accidental_adjustment);

//     return result;
// }

// pub fn applyToPitch(self: Interval, pitch: Pitch) Pitch {
//     var result = pitch;
//     const degree_change = self.number.toU8() - 1;
//     result.octave += @divFloor(degree_change, constants.diatonic_scale_degrees);
//     const target_letter_index = (@intFromEnum(pitch.note.letter) + degree_change) % constants.diatonic_scale_degrees;
//     result.note.letter = @enumFromInt(target_letter_index);

//     const semitone_change = self.semitones();
//     const octave_adjustment = @divFloor(semitone_change, constants.pitch_classes);
//     result.octave += @intCast(i8, octave_adjustment);

//     const remaining_semitones = @mod(semitone_change, constants.pitch_classes);
//     const natural_note = Note{ .letter = result.note.letter, .accidental = null };
//     const natural_semitones = natural_note.getPitchClass();
//     const accidental_adjustment = @intCast(i8, remaining_semitones) - @intCast(i8, natural_semitones);

//     result.note.accidental = Accidental.fromPitchAdjustment(accidental_adjustment);

//     return result;
// }

// pub fn longDescription(self: Interval) []const u8 {
//     return switch (self) {
//         .P1 => "Perfect Unison",
//         .P4 => "Perfect Fourth",
//         .P5 => "Perfect Fifth",
//         .P8 => "Octave",
//         .P11 => "Eleventh",
//         .P12 => "Twelfth",
//         .P15 => "Double Octave",
//         .M2 => "Major Second",
//         .M3 => "Major Third",
//         .M6 => "Major Sixth",
//         .M7 => "Major Seventh",
//         .M9 => "Major Ninth",
//         .M10 => "Major Tenth",
//         .M13 => "Major Thirteenth",
//         .M14 => "Major Fourteenth",
//         .m2 => "Minor Second",
//         .m3 => "Minor Third",
//         .m6 => "Minor Sixth",
//         .m7 => "Minor Seventh",
//         .m9 => "Minor Ninth",
//         .m10 => "Minor Tenth",
//         .m13 => "Minor Thirteenth",
//         .m14 => "Minor Fourteenth",
//         .A1 => "Augmented Unison",
//         .A2 => "Augmented Second",
//         .A3 => "Augmented Third",
//         .A4 => "Augmented Fourth (Tritone)",
//         .A5 => "Augmented Fifth",
//         .A6 => "Augmented Sixth",
//         .A7 => "Augmented Seventh",
//         .A8 => "Augmented Octave",
//         .A9 => "Augmented Ninth",
//         .A10 => "Augmented Tenth",
//         .A11 => "Augmented Eleventh",
//         .A12 => "Augmented Twelfth",
//         .A13 => "Augmented Thirteenth",
//         .A14 => "Augmented Fourteenth",
//         .d2 => "Diminished Second",
//         .d3 => "Diminished Third",
//         .d4 => "Diminished Fourth",
//         .d5 => "Diminished Fifth (Tritone)",
//         .d6 => "Diminished Sixth",
//         .d7 => "Diminished Seventh",
//         .d8 => "Diminished Octave",
//         .d9 => "Diminished Ninth",
//         .d10 => "Diminished Tenth",
//         .d11 => "Diminished Eleventh",
//         .d12 => "Diminished Twelfth",
//         .d13 => "Diminished Thirteenth",
//         .d14 => "Diminished Fourteenth",
//         .d15 => "Diminished Double Octave",
//     };
// }

// test "interval properties" {
//     try std.testing.expectEqual(Interval.M3.semitones(), 4);
//     try std.testing.expectEqual(Interval.P5.degree(), 5);
//     try std.testing.expectEqual(Interval.d2.semitones(), 0);
// }

// test "interval formatting" {
//     var buf: [10]u8 = undefined;
//     _ = try std.fmt.bufPrint(&buf, "{}", .{Interval.M3});
//     try std.testing.expectEqualStrings("M3", buf[0..2]);
// }

// test "interval long description" {
//     try std.testing.expectEqualStrings("Major Third", Interval.M3.longDescription());
//     try std.testing.expectEqualStrings("Diminished Second", Interval.d2.longDescription());
// }

// test "between pitches" {
//     const C4 = Pitch{ .note = Note{ .letter = .c, .accidental = null }, .octave = 4 };
//     const E4 = Pitch{ .note = Note{ .letter = .e, .accidental = null }, .octave = 4 };
//     const G4 = Pitch{ .note = Note{ .letter = .g, .accidental = null }, .octave = 4 };
//     const C5 = Pitch{ .note = Note{ .letter = .c, .accidental = null }, .octave = 5 };
//     const Db4 = Pitch{ .note = Note{ .letter = .d, .accidental = .flat }, .octave = 4 };
//     const Fs4 = Pitch{ .note = Note{ .letter = .f, .accidental = .sharp }, .octave = 4 };

//     try std.testing.expectEqual(Interval.M3, Interval.betweenPitches(C4, E4));
//     try std.testing.expectEqual(Interval.P5, Interval.betweenPitches(C4, G4));
//     try std.testing.expectEqual(Interval.P8, Interval.betweenPitches(C4, C5));
//     try std.testing.expectEqual(Interval.m2, Interval.betweenPitches(C4, Db4));
//     try std.testing.expectEqual(Interval.A4, Interval.betweenPitches(C4, Fs4));
// }

// test "apply interval to pitch" {
//     const C4 = Pitch{ .note = Note{ .letter = .c, .accidental = null }, .octave = 4 };
//     const E4 = Pitch{ .note = Note{ .letter = .e, .accidental = null }, .octave = 4 };
//     const G4 = Pitch{ .note = Note{ .letter = .g, .accidental = null }, .octave = 4 };
//     const C5 = Pitch{ .note = Note{ .letter = .c, .accidental = null }, .octave = 5 };
//     const Fs4 = Pitch{ .note = Note{ .letter = .f, .accidental = .sharp }, .octave = 4 };

//     try std.testing.expectEqual(E4, Interval.M3.applyToPitch(C4));
//     try std.testing.expectEqual(G4, Interval.P5.applyToPitch(C4));
//     try std.testing.expectEqual(C5, Interval.P8.applyToPitch(C4));
//     try std.testing.expectEqual(Fs4, Interval.A4.applyToPitch(C4));
// }
