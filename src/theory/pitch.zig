const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.pitch);

const constants = @import("constants.zig");
const Note = @import("note.zig").Note;

// The international standard pitch, A440.
const standard_pitch = Pitch{ .note = Note{ .letter = .a, .accidental = null }, .octave = 4 };
const standard_freq = 440.0; // hertz

// Musical pitch representation using Scientific Pitch Notation.
pub const Pitch = struct {
    note: Note,
    octave: i8,

    // pub fn new(note: Note, octave: i8) Pitch {}

    pub fn fromMidiNumber(midi_number: u7) Pitch {
        const semitones_from_c0 = @as(i16, midi_number) - constants.pitch_classes;
        const octave = @divFloor(semitones_from_c0, constants.pitch_classes);
        const pitch_class = @mod(semitones_from_c0, constants.pitch_classes);

        const note = Note.fromPitchClass(@intCast(pitch_class));
        return Pitch{ .note = note, .octave = @intCast(octave) };
    }

    // pub fn fromString(str: []const u8) !Pitch {}

    // pub fn transpose(self: Pitch, semitones: i8) Pitch {}

    pub fn getFrequency(self: Pitch) f64 {
        return self.getFrequencyWithReference(standard_pitch, standard_freq);
    }

    pub fn getFrequencyWithReference(self: Pitch, ref_pitch: Pitch, ref_freq: f64) f64 {
        const semitones_from_ref = self.semitonesFrom(ref_pitch);
        const exponent: f64 = @floatFromInt(semitones_from_ref);
        return ref_freq * std.math.pow(f64, 2.0, exponent / @as(f64, constants.pitch_classes));
    }

    pub fn getEffectiveOctave(self: Pitch) i8 {
        var adjustment: i8 = 0;

        if (self.note.accidental) |acc| {
            adjustment += switch (acc) {
                .flat, .double_flat => if (self.note.letter == .c) -1 else 0,
                .sharp, .double_sharp => if (self.note.letter == .b) 1 else 0,
                .natural => 0,
            };
        }

        return self.octave + adjustment;
    }

    pub fn toMidiNumber(self: Pitch) PitchError!u7 {
        // C-1 is the lowest MIDI number (0).
        const c_neg1_pitch = Pitch{ .note = Note{ .letter = .c, .accidental = null }, .octave = -1 };
        const semitones_from_c_neg1 = self.semitonesFrom(c_neg1_pitch);

        if (semitones_from_c_neg1 < 0 or 127 < semitones_from_c_neg1) {
            return error.OutOfMidiRange;
        }

        return @intCast(semitones_from_c_neg1);
    }

    // pub fn toString(self: Pitch) []const u8 { }

    // pub fn isEnharmonic(self: Pitch, other: Pitch) bool { }

    pub fn semitonesFrom(self: Pitch, other: Pitch) i16 {
        const self_effective_octave: i16 = @intCast(self.getEffectiveOctave());
        const other_effective_octave: i16 = @intCast(other.getEffectiveOctave());
        const self_pitch_class: i16 = @intCast(self.note.getPitchClass());
        const other_pitch_class: i16 = @intCast(other.note.getPitchClass());

        return (self_effective_octave * constants.pitch_classes + self_pitch_class) -
            (other_effective_octave * constants.pitch_classes + other_pitch_class);
    }
};

pub const PitchError = error{
    OutOfMidiRange,
};

const epsilon = 0.001;

test "frequency calculation" {
    const a4 = Pitch{ .note = Note{ .letter = .a, .accidental = null }, .octave = 4 };
    try std.testing.expectApproxEqAbs(a4.getFrequency(), 440.0, epsilon);

    const c4 = Pitch{ .note = Note{ .letter = .c, .accidental = null }, .octave = 4 };
    try std.testing.expectApproxEqAbs(c4.getFrequency(), 261.626, epsilon);
}

test "frequency calculation with octave wrapping" {
    const b3 = Pitch{ .note = Note{ .letter = .b, .accidental = null }, .octave = 3 };
    const c_flat4 = Pitch{ .note = Note{ .letter = .c, .accidental = .flat }, .octave = 4 };

    try std.testing.expectApproxEqAbs(b3.getFrequency(), c_flat4.getFrequency(), epsilon);
    try std.testing.expectApproxEqAbs(b3.getFrequency(), 246.942, epsilon);
}

test "MIDI number conversion" {
    const a4 = Pitch{ .note = Note{ .letter = .a, .accidental = null }, .octave = 4 };
    try std.testing.expectEqual(try a4.toMidiNumber(), 69);

    const c4 = Pitch{ .note = Note{ .letter = .c, .accidental = null }, .octave = 4 };
    try std.testing.expectEqual(try c4.toMidiNumber(), 60);

    const c_neg1 = Pitch{ .note = Note{ .letter = .c, .accidental = null }, .octave = -1 };
    try std.testing.expectEqual(try c_neg1.toMidiNumber(), 0);

    const g9 = Pitch{ .note = Note{ .letter = .g, .accidental = null }, .octave = 9 };
    try std.testing.expectEqual(try g9.toMidiNumber(), 127);

    // Test fromMidiNumber
    try std.testing.expectEqual(Pitch.fromMidiNumber(69).note.letter, .a);
    try std.testing.expectEqual(Pitch.fromMidiNumber(69).octave, 4);

    try std.testing.expectEqual(Pitch.fromMidiNumber(60).note.letter, .c);
    try std.testing.expectEqual(Pitch.fromMidiNumber(60).octave, 4);

    try std.testing.expectEqual(Pitch.fromMidiNumber(0).note.letter, .c);
    try std.testing.expectEqual(Pitch.fromMidiNumber(0).octave, -1);

    try std.testing.expectEqual(Pitch.fromMidiNumber(127).note.letter, .g);
    try std.testing.expectEqual(Pitch.fromMidiNumber(127).octave, 9);
}

test "MIDI number conversion with octave wrapping" {
    const b3 = Pitch{ .note = Note{ .letter = .b, .accidental = null }, .octave = 3 };
    const c_flat4 = Pitch{ .note = Note{ .letter = .c, .accidental = .flat }, .octave = 4 };

    try std.testing.expectEqual(try b3.toMidiNumber(), try c_flat4.toMidiNumber());
    try std.testing.expectEqual(try b3.toMidiNumber(), 59);
}

test "edge cases with double accidentals" {
    const b_sharp3 = Pitch{ .note = Note{ .letter = .b, .accidental = .sharp }, .octave = 3 };
    const c4 = Pitch{ .note = Note{ .letter = .c, .accidental = null }, .octave = 4 };
    try std.testing.expectEqual(try b_sharp3.toMidiNumber(), try c4.toMidiNumber());

    const c_flat4 = Pitch{ .note = Note{ .letter = .c, .accidental = .flat }, .octave = 4 };
    const b3 = Pitch{ .note = Note{ .letter = .b, .accidental = null }, .octave = 3 };
    try std.testing.expectEqual(try c_flat4.toMidiNumber(), try b3.toMidiNumber());

    const c_double_flat4 = Pitch{ .note = Note{ .letter = .c, .accidental = .double_flat }, .octave = 4 };
    const a_sharp3 = Pitch{ .note = Note{ .letter = .a, .accidental = .sharp }, .octave = 3 };
    try std.testing.expectEqual(try c_double_flat4.toMidiNumber(), try a_sharp3.toMidiNumber());
}

test "negative octaves and MIDI range boundaries" {
    const c_neg1 = Pitch{ .note = Note{ .letter = .c, .accidental = null }, .octave = -1 };
    try std.testing.expectEqual(c_neg1.getEffectiveOctave(), -1);
    try std.testing.expectEqual(try c_neg1.toMidiNumber(), 0);

    const c_flat_neg1 = Pitch{ .note = Note{ .letter = .c, .accidental = .flat }, .octave = -1 };
    try std.testing.expectEqual(c_flat_neg1.getEffectiveOctave(), -2);
    try std.testing.expectError(PitchError.OutOfMidiRange, c_flat_neg1.toMidiNumber());

    const b_neg1 = Pitch{ .note = Note{ .letter = .b, .accidental = null }, .octave = -1 };
    try std.testing.expectEqual(b_neg1.getEffectiveOctave(), -1);
    try std.testing.expectEqual(try b_neg1.toMidiNumber(), 11);

    const b_sharp_neg2 = Pitch{ .note = Note{ .letter = .b, .accidental = .sharp }, .octave = -2 };
    try std.testing.expectEqual(b_sharp_neg2.getEffectiveOctave(), -1);
    try std.testing.expectEqual(try b_sharp_neg2.toMidiNumber(), 0);

    const c_sharp_neg1 = Pitch{ .note = Note{ .letter = .c, .accidental = .sharp }, .octave = -1 };
    try std.testing.expectEqual(try c_sharp_neg1.toMidiNumber(), 1);

    const g9 = Pitch{ .note = Note{ .letter = .g, .accidental = null }, .octave = 9 };
    try std.testing.expectEqual(try g9.toMidiNumber(), 127);

    const g_sharp9 = Pitch{ .note = Note{ .letter = .g, .accidental = .sharp }, .octave = 9 };
    try std.testing.expectError(PitchError.OutOfMidiRange, g_sharp9.toMidiNumber());

    const a9 = Pitch{ .note = Note{ .letter = .a, .accidental = null }, .octave = 9 };
    try std.testing.expectError(PitchError.OutOfMidiRange, a9.toMidiNumber());
}
