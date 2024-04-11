const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.note);

// The international standard pitch, A440.
const reference_pitch = Pitch{ .letter = .A, .accidental = null };
const reference_note = Note{ .pitch = reference_pitch, .octave = 4 };
const reference_frequency = 440.0; // hertz

const semitones_per_octave = 12;

pub const Letter = enum {
    A,
    B,
    C,
    D,
    E,
    F,
    G,

    // Returns the pitch class value for the Letter.
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

    pub fn format(self: Letter, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
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

    // Returns the pitch class adjustment for the Accidental.
    pub fn pitchClassAdjustment(self: Accidental) i32 {
        return switch (self) {
            .DoubleFlat => -2,
            .Flat => -1,
            .Natural => 0,
            .Sharp => 1,
            .DoubleSharp => 2,
        };
    }

    pub fn format(self: Accidental, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
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

pub const Pitch = struct {
    letter: Letter,
    accidental: ?Accidental,

    // Creates a Pitch from a pitch class.
    pub fn new(pitch_class: u8) Pitch {
        assert(pitch_class < semitones_per_octave);

        // Mapping of a pitch class to its default Pitch.
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

        return mapping[pitch_class];
    }

    // Returns the pitch class of the Pitch.
    pub fn pitchClass(self: Pitch) i32 {
        const base_pc = self.letter.pitchClass();
        const adjustment = if (self.accidental) |acc| acc.pitchClassAdjustment() else 0;

        return wrapPitchClass(base_pc + adjustment);
    }

    // Returns the circle of fifths position of the Pitch.
    pub fn fifthsPosition(self: Pitch) i32 {
        // Base position for natural notes in the circle of fifths.
        const base_position: i32 = switch (self.letter) {
            .C => 0,
            .G => 1,
            .D => 2,
            .A => 3,
            .E => 4,
            .B => 5,
            .F => -1,
        };

        var position = base_position;
        if (self.accidental) |acc| {
            position += switch (acc) {
                .DoubleFlat => -14,
                .Flat => -7,
                .Natural => 0,
                .Sharp => 7,
                .DoubleSharp => 14,
            };
        }

        assert(-15 <= position and position <= 19);
        return position;
    }

    // Creates a Pitch from a circle of fifths position.
    fn fromFifthsPosition(position: i32) Pitch {
        assert(-15 <= position and position <= 19);

        // Mapping of a circle of fifths position to its Pitch.
        const mapping = [_]Pitch{
            Pitch{ .letter = .F, .accidental = .DoubleFlat }, // -15
            Pitch{ .letter = .C, .accidental = .DoubleFlat }, // -14
            Pitch{ .letter = .G, .accidental = .DoubleFlat }, // -13
            Pitch{ .letter = .D, .accidental = .DoubleFlat }, // -12
            Pitch{ .letter = .A, .accidental = .DoubleFlat }, // -11
            Pitch{ .letter = .E, .accidental = .DoubleFlat }, // -10
            Pitch{ .letter = .B, .accidental = .DoubleFlat }, // -9
            Pitch{ .letter = .F, .accidental = .Flat }, // -8
            Pitch{ .letter = .C, .accidental = .Flat }, // -7
            Pitch{ .letter = .G, .accidental = .Flat }, // -6
            Pitch{ .letter = .D, .accidental = .Flat }, // -5
            Pitch{ .letter = .A, .accidental = .Flat }, // -4
            Pitch{ .letter = .E, .accidental = .Flat }, // -3
            Pitch{ .letter = .B, .accidental = .Flat }, // -2
            Pitch{ .letter = .F, .accidental = null }, // -1
            Pitch{ .letter = .C, .accidental = null }, // 0
            Pitch{ .letter = .G, .accidental = null }, // 1
            Pitch{ .letter = .D, .accidental = null }, // 2
            Pitch{ .letter = .A, .accidental = null }, // 3
            Pitch{ .letter = .E, .accidental = null }, // 4
            Pitch{ .letter = .B, .accidental = null }, // 5
            Pitch{ .letter = .F, .accidental = .Sharp }, // 6
            Pitch{ .letter = .C, .accidental = .Sharp }, // 7
            Pitch{ .letter = .G, .accidental = .Sharp }, // 8
            Pitch{ .letter = .D, .accidental = .Sharp }, // 9
            Pitch{ .letter = .A, .accidental = .Sharp }, // 10
            Pitch{ .letter = .E, .accidental = .Sharp }, // 11
            Pitch{ .letter = .B, .accidental = .Sharp }, // 12
            Pitch{ .letter = .F, .accidental = .DoubleSharp }, // 13
            Pitch{ .letter = .C, .accidental = .DoubleSharp }, // 14
            Pitch{ .letter = .G, .accidental = .DoubleSharp }, // 15
            Pitch{ .letter = .D, .accidental = .DoubleSharp }, // 16
            Pitch{ .letter = .A, .accidental = .DoubleSharp }, // 17
            Pitch{ .letter = .E, .accidental = .DoubleSharp }, // 18
            Pitch{ .letter = .B, .accidental = .DoubleSharp }, // 19
        };

        // Adjust the index for negative positions.
        const index = position + 15;

        return mapping[index];
    }

    pub fn format(self: Pitch, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        try self.letter.format(fmt, options, writer);
        if (self.accidental) |acc| {
            try acc.format(fmt, options, writer);
        }
    }
};

// Utility function to wrap pitch class values within the 0-11 range.
fn wrapPitchClass(value: i32) i32 {
    return @mod(value + semitones_per_octave, semitones_per_octave);
}

pub const Note = struct {
    pitch: Pitch,
    octave: i32,

    pub fn parse(chars: []const u8) !Note {
        if (chars.len < 2) return error.InvalidNoteFormat;

        const letter = std.ascii.toUpper(chars[0]);
        const note_letter = switch (letter) {
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
        var octave_start: usize = 1;
        if (chars.len > 2) {
            accidental = switch (chars[1]) {
                'b' => Accidental.Flat,
                'n' => Accidental.Natural,
                '#' => Accidental.Sharp,
                'x' => Accidental.DoubleSharp,
                else => null,
            };
            if (accidental != null) octave_start += 1;
        }
        if (chars.len > 3) {
            if (chars[1] == 'b' and chars[2] == 'b') {
                accidental = Accidental.DoubleFlat;
                octave_start += 1;
            } else if (chars[1] == '#' and chars[2] == '#') {
                accidental = Accidental.DoubleSharp;
                octave_start += 1;
            }
        }
        const octave_str = chars[octave_start..];
        const octave = std.fmt.parseInt(i32, octave_str, 10) catch return error.InvalidOctave;

        const pitch = Pitch{ .letter = note_letter, .accidental = accidental };
        return Note{ .pitch = pitch, .octave = octave };
    }

    // Returns the pitch class value of the Note.
    pub fn pitchClass(self: Note) i32 {
        return self.pitch.pitchClass();
    }

    // Returns the effective octave of the Note, considering pitch and accidentals.
    pub fn effectiveOctave(self: Note) i32 {
        var adjustment: i32 = 0;

        if (self.pitch.accidental) |acc| {
            switch (acc) {
                .Flat, .DoubleFlat => {
                    if (self.pitch.letter == .C) {
                        adjustment -= 1;
                    }
                },
                .Sharp, .DoubleSharp => {
                    if (self.pitch.letter == .B) {
                        adjustment += 1;
                    }
                },
                else => {},
            }
        }

        return self.octave + adjustment;
    }

    pub fn semitoneDistance(self: Note, other: Note) i32 {
        const octave_distance =
            (other.effectiveOctave() - self.effectiveOctave()) * semitones_per_octave;
        const pitch_distance = other.pitch.pitchClass() - self.pitch.pitchClass();

        return octave_distance + pitch_distance;
    }

    // Returns the frequency of the Note in Hz, using twelve-tone equal temperament (12-TET).
    pub fn freq(self: Note) f64 {
        const semitones_from_ref = reference_note.semitoneDistance(self);
        const semitone_distance_ratio =
            @as(f64, @floatFromInt(semitones_from_ref)) /
            @as(f64, @floatFromInt(semitones_per_octave));

        return reference_frequency * @exp2(semitone_distance_ratio);
    }

    // Creates a Note from a frequency in Hz, using twelve-tone equal temperament (12-TET).
    pub fn fromFreq(frequency: f64) Note {
        assert(frequency > 0);

        const semitones_from_ref_raw =
            @log2(frequency / reference_frequency) * semitones_per_octave;
        const semitones_from_ref = @as(i32, @intFromFloat(@round(semitones_from_ref_raw)));

        const refnote_absolute_position =
            reference_note.pitchClass() + (reference_note.octave * semitones_per_octave);
        const target_absolute_position = semitones_from_ref + refnote_absolute_position;

        const pitch_class = wrapPitchClass(target_absolute_position);
        const octave = @divTrunc(target_absolute_position, semitones_per_octave);

        const pitch = Pitch.new(@intCast(pitch_class));
        return Note{ .pitch = pitch, .octave = octave };
    }

    // Returns the MIDI note number of the Note.
    pub fn midi(self: Note) i32 {
        const octave_offset = (self.effectiveOctave() + 1) * semitones_per_octave;
        const midi_note = octave_offset + self.pitchClass();

        assert(0 <= midi_note and midi_note <= 127);
        return midi_note;
    }

    // Creates a Note from a MIDI note number.
    pub fn fromMidi(midi_note: i32) Note {
        const pitch_class = @mod(midi_note, semitones_per_octave);
        const octave = @divTrunc(midi_note, semitones_per_octave) - 1;

        const pitch = Pitch.new(@intCast(pitch_class));
        return Note{ .pitch = pitch, .octave = octave };
    }

    pub fn format(self: Note, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        try self.pitch.format(fmt, options, writer);
        try writer.print("{d}", .{self.octave});
    }
};

test "parse basic note without accidental" {
    const note = try Note.parse("C4");
    try std.testing.expectEqual(Letter.C, note.pitch.letter);
    try std.testing.expectEqual(null, note.pitch.accidental);
    try std.testing.expectEqual(4, note.octave);
}

test "semitoneDistance" {
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
        const result = n1.semitoneDistance(n2);

        if (test_case.expected != result) {
            std.debug.print("\nTest case: from {s} to {s}, ", .{ n1, n2 });
        }
        try std.testing.expectEqual(test_case.expected, result);
    }
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
        const result = note.freq();

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
    try std.testing.expectEqual(expected, Note.fromFreq(8.176));
    expected = try Note.parse("C0");
    try std.testing.expectEqual(expected, Note.fromFreq(16.352));
    expected = try Note.parse("A0");
    try std.testing.expectEqual(expected, Note.fromFreq(27.5));
    expected = try Note.parse("C4");
    try std.testing.expectEqual(expected, Note.fromFreq(261.626));
    expected = try Note.parse("A4");
    try std.testing.expectEqual(expected, Note.fromFreq(440.0));
    expected = try Note.parse("C8");
    try std.testing.expectEqual(expected, Note.fromFreq(4186.009));
    expected = try Note.parse("B8");
    try std.testing.expectEqual(expected, Note.fromFreq(7902.133));
    expected = try Note.parse("G9");
    try std.testing.expectEqual(expected, Note.fromFreq(12543.854));
}

test "midi note calculation" {
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

test "create from midi note" {
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
