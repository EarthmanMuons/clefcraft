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

    pub fn init(tonic: Note, pattern: Pattern) Scale {
        var scale = Scale{
            .tonic = tonic,
            .pattern = pattern,
            .intervals = undefined,
            .count = 0,
            .notes = null,
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
        self.count = countNonNullIntervals(self.intervals);
        log.debug("Generated intervals: {any}", .{self.intervals[0..self.count]});
    }

    fn countNonNullIntervals(intervals: [12]?Interval) u4 {
        var count: u4 = 0;
        for (intervals) |maybe_interval| {
            if (maybe_interval != null) {
                count += 1;
            } else {
                break; // Assuming all non-null intervals are at the beginning
            }
        }
        return count;
    }

    pub fn getIntervals(self: Scale) []const Interval {
        return std.mem.sliceTo(&self.intervals, null);
    }

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

    pub fn getSemitones(self: Scale) [12]?u4 {
        var semitones: [12]?u4 = [_]?u4{null} ** 12;
        var current_semitones: u4 = 0;

        for (self.intervals[0..self.count], 0..) |maybe_interval, i| {
            semitones[i] = current_semitones;
            if (maybe_interval) |interval| {
                current_semitones += @intCast(interval.getSemitones());
            }
        }

        return semitones;
    }

    pub fn contains(self: *Scale, note: Note) !bool {
        const scale_notes = self.getNotes();
        const note_pitch_class = note.getPitchClass();

        for (scale_notes) |scale_note| {
            if (note_pitch_class == scale_note.getPitchClass()) {
                return true;
            }
        }
        return false;
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

test "scale contains note" {
    var c_major = Scale.init(Note.c, .major);

    try testing.expect(try c_major.contains(Note.c));
    try testing.expect(try c_major.contains(Note.d));
    try testing.expect(try c_major.contains(Note.e));
    try testing.expect(try c_major.contains(Note.f));
    try testing.expect(try c_major.contains(Note.g));
    try testing.expect(try c_major.contains(Note.a));
    try testing.expect(try c_major.contains(Note.b));

    try testing.expect(!try c_major.contains(Note.c.sharp()));
    try testing.expect(!try c_major.contains(Note.f.sharp()));

    try testing.expect(try c_major.contains(Note.b.sharp())); // enharmonic to C
    try testing.expect(try c_major.contains(Note.e.sharp())); // enharmonic to F
}
