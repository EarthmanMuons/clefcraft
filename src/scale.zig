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
        const intervals = try self.pattern.intervals(note_list.allocator);
        defer note_list.allocator.free(intervals);

        try note_list.ensureTotalCapacity(intervals.len);

        for (intervals) |interval| {
            const note = try self.tonic.applyInterval(interval);
            try note_list.append(note);
        }
    }

    // Checks if the given note is part of the scale.
    // pub fn contains(self: Scale, note: Note) bool {}

    // Returns the scale degree of the given note, if it exists in the scale.
    // pub fn degreeOf(self: Scale, note: Note) ?usize {}
};

pub const Pattern = enum {
    chromatic,
    major,
    natural_minor,
    // harmonic_minor,
    // melodic_minor,
    // ...

    pub fn intervals(self: Pattern, allocator: std.mem.Allocator) ![]const Interval {
        const shorthands = switch (self) {
            .chromatic => &[_][]const u8{
                "P1", "m2", "M2", "m3", "M3", "P4", "d5", "P5", "m6", "M6", "m7", "M7",
            },
            .major => &[_][]const u8{
                "P1", "M2", "M3", "P4", "P5", "M6", "M7",
            },
            .natural_minor => &[_][]const u8{
                "P1", "M2", "m3", "P4", "P5", "m6", "m7",
            },
        };

        var intervalList = try std.ArrayList(Interval).initCapacity(allocator, shorthands.len);
        errdefer intervalList.deinit();

        for (shorthands) |shorthand| {
            const interval = try Interval.parse(shorthand);
            try intervalList.append(interval);
        }

        return intervalList.items;
    }
};

test "intervals()" {
    std.testing.log_level = .debug;
    const major_intervals = try Pattern.major.intervals(std.testing.allocator);
    defer std.testing.allocator.free(major_intervals);

    std.debug.print("Major scale intervals:\n", .{});
    for (major_intervals) |interval| {
        std.debug.print("{}\n", .{interval});
    }
}

test "notes()" {
    std.testing.log_level = .debug;
    const scale = Scale.init(try Note.parse("C4"), .major);
    var note_list = ArrayList(Note).init(std.testing.allocator);
    defer note_list.deinit();

    try scale.notes(&note_list);

    std.debug.print("C4 scale notes (Major):\n", .{});
    for (note_list.items) |note| {
        std.debug.print("{} ", .{note});
    }
    std.debug.print("\n", .{});
}
