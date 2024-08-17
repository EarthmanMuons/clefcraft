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

    pub const Error = error{
        PitchOutOfMidiRange,
    };

    pub fn frequency(self: Pitch) f64 {
        return self.frequencyWithReference(standard_pitch, standard_freq);
    }

    pub fn frequencyWithReference(self: Pitch, ref_pitch: Pitch, ref_freq: f64) f64 {
        const semitones_from_ref = self.semitonesFrom(ref_pitch);
        return ref_freq * std.math.pow(f64, 2.0, @as(f64, @floatFromInt(semitones_from_ref)) / @as(f64, constants.pitch_classes));
    }

    pub fn toMidiNumber(self: Pitch) Error!u7 {
        const semitones_from_c_neg1 = self.semitonesFromC0() + constants.pitch_classes; // C-1 is 12 semitones below C0
        if (semitones_from_c_neg1 < 0 or semitones_from_c_neg1 > 127) {
            return Error.PitchOutOfMidiRange;
        }
        return @intCast(semitones_from_c_neg1);
    }

    pub fn fromMidiNumber(midi_number: u7) Pitch {
        const semitones_from_c0 = @as(i16, midi_number) - constants.pitch_classes;
        const octave = @divFloor(semitones_from_c0, constants.pitch_classes);
        const pitch_class = @mod(semitones_from_c0, constants.pitch_classes);

        const note = Note.fromPitchClass(@intCast(pitch_class));
        return Pitch{ .note = note, .octave = @intCast(octave) };
    }

    fn semitonesFrom(self: Pitch, other: Pitch) i16 {
        return self.semitonesFromC0() - other.semitonesFromC0();
    }

    fn semitonesFromC0(self: Pitch) i16 {
        const pitch_class = self.note.pitchClass();
        const effective_octave = self.effectiveOctave();

        return @as(i16, effective_octave) * constants.pitch_classes + @as(i16, pitch_class);
    }

    pub fn effectiveOctave(self: Pitch) i8 {
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
};

const epsilon = 0.001;

test "frequency calculation" {
    const a4 = Pitch{ .note = Note{ .letter = .a, .accidental = null }, .octave = 4 };
    try std.testing.expectApproxEqAbs(a4.frequency(), 440.0, epsilon);

    const c4 = Pitch{ .note = Note{ .letter = .c, .accidental = null }, .octave = 4 };
    try std.testing.expectApproxEqAbs(c4.frequency(), 261.626, epsilon);
}

test "frequency calculation with octave wrapping" {
    const b3 = Pitch{ .note = Note{ .letter = .b, .accidental = null }, .octave = 3 };
    const c_flat4 = Pitch{ .note = Note{ .letter = .c, .accidental = .flat }, .octave = 4 };

    try std.testing.expectApproxEqAbs(b3.frequency(), c_flat4.frequency(), epsilon);
    try std.testing.expectApproxEqAbs(b3.frequency(), 246.942, epsilon);
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
    try std.testing.expectEqual(c_neg1.effectiveOctave(), -1);
    try std.testing.expectEqual(try c_neg1.toMidiNumber(), 0);

    const c_flat_neg1 = Pitch{ .note = Note{ .letter = .c, .accidental = .flat }, .octave = -1 };
    try std.testing.expectEqual(c_flat_neg1.effectiveOctave(), -2);
    try std.testing.expectError(Pitch.Error.PitchOutOfMidiRange, c_flat_neg1.toMidiNumber());

    const b_neg1 = Pitch{ .note = Note{ .letter = .b, .accidental = null }, .octave = -1 };
    try std.testing.expectEqual(b_neg1.effectiveOctave(), -1);
    try std.testing.expectEqual(try b_neg1.toMidiNumber(), 11);

    const b_sharp_neg2 = Pitch{ .note = Note{ .letter = .b, .accidental = .sharp }, .octave = -2 };
    try std.testing.expectEqual(b_sharp_neg2.effectiveOctave(), -1);
    try std.testing.expectEqual(try b_sharp_neg2.toMidiNumber(), 0);

    const c_sharp_neg1 = Pitch{ .note = Note{ .letter = .c, .accidental = .sharp }, .octave = -1 };
    try std.testing.expectEqual(try c_sharp_neg1.toMidiNumber(), 1);

    const g9 = Pitch{ .note = Note{ .letter = .g, .accidental = null }, .octave = 9 };
    try std.testing.expectEqual(try g9.toMidiNumber(), 127);

    const g_sharp9 = Pitch{ .note = Note{ .letter = .g, .accidental = .sharp }, .octave = 9 };
    try std.testing.expectError(Pitch.Error.PitchOutOfMidiRange, g_sharp9.toMidiNumber());

    const a9 = Pitch{ .note = Note{ .letter = .a, .accidental = null }, .octave = 9 };
    try std.testing.expectError(Pitch.Error.PitchOutOfMidiRange, a9.toMidiNumber());
}
