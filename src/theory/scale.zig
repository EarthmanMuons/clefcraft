const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.scale);
const testing = std.testing;

const Interval = @import("interval.zig").Interval;
const Note = @import("note.zig").Note;
const Pattern = @import("scale_library.zig").Pattern;
const Pitch = @import("pitch.zig").Pitch;

pub const Scale = struct {
    tonic: Note,
    pattern: Pattern,
    intervals: [12]?Interval,
    count: u4,
    notes: ?[12]Note,
    semitones: ?[12]i8,

    pub fn init(tonic: Note, pattern: Pattern) Scale {
        var scale = Scale{
            .tonic = tonic,
            .pattern = pattern,
            .intervals = undefined,
            .count = 0,
            .notes = null,
            .semitones = null,
        };
        scale.generateIntervals();
        log.debug(
            "Scale initialized with tonic: {}, pattern: {}, count: {}",
            .{ tonic, pattern, scale.count },
        );
        return scale;
    }

    fn generateIntervals(self: *Scale) void {
        self.intervals = self.pattern.getIntervals();
        self.count = countIntervals(self.intervals);
        log.debug("Generated intervals: {any}", .{self.intervals[0..self.count]});
    }

    fn countIntervals(intervals: [12]?Interval) u4 {
        var count: u4 = 0;
        for (intervals) |maybe_interval| {
            if (maybe_interval != null) {
                count += 1;
            } else {
                break; // all non-null intervals are at the beginning
            }
        }
        return count;
    }

    pub fn getIntervals(self: Scale) []const Interval {
        return std.mem.sliceTo(&self.intervals, null);
    }

    // Returns the name of the scale pattern.
    pub fn getName(self: Scale) []const u8 {
        return self.pattern.getName();
    }

    pub fn getNotes(self: *Scale) []const Note {
        if (self.notes == null) {
            self.generateNotes();
        }
        return self.notes.?[0..self.count];
    }

    fn generateNotes(self: *Scale) void {
        var notes: [12]Note = undefined;
        const reference_pitch = Pitch{ .note = self.tonic, .octave = 4 };

        log.debug("Generating notes with reference pitch: {}", .{reference_pitch});

        for (self.intervals[0..self.count], 0..) |maybe_interval, i| {
            if (maybe_interval) |interval| {
                const new_pitch = interval.applyToPitch(reference_pitch) catch unreachable;
                notes[i] = new_pitch.note;
                log.debug("Applied interval: {}, new note: {}", .{ interval, notes[i] });
            } else {
                log.warn("Null interval at index {}", .{i});
                break;
            }
        }

        self.notes = notes;
        log.debug("Generated notes: {any}", .{self.notes.?[0..self.count]});
    }

    // Calculates semitone distances within the scale.
    pub fn getSemitones(self: *Scale) []const i8 {
        if (self.semitones == null) {
            self.generateSemitones();
        }
        return self.semitones.?[0 .. self.count - 1]; // exclude the last interval (P8)
    }

    fn generateSemitones(self: *Scale) void {
        var semitones: [12]i8 = undefined;
        var previous_semitones: i8 = 0;

        log.debug("Generating semitones for scale with tonic: {}", .{self.tonic});

        // Skip the first interval (P1)
        for (self.intervals[1..self.count], 0..) |maybe_interval, i| {
            if (maybe_interval) |interval| {
                const current_semitones = interval.getSemitones();
                semitones[i] = current_semitones - previous_semitones;
                previous_semitones = current_semitones;

                log.debug("Interval {}: {} semitones from previous note", .{ i + 2, semitones[i] });
            } else {
                break;
            }
        }

        self.semitones = semitones;
        log.debug("Generated semitones: {any}", .{self.semitones.?[0 .. self.count - 1]});
    }

    //  Finds the scale spelling for a given note.
    pub fn getScaleSpelling(self: *Scale, note: Note) ?Note {
        if (self.degreeOf(note)) |d| {
            return self.nthDegree(d);
        }
        return null;
    }

    // Checks if a note is in the scale.
    pub fn contains(self: *Scale, note: Note) bool {
        return self.degreeOf(note) != null;
    }

    // Finds the scale degree of a given note.
    pub fn degreeOf(self: *Scale, note: Note) ?u8 {
        const scale_notes = self.getNotes();
        const note_pitch_class = note.getPitchClass();

        for (scale_notes, 0..) |scale_note, i| {
            if (note_pitch_class == scale_note.getPitchClass()) {
                return @intCast(i + 1); // scale degrees are 1-indexed
            }
        }
        return null;
    }

    // Retrieves the note at a given scale degree.
    pub fn nthDegree(self: *Scale, n: u8) ?Note {
        if (n == 0 or n > self.count) {
            return null;
        }

        const scale_notes = self.getNotes();
        return scale_notes[n - 1]; // scale degrees are 1-indexed
    }
};

test "scale creation and note retrieval" {
    var c_major = Scale.init(Note.c, .major);
    const notes = c_major.getNotes();

    try testing.expectEqual(Note.c, notes[0]);
    try testing.expectEqual(Note.d, notes[1]);
    try testing.expectEqual(Note.e, notes[2]);
    try testing.expectEqual(Note.f, notes[3]);
    try testing.expectEqual(Note.g, notes[4]);
    try testing.expectEqual(Note.a, notes[5]);
    try testing.expectEqual(Note.b, notes[6]);
    try testing.expectEqual(Note.c, notes[7]);
}

test "semitones calculation" {
    var c_major = Scale.init(Note.c, .major);
    const semitones = c_major.getSemitones();

    log.debug("C Major scale semitones: {any}", .{semitones});

    const expected = [_]i8{ 2, 2, 1, 2, 2, 2, 1 };
    try std.testing.expectEqualSlices(i8, &expected, semitones);
}

test "scale degrees" {
    var c_major = Scale.init(Note.c, .major);

    try testing.expectEqual(@as(?u8, 1), c_major.degreeOf(Note.c));
    try testing.expectEqual(@as(?u8, 4), c_major.degreeOf(Note.f));
    try testing.expectEqual(@as(?u8, null), c_major.degreeOf(Note.f.sharp()));

    try testing.expectEqual(Note.c, c_major.nthDegree(1).?);
    try testing.expectEqual(Note.g, c_major.nthDegree(5).?);
    try testing.expectEqual(Note.c, c_major.nthDegree(8).?);
}

test "scale spellings" {
    var c_major = Scale.init(Note.c, .major);

    try testing.expectEqual(Note.e, c_major.getScaleSpelling(Note.f.flat()).?);
    try testing.expectEqual(Note.b, c_major.getScaleSpelling(Note.c.flat()).?);
    try testing.expectEqual(@as(?Note, null), c_major.getScaleSpelling(Note.f.sharp()));
}

test "scale contains note" {
    var c_major = Scale.init(Note.c, .major);

    try testing.expect(c_major.contains(Note.c));
    try testing.expect(c_major.contains(Note.d));
    try testing.expect(c_major.contains(Note.e));
    try testing.expect(c_major.contains(Note.f));
    try testing.expect(c_major.contains(Note.g));
    try testing.expect(c_major.contains(Note.a));
    try testing.expect(c_major.contains(Note.b));

    try testing.expect(!c_major.contains(Note.c.sharp()));
    try testing.expect(!c_major.contains(Note.f.sharp()));

    try testing.expect(c_major.contains(Note.b.sharp())); // enharmonic to C
    try testing.expect(c_major.contains(Note.e.sharp())); // enharmonic to F
}
