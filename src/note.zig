const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;

// The international standard pitch (A4 at 440 Hz).
const reference_pitch_class = 9;
const reference_octave = 4;
const reference_frequency = 440.0;

const semitones_per_octave = 12;

pub const Note = struct {
    pitch_class: u8,
    octave: i8,

    pub fn new(pitch_class: u8, octave: i8) Note {
        assert(pitch_class < semitones_per_octave);
        assert(octave >= -1 and octave <= 9);

        return Note{
            .pitch_class = pitch_class,
            .octave = octave,
        };
    }

    // Returns the fundamental frequency in Hz using twelve-tone equal temperament (12-TET).
    pub fn frequency(self: Note) f64 {
        const semitones_from_ref =
            @as(i32, self.pitch_class) - reference_pitch_class +
            (semitones_per_octave * (self.octave - reference_octave));

        const octave_difference =
            @as(f64, @floatFromInt(semitones_from_ref)) /
            @as(f64, @floatFromInt(semitones_per_octave));

        return reference_frequency * @exp2(octave_difference);
    }

    pub fn fromFrequency(freq: f64) Note {
        assert(freq > 0);

        const semitones_from_ref =
            reference_pitch_class +
            semitones_per_octave * @log2(freq / reference_frequency);

        var pitch_class = @mod(@round(semitones_from_ref), semitones_per_octave);
        if (pitch_class < 0) {
            pitch_class += semitones_per_octave;
        }

        const octave_offset = @divTrunc(@round(semitones_from_ref), semitones_per_octave);
        const octave = reference_octave + octave_offset;

        return Note.new(@intFromFloat(pitch_class), @intFromFloat(octave));
    }
};

test "frequency calculation" {
    const approxEqAbs = std.math.approxEqAbs;
    const epsilon = 0.001;

    try testing.expect(approxEqAbs(f64, Note.new(0, -1).frequency(), 8.176, epsilon)); // C-1
    try testing.expect(approxEqAbs(f64, Note.new(0, 0).frequency(), 16.352, epsilon)); // C0
    try testing.expect(approxEqAbs(f64, Note.new(9, 0).frequency(), 27.5, epsilon)); // A0
    try testing.expect(approxEqAbs(f64, Note.new(0, 4).frequency(), 261.626, epsilon)); // C4
    try testing.expect(approxEqAbs(f64, Note.new(9, 4).frequency(), 440.0, epsilon)); // A4
    try testing.expect(approxEqAbs(f64, Note.new(0, 8).frequency(), 4186.009, epsilon)); // C8
    try testing.expect(approxEqAbs(f64, Note.new(11, 8).frequency(), 7902.133, epsilon)); // B8
    try testing.expect(approxEqAbs(f64, Note.new(11, 9).frequency(), 15804.266, epsilon)); // B9
}

test "from frequency" {
    try testing.expectEqual(Note.fromFrequency(8.176), Note.new(0, -1)); // C-1
    try testing.expectEqual(Note.fromFrequency(16.352), Note.new(0, 0)); // C0
    try testing.expectEqual(Note.fromFrequency(440.0), Note.new(9, 4)); // A4
    try testing.expectEqual(Note.fromFrequency(4186.009), Note.new(0, 8)); // C8
}
