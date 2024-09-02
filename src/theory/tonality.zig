const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.key);
const testing = std.testing;

const c = @import("constants.zig");
const Note = @import("note.zig").Note;

pub const Tonality = struct {
    tonic: Note,
    mode: Mode,

    pub const Mode = enum { major, minor };

    pub fn init(tonic: Note, mode: Mode) Tonality {
        return .{ .tonic = tonic, .mode = mode };
    }

    pub fn sharpsOrFlats(self: Tonality) i8 {
        const circle_of_fifths = [_]i8{ 0, -5, 2, -3, 4, -1, 6, 1, -4, 3, -2, 5 };
        const relative_major_tonic = switch (self.mode) {
            .major => self.tonic.pitchClass(),
            .minor => @mod(self.tonic.pitchClass() + 3, c.sem_per_oct),
        };
        var sf = circle_of_fifths[relative_major_tonic];

        // Handle edge cases
        if (self.mode == .major) {
            sf = switch (self.tonic.name.ltr) {
                .d => if (self.tonic.name.acc == .flat) -5 else sf,
                .c => switch (self.tonic.name.acc) {
                    .sharp => 7,
                    .flat => -7,
                    else => sf,
                },
                .g => if (self.tonic.name.acc == .flat) -6 else sf,
                .f => if (self.tonic.name.acc == .sharp) 6 else sf,
                .b => if (self.tonic.name.acc == .natural) 5 else sf,
                else => sf,
            };
        } else {
            // Adjust for relative minor keys
            sf = switch (self.tonic.name.ltr) {
                .b => if (self.tonic.name.acc == .flat) -5 else sf, // Relative minor of Db
                .a => switch (self.tonic.name.acc) {
                    .sharp => 7, // Relative minor of C#
                    .flat => -7, // Relative minor of Cb
                    else => sf,
                },
                .e => if (self.tonic.name.acc == .flat) -6 else sf, // Relative minor of Gb
                .d => if (self.tonic.name.acc == .sharp) 6 else sf, // Relative minor of F#
                .g => if (self.tonic.name.acc == .sharp) 5 else sf, // Relative minor of B
                else => sf,
            };
        }

        return sf;
    }

    pub fn accidentals(self: Tonality) struct { sharps: u3, flats: u3 } {
        const sf = self.sharpsOrFlats();
        return if (sf >= 0)
            .{ .sharps = @intCast(sf), .flats = 0 }
        else
            .{ .sharps = 0, .flats = @intCast(-sf) };
    }

    pub fn spell(self: Tonality, midi: u7) Note {
        const sf = self.sharpsOrFlats();
        return if (sf >= 0)
            .{ .midi = midi, .name = Note.spellWithSharps(midi) }
        else
            .{ .midi = midi, .name = Note.spellWithFlats(midi) };
    }

    pub fn relativeMajor(self: Tonality) Tonality {
        return switch (self.mode) {
            .major => self,
            .minor => Tonality.init(Note.fromMidi(@intCast(@mod(self.tonic.midi + 3, c.sem_per_oct))), .major),
        };
    }

    pub fn relativeMinor(self: Tonality) Tonality {
        return switch (self.mode) {
            .major => Tonality.init(Note.fromMidi(@intCast(@mod(self.tonic.midi + 9, c.sem_per_oct))), .minor),
            .minor => self,
        };
    }
};

test "behavior" {
    const c_major = Tonality.init(try Note.fromString("C4"), .major);
    const a_minor = Tonality.init(try Note.fromString("A3"), .minor);

    try testing.expectEqual(0, c_major.sharpsOrFlats());
    try testing.expectEqual(0, a_minor.sharpsOrFlats());

    const g_major = Tonality.init(try Note.fromString("G4"), .major);
    const e_minor = Tonality.init(try Note.fromString("E4"), .minor);

    try testing.expectEqual(1, g_major.sharpsOrFlats());
    try testing.expectEqual(1, e_minor.sharpsOrFlats());

    const f_major = Tonality.init(try Note.fromString("F4"), .major);
    const d_minor = Tonality.init(try Note.fromString("D4"), .minor);

    try testing.expectEqual(-1, f_major.sharpsOrFlats());
    try testing.expectEqual(-1, d_minor.sharpsOrFlats());

    // Test cases with 6 or 7 accidentals
    const f_sharp_major = Tonality.init(try Note.fromString("F#4"), .major);
    const g_flat_major = Tonality.init(try Note.fromString("Gb4"), .major);

    try testing.expectEqual(6, f_sharp_major.sharpsOrFlats());
    try testing.expectEqual(-6, g_flat_major.sharpsOrFlats());

    const c_sharp_major = Tonality.init(try Note.fromString("C#4"), .major);
    const c_flat_major = Tonality.init(try Note.fromString("Cb4"), .major);

    try testing.expectEqual(7, c_sharp_major.sharpsOrFlats());
    try testing.expectEqual(-7, c_flat_major.sharpsOrFlats());

    const b_major = Tonality.init(try Note.fromString("B4"), .major);
    const d_flat_major = Tonality.init(try Note.fromString("Db4"), .major);

    try testing.expectEqual(5, b_major.sharpsOrFlats());
    try testing.expectEqual(-5, d_flat_major.sharpsOrFlats());

    // Test relative minor keys
    const g_sharp_minor = Tonality.init(try Note.fromString("G#4"), .minor);
    const e_flat_minor = Tonality.init(try Note.fromString("Eb4"), .minor);

    try testing.expectEqual(5, g_sharp_minor.sharpsOrFlats());
    try testing.expectEqual(-6, e_flat_minor.sharpsOrFlats());

    // Test relative key relationships
    try testing.expectEqual(c_major.tonic.pitchClass(), a_minor.relativeMajor().tonic.pitchClass());
    try testing.expectEqual(a_minor.tonic.pitchClass(), c_major.relativeMinor().tonic.pitchClass());
}
