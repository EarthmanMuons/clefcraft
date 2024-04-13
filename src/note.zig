const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.note);

const Interval = @import("interval.zig").Interval;
const constants = @import("constants.zig");
const utils = @import("utils.zig");

const notes_per_diatonic_scale = constants.notes_per_diatonic_scale;
const semitones_per_octave = constants.semitones_per_octave;

// The international standard pitch, A440.
const standard_pitch = Pitch{ .letter = .A, .accidental = null };
const standard_note = Note{ .pitch = standard_pitch, .octave = 4 };
const standard_freq = 440.0; // hertz

pub const Note = struct {
    pitch: Pitch,
    octave: i32,

    // Creates a note from a string representation.
    pub fn parse(chars: []const u8) !Note {
        if (chars.len < 2) return error.InvalidNoteFormat;

        const first_char = std.ascii.toUpper(chars[0]);
        const letter = switch (first_char) {
            'A' => Letter.A,
            'B' => Letter.B,
            'C' => Letter.C,
            'D' => Letter.D,
            'E' => Letter.E,
            'F' => Letter.F,
            'G' => Letter.G,
            else => return error.InvalidLetter,
        };

        var accidental: ?Accidental = null;
        var octave_idx: usize = 1;
        if (chars.len > 2) {
            accidental = switch (chars[1]) {
                'b' => Accidental.Flat,
                'n' => Accidental.Natural,
                '#' => Accidental.Sharp,
                'x' => Accidental.DoubleSharp,
                else => null,
            };
            if (accidental != null) octave_idx += 1;
        }
        if (chars.len > 3) {
            if (chars[1] == 'b' and chars[2] == 'b') {
                accidental = Accidental.DoubleFlat;
                octave_idx += 1;
            } else if (chars[1] == '#' and chars[2] == '#') {
                accidental = Accidental.DoubleSharp;
                octave_idx += 1;
            }
        }
        const octave_str = chars[octave_idx..];
        const octave = std.fmt.parseInt(i32, octave_str, 10) catch return error.InvalidOctave;

        const pitch = Pitch{ .letter = letter, .accidental = accidental };
        return Note{ .pitch = pitch, .octave = octave };
    }

    // Returns the pitch class of the note.
    pub fn pitchClass(self: Note) i32 {
        return self.pitch.pitchClass();
    }

    // Returns the effective octave of the note, considering accidentals.
    pub fn effectiveOctave(self: Note) i32 {
        var octave_adjustment: i32 = 0;

        if (self.pitch.accidental) |acc| {
            octave_adjustment += switch (acc) {
                .Flat, .DoubleFlat => if (self.pitch.letter == .C) -1 else 0,
                .Sharp, .DoubleSharp => if (self.pitch.letter == .B) 1 else 0,
                else => 0,
            };
        }

        return self.octave + octave_adjustment;
    }

    // Returns the frequency of the note in Hz, using twelve-tone equal temperament (12-TET)
    // and the A440 standard pitch as the reference note.
    pub fn frequency(self: Note) f64 {
        return self.frequencyWithRef(standard_note, standard_freq);
    }

    // Returns the frequency of the note in Hz, using twelve-tone equal temperament (12-TET)
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

        const semitone_delta_raw = @log2(freq / ref_freq) * semitones_per_octave;
        const semitone_delta = @as(i32, @intFromFloat(@round(semitone_delta_raw)));

        const ref_pos = (ref_note.effectiveOctave() * semitones_per_octave) + ref_note.pitchClass();
        const target_pos = ref_pos + semitone_delta;

        const pitch_class = utils.wrap(target_pos, semitones_per_octave);
        const octave = @divTrunc(target_pos, semitones_per_octave);

        const pitch = Pitch.fromPitchClass(pitch_class);
        return Note{ .pitch = pitch, .octave = octave };
    }

    // Returns the MIDI note number of the note.
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

        const pitch = Pitch.fromPitchClass(pitch_class);
        return Note{ .pitch = pitch, .octave = octave };
    }

    // Returns if two notes are enharmonically equivalent.
    pub fn isEnharmonic(self: Note, other: Note) bool {
        const same_octave = self.effectiveOctave() == other.effectiveOctave();
        const same_pitch_class = self.pitchClass() == other.pitchClass();

        return same_octave and same_pitch_class;
    }

    // Returns the difference in octaves between two notes, which can be negative.
    pub fn octaveDifference(self: Note, other: Note) i32 {
        return other.effectiveOctave() - self.effectiveOctave();
    }

    // Returns the difference in semitones between two notes, which can be negative.
    pub fn semitoneDifference(self: Note, other: Note) i32 {
        const octave_diff = self.octaveDifference(other);
        // TODO: does this need to wrap (i.e. pitch_dist)?
        const pitch_diff = other.pitchClass() - self.pitchClass();

        return (octave_diff * semitones_per_octave) + pitch_diff;
    }

    // Returns the non-negative distance between two notes based on the diatonic scale.
    pub fn diatonicDistance(self: Note, other: Note) i32 {
        const start = @intFromEnum(self.pitch.letter);
        const end = @intFromEnum(other.pitch.letter);
        const difference = @as(i32, @intCast(end)) - @as(i32, @intCast(start));

        return utils.wrap(difference, notes_per_diatonic_scale);
    }

    // Applies the given interval to the current note an returns the resulting note.
    pub fn applyInterval(self: Note, interval: Interval) !Note {
        const semitones: i32 = switch (interval.number) {
            .Unison => 0,
            .Second => 2,
            .Third => 4,
            .Fourth => 5,
            .Fifth => 7,
            .Sixth => 9,
            .Seventh => 11,
            .Octave => 12,
        };

        const adjusted_semitones = switch (interval.quality) {
            .Perfect => semitones,
            .Major => semitones,
            .Minor => semitones - 1,
            .Augmented => semitones + 1,
            .Diminished => semitones - 1,
        };

        const target_pitch_class = @mod(self.pitchClass() + adjusted_semitones, 12);
        const target_pitch = Pitch.fromPitchClass(target_pitch_class);

        const octave_adjustment = @divFloor(self.pitchClass() + adjusted_semitones, 12);
        const target_octave = self.octave + octave_adjustment;

        return Note{ .pitch = target_pitch, .octave = target_octave };
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

pub const Pitch = struct {
    letter: Letter,
    accidental: ?Accidental,

    // Creates a pitch from a pitch class.
    pub fn fromPitchClass(pitch_class: i32) Pitch {
        assert(0 <= pitch_class and pitch_class < semitones_per_octave);

        // Mapping of a pitch class to its default pitch.
        // 0:C, 1:C♯, 2:D, 3:D♯, 4:E, 5:F, 6:F♯, 7:G, 8:G♯, 9:A, 10:A♯, 11:B
        const mapping = [_]Pitch{
            Pitch{ .letter = .C, .accidental = null },
            Pitch{ .letter = .C, .accidental = Accidental.Sharp },
            Pitch{ .letter = .D, .accidental = null },
            Pitch{ .letter = .D, .accidental = Accidental.Sharp },
            Pitch{ .letter = .E, .accidental = null },
            Pitch{ .letter = .F, .accidental = null },
            Pitch{ .letter = .F, .accidental = Accidental.Sharp },
            Pitch{ .letter = .G, .accidental = null },
            Pitch{ .letter = .G, .accidental = Accidental.Sharp },
            Pitch{ .letter = .A, .accidental = null },
            Pitch{ .letter = .A, .accidental = Accidental.Sharp },
            Pitch{ .letter = .B, .accidental = null },
        };

        return mapping[@intCast(pitch_class)];
    }

    // Returns the pitch class of the pitch.
    pub fn pitchClass(self: Pitch) i32 {
        const base_pitch_class = self.letter.pitchClass();
        const adjustment = if (self.accidental) |acc| acc.pitchAdjustment() else 0;

        return utils.wrap(base_pitch_class + adjustment, semitones_per_octave);
    }

    // Formats the pitch as a string.
    pub fn format(
        self: Pitch,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try self.letter.format(fmt, options, writer);
        if (self.accidental) |acc| {
            try acc.format(fmt, options, writer);
        }
    }
};

pub const Letter = enum {
    A,
    B,
    C,
    D,
    E,
    F,
    G,

    // Returns the pitch class for the note letter.
    pub fn pitchClass(self: Letter) i32 {
        return switch (self) {
            .C => 0,
            .D => 2,
            .E => 4,
            .F => 5,
            .G => 7,
            .A => 9,
            .B => 11,
        };
    }

    // Formats the note letter as a string.
    pub fn format(
        self: Letter,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        const letter = switch (self) {
            .A => "A",
            .B => "B",
            .C => "C",
            .D => "D",
            .E => "E",
            .F => "F",
            .G => "G",
        };
        try writer.print("{s}", .{letter});
    }
};

pub const Accidental = enum {
    DoubleFlat,
    Flat,
    Natural,
    Sharp,
    DoubleSharp,

    // Returns the pitch class adjustment for the accidental.
    pub fn pitchAdjustment(self: Accidental) i32 {
        return switch (self) {
            .DoubleFlat => -2,
            .Flat => -1,
            .Natural => 0,
            .Sharp => 1,
            .DoubleSharp => 2,
        };
    }

    // Formats the accidental as a string.
    pub fn format(
        self: Accidental,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        const symbol = switch (self) {
            .DoubleFlat => "𝄫",
            .Flat => "♭",
            .Natural => "♮",
            .Sharp => "♯",
            .DoubleSharp => "𝄪",
        };
        try writer.print("{s}", .{symbol});
    }
};

test "parse note without accidental" {
    const note = try Note.parse("C4");
    try std.testing.expectEqual(Letter.C, note.pitch.letter);
    try std.testing.expectEqual(null, note.pitch.accidental);
    try std.testing.expectEqual(4, note.octave);
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
            const fmt = "\nTest case: {}, expected {d:.3}, found {d:.3}\n";
            std.debug.print(fmt, .{ note, test_case.expected, result });
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
            std.debug.print("\nTest case: {}, ", .{n1});
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

test "semitone difference" {
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
            const fmt = "\nTest case: from {s} to {s}\n";
            std.debug.print(fmt, .{ n1, n2 });
        }
        try std.testing.expectEqual(test_case.expected, result);
    }
}

test "apply interval" {
    std.testing.log_level = .debug;

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
            const fmt = "\nTest case: {s} with {s} applied, result: {}\n";
            std.debug.print(fmt, .{ note, interval, result });
        }
        try std.testing.expectEqual(expected, result);
    }
}
