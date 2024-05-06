const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.key_signature);

const utils = @import("../utils.zig");

const Accidental = @import("pitch.zig").Accidental;
const Letter = @import("pitch.zig").Letter;
const Note = @import("note.zig").Note;
const Pattern = @import("scale.zig").Pattern;
const Pitch = @import("pitch.zig").Pitch;
const Scale = @import("scale.zig").Scale;

const semitones_per_octave = @import("../constants.zig").theory.semitones_per_octave;

// const sharps = [_]Letter{ .f, .c, .g, .d, .a, .e, .b };
// const flats = [_]Letter{ .b, .e, .a, .d, .g, .c, .f };

pub const KeySignature = struct {
    tonic: Pitch,
    mode: Mode,
    accidentals: [7]?Accidental,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, tonic: Pitch, mode: Mode) !KeySignature {
        const pattern: Pattern = switch (mode) {
            .major => .major,
            .minor => .minor,
        };

        const tonic_note = Note{ .pitch = tonic, .octave = 4 }; // any octave will do
        var scale = Scale.init(allocator, tonic_note, pattern);
        defer scale.deinit();

        var accidentals = [_]?Accidental{null} ** 7;

        for (try scale.notes()) |note| {
            accidentals[@intFromEnum(note.pitch.letter)] = note.pitch.accidental;
        }

        return KeySignature{
            .tonic = tonic,
            .mode = mode,
            .accidentals = accidentals,
            .allocator = allocator,
        };
    }

    pub fn noteFromMidi(self: KeySignature, midi_number: i32) Note {
        assert(0 <= midi_number and midi_number <= 127);

        const pitch_class = utils.wrap(midi_number, semitones_per_octave);
        const octave = @divTrunc(midi_number, semitones_per_octave) - 1;
        const initial_letter = Letter.fromPitchClass(pitch_class);

        var letter = initial_letter;
        var accidental: ?Accidental = null;

        // Select proper enharmonic equivalents based on the key signature.
        switch (pitch_class) {
            // These pitch classes correspond to the black keys on a piano.
            1, 3, 6, 8, 10 => {
                const is_flat_key_sig = self.accidentals[1] == .flat; // check for Bb

                if (is_flat_key_sig) {
                    letter = letter.offsetBy(1);
                    accidental = .flat;
                } else {
                    accidental = .sharp;
                }
            },
            else => {
                // The remaining pitch classes correspond to the white keys on a piano.
                accidental = null;
            },
        }

        return Note{
            .pitch = Pitch{ .letter = letter, .accidental = accidental },
            .octave = octave,
        };
    }

    /// Renders a format string for the `KeySignature` type.
    pub fn format(
        self: KeySignature,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("KeySignature({} {s})", .{ self.tonic, @tagName(self.mode) });
    }
};

/// The modality of a `KeySignature`.
pub const Mode = enum {
    major,
    minor,
};

// pub fn accidentalFor(self: KeySignature, letter: pitch.Letter) ?pitch.Accidental {}
// pub fn asText(self: KeySignature) []const u8 {}
// pub fn isEnharmonicWith(self: KeySignature, other: KeySignature) bool {}
// pub fn relativeMinor(self: KeySignature) KeySignature {}
// pub fn relativeMajor(self: KeySignature) KeySignature {}
// pub fn transpose(self: *KeySignature, interval: interval.Interval) void {}

test "key signatures" {
    for (std.enums.values(Letter)) |letter| {
        for ([_]?Accidental{ null, .flat, .sharp }) |accidental| {
            const tonic = Pitch{
                .letter = letter,
                .accidental = accidental,
            };

            for (std.enums.values(Mode)) |mode| {
                const key_signature = try KeySignature.init(std.testing.allocator, tonic, mode);

                std.debug.print("{},\tAccidentals: ", .{key_signature});
                for (key_signature.accidentals) |acc| {
                    if (acc) |a| {
                        std.debug.print("{s} ", .{a});
                    } else {
                        std.debug.print("_ ", .{});
                    }
                }
                std.debug.print("\n", .{});
            }
        }
    }
}
