const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;

// The international standard pitch (A4 at 440 Hz).
const reference_pitch_class = 9;
const reference_octave = 4;
const reference_frequency = 440.0;

const semitones_per_octave = 12;

pub const Note = struct {
    pitch_class: u8,
    octave: i8,

    pub fn new(pitch_class: u8, octave: i8) Note {
        assert(pitch_class < semitones_per_octave);
        assert(octave >= -1 and octave <= 9);

        return Note{
            .pitch_class = pitch_class,
            .octave = octave,
        };
    }

    pub fn parse(chars: []const u8) !Note {
        assert(chars.len > 1);

        const letter = std.ascii.toUpper(chars[0]);

        var pitch_map: [26]u8 = undefined;
        pitch_map['C' - 'A'] = 0;
        pitch_map['D' - 'A'] = 2;
        pitch_map['E' - 'A'] = 4;
        pitch_map['F' - 'A'] = 5;
        pitch_map['G' - 'A'] = 7;
        pitch_map['A' - 'A'] = 9;
        pitch_map['B' - 'A'] = 11;

        // Parse the pitch class.
        if (letter < 'A' or letter > 'G') return error.InvalidNoteFormat;
        const pitch_class_base = pitch_map[letter - 'A'];

        // Check for accidentals.
        var accidental: i8 = 0;
        var octave_start: usize = 1;

        if (chars.len > 2) {
            if (chars[1] == '#' or chars[1] == 'b') {
                accidental = if (chars[1] == '#') 1 else -1;
                octave_start += 1;
            }
        }

        // Parse the octave.
        const octave_str = chars[octave_start..];
        var octave = std.fmt.parseInt(i8, octave_str, 10) catch return error.InvalidNoteFormat;

        // Calculate the final pitch class with accidental.
        var pitch_class = @as(i8, @intCast(pitch_class_base)) +% accidental;

        // Handle pitch class wrap-around for octave boundaries.
        if (pitch_class >= semitones_per_octave) {
            pitch_class -= semitones_per_octave;
            octave += 1;
        } else if (pitch_class < 0) {
            pitch_class += semitones_per_octave;
            octave -= 1;
        }

        // std.debug.print("\n", .{});
        // std.debug.print("chars: {s}\n", .{chars});
        // std.debug.print("letter: {c}\n", .{letter});
        // std.debug.print("accidental: {}\n", .{accidental});
        // std.debug.print("octave_start: {}\n", .{octave_start});
        // std.debug.print("octave: {}\n", .{octave});
        // std.debug.print("pitch_class_base: {}\n", .{pitch_class_base});
        // std.debug.print("pitch_class: {}\n", .{pitch_class});

        return Note.new(@as(u8, @intCast(pitch_class)), octave);
    }

    // Returns the fundamental frequency in Hz using twelve-tone equal temperament (12-TET).
    pub fn freq(self: Note) f64 {
        const semitones_from_ref =
            @as(i32, self.pitch_class) - reference_pitch_class +
            (semitones_per_octave * (self.octave - reference_octave));

        const octave_difference =
            @as(f64, @floatFromInt(semitones_from_ref)) /
            @as(f64, @floatFromInt(semitones_per_octave));

        return reference_frequency * @exp2(octave_difference);
    }

    pub fn fromFreq(frequency: f64) Note {
        assert(frequency > 0);

        const semitones_from_ref =
            @round(reference_pitch_class +
            semitones_per_octave * @log2(frequency / reference_frequency));

        var pitch_class = @mod(semitones_from_ref, semitones_per_octave);
        if (pitch_class < 0) {
            pitch_class += semitones_per_octave;
        }

        var octave_offset: f64 = undefined;
        if (semitones_from_ref < 0) {
            octave_offset = @divFloor(semitones_from_ref, semitones_per_octave);
        } else {
            octave_offset = @divTrunc(semitones_from_ref, semitones_per_octave);
        }

        const octave = reference_octave + octave_offset;

        // std.debug.print("\n", .{});
        // std.debug.print("frequency: {d}\n", .{frequency});
        // std.debug.print("semitones_from_ref: {d}\n", .{semitones_from_ref});
        // std.debug.print("pitch_class: {d}\n", .{pitch_class});
        // std.debug.print("octave_offset: {d}\n", .{octave_offset});
        // std.debug.print("octave: {d}\n", .{octave});

        return Note.new(@intFromFloat(pitch_class), @intFromFloat(octave));
    }

    // Returns the MIDI note number.
    pub fn midi(self: Note) u8 {
        const octave_offset = @as(u8, @intCast(self.octave + 1)) * semitones_per_octave;
        const midi_note = octave_offset + self.pitch_class;

        assert(midi_note < 128);
        return midi_note;
    }

    pub fn fromMidi(midi_note: u8) Note {
        const pitch_class = midi_note % semitones_per_octave;
        const octave = @as(i8, @intCast(midi_note / semitones_per_octave)) - 1;

        return Note.new(pitch_class, octave);
    }
};

test "create from string" {
    try testing.expectEqual(Note.parse("C-1"), Note.new(0, -1));
    try testing.expectEqual(Note.parse("A4"), Note.new(9, 4));
    try testing.expectEqual(Note.parse("a4"), Note.new(9, 4));
    try testing.expectEqual(Note.parse("B9"), Note.new(11, 9));

    try testing.expectEqual(Note.parse("C4"), Note.new(0, 4));
    try testing.expectEqual(Note.parse("C#4"), Note.new(1, 4));

    try testing.expectEqual(Note.parse("B4"), Note.new(11, 4));
    try testing.expectEqual(Note.parse("Bb4"), Note.new(10, 4));

    try testing.expectEqual(Note.parse("Cb4"), Note.new(11, 3));
    try testing.expectEqual(Note.parse("B3"), Note.new(11, 3));

    try testing.expectEqual(Note.parse("B#4"), Note.new(0, 5));
    try testing.expectEqual(Note.parse("C5"), Note.new(0, 5));
}

test "frequency calculation" {
    const approxEqAbs = std.math.approxEqAbs;
    const epsilon = 0.001;

    try testing.expect(approxEqAbs(f64, Note.new(0, -1).freq(), 8.176, epsilon)); // C-1
    try testing.expect(approxEqAbs(f64, Note.new(0, 0).freq(), 16.352, epsilon)); // C0
    try testing.expect(approxEqAbs(f64, Note.new(9, 0).freq(), 27.5, epsilon)); // A0
    try testing.expect(approxEqAbs(f64, Note.new(0, 4).freq(), 261.626, epsilon)); // C4
    try testing.expect(approxEqAbs(f64, Note.new(9, 4).freq(), 440.0, epsilon)); // A4
    try testing.expect(approxEqAbs(f64, Note.new(0, 8).freq(), 4186.009, epsilon)); // C8
    try testing.expect(approxEqAbs(f64, Note.new(11, 8).freq(), 7902.133, epsilon)); // B8
    try testing.expect(approxEqAbs(f64, Note.new(7, 9).freq(), 12543.854, epsilon)); // G9
    try testing.expect(approxEqAbs(f64, Note.new(11, 9).freq(), 15804.266, epsilon)); // B9
}

test "create from frequency" {
    try testing.expectEqual(Note.fromFreq(8.176), Note.new(0, -1)); // C-1
    try testing.expectEqual(Note.fromFreq(16.352), Note.new(0, 0)); // C0
    try testing.expectEqual(Note.fromFreq(27.5), Note.new(9, 0)); // A0
    try testing.expectEqual(Note.fromFreq(261.626), Note.new(0, 4)); // C4
    try testing.expectEqual(Note.fromFreq(440.0), Note.new(9, 4)); // A4
    try testing.expectEqual(Note.fromFreq(4186.009), Note.new(0, 8)); // C8
    try testing.expectEqual(Note.fromFreq(7902.133), Note.new(11, 8)); // B8
    try testing.expectEqual(Note.fromFreq(12543.854), Note.new(7, 9)); // G9
    try testing.expectEqual(Note.fromFreq(15804.266), Note.new(11, 9)); // B9
}

test "midi note calculation" {
    try testing.expectEqual(Note.new(0, -1).midi(), 0); // C-1
    try testing.expectEqual(Note.new(0, 4).midi(), 60); // C4
    try testing.expectEqual(Note.new(9, 4).midi(), 69); // A4
    try testing.expectEqual(Note.new(7, 9).midi(), 127); // G9
}

test "create from midi note" {
    try testing.expectEqual(Note.fromMidi(0), Note.new(0, -1)); // C-1
    try testing.expectEqual(Note.fromMidi(60), Note.new(0, 4)); // C4
    try testing.expectEqual(Note.fromMidi(69), Note.new(9, 4)); // A4
    try testing.expectEqual(Note.fromMidi(127), Note.new(7, 9)); // G9
}
