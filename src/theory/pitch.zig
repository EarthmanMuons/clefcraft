const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.pitch);
const testing = std.testing;

const constants = @import("constants.zig");
const Note = @import("note.zig").Note;

// The international standard pitch, A440.
const standard_pitch = Pitch{ .note = Note.a, .octave = 4 };
const standard_freq = 440.0; // hertz

// The practical range for musical octaves covering MIDI numbers and human hearing.
// On the low side, B#-2 has an effective octave of -1 and would be MIDI number 0.
// On the high side, octave 10 gets us above the typical 20k Hz hearing range.
const min_octave: i16 = -2;
const max_octave: i16 = 10;

/// Musical pitch representation using Scientific Pitch Notation.
pub const Pitch = struct {
    note: Note,
    octave: i16,

    /// Creates a Pitch from the given frequency in Hz.
    pub fn fromFrequency(freq: f64) Pitch {
        return fromFrequencyWithReference(freq, standard_pitch, standard_freq);
    }

    /// Creates a Pitch from the given frequency, using a custom reference pitch and frequency.
    pub fn fromFrequencyWithReference(freq: f64, ref_pitch: Pitch, ref_freq: f64) Pitch {
        assert(freq > 0);

        const octave_ratio = @log2(freq / ref_freq);
        const semitones_from_ref = @round(octave_ratio * constants.pitch_classes);

        const ref_semitones = (ref_pitch.octave * constants.pitch_classes) + ref_pitch.note.getPitchClass();
        const total_semitones = ref_semitones + @as(i16, @intFromFloat(semitones_from_ref));

        const new_octave = @divFloor(total_semitones, constants.pitch_classes);
        const new_pitch_class = @mod(total_semitones, constants.pitch_classes);

        const new_note = Note.fromPitchClass(@intCast(new_pitch_class));

        return .{ .note = new_note, .octave = new_octave };
    }

    /// Creates a Pitch from the given MIDI note number.
    pub fn fromMidiNumber(midi_number: u7) Pitch {
        const semitones_from_c0 = @as(i16, midi_number) - constants.pitch_classes;
        const octave = @divFloor(semitones_from_c0, constants.pitch_classes);
        const pitch_class = @mod(semitones_from_c0, constants.pitch_classes);

        const note = Note.fromPitchClass(@intCast(pitch_class));
        return .{ .note = note, .octave = @intCast(octave) };
    }

    /// Parses a string representation of a pitch and returns the corresponding Pitch.
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
        const octave = try std.fmt.parseInt(i16, octave_str, 10);

        if (octave < min_octave or max_octave < octave) {
            return error.OctaveOutOfRange;
        }

        return .{ .note = note, .octave = octave };
    }

    /// Returns the frequency of the pitch in Hz.
    pub fn getFrequency(self: Pitch) f64 {
        return self.getFrequencyWithReference(standard_pitch, standard_freq);
    }

    /// Returns the frequency of the pitch in Hz, using a custom reference pitch and frequency.
    pub fn getFrequencyWithReference(self: Pitch, ref_pitch: Pitch, ref_freq: f64) f64 {
        const semitones_from_ref: f64 = @floatFromInt(ref_pitch.semitonesTo(self));
        const octave_ratio = semitones_from_ref / constants.pitch_classes;
        return ref_freq * @exp2(octave_ratio);
    }

    /// Returns the effective octave of the pitch, accounting for accidentals.
    pub fn getEffectiveOctave(self: Pitch) i16 {
        const offset: i16 = switch (self.note.accidental) {
            .flat, .double_flat => if (self.note.letter == .c) -1 else 0,
            .natural => 0,
            .sharp, .double_sharp => if (self.note.letter == .b) 1 else 0,
        };
        return self.octave + offset;
    }

    /// Returns a new Pitch with the desired accidental, maintaining the same pitch class.
    pub fn toEnharmonic(self: Pitch, desired_accidental: Note.Accidental) Pitch {
        const current_pc = self.note.getPitchClass();
        var new_letter = self.note.letter;
        var new_octave = self.octave;

        log.debug("Start - Current: {}, Current PC: {}, Desired accidental: {}", .{ self, current_pc, desired_accidental });

        // Determine the direction of change
        const direction: i8 = switch (desired_accidental) {
            .flat, .double_flat => 1, // Move forward in the circle of fifths
            .sharp, .double_sharp => -1, // Move backward in the circle of fifths
            .natural => return self, // No change needed for natural
        };

        // Adjust the letter
        const letter_value = @intFromEnum(new_letter);
        new_letter = @enumFromInt(@mod(letter_value + direction + 7, 7));

        log.debug("After letter adjustment - New letter: {}", .{new_letter});

        // Adjust octave if crossing C
        if (new_letter == .c and self.note.letter == .b) {
            new_octave += 1;
        } else if (self.note.letter == .c and new_letter == .b) {
            new_octave -= 1;
        }

        log.debug("After octave adjustment - New octave: {}", .{new_octave});

        const result = Pitch{
            .note = Note{ .letter = new_letter, .accidental = desired_accidental },
            .octave = new_octave,
        };

        log.debug("End - Result: {}", .{result});

        return result;
    }

    /// Converts the pitch to its corresponding MIDI note number.
    pub fn toMidiNumber(self: Pitch) !u7 {
        const midi_zero_pitch = Pitch{ .note = Note.c, .octave = -1 };
        const semitones_above_midi_zero = midi_zero_pitch.semitonesTo(self);

        if (semitones_above_midi_zero < 0 or 127 < semitones_above_midi_zero) {
            return error.OutOfMidiRange;
        }

        return @intCast(semitones_above_midi_zero);
    }

    /// Checks if this pitch is enharmonic with another pitch.
    pub fn isEnharmonic(self: Pitch, other: Pitch) bool {
        const same_octave = self.getEffectiveOctave() == other.getEffectiveOctave();
        const same_pitch_class = self.note.getPitchClass() == other.note.getPitchClass();

        return same_octave and same_pitch_class;
    }

    /// Calculates the number of diatonic steps between this pitch and another pitch.
    pub fn diatonicStepsTo(self: Pitch, other: Pitch) i16 {
        const self_letter = @intFromEnum(self.note.letter);
        const other_letter = @intFromEnum(other.note.letter);
        const octave_diff = other.octave - self.octave;

        return (other_letter - self_letter) + (octave_diff * constants.diatonic_degrees) + 1;
    }

    /// Calculates the number of octaves between this pitch and another pitch.
    pub fn octavesTo(self: Pitch, other: Pitch) i16 {
        return other.getEffectiveOctave() - self.getEffectiveOctave();
    }

    /// Calculates the number of semitones between this pitch and another pitch.
    pub fn semitonesTo(self: Pitch, other: Pitch) i16 {
        const self_octave = self.getEffectiveOctave();
        const other_octave = other.getEffectiveOctave();
        const self_pitch_class = self.note.getPitchClass();
        const other_pitch_class = other.note.getPitchClass();

        return (other_octave * constants.pitch_classes + other_pitch_class) -
            (self_octave * constants.pitch_classes + self_pitch_class);
    }

    /// Formats the Pitch for output.
    ///
    /// Outputs the note followed by the octave number (e.g., "A4" for A in the 4th octave).
    pub fn format(
        self: Pitch,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try self.note.format(fmt, options, writer);
        try writer.print("{d}", .{self.octave});
    }
};

test "creation from frequencies" {
    const epsilon = 0.01;
    const test_cases = .{
        .{ 440.0, Pitch{ .note = Note.a, .octave = 4 } },
        .{ 261.63, Pitch{ .note = Note.c, .octave = 4 } },
        .{ 329.63, Pitch{ .note = Note.e, .octave = 4 } },
        .{ 880.0, Pitch{ .note = Note.a, .octave = 5 } },
        .{ 220.0, Pitch{ .note = Note.a, .octave = 3 } },
        .{ 27.5, Pitch{ .note = Note.a, .octave = 0 } }, // A0, lowest piano key
        .{ 4186.01, Pitch{ .note = Note.c, .octave = 8 } }, // C8, highest piano key
        .{ 8.18, Pitch{ .note = Note.c, .octave = -1 } }, // C-1, below MIDI range
        .{ 31608.53, Pitch{ .note = Note.b, .octave = 10 } }, // B10, above MIDI range
    };

    inline for (test_cases) |case| {
        const result = Pitch.fromFrequency(case[0]);
        try testing.expectEqual(case[1].note, result.note);
        try testing.expectEqual(case[1].octave, result.octave);
        try testing.expectApproxEqAbs(case[0], result.getFrequency(), epsilon);
    }
}

test "valid string formats" {
    const test_cases = .{
        .{ "C-2", Pitch{ .note = Note.c, .octave = -2 } },
        .{ "A0", Pitch{ .note = Note.a, .octave = 0 } },
        .{ "C4", Pitch{ .note = Note.c, .octave = 4 } },
        .{ "C♯4", Pitch{ .note = Note.c.sharp(), .octave = 4 } },
        .{ "A4", Pitch{ .note = Note.a, .octave = 4 } },
        .{ "C8", Pitch{ .note = Note.c, .octave = 8 } },
        .{ "C10", Pitch{ .note = Note.c, .octave = 10 } },
    };

    inline for (test_cases) |case| {
        const result = try Pitch.fromString(case[0]);
        try testing.expectEqual(case[1], result);
    }
}

test "invalid string formats" {
    const test_cases = .{
        .{ "C", error.InvalidStringFormat },
        .{ "4", error.InvalidStringFormat },
        .{ "H4", error.InvalidLetter },
        .{ "Cy4", error.InvalidAccidental },
        .{ "C-3", error.OctaveOutOfRange },
        .{ "C11", error.OctaveOutOfRange },
    };

    inline for (test_cases) |case| {
        try testing.expectError(case[1], Pitch.fromString(case[0]));
    }
}

test "string roundtrip consistency" {
    const test_cases = .{ "C-2", "A0", "C4", "C♯4", "F♭3", "G𝄫2", "E𝄪6" };

    inline for (test_cases) |input| {
        const pitch = try Pitch.fromString(input);
        try testing.expectFmt(input, "{}", .{pitch});
    }
}

test "frequency calculations" {
    const epsilon = 0.001;
    const test_cases = .{
        .{ Pitch{ .note = Note.a, .octave = 4 }, 440.0 },
        .{ Pitch{ .note = Note.c, .octave = 4 }, 261.626 },
        .{ Pitch{ .note = Note.b, .octave = 3 }, 246.942 },
        .{ Pitch{ .note = Note.c.flat(), .octave = 4 }, 246.942 },
    };

    inline for (test_cases) |case| {
        try testing.expectApproxEqAbs(case[0].getFrequency(), case[1], epsilon);
    }
}

test "MIDI number conversions" {
    const test_cases = .{
        .{ Pitch{ .note = Note.a, .octave = 4 }, 69 },
        .{ Pitch{ .note = Note.c, .octave = 4 }, 60 },
        .{ Pitch{ .note = Note.c, .octave = -1 }, 0 },
        .{ Pitch{ .note = Note.g, .octave = 9 }, 127 },
        .{ Pitch{ .note = Note.b, .octave = 3 }, 59 },
        .{ Pitch{ .note = Note.c.flat(), .octave = 4 }, 59 },
        .{ Pitch{ .note = Note.c.doubleFlat(), .octave = 4 }, 58 },
        .{ Pitch{ .note = Note.a.sharp(), .octave = 3 }, 58 },
    };

    inline for (test_cases) |case| {
        try testing.expectEqual(try case[0].toMidiNumber(), case[1]);
    }
}

test "negative octaves and MIDI range boundaries" {
    const test_cases = .{
        .{ Pitch{ .note = Note.c, .octave = -1 }, 0, false },
        .{ Pitch{ .note = Note.c.flat(), .octave = -1 }, 0, true },
        .{ Pitch{ .note = Note.b, .octave = -1 }, 11, false },
        .{ Pitch{ .note = Note.b.sharp(), .octave = -2 }, 0, false },
        .{ Pitch{ .note = Note.c.sharp(), .octave = -1 }, 1, false },
        .{ Pitch{ .note = Note.g, .octave = 9 }, 127, false },
        .{ Pitch{ .note = Note.g.sharp(), .octave = 9 }, 0, true },
        .{ Pitch{ .note = Note.a, .octave = 9 }, 0, true },
    };

    inline for (test_cases) |case| {
        if (case[2]) {
            try testing.expectError(error.OutOfMidiRange, case[0].toMidiNumber());
        } else {
            try testing.expectEqual(try case[0].toMidiNumber(), case[1]);
        }
    }
}

test "MIDI number roundtrip consistency" {
    for (0..128) |midi_number| {
        const pitch = Pitch.fromMidiNumber(@as(u7, @intCast(midi_number)));
        try testing.expectEqual(midi_number, try pitch.toMidiNumber());
    }
}

test "enharmonic spelling" {
    const test_cases = .{
        .{ "C#4", Note.Accidental.flat, "Db4" },
        .{ "Eb3", Note.Accidental.sharp, "D#3" },
        .{ "B4", Note.Accidental.flat, "Cb5" },
        .{ "C4", Note.Accidental.sharp, "B#3" },
        .{ "F#2", Note.Accidental.flat, "Gb2" },
        .{ "Ab5", Note.Accidental.sharp, "G#5" },
    };

    inline for (test_cases) |case| {
        const input = Pitch.fromString(case[0]) catch unreachable;
        const expected = Pitch.fromString(case[2]) catch unreachable;
        const result = input.toEnharmonic(case[1]);
        log.debug("Input: {s} ({}), Desired: {}, Result: {}, Expected: {s} ({})", .{ case[0], input, case[1], result, case[2], expected });
        try testing.expectEqual(expected, result);
    }
}

test "enharmonic equivalence" {
    const test_cases = .{
        .{
            Pitch{ .note = Note.c, .octave = 4 },
            Pitch{ .note = Note.b.sharp(), .octave = 3 },
            true,
        },
        .{
            Pitch{ .note = Note.d.flat(), .octave = 4 },
            Pitch{ .note = Note.c.sharp(), .octave = 4 },
            true,
        },
        .{
            Pitch{ .note = Note.e.doubleFlat(), .octave = 4 },
            Pitch{ .note = Note.d, .octave = 4 },
            true,
        },
        .{
            Pitch{ .note = Note.d.flat(), .octave = 4 },
            Pitch{ .note = Note.e.doubleFlat(), .octave = 4 },
            false,
        },
        .{
            Pitch{ .note = Note.c, .octave = 4 },
            Pitch{ .note = Note.d.flat(), .octave = 4 },
            false,
        },
    };

    inline for (test_cases) |case| {
        try testing.expectEqual(case[0].isEnharmonic(case[1]), case[2]);
    }
}
