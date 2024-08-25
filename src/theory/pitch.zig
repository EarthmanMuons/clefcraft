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
pub const min_octave: i16 = -2;
pub const max_octave: i16 = 10;

// Musical pitch representation using Scientific Pitch Notation.
pub const Pitch = struct {
    note: Note,
    octave: i16,

    pub fn fromFrequency(freq: f64) Pitch {
        return fromFrequencyWithReference(freq, standard_pitch, standard_freq);
    }

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

    pub fn fromMidiNumber(midi_number: u7) Pitch {
        const semitones_from_c0 = @as(i16, midi_number) - constants.pitch_classes;
        const octave = @divFloor(semitones_from_c0, constants.pitch_classes);
        const pitch_class = @mod(semitones_from_c0, constants.pitch_classes);

        const note = Note.fromPitchClass(@intCast(pitch_class));
        return .{ .note = note, .octave = @intCast(octave) };
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
        const octave = try std.fmt.parseInt(i16, octave_str, 10);

        if (octave < min_octave or max_octave < octave) {
            return error.OctaveOutOfRange;
        }

        return .{ .note = note, .octave = octave };
    }

    // pub fn transpose(self: Pitch, semitones: i8) Pitch {}

    pub fn getFrequency(self: Pitch) f64 {
        return self.getFrequencyWithReference(standard_pitch, standard_freq);
    }

    pub fn getFrequencyWithReference(self: Pitch, ref_pitch: Pitch, ref_freq: f64) f64 {
        const semitones_from_ref: f64 = @floatFromInt(ref_pitch.semitonesTo(self));
        const octave_ratio = semitones_from_ref / constants.pitch_classes;
        return ref_freq * @exp2(octave_ratio);
    }

    pub fn getEffectiveOctave(self: Pitch) i16 {
        var offset: i16 = 0;
        if (self.note.accidental) |acc| {
            offset += switch (acc) {
                .flat, .double_flat => if (self.note.letter == .c) -1 else 0,
                .sharp, .double_sharp => if (self.note.letter == .b) 1 else 0,
                .natural => 0,
            };
        }
        return self.octave + offset;
    }

    pub fn toMidiNumber(self: Pitch) !u7 {
        const midi_zero_pitch = Pitch{ .note = Note.c, .octave = -1 };
        const semitones_above_midi_zero = midi_zero_pitch.semitonesTo(self);

        if (semitones_above_midi_zero < 0 or 127 < semitones_above_midi_zero) {
            return error.OutOfMidiRange;
        }

        return @intCast(semitones_above_midi_zero);
    }

    pub fn isEnharmonic(self: Pitch, other: Pitch) bool {
        const same_octave = self.getEffectiveOctave() == other.getEffectiveOctave();
        const same_pitch_class = self.note.getPitchClass() == other.note.getPitchClass();

        return same_octave and same_pitch_class;
    }

    pub fn diatonicStepsTo(self: Pitch, other: Pitch) i16 {
        const self_letter = @intFromEnum(self.note.letter);
        const other_letter = @intFromEnum(other.note.letter);
        const octave_diff = other.octave - self.octave;

        return (other_letter - self_letter) + (octave_diff * constants.diatonic_degrees) + 1;
    }

    pub fn octavesTo(self: Pitch, other: Pitch) i16 {
        return other.getEffectiveOctave() - self.getEffectiveOctave();
    }

    pub fn semitonesTo(self: Pitch, other: Pitch) i16 {
        const self_octave = self.getEffectiveOctave();
        const other_octave = other.getEffectiveOctave();
        const self_pitch_class = self.note.getPitchClass();
        const other_pitch_class = other.note.getPitchClass();

        return (other_octave * constants.pitch_classes + other_pitch_class) -
            (self_octave * constants.pitch_classes + self_pitch_class);
    }

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
    const test_cases = .{ "C-2", "A0", "C4", "C♯4", "F♭3", "B♮7", "G𝄫2", "E𝄪6" };

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
