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
    allocator: std.mem.Allocator,
    intervals_cache: ?[]const Interval,
    notes_cache: ?[]Note,

    pub fn init(
        allocator: std.mem.Allocator,
        tonic: Note,
        pattern: Pattern,
    ) Scale {
        return .{
            .tonic = tonic,
            .pattern = pattern,
            .allocator = allocator,
            .intervals_cache = null,
            .notes_cache = null,
        };
    }

    pub fn deinit(self: *Scale) void {
        if (self.intervals_cache) |intervals| {
            self.allocator.free(intervals);
        }
        if (self.notes_cache) |notes| {
            self.allocator.free(notes);
        }
    }

    pub fn getIntervals(self: *Scale) ![]const Interval {
        if (self.intervals_cache) |cached_intervals| {
            return cached_intervals;
        }

        const intervals = try self.pattern.getIntervals(self.allocator);
        self.intervals_cache = intervals;
        return intervals;
    }

    pub fn getName(self: Scale) []const u8 {
        return self.pattern.getName();
    }

    pub fn getNotes(self: *Scale) ![]const Note {
        if (self.notes_cache) |cached_notes| {
            return cached_notes;
        }

        const intervals = try self.getIntervals();
        var notes = try self.allocator.alloc(Note, intervals.len);
        errdefer self.allocator.free(notes);

        // Use a Pitch for internal calculations, but only keep the Note.
        const reference_pitch = Pitch{ .note = self.tonic, .octave = 4 };

        for (intervals, 0..) |interval, i| {
            const pitch = try interval.applyToPitch(reference_pitch);
            notes[i] = pitch.note;
        }

        self.notes_cache = notes;
        return notes;
    }

    pub fn contains(self: *Scale, note: Note) !bool {
        const scale_notes = try self.getNotes();
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
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var c_major = Scale.init(allocator, Note.c, .major);
    defer c_major.deinit();
    const notes = try c_major.getNotes();

    try testing.expectEqual(Note.c, notes[0]);
    try testing.expectEqual(Note.d, notes[1]);
    try testing.expectEqual(Note.e, notes[2]);
    try testing.expectEqual(Note.f, notes[3]);
    try testing.expectEqual(Note.g, notes[4]);
    try testing.expectEqual(Note.a, notes[5]);
    try testing.expectEqual(Note.b, notes[6]);
    try testing.expectEqual(Note.c, notes[7]);
}

test "interval and note caching" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var c_major = Scale.init(allocator, Note.c, .major);
    defer c_major.deinit();

    // First call should compute and cache the results.
    const intervals1 = try c_major.getIntervals();
    try testing.expect(c_major.intervals_cache != null);
    const notes1 = try c_major.getNotes();
    try testing.expect(c_major.notes_cache != null);

    // Second call should return cached intervals and notes.
    const intervals2 = try c_major.getIntervals();
    const notes2 = try c_major.getNotes();
    try testing.expectEqual(intervals1.ptr, intervals2.ptr);
    try testing.expectEqual(notes1.ptr, notes2.ptr);
}

test "scale contains note" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var c_major = Scale.init(allocator, Note.c, .major);
    defer c_major.deinit();

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
