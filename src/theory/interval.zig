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
        const diatonic_steps = from.diatonicStepsTo(to);
        const semitones = from.semitonesTo(to);
        const max_interval = @typeInfo(Number).Enum.fields.len;

        const number: Number = if (1 <= diatonic_steps and diatonic_steps <= max_interval)
            @enumFromInt(diatonic_steps)
        else
            return error.IntervalOutOfRange;

        const quality = try calcQuality(semitones, number);

        assert(isValid(quality, number));
        return .{ .quality = quality, .number = number };
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

// pub fn applyToPitch(self: Interval, pitch: Pitch) Pitch {
//     var result = pitch;
//     result.octave += @divFloor(self.degree() - 1, constants.diatonic_degrees );
//     const target_letter_index = (@intFromEnum(pitch.note.letter) + self.degree() - 1) % constants.diatonic_degrees ;
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
//     result.octave += @divFloor(degree_change, constants.diatonic_degrees );
//     const target_letter_index = (@intFromEnum(pitch.note.letter) + degree_change) % constants.diatonic_degrees ;
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
