const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.scale);

const Note = @import("note.zig").Note;
const Interval = @import("interval.zig").Interval;

pub const Scale = struct {
    tonic: Note,
    pattern: Pattern,
    mode: u8 = 1,

    pub fn init(tonic: Note, pattern: Pattern) Scale {
        return Scale{
            .tonic = tonic,
            .pattern = pattern,
        };
    }

    // Creates a scale from string representations of the tonic and interval pattern name.
    // pub fn parse(tonic: []const u8, pattern: []const u8) !Scale { }

    // Returns a slice of notes representing the scale.
    pub fn notes(self: Scale, allocator: std.mem.Allocator) ![]Note {
        const intervals_slice = try self.intervals(allocator);
        defer allocator.free(intervals_slice);

        const notes_slice = try self.applyIntervals(allocator, intervals_slice);
        defer allocator.free(notes_slice);

        return try self.rotateNotesForMode(allocator, notes_slice);
    }

    // Returns a slice of semitone distances between each successive note in the scale.
    pub fn semitones(self: Scale, allocator: std.mem.Allocator) ![]i32 {
        const notes_slice = try self.notes(allocator);
        defer allocator.free(notes_slice);

        const distances = try allocator.alloc(i32, notes_slice.len - 1);
        errdefer allocator.free(distances);

        for (notes_slice[0 .. notes_slice.len - 1], 0..) |note, i| {
            const next_note = notes_slice[i + 1];
            distances[i] = note.semitoneDifference(next_note);
        }

        return distances;
    }

    pub fn intervals(self: Scale, allocator: std.mem.Allocator) ![]const Interval {
        return switch (self.pattern) {
            .chromatic => try self.chromaticIntervals(allocator),
            .whole_tone => try self.wholeToneIntervals(allocator),
            else => try self.pattern.intervals(allocator),
        };
    }

    fn chromaticIntervals(self: Scale, allocator: std.mem.Allocator) ![]const Interval {
        return self.getIntervals(allocator, chromatic_intervals);
    }

    fn wholeToneIntervals(self: Scale, allocator: std.mem.Allocator) ![]const Interval {
        return self.getIntervals(allocator, whole_tone_intervals);
    }

    fn getIntervals(
        self: Scale,
        allocator: std.mem.Allocator,
        intervals_map: type,
    ) ![]const Interval {
        const pitch_str = self.tonic.pitch.asText();
        const shorthands = intervals_map.get(pitch_str) orelse {
            log.err(
                "{s} scale intervals not found for tonic {s}",
                .{ self.pattern.asText(), self.tonic.pitch },
            );
            return error.InvalidTonic;
        };

        var intervals_slice = try allocator.alloc(Interval, shorthands.len);
        errdefer allocator.free(intervals_slice);

        for (shorthands, 0..) |shorthand, i| {
            intervals_slice[i] = try Interval.parse(shorthand);
        }

        return intervals_slice;
    }

    fn applyIntervals(
        self: Scale,
        allocator: std.mem.Allocator,
        shorthands: []const Interval,
    ) ![]Note {
        const notes_slice = try allocator.alloc(Note, shorthands.len);
        errdefer allocator.free(notes_slice);

        for (shorthands, 0..) |shorthand, i| {
            notes_slice[i] = try self.tonic.applyInterval(shorthand);
        }

        return notes_slice;
    }

    fn rotateNotesForMode(self: Scale, allocator: std.mem.Allocator, notes_slice: []Note) ![]Note {
        const notes_without_p8 = notes_slice[0 .. notes_slice.len - 1];

        std.mem.rotate(Note, notes_without_p8, self.mode - 1);

        const new_first_note = notes_without_p8[0];
        const p8_interval = try Interval.parse("P8");
        const new_p8_note = try new_first_note.applyInterval(p8_interval);

        const new_notes_slice = try allocator.alloc(Note, notes_without_p8.len + 1);
        errdefer allocator.free(new_notes_slice);

        std.mem.copyForwards(Note, new_notes_slice, notes_without_p8);
        new_notes_slice[notes_without_p8.len] = new_p8_note;

        return new_notes_slice;
    }

    // Checks if the given note is part of the scale.
    // pub fn contains(self: Scale, note: Note) bool {}

    // Returns the scale degree of the given note, if it exists in the scale.
    // pub fn degreeOf(self: Scale, note: Note) ?usize {}

    // Formats the scale as a string.
    pub fn format(
        self: Scale,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        const pattern_text = self.pattern.asText();
        try writer.print("Scale({s} {s})", .{ self.tonic.pitch, pattern_text });
    }
};

pub const Pattern = enum {
    blues,
    chromatic,
    major,
    major_pentatonic,
    minor,
    minor_harmonic,
    minor_melodic,
    minor_pentatonic,
    whole_tone,

    fn intervals(self: Pattern, allocator: std.mem.Allocator) ![]const Interval {
        const shorthands = switch (self) {
            .blues => &[_][]const u8{ "P1", "m3", "P4", "d5", "P5", "m7", "P8" },
            .major => &[_][]const u8{ "P1", "M2", "M3", "P4", "P5", "M6", "M7", "P8" },
            .major_pentatonic => &[_][]const u8{ "P1", "M2", "M3", "P5", "M6", "P8" },
            .minor => &[_][]const u8{ "P1", "M2", "m3", "P4", "P5", "m6", "m7", "P8" },
            .minor_harmonic => &[_][]const u8{ "P1", "M2", "m3", "P4", "P5", "m6", "M7", "P8" },
            .minor_melodic => &[_][]const u8{ "P1", "M2", "m3", "P4", "P5", "M6", "M7", "P8" },
            .minor_pentatonic => &[_][]const u8{ "P1", "m3", "P4", "P5", "m7", "P8" },
            else => unreachable,
        };

        var intervals_slice = try allocator.alloc(Interval, shorthands.len);
        errdefer allocator.free(intervals_slice);

        for (shorthands, 0..) |shorthand, i| {
            intervals_slice[i] = try Interval.parse(shorthand);
        }

        return intervals_slice;
    }

    pub fn asText(self: Pattern) []const u8 {
        return switch (self) {
            .blues => "Blues",
            .chromatic => "Chromatic",
            .major => "Major",
            .major_pentatonic => "Major Pentatonic",
            .minor => "Natural Minor",
            .minor_harmonic => "Harmonic Minor",
            .minor_melodic => "Melodic Minor",
            .minor_pentatonic => "Minor Pentatonic",
            .whole_tone => "Whole-Tone",
        };
    }

    // Formats the pattern as a string.
    pub fn format(
        self: Pattern,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        const output = self.asText();
        try writer.print("Pattern({s})", .{output});
    }
};

// sharp_pitches: A, A#, B, C, C#, D, D#, E, F, F#, G, G#
//  flat_pitches: A, Bb, B, C, Db, D, Eb, E, F, Gb, G, Ab
const chromatic_intervals = std.ComptimeStringMap([]const []const u8, .{
    .{ "A", &[_][]const u8{ "P1", "A1", "M2", "m3", "M3", "P4", "A4", "P5", "m6", "M6", "m7", "M7", "P8" } },
    .{ "A#", &[_][]const u8{ "P1", "m2", "d3", "m3", "m4", "P4", "d5", "d6", "m6", "d7", "m7", "d8", "P8" } },
    .{ "Bb", &[_][]const u8{ "P1", "A1", "M2", "m3", "M3", "P4", "A4", "P5", "m6", "M6", "m7", "M7", "P8" } },
    .{ "B", &[_][]const u8{ "P1", "m2", "M2", "m3", "M3", "P4", "d5", "P5", "m6", "M6", "m7", "M7", "P8" } },
    .{ "C", &[_][]const u8{ "P1", "A1", "M2", "A2", "M3", "P4", "A4", "P5", "A5", "M6", "A6", "M7", "P8" } },
    .{ "C#", &[_][]const u8{ "P1", "m2", "M2", "m3", "d4", "P4", "d5", "P5", "m6", "M6", "m7", "d8", "P8" } },
    .{ "Db", &[_][]const u8{ "P1", "A1", "M2", "A2", "M3", "P4", "A4", "P5", "A5", "M6", "A6", "M7", "P8" } },
    .{ "D", &[_][]const u8{ "P1", "A1", "M2", "m3", "M3", "P4", "A4", "P5", "A5", "M6", "m7", "M7", "P8" } },
    .{ "D#", &[_][]const u8{ "P1", "m2", "d3", "m3", "d4", "P4", "d5", "P5", "m6", "d7", "m7", "d8", "P8" } },
    .{ "Eb", &[_][]const u8{ "P1", "A1", "M2", "m3", "M3", "P4", "A4", "P5", "A5", "M6", "m7", "M7", "P8" } },
    .{ "E", &[_][]const u8{ "P1", "m2", "M2", "m3", "M3", "P4", "A4", "P5", "m6", "M6", "m7", "M7", "P8" } },
    .{ "F", &[_][]const u8{ "P1", "m2", "M2", "m3", "M3", "P4", "A4", "P5", "m6", "M6", "m7", "M7", "P8" } },
    .{ "F#", &[_][]const u8{ "P1", "m2", "M2", "m3", "M3", "P4", "d5", "P5", "m6", "M6", "m7", "d8", "P8" } },
    .{ "Gb", &[_][]const u8{ "P1", "A1", "M2", "A2", "M3", "A3", "A4", "P5", "A5", "M6", "A6", "M7", "P8" } },
    .{ "G", &[_][]const u8{ "P1", "A1", "M2", "A2", "M3", "P4", "A4", "P5", "A5", "M6", "m7", "M7", "P8" } },
    .{ "G#", &[_][]const u8{ "P1", "m2", "M2", "m3", "m4", "P4", "d5", "P5", "m6", "d7", "m7", "d8", "P8" } },
    .{ "Ab", &[_][]const u8{ "P1", "A1", "M2", "A2", "M3", "P4", "A4", "P5", "A5", "M6", "m7", "M7", "P8" } },
});

const whole_tone_intervals = std.ComptimeStringMap([]const []const u8, .{
    // cn_pitches: C, D, E, F#, G#, A#
    .{ "C", &[_][]const u8{ "P1", "M2", "M3", "A4", "A5", "A6", "P8" } },
    .{ "D", &[_][]const u8{ "P1", "M2", "M3", "A4", "A5", "m7", "P8" } },
    .{ "E", &[_][]const u8{ "P1", "M2", "M3", "A4", "m6", "m7", "P8" } },
    .{ "F#", &[_][]const u8{ "P1", "M2", "M3", "d5", "m6", "m7", "P8" } },
    .{ "G#", &[_][]const u8{ "P1", "M2", "d4", "d5", "m6", "m7", "P8" } },
    .{ "A#", &[_][]const u8{ "P1", "d3", "d4", "d5", "m6", "m7", "P8" } },
    // db_pitches: Db, Eb, F, G, A, B
    .{ "Db", &[_][]const u8{ "P1", "M2", "M3", "A4", "A5", "A6", "P8" } },
    .{ "Eb", &[_][]const u8{ "P1", "M2", "M3", "A4", "A5", "m7", "P8" } },
    .{ "F", &[_][]const u8{ "P1", "M2", "M3", "A4", "m6", "m7", "P8" } },
    .{ "G", &[_][]const u8{ "P1", "M2", "M3", "d5", "m6", "m7", "P8" } },
    .{ "A", &[_][]const u8{ "P1", "M2", "d4", "d5", "m6", "m7", "P8" } },
    .{ "B", &[_][]const u8{ "P1", "d3", "d4", "d5", "m6", "m7", "P8" } },
});

test "notes()" {
    const tonics = [_][]const u8{
        "C4",
        "D4",
        "E4",
        "F#4",
        "G#4",
        "A#4",
        "Db4",
        "Eb4",
        "F4",
        "G4",
        "A4",
        "B4",
    };

    for (tonics) |tonic| {
        const scale = Scale.init(try Note.parse(tonic), .major);

        const notes = try scale.notes(std.testing.allocator);
        defer std.testing.allocator.free(notes);

        std.debug.print("Notes for {}\t", .{scale});
        for (notes) |note| {
            std.debug.print("{} ", .{note.pitch});
        }
        std.debug.print("\n", .{});
    }
}

test "semitones()" {
    const tonics = [_][]const u8{
        "C4",
        "D4",
        "E4",
        "F#4",
        "G#4",
        "A#4",
        "Db4",
        "Eb4",
        "F4",
        "G4",
        "A4",
        "B4",
    };

    for (tonics) |tonic| {
        const scale = Scale.init(try Note.parse(tonic), .major);

        const semitones = try scale.semitones(std.testing.allocator);
        defer std.testing.allocator.free(semitones);

        std.debug.print("Semitones for {}:\t", .{scale});
        for (semitones) |distance| {
            std.debug.print("{} ", .{distance});
        }
        std.debug.print("\n", .{});
    }
}
