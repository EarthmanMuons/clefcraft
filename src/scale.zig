const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.scale);

const _note = @import("note.zig");

const Note = _note.Note;
const Interval = @import("interval.zig").Interval;

pub const Scale = struct {
    tonic: Note,
    pattern: Pattern,
    allocator: std.mem.Allocator,
    notes_cache: ?[]Note = null,
    intervals_cache: ?[]const Interval = null,
    semitones_cache: ?[]i32 = null,

    pub fn init(allocator: std.mem.Allocator, tonic: Note, pattern: Pattern) Scale {
        return Scale{
            .tonic = tonic,
            .pattern = pattern,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Scale) void {
        if (self.notes_cache) |scale_notes| {
            self.allocator.free(scale_notes);
        }
        if (self.intervals_cache) |scale_intervals| {
            self.allocator.free(scale_intervals);
        }
        if (self.semitones_cache) |scale_semitones| {
            self.allocator.free(scale_semitones);
        }
    }

    // Creates a scale from string representations of the tonic and interval pattern name.
    // pub fn parse(tonic: []const u8, pattern: []const u8) !Scale { }

    // Checks if the given note is part of the scale.
    pub fn contains(self: *Scale, needle: Note) bool {
        return self.degreeOf(needle) != null;
    }

    // Checks if any note in the scale is an enharmonic equivalent to the given note.
    pub fn containsEnharmonicOf(self: *Scale, needle: Note) bool {
        const haystack = self.notes() catch return false;

        for (haystack) |item| {
            if (_note.isEnharmonic(item, needle)) {
                return true;
            }
        }
        return false;
    }

    // Returns the degree of the given note, if it exists in the scale.
    pub fn degreeOf(self: *Scale, needle: Note) ?usize {
        const haystack = self.notes() catch return null;

        for (haystack, 0..) |item, i| {
            if (std.meta.eql(item, needle)) {
                return i + 1;
            }
        }
        return null;
    }

    // Returns the note of the scale at the given degree position.
    pub fn nthDegree(self: *Scale, degree: usize) !Note {
        const scale_notes = try self.notes();

        if (degree < 1 or degree > scale_notes.len - 1) {
            return error.InvalidDegree;
        }

        const index = degree - 1;
        return scale_notes[index];
    }

    // Returns a slice of notes representing the scale.
    pub fn notes(self: *Scale) ![]Note {
        if (self.notes_cache) |cached_notes| {
            return cached_notes;
        }

        const scale_intervals = try self.intervals();
        const scale_notes = try self.applyIntervals(scale_intervals);

        self.notes_cache = scale_notes;
        return scale_notes;
    }

    // Returns a slice of semitone distances between each successive note in the scale.
    pub fn semitones(self: *Scale) ![]i32 {
        if (self.semitones_cache) |cached_semitones| {
            return cached_semitones;
        }

        const scale_notes = try self.notes();
        const all_but_last = scale_notes[0 .. scale_notes.len - 1];
        const scale_semitones = try self.allocator.alloc(i32, scale_notes.len - 1);

        for (all_but_last, 0..) |note, i| {
            scale_semitones[i] = note.semitoneDifference(scale_notes[i + 1]);
        }

        self.semitones_cache = scale_semitones;
        return scale_semitones;
    }

    pub fn intervals(self: *Scale) ![]const Interval {
        if (self.intervals_cache) |cached_intervals| {
            return cached_intervals;
        }

        const scale_intervals = switch (self.pattern) {
            .chromatic => try self.chromaticIntervals(),
            .whole_tone => try self.wholeToneIntervals(),
            else => try self.pattern.intervals(self.allocator),
        };

        self.intervals_cache = scale_intervals;
        return scale_intervals;
    }

    fn chromaticIntervals(self: Scale) ![]const Interval {
        return self.getIntervals(chromatic_intervals);
    }

    fn wholeToneIntervals(self: Scale) ![]const Interval {
        return self.getIntervals(whole_tone_intervals);
    }

    fn getIntervals(self: Scale, intervals_map: type) ![]const Interval {
        const pitch_str = self.tonic.pitch.asText();
        const shorthands = intervals_map.get(pitch_str) orelse {
            log.err(
                "{s} scale intervals not found for tonic {s}",
                .{ self.pattern.asText(), self.tonic.pitch },
            );
            return error.InvalidTonic;
        };

        var scale_intervals = try self.allocator.alloc(Interval, shorthands.len);
        errdefer self.allocator.free(scale_intervals);

        for (shorthands, 0..) |shorthand, i| {
            scale_intervals[i] = try Interval.parse(shorthand);
        }

        return scale_intervals;
    }

    fn applyIntervals(self: Scale, scale_intervals: []const Interval) ![]Note {
        const scale_notes = try self.allocator.alloc(Note, scale_intervals.len);
        errdefer self.allocator.free(scale_notes);

        for (scale_intervals, 0..) |shorthand, i| {
            scale_notes[i] = try self.tonic.applyInterval(shorthand);
        }

        return scale_notes;
    }

    // Returns the type of scale based on the number of notes it contains.
    pub fn asType(self: *Scale) ![]const u8 {
        const scale_intervals = try self.intervals();

        return switch (scale_intervals.len - 1) {
            12 => "Dodecatonic",
            9 => "Nonatonic",
            8 => "Octatonic",
            7 => "Heptatonic",
            6 => "Hexatonic",
            5 => "Pentatonic",
            4 => "Tetratonic",
            3 => "Tritonic",
            2 => "Ditonic",
            else => "Unknown",
        };
    }

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
    ionian,
    dorian,
    phrygian,
    lydian,
    mixolydian,
    aeolian,
    locrian,
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
            .ionian => &[_][]const u8{ "P1", "M2", "M3", "P4", "P5", "M6", "M7", "P8" },
            .dorian => &[_][]const u8{ "P1", "M2", "m3", "P4", "P5", "M6", "m7", "P8" },
            .phrygian => &[_][]const u8{ "P1", "m2", "m3", "P4", "P5", "m6", "m7", "P8" },
            .lydian => &[_][]const u8{ "P1", "M2", "M3", "A4", "P5", "M6", "M7", "P8" },
            .mixolydian => &[_][]const u8{ "P1", "M2", "M3", "P4", "P5", "M6", "m7", "P8" },
            .aeolian => &[_][]const u8{ "P1", "M2", "m3", "P4", "P5", "m6", "m7", "P8" },
            .locrian => &[_][]const u8{ "P1", "m2", "m3", "P4", "d5", "m6", "m7", "P8" },
            .blues => &[_][]const u8{ "P1", "m3", "P4", "d5", "P5", "m7", "P8" },
            .major => &[_][]const u8{ "P1", "M2", "M3", "P4", "P5", "M6", "M7", "P8" },
            .major_pentatonic => &[_][]const u8{ "P1", "M2", "M3", "P5", "M6", "P8" },
            .minor => &[_][]const u8{ "P1", "M2", "m3", "P4", "P5", "m6", "m7", "P8" },
            .minor_harmonic => &[_][]const u8{ "P1", "M2", "m3", "P4", "P5", "m6", "M7", "P8" },
            .minor_melodic => &[_][]const u8{ "P1", "M2", "m3", "P4", "P5", "M6", "M7", "P8" },
            .minor_pentatonic => &[_][]const u8{ "P1", "m3", "P4", "P5", "m7", "P8" },
            else => unreachable,
        };

        var pattern_intervals = try allocator.alloc(Interval, shorthands.len);
        errdefer allocator.free(pattern_intervals);

        for (shorthands, 0..) |shorthand, i| {
            pattern_intervals[i] = try Interval.parse(shorthand);
        }

        return pattern_intervals;
    }

    pub fn asText(self: Pattern) []const u8 {
        return switch (self) {
            .ionian => "Ionian",
            .dorian => "Dorian",
            .phrygian => "Phrygian",
            .lydian => "Lydian",
            .mixolydian => "Mixolydian",
            .aeolian => "Aeolian",
            .locrian => "Locrian",
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

const chromatic_intervals = std.ComptimeStringMap([]const []const u8, .{
    // sharp_pitches: A, A#, B, C, C#, D, D#, E, F, F#, G, G#
    .{ "A", &[_][]const u8{ "P1", "A1", "M2", "m3", "M3", "P4", "A4", "P5", "m6", "M6", "m7", "M7", "P8" } },
    .{ "A#", &[_][]const u8{ "P1", "m2", "d3", "m3", "m4", "P4", "d5", "d6", "m6", "d7", "m7", "d8", "P8" } },
    .{ "B", &[_][]const u8{ "P1", "m2", "M2", "m3", "M3", "P4", "d5", "P5", "m6", "M6", "m7", "M7", "P8" } },
    .{ "C", &[_][]const u8{ "P1", "A1", "M2", "A2", "M3", "P4", "A4", "P5", "A5", "M6", "A6", "M7", "P8" } },
    .{ "C#", &[_][]const u8{ "P1", "m2", "M2", "m3", "d4", "P4", "d5", "P5", "m6", "M6", "m7", "d8", "P8" } },
    .{ "D", &[_][]const u8{ "P1", "A1", "M2", "m3", "M3", "P4", "A4", "P5", "A5", "M6", "m7", "M7", "P8" } },
    .{ "D#", &[_][]const u8{ "P1", "m2", "d3", "m3", "d4", "P4", "d5", "P5", "m6", "d7", "m7", "d8", "P8" } },
    .{ "E", &[_][]const u8{ "P1", "m2", "M2", "m3", "M3", "P4", "A4", "P5", "m6", "M6", "m7", "M7", "P8" } },
    .{ "F#", &[_][]const u8{ "P1", "m2", "M2", "m3", "M3", "P4", "d5", "P5", "m6", "M6", "m7", "d8", "P8" } },
    .{ "G", &[_][]const u8{ "P1", "A1", "M2", "A2", "M3", "P4", "A4", "P5", "A5", "M6", "m7", "M7", "P8" } },
    .{ "G#", &[_][]const u8{ "P1", "m2", "M2", "m3", "m4", "P4", "d5", "P5", "m6", "d7", "m7", "d8", "P8" } },
    //  flat_pitches: A, Bb, B, C, Db, D, Eb, E, F, Gb, G, Ab
    .{ "Bb", &[_][]const u8{ "P1", "A1", "M2", "m3", "M3", "P4", "A4", "P5", "m6", "M6", "m7", "M7", "P8" } },
    .{ "Db", &[_][]const u8{ "P1", "A1", "M2", "A2", "M3", "P4", "A4", "P5", "A5", "M6", "A6", "M7", "P8" } },
    .{ "Eb", &[_][]const u8{ "P1", "A1", "M2", "m3", "M3", "P4", "A4", "P5", "A5", "M6", "m7", "M7", "P8" } },
    .{ "F", &[_][]const u8{ "P1", "m2", "M2", "m3", "M3", "P4", "A4", "P5", "m6", "M6", "m7", "M7", "P8" } },
    .{ "Gb", &[_][]const u8{ "P1", "A1", "M2", "A2", "M3", "A3", "A4", "P5", "A5", "M6", "A6", "M7", "P8" } },
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

test "nthDegree()" {
    var scale = Scale.init(std.testing.allocator, try Note.parse("A4"), .major);
    defer scale.deinit();

    const degree = 7;
    const result = try scale.nthDegree(degree);

    std.debug.print("Degree {} of {}: {}\n", .{ degree, scale, result.pitch });
}

test "asType()" {
    var scale = Scale.init(std.testing.allocator, try Note.parse("C4"), .whole_tone);
    defer scale.deinit();

    const result = try scale.asType();

    std.debug.print("{} is type: {s}\n", .{ scale, result });
}

test "contains" {
    var scale = Scale.init(std.testing.allocator, try Note.parse("C4"), .major);
    defer scale.deinit();

    const note1 = try Note.parse("C4");
    const note2 = try Note.parse("C#4");
    const result1 = scale.contains(note1);
    const result2 = scale.contains(note2);

    std.debug.print("{}.contains({}) = {}\n", .{ scale, note1.pitch, result1 });
    std.debug.print("{}.contains({}) = {}\n", .{ scale, note2.pitch, result2 });

    try std.testing.expect(result1);
    try std.testing.expect(!result2);
}

test "containsEnharmonicEquivalent" {
    var scale = Scale.init(std.testing.allocator, try Note.parse("C4"), .major);
    defer scale.deinit();

    const note1 = try Note.parse("C4");
    const note2 = try Note.parse("C#4");
    const note3 = try Note.parse("B#4");
    const result1 = scale.containsEnharmonicOf(note1);
    const result2 = scale.containsEnharmonicOf(note2);
    const result3 = scale.containsEnharmonicOf(note3);

    std.debug.print("{}.containsEnharmonicOf({}) = {}\n", .{ scale, note1.pitch, result1 });
    std.debug.print("{}.containsEnharmonicOf({}) = {}\n", .{ scale, note2.pitch, result2 });
    std.debug.print("{}.containsEnharmonicOf({}) = {}\n", .{ scale, note3.pitch, result3 });

    try std.testing.expect(result1);
    try std.testing.expect(!result2);
    try std.testing.expect(result3);
}

test "notes()" {
    const tonics = [_][]const u8{
        "A4",
        "A#4",
        "Bb4",
        "B4",
        "C4",
        "C#4",
        "Db4",
        "D4",
        "D#4",
        "Eb4",
        "E4",
        "F4",
        "F#4",
        "Gb4",
        "G4",
        "G#4",
        "Ab4",
    };

    for (tonics) |tonic| {
        var scale = Scale.init(std.testing.allocator, try Note.parse(tonic), .major);
        defer scale.deinit();

        const notes = try scale.notes();

        std.debug.print("Notes for {}\t", .{scale});
        for (notes) |note| {
            std.debug.print("{} ", .{note.pitch});
        }
        std.debug.print("\n", .{});
    }
}

test "semitones()" {
    const tonics = [_][]const u8{
        "A4",
        "A#4",
        "Bb4",
        "B4",
        "C4",
        "C#4",
        "Db4",
        "D4",
        "D#4",
        "Eb4",
        "E4",
        "F4",
        "F#4",
        "Gb4",
        "G4",
        "G#4",
        "Ab4",
    };

    for (tonics) |tonic| {
        var scale = Scale.init(std.testing.allocator, try Note.parse(tonic), .major);
        defer scale.deinit();

        const semitones = try scale.semitones();

        std.debug.print("Semitones for {}:\t", .{scale});
        for (semitones) |distance| {
            std.debug.print("{} ", .{distance});
        }
        std.debug.print("\n", .{});
    }
}
