const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.note);
const testing = std.testing;

const c = @import("constants.zig");

/// Represents a musical note using Western music theory conventions.
///
/// This struct encapsulates the concept of a note, including its pitch (represented
/// by a MIDI number), spelling (letter name and accidental), and various operations
/// for working with notes in different contexts.
///
/// This implementation assumes 12-tone equal temperament (12-TET) and uses the
/// international standard pitch of A4 = 440 Hz (A440).
pub const Note = struct {
    midi: u7,
    name: Spelling,

    pub const Spelling = struct {
        ltr: Letter,
        acc: Accidental,
    };

    pub const Letter = enum {
        c,
        d,
        e,
        f,
        g,
        a,
        b,

        /// Converts the letter to its corresponding semitone value.
        pub fn semitones(self: Letter) u4 {
            return switch (self) {
                .c => 0,
                .d => 2,
                .e => 4,
                .f => 5,
                .g => 7,
                .a => 9,
                .b => 11,
            };
        }
    };

    pub const Accidental = enum { double_flat, flat, natural, sharp, double_sharp };

    /// Creates a note from a letter, accidental, and octave.
    /// Returns an error if the resulting note is out of the valid MIDI range.
    pub fn init(ltr: Letter, acc: Accidental, oct: i8) !Note {
        const base_sem: i16 = ltr.semitones();
        const acc_offset: i16 = switch (acc) {
            .double_flat => -2,
            .flat => -1,
            .natural => 0,
            .sharp => 1,
            .double_sharp => 2,
        };
        const oct_sem = (@as(i16, oct) + 1) * c.sem_per_oct;

        const midi = base_sem + acc_offset + oct_sem;

        if (midi < 0 or midi > c.midi_max) {
            return error.NoteOutOfRange;
        }
        return .{ .midi = @intCast(midi), .name = .{ .ltr = ltr, .acc = acc } };
    }

    /// Creates a note from the given frequency in Hz.
    /// Uses 12-TET and A440.
    /// The resulting note will be spelled with sharps.
    pub fn fromFrequency(freq: f64) Note {
        assert(freq > 0);

        const a4_freq = 440.0;
        const a4_midi = 69;
        const midi_float = a4_midi + c.sem_per_oct * @log2(freq / a4_freq);
        const midi: u7 = @intFromFloat(@round(midi_float));

        return Note.fromMidi(midi);
    }

    /// Creates a note from the given MIDI number.
    /// The resulting note will be spelled with sharps.
    pub fn fromMidi(midi: u7) Note {
        return .{ .midi = midi, .name = spellWithSharps(midi) };
    }

    /// Creates a note from a string representation in Scientific Pitch Notation.
    /// Supports Unicode and ASCII representations of accidentals.
    /// Returns an error for invalid input.
    pub fn fromString(str: []const u8) !Note {
        if (str.len == 0) return error.EmptyString;

        var iter = (try std.unicode.Utf8View.init(str)).iterator();

        const ltr: Letter = switch (iter.nextCodepoint().?) {
            'C', 'c' => .c,
            'D', 'd' => .d,
            'E', 'e' => .e,
            'F', 'f' => .f,
            'G', 'g' => .g,
            'A', 'a' => .a,
            'B', 'b' => .b,
            else => return error.InvalidLetter,
        };

        var acc: Accidental = .natural;
        if (iter.nextCodepoint()) |cp| {
            switch (cp) {
                '𝄫' => acc = .double_flat,
                '♭', 'b' => {
                    acc = .flat;
                    if (iter.nextCodepoint()) |next_cp| {
                        if (next_cp == cp) {
                            acc = .double_flat;
                        } else {
                            // Move iterator back if it's not a double flat.
                            iter.i -= try std.unicode.utf8CodepointSequenceLength(next_cp);
                        }
                    }
                },
                '♯', '#' => {
                    acc = .sharp;
                    if (iter.nextCodepoint()) |next_cp| {
                        if (next_cp == cp) {
                            acc = .double_sharp;
                        } else {
                            // Move iterator back if it's not a double sharp.
                            iter.i -= try std.unicode.utf8CodepointSequenceLength(next_cp);
                        }
                    }
                },
                '𝄪', 'x' => acc = .double_sharp,
                else => {
                    // Move iterator back if it's not an accidental.
                    iter.i -= try std.unicode.utf8CodepointSequenceLength(cp);
                },
            }
        }

        const oct_str = str[iter.i..];
        if (oct_str.len == 0) return error.MissingOctave;
        const oct = std.fmt.parseInt(i8, oct_str, 10) catch return error.InvalidOctave;

        return Note.init(ltr, acc, oct);
    }

    /// Returns the frequency of the note in Hz.
    /// Uses 12-TET and A440.
    pub fn frequency(self: Note) f64 {
        const a4_freq = 440.0;
        const a4_midi = 69;
        const midi: f64 = @floatFromInt(self.midi);
        return a4_freq * @exp2((midi - a4_midi) / c.sem_per_oct);
    }

    /// Returns the octave of the note, accounting for accidentals.
    /// Follows Scientific Pitch Notation conventions.
    pub fn octave(self: Note) i8 {
        const oct = @divFloor(@as(i8, self.midi), c.sem_per_oct) - 1;

        // Handle notes that cross octave boundaries.
        const offset: i8 = switch (self.name.acc) {
            .flat, .double_flat => if (self.name.ltr == .c) 1 else 0,
            .natural => 0,
            .sharp, .double_sharp => if (self.name.ltr == .b) -1 else 0,
        };

        return oct + offset;
    }

    /// Returns the pitch class of the note.
    pub fn pitchClass(self: Note) u4 {
        return @intCast(@mod(self.midi, c.sem_per_oct));
    }

    /// Calculates the number of diatonic steps between this note and another note.
    /// A positive result means the second note is higher, negative means lower.
    pub fn diatonicStepsTo(self: Note, other: Note) i8 {
        const ltr_diff = @as(i8, @intFromEnum(other.name.ltr)) - @as(i8, @intFromEnum(self.name.ltr));
        const oct_diff = other.octave() - self.octave();

        return @intCast(ltr_diff + oct_diff * c.ltr_per_oct);
    }

    /// Calculates the number of semitones between this note and another note.
    /// A positive result means the second note is higher, negative means lower.
    pub fn semitonesTo(self: Note, other: Note) i8 {
        return @as(i8, other.midi) - @as(i8, self.midi);
    }

    /// Checks if the note is enharmonic with another note.
    pub fn isEnharmonic(self: Note, other: Note) bool {
        return self.midi == other.midi;
    }

    /// Spells a note using sharps based on its MIDI number.
    /// For example, MIDI 61 will be spelled as C♯, not D♭.
    pub fn spellWithSharps(midi: u7) Spelling {
        const pc = @mod(midi, c.sem_per_oct);
        return switch (pc) {
            0 => .{ .ltr = .c, .acc = .natural },
            1 => .{ .ltr = .c, .acc = .sharp },
            2 => .{ .ltr = .d, .acc = .natural },
            3 => .{ .ltr = .d, .acc = .sharp },
            4 => .{ .ltr = .e, .acc = .natural },
            5 => .{ .ltr = .f, .acc = .natural },
            6 => .{ .ltr = .f, .acc = .sharp },
            7 => .{ .ltr = .g, .acc = .natural },
            8 => .{ .ltr = .g, .acc = .sharp },
            9 => .{ .ltr = .a, .acc = .natural },
            10 => .{ .ltr = .a, .acc = .sharp },
            11 => .{ .ltr = .b, .acc = .natural },
            else => unreachable,
        };
    }

    /// Spells a note using flats based on its MIDI number.
    /// For example, MIDI 61 will be spelled as D♭, not C♯.
    pub fn spellWithFlats(midi: u7) Spelling {
        const pc = @mod(midi, c.sem_per_oct);
        return switch (pc) {
            0 => .{ .ltr = .c, .acc = .natural },
            1 => .{ .ltr = .d, .acc = .flat },
            2 => .{ .ltr = .d, .acc = .natural },
            3 => .{ .ltr = .e, .acc = .flat },
            4 => .{ .ltr = .e, .acc = .natural },
            5 => .{ .ltr = .f, .acc = .natural },
            6 => .{ .ltr = .g, .acc = .flat },
            7 => .{ .ltr = .g, .acc = .natural },
            8 => .{ .ltr = .a, .acc = .flat },
            9 => .{ .ltr = .a, .acc = .natural },
            10 => .{ .ltr = .b, .acc = .flat },
            11 => .{ .ltr = .b, .acc = .natural },
            else => unreachable,
        };
    }

    // /// Respells a note according to the given musical context.
    // pub fn respell(self: Note, context: ???) Note { }

    /// Formats the note for output in Scientific Pitch Notation.
    /// Uses Unicode symbols for accidentals by default.
    /// If the format specifier 'c' is used, it outputs ASCII symbols instead.
    pub fn format(
        self: Note,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = options;
        const use_ascii = std.mem.indexOfScalar(u8, fmt, 'c') != null;

        try writer.print("{c}{s}{d}", .{
            std.ascii.toUpper(@tagName(self.name.ltr)[0]),
            if (use_ascii)
                switch (self.name.acc) {
                    .double_flat => "bb",
                    .flat => "b",
                    .natural => "",
                    .sharp => "#",
                    .double_sharp => "x",
                }
            else switch (self.name.acc) {
                .double_flat => "𝄫",
                .flat => "♭",
                .natural => "",
                .sharp => "♯",
                .double_sharp => "𝄪",
            },
            self.octave(),
        });
    }
};

test "initialization" {
    try testing.expectError(error.NoteOutOfRange, Note.init(.c, .flat, -1));
    try testing.expectEqual(0, (try Note.init(.c, .natural, -1)).midi);
    try testing.expectEqual(21, (try Note.init(.a, .natural, 0)).midi);
    try testing.expectEqual(58, (try Note.init(.c, .double_flat, 4)).midi);
    try testing.expectEqual(59, (try Note.init(.c, .flat, 4)).midi);
    try testing.expectEqual(60, (try Note.init(.c, .natural, 4)).midi);
    try testing.expectEqual(61, (try Note.init(.c, .sharp, 4)).midi);
    try testing.expectEqual(62, (try Note.init(.c, .double_sharp, 4)).midi);
    try testing.expectEqual(69, (try Note.init(.a, .natural, 4)).midi);
    try testing.expectEqual(108, (try Note.init(.c, .natural, 8)).midi);
    try testing.expectEqual(127, (try Note.init(.g, .natural, 9)).midi);
    try testing.expectError(error.NoteOutOfRange, Note.init(.g, .sharp, 9));
}

test "properties" {
    const b3 = try Note.init(.b, .natural, 3);
    try testing.expectEqual(Note.Letter.b, b3.name.ltr);
    try testing.expectEqual(Note.Accidental.natural, b3.name.acc);
    try testing.expectEqual(3, b3.octave());
    try testing.expectEqual(11, b3.pitchClass());

    const cf4 = try Note.init(.c, .flat, 4);
    try testing.expectEqual(Note.Letter.c, cf4.name.ltr);
    try testing.expectEqual(Note.Accidental.flat, cf4.name.acc);
    try testing.expectEqual(4, cf4.octave());
    try testing.expectEqual(11, cf4.pitchClass());

    const c4 = try Note.init(.c, .natural, 4);
    try testing.expectEqual(Note.Letter.c, c4.name.ltr);
    try testing.expectEqual(Note.Accidental.natural, c4.name.acc);
    try testing.expectEqual(4, c4.octave());
    try testing.expectEqual(0, c4.pitchClass());

    const cs4 = try Note.init(.c, .sharp, 4);
    try testing.expectEqual(Note.Letter.c, cs4.name.ltr);
    try testing.expectEqual(Note.Accidental.sharp, cs4.name.acc);
    try testing.expectEqual(4, cs4.octave());
    try testing.expectEqual(1, cs4.pitchClass());

    const df4 = try Note.init(.d, .flat, 4);
    try testing.expectEqual(Note.Letter.d, df4.name.ltr);
    try testing.expectEqual(Note.Accidental.flat, df4.name.acc);
    try testing.expectEqual(4, df4.octave());
    try testing.expectEqual(1, df4.pitchClass());
}

test "basic parsing" {
    try testing.expectEqual(0, (try Note.fromString("C-1")).midi);
    try testing.expectEqual(59, (try Note.fromString("B3")).midi);
    try testing.expectEqual(59, (try Note.fromString("Cb4")).midi);
    try testing.expectEqual(60, (try Note.fromString("C4")).midi);
    try testing.expectEqual(69, (try Note.fromString("A4")).midi);
}

test "Unicode parsing" {
    try testing.expectEqual(58, (try Note.fromString("C𝄫4")).midi);
    try testing.expectEqual(58, (try Note.fromString("C♭♭4")).midi);
    try testing.expectEqual(59, (try Note.fromString("C♭4")).midi);
    try testing.expectEqual(61, (try Note.fromString("C♯4")).midi);
    try testing.expectEqual(62, (try Note.fromString("C♯♯4")).midi);
    try testing.expectEqual(62, (try Note.fromString("C𝄪4")).midi);
}

test "ASCII parsing" {
    try testing.expectEqual(58, (try Note.fromString("Cbb4")).midi);
    try testing.expectEqual(59, (try Note.fromString("Cb4")).midi);
    try testing.expectEqual(61, (try Note.fromString("C#4")).midi);
    try testing.expectEqual(62, (try Note.fromString("C##4")).midi);
    try testing.expectEqual(62, (try Note.fromString("Cx4")).midi);
}

test "parsing errors" {
    try testing.expectError(error.EmptyString, Note.fromString(""));
    try testing.expectError(error.InvalidLetter, Note.fromString("H4"));
    try testing.expectError(error.MissingOctave, Note.fromString("C"));
    try testing.expectError(error.InvalidOctave, Note.fromString("C#X"));
    try testing.expectError(error.NoteOutOfRange, Note.fromString("C-2"));
    try testing.expectError(error.NoteOutOfRange, Note.fromString("G10"));
}

test "frequencies" {
    const epsilon = 0.001;
    try testing.expectApproxEqAbs(8.176, (try Note.init(.c, .natural, -1)).frequency(), epsilon);
    try testing.expectApproxEqAbs(27.5, (try Note.init(.a, .natural, 0)).frequency(), epsilon);
    try testing.expectApproxEqAbs(261.626, (try Note.init(.c, .natural, 4)).frequency(), epsilon);
    try testing.expectApproxEqAbs(440.0, (try Note.init(.a, .natural, 4)).frequency(), epsilon);
    try testing.expectApproxEqAbs(4186.009, (try Note.init(.c, .natural, 8)).frequency(), epsilon);
    try testing.expectApproxEqAbs(12543.854, (try Note.init(.g, .natural, 9)).frequency(), epsilon);

    try testing.expectEqual(0, (Note.fromFrequency(8.176).midi));
    try testing.expectEqual(21, (Note.fromFrequency(27.5).midi));
    try testing.expectEqual(60, (Note.fromFrequency(261.626).midi));
    try testing.expectEqual(69, (Note.fromFrequency(440.0).midi));
    try testing.expectEqual(108, (Note.fromFrequency(4186.009).midi));
    try testing.expectEqual(127, (Note.fromFrequency(12543.854).midi));
}

test "simple diatonic steps" {
    const c4 = try Note.init(.c, .natural, 4);
    const d4 = try Note.init(.d, .natural, 4);
    const g4 = try Note.init(.g, .natural, 4);
    const c5 = try Note.init(.c, .natural, 5);
    const c6 = try Note.init(.c, .natural, 6);

    try testing.expectEqual(-7, c5.diatonicStepsTo(c4));
    try testing.expectEqual(0, c4.diatonicStepsTo(c4));
    try testing.expectEqual(1, c4.diatonicStepsTo(d4));
    try testing.expectEqual(4, c4.diatonicStepsTo(g4));
    try testing.expectEqual(7, c4.diatonicStepsTo(c5));
    try testing.expectEqual(14, c4.diatonicStepsTo(c6));
}

test "enharmonic diatonic steps" {
    const b3 = try Note.init(.b, .natural, 3);
    const cf4 = try Note.init(.c, .flat, 4);
    const c4 = try Note.init(.c, .natural, 4);
    const d4 = try Note.init(.d, .natural, 4);
    const fs4 = try Note.init(.f, .sharp, 4);
    const gf4 = try Note.init(.g, .flat, 4);

    try testing.expect(b3.isEnharmonic(cf4));
    try testing.expect(fs4.isEnharmonic(gf4));
    try testing.expectEqual(-1, c4.diatonicStepsTo(b3));
    try testing.expectEqual(-1, cf4.diatonicStepsTo(b3));
    try testing.expectEqual(2, d4.diatonicStepsTo(fs4));
    try testing.expectEqual(3, d4.diatonicStepsTo(gf4));
}

test "semitones" {
    const c4 = try Note.init(.c, .natural, 4);
    const e4 = try Note.init(.e, .natural, 4);
    const g4 = try Note.init(.g, .natural, 4);
    const c5 = try Note.init(.c, .natural, 5);
    const f5 = try Note.init(.f, .natural, 5);

    try testing.expectEqual(0, c4.semitonesTo(c4));
    try testing.expectEqual(4, c4.semitonesTo(e4));
    try testing.expectEqual(-4, e4.semitonesTo(c4));
    try testing.expectEqual(7, c4.semitonesTo(g4));
    try testing.expectEqual(12, c4.semitonesTo(c5));
    try testing.expectEqual(17, c4.semitonesTo(f5));
}

test "formatting" {
    try testing.expectFmt("C𝄫4", "{}", .{try Note.init(.c, .double_flat, 4)});
    try testing.expectFmt("C♭4", "{}", .{try Note.init(.c, .flat, 4)});
    try testing.expectFmt("C4", "{}", .{try Note.init(.c, .natural, 4)});
    try testing.expectFmt("C♯4", "{}", .{try Note.init(.c, .sharp, 4)});
    try testing.expectFmt("C𝄪4", "{}", .{try Note.init(.c, .double_sharp, 4)});
}

test "ASCII formatting" {
    try testing.expectFmt("Cbb4", "{c}", .{try Note.init(.c, .double_flat, 4)});
    try testing.expectFmt("Cb4", "{c}", .{try Note.init(.c, .flat, 4)});
    try testing.expectFmt("C4", "{c}", .{try Note.init(.c, .natural, 4)});
    try testing.expectFmt("C#4", "{c}", .{try Note.init(.c, .sharp, 4)});
    try testing.expectFmt("Cx4", "{c}", .{try Note.init(.c, .double_sharp, 4)});
}
