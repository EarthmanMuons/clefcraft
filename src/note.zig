const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.note);
const testing = std.testing;

// The international standard pitch (A4 at 440 Hz).
const reference_pitch_class = 9;
const reference_octave = 4;
const reference_frequency = 440.0;

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
    pub fn adjustment(self: Accidental) i32 {
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
        assert(pitch_class < 12);

        // Mapping of pitch class numbers to default Letters and Accidentals.
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

    // Returns the pitch class value of the Pitch.
    pub fn pitchClass(self: Pitch) i32 {
        const base_pc = self.letter.pitchClass();
        const adjustment = if (self.accidental) |acc| acc.adjustment() else 0;
        return wrapPitchClass(base_pc + adjustment);
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
    return @mod(value + 12, 12);
}

pub const Note = struct {
    pitch: Pitch,
    octave: i32,

    pub fn parse(chars: []const u8) !Note {
        if (chars.len < 2) return error.InvalidNoteFormat;

        // Parse the note letter.
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

        // Check for and parse any accidentals.
        var accidental: ?Accidental = null;
        var octave_start: usize = 1;

        if (chars.len > 2) {
            accidental = switch (chars[1]) {
                '#' => Accidental.Sharp,
                'b' => Accidental.Flat,
                'n' => Accidental.Natural,
                'x' => Accidental.DoubleSharp,
                else => null,
            };
            if (accidental != null) octave_start += 1;
        }

        if (chars.len > 3) {
            if (chars[1] == '#' and chars[2] == '#') {
                accidental = Accidental.DoubleSharp;
                octave_start += 1;
            } else if (chars[1] == 'b' and chars[2] == 'b') {
                accidental = Accidental.DoubleFlat;
                octave_start += 1;
            }
        }

        // Parse the octave.
        const octave_str = chars[octave_start..];
        const octave = std.fmt.parseInt(i32, octave_str, 10) catch return error.InvalidOctave;

        const pitch = Pitch{ .letter = note_letter, .accidental = accidental };
        const note = Note{ .pitch = pitch, .octave = octave };

        return note;
    }

    // Returns the pitch class value of the Note.
    pub fn pitchClass(self: Note) i32 {
        return self.pitch.pitchClass();
    }

    // Returns the effective octave, considering pitch and accidentals.
    pub fn effectiveOctave(self: Note) i32 {
        var adjustment: i32 = 0;

        if (self.pitch.accidental) |acc| {
            switch (acc) {
                .Flat => {
                    if (self.pitch.letter == .C) {
                        adjustment -= 1;
                    }
                },
                .DoubleFlat => {
                    if (self.pitch.letter == .C) {
                        adjustment -= 1;
                    }
                },
                .Sharp => {
                    if (self.pitch.letter == .B) {
                        adjustment += 1;
                    }
                },
                .DoubleSharp => {
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
        log.debug("semitoneDistance from {} to {}", .{ self, other });

        const octave_distance =
            (other.effectiveOctave() - self.effectiveOctave()) * semitones_per_octave;
        const pitch_distance = other.pitch.pitchClass() - self.pitch.pitchClass();

        log.debug("octave_distance: {}", .{octave_distance});
        log.debug("pitch_distance: {}", .{pitch_distance});

        return octave_distance + pitch_distance;
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
    // std.testing.log_level = .debug;

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
        try std.testing.expectEqual(test_case.expected, result);
    }
}

// pub const Note = struct {
//     pitch_class: u8,
//     octave: i8,

//     pub fn parse(chars: []const u8) !Note {
//         // Parse the pitch class.
//         const pitch_class_base = pitch_map[letter - 'A'];

//         // Parse the octave.
//         const octave_str = chars[octave_start..];
//         var octave = std.fmt.parseInt(i8, octave_str, 10) catch return error.InvalidNoteFormat;

//         // Calculate the final pitch class with accidental.
//         var pitch_class = @as(i8, @intCast(pitch_class_base)) +% accidental;

//         // Handle pitch class wrap-around for octave boundaries.
//         if (pitch_class >= semitones_per_octave) {
//             pitch_class -= semitones_per_octave;
//             octave += 1;
//         } else if (pitch_class < 0) {
//             pitch_class += semitones_per_octave;
//             octave -= 1;
//         }
//     }

//     // Returns the fundamental frequency in Hz using twelve-tone equal temperament (12-TET).
//     pub fn freq(self: Note) f64 {
//         const semitones_from_ref =
//             @as(i32, self.pitch_class) - reference_pitch_class +
//             (semitones_per_octave * (self.octave - reference_octave));

//         const octave_difference =
//             @as(f64, @floatFromInt(semitones_from_ref)) /
//             @as(f64, @floatFromInt(semitones_per_octave));

//         return reference_frequency * @exp2(octave_difference);
//     }

//     pub fn fromFreq(frequency: f64) Note {
//         assert(frequency > 0);

//         const semitones_from_ref =
//             @round(reference_pitch_class +
//             semitones_per_octave * @log2(frequency / reference_frequency));

//         var pitch_class = @mod(semitones_from_ref, semitones_per_octave);
//         if (pitch_class < 0) {
//             pitch_class += semitones_per_octave;
//         }

//         var octave_offset: f64 = undefined;
//         if (semitones_from_ref < 0) {
//             octave_offset = @divFloor(semitones_from_ref, semitones_per_octave);
//         } else {
//             octave_offset = @divTrunc(semitones_from_ref, semitones_per_octave);
//         }

//         const octave = reference_octave + octave_offset;

//         log.debug("", .{});
//         log.debug("frequency: {d}", .{frequency});
//         log.debug("semitones_from_ref: {d}", .{semitones_from_ref});
//         log.debug("pitch_class: {d}", .{pitch_class});
//         log.debug("octave_offset: {d}", .{octave_offset});
//         log.debug("octave: {d}", .{octave});

//         return Note.new(@intFromFloat(pitch_class), @intFromFloat(octave));
//     }

//     // Returns the MIDI note number.
//     pub fn midi(self: Note) u8 {
//         const octave_offset = @as(u8, @intCast(self.octave + 1)) * semitones_per_octave;
//         const midi_note = octave_offset + self.pitch_class;

//         assert(midi_note < 128);
//         return midi_note;
//     }

//     pub fn fromMidi(midi_note: u8) Note {
//         const pitch_class = midi_note % semitones_per_octave;
//         const octave = @as(i8, @intCast(midi_note / semitones_per_octave)) - 1;

//         return Note.new(pitch_class, octave);
//     }
// };

// test "create from string" {
//     try testing.expectEqual(Note.parse("C-1"), Note.new(0, -1));
//     try testing.expectEqual(Note.parse("A4"), Note.new(9, 4));
//     try testing.expectEqual(Note.parse("a4"), Note.new(9, 4));
//     try testing.expectEqual(Note.parse("B9"), Note.new(11, 9));

//     try testing.expectEqual(Note.parse("C4"), Note.new(0, 4));
//     try testing.expectEqual(Note.parse("C#4"), Note.new(1, 4));

//     try testing.expectEqual(Note.parse("B4"), Note.new(11, 4));
//     try testing.expectEqual(Note.parse("Bb4"), Note.new(10, 4));

//     try testing.expectEqual(Note.parse("Cb4"), Note.new(11, 3));
//     try testing.expectEqual(Note.parse("B3"), Note.new(11, 3));

//     try testing.expectEqual(Note.parse("B#4"), Note.new(0, 5));
//     try testing.expectEqual(Note.parse("C5"), Note.new(0, 5));
// }

// test "frequency calculation" {
//     const approxEqAbs = std.math.approxEqAbs;
//     const epsilon = 0.001;

//     try testing.expect(approxEqAbs(f64, Note.new(0, -1).freq(), 8.176, epsilon)); // C-1
//     try testing.expect(approxEqAbs(f64, Note.new(0, 0).freq(), 16.352, epsilon)); // C0
//     try testing.expect(approxEqAbs(f64, Note.new(9, 0).freq(), 27.5, epsilon)); // A0
//     try testing.expect(approxEqAbs(f64, Note.new(0, 4).freq(), 261.626, epsilon)); // C4
//     try testing.expect(approxEqAbs(f64, Note.new(9, 4).freq(), 440.0, epsilon)); // A4
//     try testing.expect(approxEqAbs(f64, Note.new(0, 8).freq(), 4186.009, epsilon)); // C8
//     try testing.expect(approxEqAbs(f64, Note.new(11, 8).freq(), 7902.133, epsilon)); // B8
//     try testing.expect(approxEqAbs(f64, Note.new(7, 9).freq(), 12543.854, epsilon)); // G9
//     try testing.expect(approxEqAbs(f64, Note.new(11, 9).freq(), 15804.266, epsilon)); // B9
// }

// test "create from frequency" {
//     std.testing.log_level = .debug;
//     try testing.expectEqual(Note.fromFreq(8.176), Note.new(0, -1)); // C-1
//     try testing.expectEqual(Note.fromFreq(16.352), Note.new(0, 0)); // C0
//     try testing.expectEqual(Note.fromFreq(27.5), Note.new(9, 0)); // A0
//     try testing.expectEqual(Note.fromFreq(261.626), Note.new(0, 4)); // C4
//     try testing.expectEqual(Note.fromFreq(440.0), Note.new(9, 4)); // A4
//     try testing.expectEqual(Note.fromFreq(4186.009), Note.new(0, 8)); // C8
//     try testing.expectEqual(Note.fromFreq(7902.133), Note.new(11, 8)); // B8
//     try testing.expectEqual(Note.fromFreq(12543.854), Note.new(7, 9)); // G9
//     try testing.expectEqual(Note.fromFreq(15804.266), Note.new(11, 9)); // B9
// }

// test "midi note calculation" {
//     try testing.expectEqual(Note.new(0, -1).midi(), 0); // C-1
//     try testing.expectEqual(Note.new(0, 4).midi(), 60); // C4
//     try testing.expectEqual(Note.new(9, 4).midi(), 69); // A4
//     try testing.expectEqual(Note.new(7, 9).midi(), 127); // G9
// }

// test "create from midi note" {
//     try testing.expectEqual(Note.fromMidi(0), Note.new(0, -1)); // C-1
//     try testing.expectEqual(Note.fromMidi(60), Note.new(0, 4)); // C4
//     try testing.expectEqual(Note.fromMidi(69), Note.new(9, 4)); // A4
//     try testing.expectEqual(Note.fromMidi(127), Note.new(7, 9)); // G9
// }
