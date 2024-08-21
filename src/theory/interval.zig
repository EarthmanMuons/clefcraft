const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.interval);
const testing = std.testing;

const constants = @import("constants.zig");
const Pitch = @import("pitch.zig").Pitch;
const Note = @import("note.zig").Note;
const Letter = @import("note.zig").Letter;
const Accidental = @import("note.zig").Accidental;

pub const Interval = enum {
    // zig fmt: off
    P1, P4, P5, P8, P11, P12, P15, // Perfect
    M2, M3, M6, M7, M9, M10, M13, M14, // Major
    m2, m3, m6, m7, m9, m10, m13, m14, // Minor
    A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12, A13, A14, // Augmented
    d2, d3, d4, d5, d6, d7, d8, d9, d10, d11, d12, d13, d14, d15, // Diminished
    // zig fmt: on

    pub fn semitones(self: Interval) u8 {
        return switch (self) {
            .P1, .d2 => 0,
            .m2, .A1 => 1,
            .M2, .d3 => 2,
            .m3, .A2 => 3,
            .M3, .d4 => 4,
            .P4, .A3 => 5,
            .A4, .d5 => 6,
            .P5, .d6 => 7,
            .m6, .A5 => 8,
            .M6, .d7 => 9,
            .m7, .A6 => 10,
            .M7, .d8 => 11,
            .P8, .A7, .d9 => 12,
            .m9, .A8 => 13,
            .M9, .d10 => 14,
            .m10, .A9 => 15,
            .M10, .d11 => 16,
            .P11, .A10 => 17,
            .A11, .d12 => 18,
            .P12, .d13 => 19,
            .m13, .A12 => 20,
            .M13, .d14 => 21,
            .m14, .A13 => 22,
            .M14, .d15 => 23,
            .P15, .A14 => 24,
        };
    }

    // pub fn quality(self: Interval) {}

    // Number of letters the interval spans.
    pub fn degree(self: Interval) u8 {
        return switch (self) {
            .P1, .A1 => 1,
            .m2, .M2, .A2, .d2 => 2,
            .m3, .M3, .A3, .d3 => 3,
            .P4, .A4, .d4 => 4,
            .P5, .A5, .d5 => 5,
            .m6, .M6, .A6, .d6 => 6,
            .m7, .M7, .A7, .d7 => 7,
            .P8, .A8, .d8 => 8,
            .m9, .M9, .A9, .d9 => 9,
            .m10, .M10, .A10, .d10 => 10,
            .P11, .A11, .d11 => 11,
            .P12, .A12, .d12 => 12,
            .m13, .M13, .A13, .d13 => 13,
            .m14, .M14, .A14, .d14 => 14,
            .P15, .d15 => 15,
        };
    }

    // fn baseSemitones(number: Number) i32 {
    //     return switch (number) {
    //         .unison => 0,
    //         .second => 2,
    //         .third => 4,
    //         .fourth => 5,
    //         .fifth => 7,
    //         .sixth => 9,
    //         .seventh => 11,
    //         .octave => 12,
    //         .ninth => 14,
    //         .tenth => 16,
    //         .eleventh => 17,
    //         .twelfth => 19,
    //         .thirteenth => 21,
    //         .fourteenth => 22,
    //         .double_octave => 24,
    //     };
    // }

    // pub fn betweenPitches(from: Pitch, to: Pitch) Interval {
    //     const semitone_distance = @intCast(u8, @mod(to.semitonesFrom(from), constants.pitch_classes));
    //     const degrees = diatonicSpan(from, to);

    //     const base_interval = switch (degrees) {
    //         1 => Interval.P1,
    //         2 => Interval.M2,
    //         3 => Interval.M3,
    //         4 => Interval.P4,
    //         5 => Interval.P5,
    //         6 => Interval.M6,
    //         7 => Interval.M7,
    //         else => unreachable,
    //     };

    //     const base_semitones = base_interval.semitones();
    //     const diff = @intCast(i8, semitones_distance) - @intCast(i8, base_semitones);

    //     return switch (diff) {
    //         -2 => switch (base_interval) {
    //             .M2 => .d2,
    //             .M3 => .m3,
    //             .P4 => .d4,
    //             .P5 => .d5,
    //             .M6 => .m6,
    //             .M7 => .m7,
    //             else => unreachable,
    //         },
    //         -1 => switch (base_interval) {
    //             .M2 => .m2,
    //             .M3 => .m3,
    //             .M6 => .m6,
    //             .M7 => .m7,
    //             else => unreachable,
    //         },
    //         0 => base_interval,
    //         1 => switch (base_interval) {
    //             .P1 => .A1,
    //             .M2 => .A2,
    //             .M3 => .A3,
    //             .P4 => .A4,
    //             .P5 => .A5,
    //             .M6 => .A6,
    //             .M7 => .A7,
    //             else => unreachable,
    //         },
    //         2 => switch (base_interval) {
    //             .P4 => .A4,
    //             .P5 => .A5,
    //             else => unreachable,
    //         },
    //         else => unreachable, // Handle larger augmentations/diminutions if needed
    //     };
    // }

    // Counts the sequence of note letters spanning two pitches (inclusive).
    pub fn diatonicSpan(from: Pitch, to: Pitch) u8 {
        const from_letter = @as(i8, @intFromEnum(from.note.letter));
        const to_letter = @as(i8, @intFromEnum(to.note.letter));
        const result = @mod((to_letter - from_letter), constants.diatonic_scale_degrees) + 1;
        return @intCast(result);
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

    pub fn longDescription(self: Interval) []const u8 {
        return switch (self) {
            .P1 => "Perfect Unison",
            .P4 => "Perfect Fourth",
            .P5 => "Perfect Fifth",
            .P8 => "Octave",
            .P11 => "Eleventh",
            .P12 => "Twelfth",
            .P15 => "Double Octave",
            .M2 => "Major Second",
            .M3 => "Major Third",
            .M6 => "Major Sixth",
            .M7 => "Major Seventh",
            .M9 => "Major Ninth",
            .M10 => "Major Tenth",
            .M13 => "Major Thirteenth",
            .M14 => "Major Fourteenth",
            .m2 => "Minor Second",
            .m3 => "Minor Third",
            .m6 => "Minor Sixth",
            .m7 => "Minor Seventh",
            .m9 => "Minor Ninth",
            .m10 => "Minor Tenth",
            .m13 => "Minor Thirteenth",
            .m14 => "Minor Fourteenth",
            .A1 => "Augmented Unison",
            .A2 => "Augmented Second",
            .A3 => "Augmented Third",
            .A4 => "Augmented Fourth (Tritone)",
            .A5 => "Augmented Fifth",
            .A6 => "Augmented Sixth",
            .A7 => "Augmented Seventh",
            .A8 => "Augmented Octave",
            .A9 => "Augmented Ninth",
            .A10 => "Augmented Tenth",
            .A11 => "Augmented Eleventh",
            .A12 => "Augmented Twelfth",
            .A13 => "Augmented Thirteenth",
            .A14 => "Augmented Fourteenth",
            .d2 => "Diminished Second",
            .d3 => "Diminished Third",
            .d4 => "Diminished Fourth",
            .d5 => "Diminished Fifth (Tritone)",
            .d6 => "Diminished Sixth",
            .d7 => "Diminished Seventh",
            .d8 => "Diminished Octave",
            .d9 => "Diminished Ninth",
            .d10 => "Diminished Tenth",
            .d11 => "Diminished Eleventh",
            .d12 => "Diminished Twelfth",
            .d13 => "Diminished Thirteenth",
            .d14 => "Diminished Fourteenth",
            .d15 => "Diminished Double Octave",
        };
    }

    pub fn format(
        self: Interval,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{s}", .{@tagName(self)});
    }
};

// Compile-time check for exhaustiveness.
comptime {
    for (std.enums.values(Interval)) |interval| {
        _ = interval.semitones();
        _ = interval.degree();
        _ = interval.longDescription();
    }
}

// test {
//     const p1 = try Pitch.fromString("B4");
//     const p2 = try Pitch.fromString("D5");
//     const result = Interval.diatonicSpan(p1, p2);
//     std.debug.print("diatonicSpan({}, {}): {d}\n", .{ p1, p2, result });
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
