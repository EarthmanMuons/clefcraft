const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.key_signature);

const Accidental = @import("pitch.zig").Accidental;
const Letter = @import("pitch.zig").Letter;
const Note = @import("note.zig").Note;
const Pattern = @import("scale.zig").Pattern;
const Pitch = @import("pitch.zig").Pitch;
const Scale = @import("scale.zig").Scale;

// const sharps = [_]Letter{ .f, .c, .g, .d, .a, .e, .b };
// const flats = [_]Letter{ .b, .e, .a, .d, .g, .c, .f };

pub const KeySignature = struct {
    tonic: Pitch,
    accidentals: [7]?Accidental,

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
            .accidentals = accidentals,
        };
    }
};

pub const Mode = enum {
    major,
    minor,
};

test "key signatures" {
    for (std.enums.values(Letter)) |letter| {
        for ([_]?Accidental{ null, .flat, .sharp }) |accidental| {
            const tonic = Pitch{
                .letter = letter,
                .accidental = accidental,
            };

            std.debug.print("--- Tonic({})\n", .{tonic});
            for (std.enums.values(Mode)) |mode| {
                const key_signature = try KeySignature.init(std.testing.allocator, tonic, mode);

                std.debug.print("Mode({s}), ", .{@tagName(mode)});

                std.debug.print("Accidentals: ", .{});
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
