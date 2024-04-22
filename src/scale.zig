const std = @import("std");
const ArrayList = std.ArrayList;
const assert = std.debug.assert;
const log = std.log.scoped(.scale);

const Note = @import("note.zig").Note;
const Interval = @import("interval.zig").Interval;

pub const Scale = struct {
    tonic: Note,
    pattern: Pattern,

    pub fn init(tonic: Note, pattern: Pattern) Scale {
        return Scale{
            .tonic = tonic,
            .pattern = pattern,
        };
    }

    // Creates a scale from string representations of the tonic and interval pattern name.
    // pub fn parse(tonic: []const u8, pattern: []const u8) !Scale { }

    // Stores the notes of the scale in the given list.
    pub fn notes(self: Scale, note_list: *ArrayList(Note)) !void {
        const intervals_list = try self.intervals(note_list.allocator);
        defer note_list.allocator.free(intervals_list);

        try note_list.ensureTotalCapacity(intervals_list.len);

        for (intervals_list) |interval| {
            const note = try self.tonic.applyInterval(interval);
            try note_list.append(note);
        }
    }

    fn intervals(self: Scale, allocator: std.mem.Allocator) ![]const Interval {
        const shorthands = switch (self.pattern) {
            .chromatic => blk: {
                const pitch_str = self.tonic.pitch.asText();
                const chromatic_shorthands = chromatic_patterns.get(pitch_str) orelse {
                    log.err("Chromatic scale pattern not found for tonic {s}", .{self.tonic.pitch});
                    return error.InvalidTonic;
                };
                break :blk chromatic_shorthands;
            },
            .major => &[_][]const u8{
                "P1", "M2", "M3", "P4", "P5", "M6", "M7",
            },
            .minor => &[_][]const u8{
                "P1", "M2", "m3", "P4", "P5", "m6", "m7",
            },
        };

        var interval_list = try std.ArrayList(Interval).initCapacity(allocator, shorthands.len);
        errdefer interval_list.deinit();

        for (shorthands) |shorthand| {
            const interval = try Interval.parse(shorthand);
            try interval_list.append(interval);
        }

        return interval_list.items;
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
    chromatic,
    major,
    minor,
    // minor_harmonic,
    // minor_melodic,
    // ...

    pub fn asText(self: Pattern) []const u8 {
        return switch (self) {
            .chromatic => "Chromatic",
            .major => "Major",
            .minor => "Natural Minor",
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

const chromatic_patterns = std.ComptimeStringMap([]const []const u8, .{
    .{ "C", &[_][]const u8{ "P1", "A1", "M2", "A2", "M3", "P4", "A4", "P5", "A5", "M6", "A6", "M7" } },
    .{ "C#", &[_][]const u8{ "P1", "m2", "M2", "m3", "d4", "P4", "d5", "P5", "m6", "M6", "m7", "d8" } },
    .{ "Db", &[_][]const u8{ "P1", "A1", "M2", "A2", "M3", "P4", "A4", "P5", "A5", "M6", "A6", "M7" } },
    .{ "D", &[_][]const u8{ "P1", "A1", "M2", "m3", "M3", "P4", "A4", "P5", "A5", "M6", "m7", "M7" } },
    .{ "D#", &[_][]const u8{ "P1", "m2", "d3", "m3", "d4", "P4", "d5", "P5", "m6", "d7", "m7", "d8" } },
    .{ "Eb", &[_][]const u8{ "P1", "A1", "M2", "m3", "M3", "P4", "A4", "P5", "A5", "M6", "m7", "M7" } },
    .{ "E", &[_][]const u8{ "P1", "m2", "M2", "m3", "M3", "P4", "A4", "P5", "m6", "M6", "m7", "M7" } },
    .{ "F", &[_][]const u8{ "P1", "m2", "M2", "m3", "M3", "P4", "A4", "P5", "m6", "M6", "m7", "M7" } },
    .{ "F#", &[_][]const u8{ "P1", "m2", "M2", "m3", "M3", "P4", "d5", "P5", "m6", "M6", "m7", "d8" } },
    .{ "Gb", &[_][]const u8{ "P1", "A1", "M2", "A2", "M3", "A3", "A4", "P5", "A5", "M6", "A6", "M7" } },
    .{ "G", &[_][]const u8{ "P1", "A1", "M2", "A2", "M3", "P4", "A4", "P5", "A5", "M6", "m7", "M7" } },
    .{ "G#", &[_][]const u8{ "P1", "m2", "M2", "m3", "m4", "P4", "d5", "P5", "m6", "d7", "m7", "d8" } },
    .{ "Ab", &[_][]const u8{ "P1", "A1", "M2", "A2", "M3", "P4", "A4", "P5", "A5", "M6", "m7", "M7" } },
    .{ "A", &[_][]const u8{ "P1", "A1", "M2", "m3", "M3", "P4", "A4", "P5", "m6", "M6", "m7", "M7" } },
    .{ "A#", &[_][]const u8{ "P1", "m2", "d3", "m3", "m4", "P4", "d5", "d6", "m6", "d7", "m7", "d8" } },
    .{ "Bb", &[_][]const u8{ "P1", "A1", "M2", "m3", "M3", "P4", "A4", "P5", "m6", "M6", "m7", "M7" } },
    .{ "B", &[_][]const u8{ "P1", "m2", "M2", "m3", "M3", "P4", "d5", "P5", "m6", "M6", "m7", "M7" } },
});

test "notes()" {
    std.testing.log_level = .debug;
    const tonics = [_][]const u8{
        "C4",
        "G4",
        "D4",
        "A4",
        "E4",
        "B4",
        "F#4",
        "Gb4",
        "Db4",
        "Ab4",
        "Eb4",
        "Bb4",
        "F4",
    };
    var note_list = ArrayList(Note).init(std.testing.allocator);
    defer note_list.deinit();

    for (tonics) |tonic| {
        const scale = Scale.init(try Note.parse(tonic), .chromatic);

        note_list.clearAndFree();
        try scale.notes(&note_list);

        std.debug.print("{}:\t", .{scale});
        for (note_list.items) |note| {
            std.debug.print("{} ", .{note.pitch});
        }
        std.debug.print("\n", .{});
    }
}
