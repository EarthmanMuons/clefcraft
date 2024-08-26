const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.scale);
const testing = std.testing;

const Interval = @import("interval.zig").Interval;
const Note = @import("note.zig").Note;
const Pitch = @import("pitch.zig").Pitch;

pub const Scale = struct {
    tonic: Note,
    pattern: Pattern,
    count: usize = undefined,
    intervals: ?[12]Interval = null,
    notes: ?[12]Note = null,
    semitones: ?[12]i8 = null,

    pub const Pattern = enum {
        major,
        natural_minor,
        harmonic_minor,
        melodic_minor,
        pentatonic_major,
        pentatonic_minor,
        chromatic,
        dorian,
        phrygian,
        lydian,
        mixolydian,
        locrian,
        whole_tone,
    };

    /// Initializes a new Scale with the given tonic note and scale pattern.
    pub fn init(tonic: Note, pattern: Pattern) Scale {
        var scale = Scale{
            .tonic = tonic,
            .pattern = pattern,
        };
        scale.generateIntervals();
        return scale;
    }

    fn generateIntervals(self: *Scale) void {
        var intervals: [12]Interval = undefined;
        const interval_strings = switch (self.pattern) {
            .major => &[_][]const u8{ "P1", "M2", "M3", "P4", "P5", "M6", "M7" },
            .natural_minor => &[_][]const u8{ "P1", "M2", "m3", "P4", "P5", "m6", "m7" },
            .harmonic_minor => &[_][]const u8{ "P1", "M2", "m3", "P4", "P5", "m6", "M7" },
            .melodic_minor => &[_][]const u8{ "P1", "M2", "m3", "P4", "P5", "M6", "M7" },
            .pentatonic_major => &[_][]const u8{ "P1", "M2", "M3", "P5", "M6" },
            .pentatonic_minor => &[_][]const u8{ "P1", "m3", "P4", "P5", "m7" },
            .chromatic => &self.generateChromaticIntervals(),
            .dorian => &[_][]const u8{ "P1", "M2", "m3", "P4", "P5", "M6", "m7" },
            .phrygian => &[_][]const u8{ "P1", "m2", "m3", "P4", "P5", "m6", "m7" },
            .lydian => &[_][]const u8{ "P1", "M2", "M3", "A4", "P5", "M6", "M7" },
            .mixolydian => &[_][]const u8{ "P1", "M2", "M3", "P4", "P5", "M6", "m7" },
            .locrian => &[_][]const u8{ "P1", "m2", "m3", "P4", "d5", "m6", "m7" },
            .whole_tone => &self.generateWholeToneIntervals(),
        };

        for (interval_strings, 0..) |interval_str, i| {
            intervals[i] = Interval.fromString(interval_str) catch unreachable;
        }

        self.intervals = intervals;
        self.count = interval_strings.len;
    }

    // TODO: these patterns change based on the tonic
    fn generateChromaticIntervals(self: Scale) [12][]const u8 {
        _ = self.tonic; // Unused for now
        // Placeholder: returns a single hard-coded list
        return .{ "P1", "m2", "M2", "m3", "M3", "P4", "A4", "P5", "m6", "M6", "m7", "M7" };
    }

    // TODO: these patterns change based on the tonic
    fn generateWholeToneIntervals(self: Scale) [6][]const u8 {
        _ = self.tonic; // Unused for now
        // Placeholder: returns a single hard-coded list
        return .{ "P1", "M2", "M3", "A4", "A5", "A6" };
    }

    /// Returns the intervals that make up the scale.
    pub fn getIntervals(self: *Scale) []const Interval {
        if (self.intervals == null) {
            self.generateIntervals();
        }
        return self.intervals.?[0..self.count];
    }

    /// Returns the name of the scale pattern.
    pub fn getName(self: Scale) []const u8 {
        return switch (self.pattern) {
            .major => "Major",
            .natural_minor => "Natural Minor",
            .harmonic_minor => "Harmonic Minor",
            .melodic_minor => "Melodic Minor",
            .pentatonic_major => "Pentatonic Major",
            .pentatonic_minor => "Pentatonic Minor",
            .chromatic => "Chromatic",
            .dorian => "Dorian",
            .phrygian => "Phrygian",
            .lydian => "Lydian",
            .mixolydian => "Mixolydian",
            .locrian => "Locrian",
            .whole_tone => "Whole Tone",
        };
    }

    /// Returns the notes that make up the scale.
    pub fn getNotes(self: *Scale) []const Note {
        if (self.notes == null) {
            self.generateNotes();
        }
        return self.notes.?[0..self.count];
    }

    fn generateNotes(self: *Scale) void {
        var notes: [12]Note = undefined;
        const reference_pitch = Pitch{ .note = self.tonic, .octave = 4 };
        const intervals = self.getIntervals();

        log.debug("Generating notes with reference pitch: {}", .{reference_pitch});

        for (intervals, 0..) |interval, i| {
            const new_pitch = interval.applyToPitch(reference_pitch) catch unreachable;
            notes[i] = new_pitch.note;
            log.debug("Applied interval: {}, new note: {}", .{ interval, notes[i] });
        }

        self.notes = notes;
        log.debug("Generated notes: {any}", .{self.notes.?[0..self.count]});
    }

    /// Returns the semitone distances between consecutive notes in the scale.
    pub fn getSemitones(self: *Scale) []const i8 {
        if (self.semitones == null) {
            self.generateSemitones();
        }
        return self.semitones.?[0..self.count];
    }

    fn generateSemitones(self: *Scale) void {
        var semitones: [12]i8 = undefined;
        var previous_semitones: i8 = 0;
        const intervals = self.getIntervals();

        log.debug("Generating semitones for scale with tonic: {}", .{self.tonic});

        // Skip the first interval (P1).
        for (intervals[1..], 0..) |interval, i| {
            const current_semitones = interval.getSemitones();
            semitones[i] = current_semitones - previous_semitones;
            previous_semitones = current_semitones;

            log.debug("Interval {}: {} semitones from previous note", .{ interval, semitones[i] });
        }

        // Add the final interval (P8) to complete the octave.
        const octave_semitones = 12;
        semitones[intervals.len - 1] = octave_semitones - previous_semitones;

        self.semitones = semitones;
        log.debug("Generated semitones: {any}", .{self.semitones.?[0..self.count]});
    }

    /// Checks if a note is in the scale.
    pub fn contains(self: *Scale, note: Note) bool {
        return self.degreeOf(note) != null;
    }

    /// Finds the scale degree of a given note.
    ///
    /// Returns null if the note is not in the scale.
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

    /// Retrieves the note at a given scale degree.
    ///
    /// The scale degree should be 1-indexed (1 for the tonic, 2 for the supertonic, etc.).
    /// Returns null if the given degree is out of range for the scale.
    pub fn nthDegree(self: *Scale, n: u8) ?Note {
        if (n == 0 or n > self.count) {
            return null;
        }

        const scale_notes = self.getNotes();
        return scale_notes[n - 1]; // scale degrees are 1-indexed
    }

    /// Returns the enharmonic equivalent of the given note that fits the scale.
    ///
    /// Returns null if no enharmonic equivalent exists in the scale.
    pub fn getScaleSpelling(self: *Scale, note: Note) ?Note {
        if (self.degreeOf(note)) |d| {
            return self.nthDegree(d);
        }
        return null;
    }

    /// Formats the Scale for output.
    ///
    /// Outputs the tonic note followed by the scale name (e.g., "C Major").
    pub fn format(
        self: Scale,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{} {s}", .{ self.tonic, self.getName() });
    }
};

// Compile-time safety check for exhaustiveness of scale pattern definitions
comptime {
    const pattern_fields = @typeInfo(Scale.Pattern).Enum.fields;
    for (pattern_fields) |field| {
        const pattern = @as(Scale.Pattern, @enumFromInt(field.value));
        var scale = Scale{ .tonic = Note.c, .pattern = pattern };

        _ = scale.getName();
        scale.generateIntervals();
    }
}

test "scale creation and interval retrieval" {
    var c_major = Scale.init(Note.c, .major);
    const intervals = c_major.getIntervals();

    try testing.expectEqual(try Interval.perf(1), intervals[0]);
    try testing.expectEqual(try Interval.maj(2), intervals[1]);
    try testing.expectEqual(try Interval.maj(3), intervals[2]);
    try testing.expectEqual(try Interval.perf(4), intervals[3]);
    try testing.expectEqual(try Interval.perf(5), intervals[4]);
    try testing.expectEqual(try Interval.maj(6), intervals[5]);
    try testing.expectEqual(try Interval.maj(7), intervals[6]);
    try testing.expectEqual(@as(usize, 7), intervals.len);
}

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
    try testing.expectEqual(7, notes.len);
}

test "semitones calculation" {
    var c_major = Scale.init(Note.c, .major);
    const semitones = c_major.getSemitones();

    const expected = [_]i8{ 2, 2, 1, 2, 2, 2, 1 };
    try std.testing.expectEqualSlices(i8, &expected, semitones);
}

test "scale degrees" {
    var c_major = Scale.init(Note.c, .major);

    try testing.expectEqual(1, c_major.degreeOf(Note.c));
    try testing.expectEqual(4, c_major.degreeOf(Note.f));
    try testing.expectEqual(null, c_major.degreeOf(Note.f.sharp()));

    try testing.expectEqual(Note.c, c_major.nthDegree(1));
    try testing.expectEqual(Note.g, c_major.nthDegree(5));
    try testing.expectEqual(null, c_major.nthDegree(8));
}

test "scale spellings" {
    var c_major = Scale.init(Note.c, .major);

    try testing.expectEqual(Note.e, c_major.getScaleSpelling(Note.f.flat()));
    try testing.expectEqual(Note.b, c_major.getScaleSpelling(Note.c.flat()));
    try testing.expectEqual(null, c_major.getScaleSpelling(Note.f.sharp()));
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
