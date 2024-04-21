const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.note);

const pitch = @import("pitch.zig");
const _interval = @import("interval.zig");
const utils = @import("utils.zig");

const Accidental = pitch.Accidental;
const Interval = _interval.Interval;
const Letter = pitch.Letter;
const Pitch = pitch.Pitch;

const semitones_per_octave = @import("constants.zig").music_theory.semitones_per_octave;

// The international standard pitch, A440.
const standard_note = Note{ .pitch = Pitch{ .letter = .a, .accidental = null }, .octave = 4 };
const standard_freq = 440.0; // hertz

pub const Note = struct {
    pitch: Pitch,
    octave: i32,

    // Creates a note from a string representation.
    pub fn parse(text: []const u8) !Note {
        if (text.len < 2) return error.InvalidNoteFormat;

        const first_char = std.ascii.toUpper(text[0]);
        const letter = switch (first_char) {
            'A' => Letter.a,
            'B' => Letter.b,
            'C' => Letter.c,
            'D' => Letter.d,
            'E' => Letter.e,
            'F' => Letter.f,
            'G' => Letter.g,
            else => return error.InvalidLetter,
        };

        var accidental: ?Accidental = null;
        var octave_idx: usize = 1;
        if (text.len > 2) {
            accidental = switch (text[1]) {
                'b' => Accidental.flat,
                'n' => Accidental.natural,
                '#' => Accidental.sharp,
                'x' => Accidental.double_sharp,
                else => null,
            };
            if (accidental != null) octave_idx += 1;
        }
        if (text.len > 3) {
            if (text[1] == 'b' and text[2] == 'b') {
                accidental = Accidental.double_flat;
                octave_idx += 1;
            } else if (text[1] == '#' and text[2] == '#') {
                accidental = Accidental.double_sharp;
                octave_idx += 1;
            }
        }
        const octave_str = text[octave_idx..];
        const octave = std.fmt.parseInt(i32, octave_str, 10) catch return error.InvalidOctave;

        return Note{
            .pitch = Pitch{ .letter = letter, .accidental = accidental },
            .octave = octave,
        };
    }

    // Returns the pitch class of the current note.
    pub fn pitchClass(self: Note) i32 {
        return self.pitch.pitchClass();
    }

    // Returns the effective octave of the current note, considering accidentals.
    pub fn effectiveOctave(self: Note) i32 {
        var octave_adjustment: i32 = 0;

        if (self.pitch.accidental) |acc| {
            octave_adjustment += switch (acc) {
                .flat, .double_flat => if (self.pitch.letter == .c) -1 else 0,
                .sharp, .double_sharp => if (self.pitch.letter == .b) 1 else 0,
                else => 0,
            };
        }

        return self.octave + octave_adjustment;
    }

    // Returns the frequency of the current note in Hz, using twelve-tone equal temperament (12-TET)
    // and the A440 standard pitch as the reference note.
    pub fn frequency(self: Note) f64 {
        return self.frequencyWithRef(standard_note, standard_freq);
    }

    // Returns the frequency of the current note in Hz, using twelve-tone equal temperament (12-TET)
    // and the given reference note.
    pub fn frequencyWithRef(self: Note, ref_note: Note, ref_freq: f64) f64 {
        const semitone_diff = ref_note.semitoneDifference(self);
        const semitone_diff_ratio =
            @as(f64, @floatFromInt(semitone_diff)) /
            @as(f64, @floatFromInt(semitones_per_octave));

        return ref_freq * @exp2(semitone_diff_ratio);
    }

    // Creates a note from a frequency in Hz, using twelve-tone equal temperament (12-TET)
    // and the A440 standard pitch as the reference note.
    pub fn fromFrequency(freq: f64) Note {
        return fromFrequencyWithRef(freq, standard_note, standard_freq);
    }

    // Creates a note from a frequency in Hz, using twelve-tone equal temperament (12-TET)
    // and the given reference note.
    pub fn fromFrequencyWithRef(freq: f64, ref_note: Note, ref_freq: f64) Note {
        assert(freq > 0);

        const semitone_diff_raw = @log2(freq / ref_freq) * semitones_per_octave;
        const semitone_diff = @as(i32, @intFromFloat(@round(semitone_diff_raw)));

        const ref_pos = (ref_note.effectiveOctave() * semitones_per_octave) + ref_note.pitchClass();
        const target_pos = ref_pos + semitone_diff;

        const pitch_class = utils.wrap(target_pos, semitones_per_octave);
        const octave = @divTrunc(target_pos, semitones_per_octave);

        return Note{
            .pitch = Pitch.fromPitchClass(pitch_class),
            .octave = octave,
        };
    }

    // Returns the MIDI note number of the current note.
    pub fn midi(self: Note) i32 {
        const octave_offset = (self.effectiveOctave() + 1) * semitones_per_octave;
        const midi_note = octave_offset + self.pitchClass();

        assert(0 <= midi_note and midi_note <= 127);
        return midi_note;
    }

    // Creates a note from a MIDI note number.
    pub fn fromMidi(midi_note: i32) Note {
        assert(0 <= midi_note and midi_note <= 127);

        const pitch_class = utils.wrap(midi_note, semitones_per_octave);
        const octave = @divTrunc(midi_note, semitones_per_octave) - 1;

        return Note{
            .pitch = Pitch.fromPitchClass(pitch_class),
            .octave = octave,
        };
    }

    // Returns the difference in octaves between two notes, which can be negative.
    pub fn octaveDifference(self: Note, other: Note) i32 {
        return other.effectiveOctave() - self.effectiveOctave();
    }

    // Returns the difference in semitones between two notes, which can be negative.
    pub fn semitoneDifference(self: Note, other: Note) i32 {
        const octave_diff = self.octaveDifference(other);
        const pitch_diff = other.pitchClass() - self.pitchClass();

        return (octave_diff * semitones_per_octave) + pitch_diff;
    }

    // Returns the non-negative distance between two notes based on their letters.
    pub fn letterDistance(self: Note, other: Note) i32 {
        return pitch.distanceBetween(self.pitch.letter, other.pitch.letter);
    }

    // Applies the given interval to the current note and returns the resulting note.
    pub fn applyInterval(self: Note, interval: Interval) !Note {
        const start_pitch_class = self.pitchClass();
        const interval_semitones = interval.semitoneCount();
        const target_pitch_class = utils.wrap(start_pitch_class + interval_semitones, 12);

        const start_letter = self.pitch.letter;
        const interval_num = @intFromEnum(interval.number);
        // Minus one since interval numbers are one-based.
        const target_letter = start_letter.offsetBy(interval_num - 1);
        const target_pitch = try selectEnharmonic(target_pitch_class, target_letter);

        const octave_adjustment = @divFloor(start_pitch_class + interval_semitones, 12);
        const target_octave = self.octave + octave_adjustment;

        return Note{
            .pitch = target_pitch,
            .octave = target_octave,
        };
    }

    fn selectEnharmonic(target_pitch_class: i32, target_letter: Letter) !Pitch {
        assert(0 <= target_pitch_class and target_pitch_class < semitones_per_octave);

        const natural_pitch_class = target_letter.pitchClass();
        const adjustment = target_pitch_class - natural_pitch_class;
        const accidental: ?Accidental = try Accidental.fromPitchAdjustment(adjustment);

        return Pitch{
            .letter = target_letter,
            .accidental = accidental,
        };
    }

    // Formats the note as a string.
    pub fn format(
        self: Note,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try self.pitch.format(fmt, options, writer);
        try writer.print("{d}", .{self.octave});
    }
};

// Tests if two notes are enharmonic equivalents.
pub fn isEnharmonic(note1: Note, note2: Note) bool {
    const same_octave = note1.effectiveOctave() == note2.effectiveOctave();
    const same_pitch_class = note1.pitchClass() == note2.pitchClass();

    return same_octave and same_pitch_class;
}

test "frequency calculation" {
    const TestCase = struct {
        n1: []const u8,
        expected: f64,
    };

    const test_cases = [_]TestCase{
        TestCase{ .n1 = "C-1", .expected = 8.176 },
        TestCase{ .n1 = "C0", .expected = 16.352 },
        TestCase{ .n1 = "A0", .expected = 27.5 },
        TestCase{ .n1 = "C4", .expected = 261.626 },
        TestCase{ .n1 = "A4", .expected = 440.0 },
        TestCase{ .n1 = "C8", .expected = 4186.009 },
        TestCase{ .n1 = "B8", .expected = 7902.133 },
        TestCase{ .n1 = "G9", .expected = 12543.854 },
    };

    const epsilon = 0.001;
    for (test_cases) |test_case| {
        const note = try Note.parse(test_case.n1);
        const result = note.frequency();

        const passed = std.math.approxEqAbs(f64, test_case.expected, result, epsilon);
        if (!passed) {
            std.debug.print(
                "\nTestCase: Note({})\nexpected {d:.3}, found {d:.3}\n",
                .{ note, test_case.expected, result },
            );
        }
        try std.testing.expect(passed);
    }
}

test "create from frequency" {
    var expected: Note = undefined;

    expected = try Note.parse("C-1");
    try std.testing.expectEqual(expected, Note.fromFrequency(8.176));
    expected = try Note.parse("C0");
    try std.testing.expectEqual(expected, Note.fromFrequency(16.352));
    expected = try Note.parse("A0");
    try std.testing.expectEqual(expected, Note.fromFrequency(27.5));
    expected = try Note.parse("C4");
    try std.testing.expectEqual(expected, Note.fromFrequency(261.626));
    expected = try Note.parse("A4");
    try std.testing.expectEqual(expected, Note.fromFrequency(440.0));
    expected = try Note.parse("C8");
    try std.testing.expectEqual(expected, Note.fromFrequency(4186.009));
    expected = try Note.parse("B8");
    try std.testing.expectEqual(expected, Note.fromFrequency(7902.133));
    expected = try Note.parse("G9");
    try std.testing.expectEqual(expected, Note.fromFrequency(12543.854));
}

test "midi note number calculation" {
    const TestCase = struct {
        n1: []const u8,
        expected: i32,
    };

    const test_cases = [_]TestCase{
        TestCase{ .n1 = "C-1", .expected = 0 },
        TestCase{ .n1 = "B3", .expected = 59 },
        TestCase{ .n1 = "Cb4", .expected = 59 },
        TestCase{ .n1 = "C4", .expected = 60 },
        TestCase{ .n1 = "A4", .expected = 69 },
        TestCase{ .n1 = "G9", .expected = 127 },
    };

    for (test_cases) |test_case| {
        const n1 = try Note.parse(test_case.n1);
        const result = n1.midi();

        if (test_case.expected != result) {
            std.debug.print("\nTestCase: Note({})\n", .{n1});
        }
        try std.testing.expectEqual(test_case.expected, result);
    }
}

test "create from midi note number" {
    var expected: Note = undefined;

    expected = try Note.parse("C-1");
    try std.testing.expectEqual(expected, Note.fromMidi(0));
    expected = try Note.parse("C4");
    try std.testing.expectEqual(expected, Note.fromMidi(60));
    expected = try Note.parse("A4");
    try std.testing.expectEqual(expected, Note.fromMidi(69));
    expected = try Note.parse("G9");
    try std.testing.expectEqual(expected, Note.fromMidi(127));
}

test "semitoneDifference()" {
    const TestCase = struct {
        n1: []const u8,
        n2: []const u8,
        expected: i32,
    };

    const test_cases = [_]TestCase{
        TestCase{ .n1 = "C1", .n2 = "C8", .expected = 84 },
        TestCase{ .n1 = "A0", .n2 = "C8", .expected = 87 },
        TestCase{ .n1 = "C0", .n2 = "B8", .expected = 107 },

        TestCase{ .n1 = "A0", .n2 = "C4", .expected = 39 },
        TestCase{ .n1 = "C4", .n2 = "A0", .expected = -39 },
        TestCase{ .n1 = "C4", .n2 = "C5", .expected = 12 },
        TestCase{ .n1 = "C4", .n2 = "C3", .expected = -12 },
        TestCase{ .n1 = "C4", .n2 = "A4", .expected = 9 },
        TestCase{ .n1 = "C4", .n2 = "A3", .expected = -3 },

        TestCase{ .n1 = "B3", .n2 = "B#3", .expected = 1 },
        TestCase{ .n1 = "B3", .n2 = "C4", .expected = 1 },
        TestCase{ .n1 = "C4", .n2 = "B3", .expected = -1 },
        TestCase{ .n1 = "C4", .n2 = "Cb4", .expected = -1 },

        TestCase{ .n1 = "B#3", .n2 = "C4", .expected = 0 },
        TestCase{ .n1 = "Cb4", .n2 = "B3", .expected = 0 },
        TestCase{ .n1 = "C##4", .n2 = "D4", .expected = 0 },
        TestCase{ .n1 = "Dbb4", .n2 = "C4", .expected = 0 },
        TestCase{ .n1 = "E#4", .n2 = "F4", .expected = 0 },
        TestCase{ .n1 = "Fb4", .n2 = "E4", .expected = 0 },
        TestCase{ .n1 = "F#4", .n2 = "Gb4", .expected = 0 },

        TestCase{ .n1 = "C4", .n2 = "Cbb4", .expected = -2 },
        TestCase{ .n1 = "C4", .n2 = "Cb4", .expected = -1 },
        TestCase{ .n1 = "C4", .n2 = "C4", .expected = 0 },
        TestCase{ .n1 = "C4", .n2 = "C#4", .expected = 1 },
        TestCase{ .n1 = "C4", .n2 = "C##4", .expected = 2 },

        TestCase{ .n1 = "G4", .n2 = "G#4", .expected = 1 },
        TestCase{ .n1 = "G4", .n2 = "G##4", .expected = 2 },
        TestCase{ .n1 = "Gb4", .n2 = "G4", .expected = 1 },
        TestCase{ .n1 = "Gb4", .n2 = "G#4", .expected = 2 },
        TestCase{ .n1 = "Gb4", .n2 = "G##4", .expected = 3 },
        TestCase{ .n1 = "Gbb4", .n2 = "Gb4", .expected = 1 },
        TestCase{ .n1 = "Gbb4", .n2 = "G4", .expected = 2 },
        TestCase{ .n1 = "Gbb4", .n2 = "G#4", .expected = 3 },
        TestCase{ .n1 = "Gbb4", .n2 = "G##4", .expected = 4 },
    };

    for (test_cases) |test_case| {
        const n1 = try Note.parse(test_case.n1);
        const n2 = try Note.parse(test_case.n2);
        const result = n1.semitoneDifference(n2);

        if (test_case.expected != result) {
            std.debug.print("\nTestCase: Note({}), Note({s})\n", .{ n1, n2 });
        }
        try std.testing.expectEqual(test_case.expected, result);
    }
}

test "applyInterval()" {
    const TestCase = struct {
        note: []const u8,
        interval: []const u8,
        expected: []const u8,
    };

    const test_cases = [_]TestCase{
        TestCase{ .note = "C4", .interval = "P1", .expected = "C4" },
        TestCase{ .note = "C4", .interval = "P8", .expected = "C5" },
        TestCase{ .note = "C4", .interval = "M3", .expected = "E4" },
        TestCase{ .note = "E4", .interval = "m6", .expected = "C5" },
        TestCase{ .note = "D4", .interval = "M3", .expected = "F#4" },
        TestCase{ .note = "D4", .interval = "d4", .expected = "Gb4" },
    };

    for (test_cases) |test_case| {
        const note = try Note.parse(test_case.note);
        const interval = try Interval.parse(test_case.interval);
        const expected = try Note.parse(test_case.expected);
        const result = try note.applyInterval(interval);

        if (!std.meta.eql(expected, result)) {
            std.debug.print("\nTestCase: Note({}), {}\n", .{ note, interval });
        }
        try std.testing.expectEqual(expected, result);
    }
}
