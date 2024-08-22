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
// On the low side, B#-2 has an effective octave of -1 and would be MIDI number 0.
// On the high side, octave 10 gets us above the typical 20k Hz hearing range.
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
        const octave = try std.fmt.parseInt(i8, octave_str, 10);

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
        const semitones_from_ref: f64 = @floatFromInt(self.semitonesFrom(ref_pitch));
        const ratio = semitones_from_ref / constants.pitch_classes;
        return ref_freq * @exp2(ratio);
    }

    pub fn getEffectiveOctave(self: Pitch) i8 {
        var octave_offset: i8 = 0;

        if (self.note.accidental) |acc| {
            octave_offset += switch (acc) {
                .flat, .double_flat => if (self.note.letter == .c) -1 else 0,
                .sharp, .double_sharp => if (self.note.letter == .b) 1 else 0,
                .natural => 0,
            };
        }

        return self.octave + octave_offset;
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

    pub fn isEnharmonic(self: Pitch, other: Pitch) bool {
        const same_octave = self.getEffectiveOctave() == other.getEffectiveOctave();
        const same_pitch_class = self.note.getPitchClass() == other.note.getPitchClass();

        return same_octave and same_pitch_class;
    }

    pub fn semitonesFrom(self: Pitch, other: Pitch) i16 {
        const self_effective_octave: i16 = @intCast(self.getEffectiveOctave());
        const other_effective_octave: i16 = @intCast(other.getEffectiveOctave());
        const self_pitch_class: i16 = @intCast(self.note.getPitchClass());
        const other_pitch_class: i16 = @intCast(other.note.getPitchClass());

        return (self_effective_octave * constants.pitch_classes + self_pitch_class) -
            (other_effective_octave * constants.pitch_classes + other_pitch_class);
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

pub const PitchError = error{
    InvalidStringFormat,
    OctaveOutOfRange,
    OutOfMidiRange,
};

test "valid string formats" {
    const test_cases = .{
        .{ "C-2", Pitch{ .note = .{ .letter = .c, .accidental = null }, .octave = -2 } },
        .{ "A0", Pitch{ .note = .{ .letter = .a, .accidental = null }, .octave = 0 } },
        .{ "C4", Pitch{ .note = .{ .letter = .c, .accidental = null }, .octave = 4 } },
        .{ "C♯4", Pitch{ .note = .{ .letter = .c, .accidental = .sharp }, .octave = 4 } },
        .{ "A4", Pitch{ .note = .{ .letter = .a, .accidental = null }, .octave = 4 } },
        .{ "C8", Pitch{ .note = .{ .letter = .c, .accidental = null }, .octave = 8 } },
        .{ "C10", Pitch{ .note = .{ .letter = .c, .accidental = null }, .octave = 10 } },
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
        .{ Pitch{ .note = .{ .letter = .a, .accidental = null }, .octave = 4 }, 440.0 },
        .{ Pitch{ .note = .{ .letter = .c, .accidental = null }, .octave = 4 }, 261.626 },
        .{ Pitch{ .note = .{ .letter = .b, .accidental = null }, .octave = 3 }, 246.942 },
        .{ Pitch{ .note = .{ .letter = .c, .accidental = .flat }, .octave = 4 }, 246.942 },
    };

    inline for (test_cases) |case| {
        try testing.expectApproxEqAbs(case[0].getFrequency(), case[1], epsilon);
    }
}

test "MIDI number conversions" {
    const test_cases = .{
        .{ Pitch{ .note = .{ .letter = .a, .accidental = null }, .octave = 4 }, 69 },
        .{ Pitch{ .note = .{ .letter = .c, .accidental = null }, .octave = 4 }, 60 },
        .{ Pitch{ .note = .{ .letter = .c, .accidental = null }, .octave = -1 }, 0 },
        .{ Pitch{ .note = .{ .letter = .g, .accidental = null }, .octave = 9 }, 127 },
        .{ Pitch{ .note = .{ .letter = .b, .accidental = null }, .octave = 3 }, 59 },
        .{ Pitch{ .note = .{ .letter = .c, .accidental = .flat }, .octave = 4 }, 59 },
        .{ Pitch{ .note = .{ .letter = .c, .accidental = .double_flat }, .octave = 4 }, 58 },
        .{ Pitch{ .note = .{ .letter = .a, .accidental = .sharp }, .octave = 3 }, 58 },
    };

    inline for (test_cases) |case| {
        try testing.expectEqual(try case[0].toMidiNumber(), case[1]);
    }
}

test "negative octaves and MIDI range boundaries" {
    const test_cases = .{
        .{ Pitch{ .note = .{ .letter = .c, .accidental = null }, .octave = -1 }, 0, false },
        .{ Pitch{ .note = .{ .letter = .c, .accidental = .flat }, .octave = -1 }, 0, true },
        .{ Pitch{ .note = .{ .letter = .b, .accidental = null }, .octave = -1 }, 11, false },
        .{ Pitch{ .note = .{ .letter = .b, .accidental = .sharp }, .octave = -2 }, 0, false },
        .{ Pitch{ .note = .{ .letter = .c, .accidental = .sharp }, .octave = -1 }, 1, false },
        .{ Pitch{ .note = .{ .letter = .g, .accidental = null }, .octave = 9 }, 127, false },
        .{ Pitch{ .note = .{ .letter = .g, .accidental = .sharp }, .octave = 9 }, 0, true },
        .{ Pitch{ .note = .{ .letter = .a, .accidental = null }, .octave = 9 }, 0, true },
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
            Pitch{ .note = .{ .letter = .c, .accidental = null }, .octave = 4 },
            Pitch{ .note = .{ .letter = .b, .accidental = .sharp }, .octave = 3 },
            true,
        },
        .{
            Pitch{ .note = .{ .letter = .d, .accidental = .flat }, .octave = 4 },
            Pitch{ .note = .{ .letter = .c, .accidental = .sharp }, .octave = 4 },
            true,
        },
        .{
            Pitch{ .note = .{ .letter = .e, .accidental = .double_flat }, .octave = 4 },
            Pitch{ .note = .{ .letter = .d, .accidental = null }, .octave = 4 },
            true,
        },
        .{
            Pitch{ .note = .{ .letter = .d, .accidental = .flat }, .octave = 4 },
            Pitch{ .note = .{ .letter = .e, .accidental = .double_flat }, .octave = 4 },
            false,
        },
        .{
            Pitch{ .note = .{ .letter = .c, .accidental = null }, .octave = 4 },
            Pitch{ .note = .{ .letter = .d, .accidental = .flat }, .octave = 4 },
            false,
        },
    };

    inline for (test_cases) |case| {
        try testing.expectEqual(case[0].isEnharmonic(case[1]), case[2]);
    }
}
