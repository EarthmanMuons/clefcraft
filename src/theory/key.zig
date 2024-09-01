const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.key);
const testing = std.testing;

const c = @import("constants.zig");
const Note = @import("note.zig").Note;

pub const Key = struct {
    tonic: Note,
    mode: Mode,

    pub const Mode = enum { major, minor };

    pub fn init(tonic: Note, mode: Mode) Key {
        return .{ .tonic = tonic, .mode = mode };
    }

    pub fn sharpsOrFlats(self: Key) i8 {
        const circle_of_fifths = [_]i8{ 0, -5, 2, -3, 4, -1, 6, 1, -4, 3, -2, 5 };
        const relative_major_tonic = switch (self.mode) {
            .major => self.tonic.pitchClass(),
            .minor => @mod(self.tonic.pitchClass() + 3, c.sem_per_oct),
        };
        return circle_of_fifths[relative_major_tonic];
    }

    pub fn accidentals(self: Key) struct { sharps: u3, flats: u3 } {
        const sf = self.sharpsOrFlats();
        return if (sf >= 0)
            .{ .sharps = @intCast(sf), .flats = 0 }
        else
            .{ .sharps = 0, .flats = @intCast(-sf) };
    }

    pub fn spell(self: Key, note: Note) Note {
        const sf = self.sharpsOrFlats();
        return if (sf >= 0)
            Note.spellWithSharps(note.midi)
        else
            Note.spellWithFlats(note.midi);
    }

    pub fn relativeMajor(self: Key) Key {
        return switch (self.mode) {
            .major => self,
            .minor => Key.init(Note.fromMidi(@intCast(@mod(self.tonic.midi + 3, c.sem_per_oct))), .major),
        };
    }

    pub fn relativeMinor(self: Key) Key {
        return switch (self.mode) {
            .major => Key.init(Note.fromMidi(@intCast(@mod(self.tonic.midi + 9, c.sem_per_oct))), .minor),
            .minor => self,
        };
    }
};

test "Key behavior" {
    const c_major = Key.init(try Note.fromString("C4"), .major);
    const a_minor = Key.init(try Note.fromString("A3"), .minor);

    try testing.expectEqual(0, c_major.sharpsOrFlats());
    try testing.expectEqual(0, a_minor.sharpsOrFlats());

    const g_major = Key.init(try Note.fromString("G4"), .major);
    const e_minor = Key.init(try Note.fromString("E4"), .minor);

    try testing.expectEqual(1, g_major.sharpsOrFlats());
    try testing.expectEqual(1, e_minor.sharpsOrFlats());

    const f_major = Key.init(try Note.fromString("F4"), .major);
    const d_minor = Key.init(try Note.fromString("D4"), .minor);

    try testing.expectEqual(-1, f_major.sharpsOrFlats());
    try testing.expectEqual(-1, d_minor.sharpsOrFlats());

    // Test relative key relationships
    try testing.expectEqual(c_major.tonic.pitchClass(), a_minor.relativeMajor().tonic.pitchClass());
    try testing.expectEqual(a_minor.tonic.pitchClass(), c_major.relativeMinor().tonic.pitchClass());
}
