const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.pitch);
const testing = std.testing;

const constants = @import("constants.zig");
const Note = @import("note.zig").Note;

// The international standard pitch, A440.
const standard_pitch = Pitch{ .note = Note{ .letter = .a, .accidental = null }, .octave = 4 };
const standard_freq = 440.0; // hertz

// The practical range for musical octaves covering MIDI numbers and human hearing.
pub const min_octave: i8 = -2;
pub const max_octave: i8 = 10;

// Musical pitch representation using Scientific Pitch Notation.
pub const Pitch = struct {
    note: Note,
    octave: i8,

    pub fn fromMidiNumber(midi_number: u7) Pitch {
        const semitones_from_c0 = @as(i16, midi_number) - constants.pitch_classes;
        const octave = @divFloor(semitones_from_c0, constants.pitch_classes);
        const pitch_class = @mod(semitones_from_c0, constants.pitch_classes);

        const note = Note.fromPitchClass(@intCast(pitch_class));
        return Pitch{ .note = note, .octave = @intCast(octave) };
    }

    pub fn fromString(str: []const u8) !Pitch {
        if (str.len < 2) return error.InvalidStringFormat;

        // Parse the octave number from the end of the string.
        var octave_start: usize = str.len;
        while (octave_start > 0) : (octave_start -= 1) {
            if (std.ascii.isDigit(str[octave_start - 1]) or str[octave_start - 1] == '-') {
                continue;
            } else {
                break;
            }
        }

        if (octave_start == str.len) return error.InvalidStringFormat;

        const note_str = str[0..octave_start];
        const octave_str = str[octave_start..];

        const note = try Note.fromString(note_str);
        const octave = try std.fmt.parseInt(i8, octave_str, 10);

        if (octave < min_octave or max_octave < octave) {
            return error.OctaveOutOfRange;
        }

        return Pitch{ .note = note, .octave = octave };
    }

    // pub fn transpose(self: Pitch, semitones: i8) Pitch {}

    pub fn getFrequency(self: Pitch) f64 {
        return self.getFrequencyWithReference(standard_pitch, standard_freq);
    }

    pub fn getFrequencyWithReference(self: Pitch, ref_pitch: Pitch, ref_freq: f64) f64 {
        const semitones_from_ref: f64 = @floatFromInt(self.semitonesFrom(ref_pitch));
        const ratio = semitones_from_ref / constants.pitch_classes;
        return ref_freq * @exp2(ratio);
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

    pub fn isEnharmonic(self: Pitch, other: Pitch) bool {
        const self_effective_octave: i16 = @intCast(self.getEffectiveOctave());
        const other_effective_octave: i16 = @intCast(other.getEffectiveOctave());
        const self_pitch_class: i16 = @intCast(self.note.getPitchClass());
        const other_pitch_class: i16 = @intCast(other.note.getPitchClass());

        return (self_effective_octave == other_effective_octave) and
            (self_pitch_class == other_pitch_class);
    }

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
    InvalidStringFormat,
    OctaveOutOfRange,
    OutOfMidiRange,
};

const epsilon = 0.001;

test "Pitch.fromString" {
    const TestCase = struct { input: []const u8, expected: Pitch };
    const test_cases = [_]TestCase{
        .{ .input = "C-2", .expected = .{ .note = .{ .letter = .c, .accidental = null }, .octave = -2 } },
        .{ .input = "A0", .expected = .{ .note = .{ .letter = .a, .accidental = null }, .octave = 0 } },
        .{ .input = "C4", .expected = .{ .note = .{ .letter = .c, .accidental = null }, .octave = 4 } },
        .{ .input = "C♯4", .expected = .{ .note = .{ .letter = .c, .accidental = .sharp }, .octave = 4 } },
        .{ .input = "A4", .expected = .{ .note = .{ .letter = .a, .accidental = null }, .octave = 4 } },
        .{ .input = "C8", .expected = .{ .note = .{ .letter = .c, .accidental = null }, .octave = 8 } },
        .{ .input = "C10", .expected = .{ .note = .{ .letter = .c, .accidental = null }, .octave = 10 } },
    };

    for (test_cases) |case| {
        const result = try Pitch.fromString(case.input);
        try testing.expectEqual(case.expected.note.letter, result.note.letter);
        try testing.expectEqual(case.expected.note.accidental, result.note.accidental);
        try testing.expectEqual(case.expected.octave, result.octave);
    }

    // Test error cases
    try testing.expectError(error.InvalidStringFormat, Pitch.fromString("C"));
    try testing.expectError(error.InvalidStringFormat, Pitch.fromString("4"));
    try testing.expectError(error.InvalidLetter, Pitch.fromString("H4"));
    try testing.expectError(error.InvalidAccidental, Pitch.fromString("Cy4"));
    try testing.expectError(error.OctaveOutOfRange, Pitch.fromString("C-3"));
    try testing.expectError(error.OctaveOutOfRange, Pitch.fromString("C11"));
}

test "frequency calculation" {
    const a4 = Pitch{ .note = Note{ .letter = .a, .accidental = null }, .octave = 4 };
    try testing.expectApproxEqAbs(a4.getFrequency(), 440.0, epsilon);

    const c4 = Pitch{ .note = Note{ .letter = .c, .accidental = null }, .octave = 4 };
    try testing.expectApproxEqAbs(c4.getFrequency(), 261.626, epsilon);
}

test "frequency calculation with octave wrapping" {
    const b3 = Pitch{ .note = Note{ .letter = .b, .accidental = null }, .octave = 3 };
    const c_flat4 = Pitch{ .note = Note{ .letter = .c, .accidental = .flat }, .octave = 4 };

    try testing.expectApproxEqAbs(b3.getFrequency(), c_flat4.getFrequency(), epsilon);
    try testing.expectApproxEqAbs(b3.getFrequency(), 246.942, epsilon);
}

test "MIDI number conversion" {
    const a4 = Pitch{ .note = Note{ .letter = .a, .accidental = null }, .octave = 4 };
    try testing.expectEqual(try a4.toMidiNumber(), 69);

    const c4 = Pitch{ .note = Note{ .letter = .c, .accidental = null }, .octave = 4 };
    try testing.expectEqual(try c4.toMidiNumber(), 60);

    const c_neg1 = Pitch{ .note = Note{ .letter = .c, .accidental = null }, .octave = -1 };
    try testing.expectEqual(try c_neg1.toMidiNumber(), 0);

    const g9 = Pitch{ .note = Note{ .letter = .g, .accidental = null }, .octave = 9 };
    try testing.expectEqual(try g9.toMidiNumber(), 127);

    // Test fromMidiNumber
    try testing.expectEqual(Pitch.fromMidiNumber(69).note.letter, .a);
    try testing.expectEqual(Pitch.fromMidiNumber(69).octave, 4);

    try testing.expectEqual(Pitch.fromMidiNumber(60).note.letter, .c);
    try testing.expectEqual(Pitch.fromMidiNumber(60).octave, 4);

    try testing.expectEqual(Pitch.fromMidiNumber(0).note.letter, .c);
    try testing.expectEqual(Pitch.fromMidiNumber(0).octave, -1);

    try testing.expectEqual(Pitch.fromMidiNumber(127).note.letter, .g);
    try testing.expectEqual(Pitch.fromMidiNumber(127).octave, 9);
}

test "MIDI number conversion with octave wrapping" {
    const b3 = Pitch{ .note = Note{ .letter = .b, .accidental = null }, .octave = 3 };
    const c_flat4 = Pitch{ .note = Note{ .letter = .c, .accidental = .flat }, .octave = 4 };

    try testing.expectEqual(try b3.toMidiNumber(), try c_flat4.toMidiNumber());
    try testing.expectEqual(try b3.toMidiNumber(), 59);
}

test "edge cases with double accidentals" {
    const b_sharp3 = Pitch{ .note = Note{ .letter = .b, .accidental = .sharp }, .octave = 3 };
    const c4 = Pitch{ .note = Note{ .letter = .c, .accidental = null }, .octave = 4 };
    try testing.expectEqual(try b_sharp3.toMidiNumber(), try c4.toMidiNumber());

    const c_flat4 = Pitch{ .note = Note{ .letter = .c, .accidental = .flat }, .octave = 4 };
    const b3 = Pitch{ .note = Note{ .letter = .b, .accidental = null }, .octave = 3 };
    try testing.expectEqual(try c_flat4.toMidiNumber(), try b3.toMidiNumber());

    const c_double_flat4 = Pitch{ .note = Note{ .letter = .c, .accidental = .double_flat }, .octave = 4 };
    const a_sharp3 = Pitch{ .note = Note{ .letter = .a, .accidental = .sharp }, .octave = 3 };
    try testing.expectEqual(try c_double_flat4.toMidiNumber(), try a_sharp3.toMidiNumber());
}

test "negative octaves and MIDI range boundaries" {
    const c_neg1 = Pitch{ .note = Note{ .letter = .c, .accidental = null }, .octave = -1 };
    try testing.expectEqual(c_neg1.getEffectiveOctave(), -1);
    try testing.expectEqual(try c_neg1.toMidiNumber(), 0);

    const c_flat_neg1 = Pitch{ .note = Note{ .letter = .c, .accidental = .flat }, .octave = -1 };
    try testing.expectEqual(c_flat_neg1.getEffectiveOctave(), -2);
    try testing.expectError(PitchError.OutOfMidiRange, c_flat_neg1.toMidiNumber());

    const b_neg1 = Pitch{ .note = Note{ .letter = .b, .accidental = null }, .octave = -1 };
    try testing.expectEqual(b_neg1.getEffectiveOctave(), -1);
    try testing.expectEqual(try b_neg1.toMidiNumber(), 11);

    const b_sharp_neg2 = Pitch{ .note = Note{ .letter = .b, .accidental = .sharp }, .octave = -2 };
    try testing.expectEqual(b_sharp_neg2.getEffectiveOctave(), -1);
    try testing.expectEqual(try b_sharp_neg2.toMidiNumber(), 0);

    const c_sharp_neg1 = Pitch{ .note = Note{ .letter = .c, .accidental = .sharp }, .octave = -1 };
    try testing.expectEqual(try c_sharp_neg1.toMidiNumber(), 1);

    const g9 = Pitch{ .note = Note{ .letter = .g, .accidental = null }, .octave = 9 };
    try testing.expectEqual(try g9.toMidiNumber(), 127);

    const g_sharp9 = Pitch{ .note = Note{ .letter = .g, .accidental = .sharp }, .octave = 9 };
    try testing.expectError(PitchError.OutOfMidiRange, g_sharp9.toMidiNumber());

    const a9 = Pitch{ .note = Note{ .letter = .a, .accidental = null }, .octave = 9 };
    try testing.expectError(PitchError.OutOfMidiRange, a9.toMidiNumber());
}

test "Pitch.isEnharmonic" {
    const c4 = Pitch{ .note = Note{ .letter = .c, .accidental = null }, .octave = 4 };
    const b_sharp3 = Pitch{ .note = Note{ .letter = .b, .accidental = .sharp }, .octave = 3 };
    const d_flat4 = Pitch{ .note = Note{ .letter = .d, .accidental = .flat }, .octave = 4 };
    const c_sharp4 = Pitch{ .note = Note{ .letter = .c, .accidental = .sharp }, .octave = 4 };
    const e_double_flat4 = Pitch{ .note = Note{ .letter = .e, .accidental = .double_flat }, .octave = 4 };
    const d4 = Pitch{ .note = Note{ .letter = .d, .accidental = null }, .octave = 4 };

    try testing.expect(c4.isEnharmonic(b_sharp3));
    try testing.expect(d_flat4.isEnharmonic(c_sharp4));
    try testing.expect(e_double_flat4.isEnharmonic(d4));
    try testing.expect(!d_flat4.isEnharmonic(e_double_flat4));
    try testing.expect(!c4.isEnharmonic(d_flat4));

    // Test extreme pitches
    const c_neg10 = Pitch{ .note = Note{ .letter = .c, .accidental = null }, .octave = -10 };
    const b_sharp_neg11 = Pitch{ .note = Note{ .letter = .b, .accidental = .sharp }, .octave = -11 };
    const c_sharp20 = Pitch{ .note = Note{ .letter = .c, .accidental = .sharp }, .octave = 20 };
    const d_flat20 = Pitch{ .note = Note{ .letter = .d, .accidental = .flat }, .octave = 20 };

    try testing.expect(c_neg10.isEnharmonic(b_sharp_neg11));
    try testing.expect(c_sharp20.isEnharmonic(d_flat20));
    try testing.expect(!c_neg10.isEnharmonic(c_sharp20));

    // Test octave wrapping
    const b_sharp4 = Pitch{ .note = Note{ .letter = .b, .accidental = .sharp }, .octave = 4 };
    const c5 = Pitch{ .note = Note{ .letter = .c, .accidental = null }, .octave = 5 };
    try testing.expect(b_sharp4.isEnharmonic(c5));

    const c_flat5 = Pitch{ .note = Note{ .letter = .c, .accidental = .flat }, .octave = 5 };
    const b4 = Pitch{ .note = Note{ .letter = .b, .accidental = null }, .octave = 4 };
    try testing.expect(c_flat5.isEnharmonic(b4));

    // Additional tests with double accidentals
    const f_double_sharp4 = Pitch{ .note = Note{ .letter = .f, .accidental = .double_sharp }, .octave = 4 };
    const g4 = Pitch{ .note = Note{ .letter = .g, .accidental = null }, .octave = 4 };
    try testing.expect(f_double_sharp4.isEnharmonic(g4));

    const g_double_flat4 = Pitch{ .note = Note{ .letter = .g, .accidental = .double_flat }, .octave = 4 };
    const f4 = Pitch{ .note = Note{ .letter = .f, .accidental = null }, .octave = 4 };
    try testing.expect(g_double_flat4.isEnharmonic(f4));
}
