const std = @import("std");
const Interval = @import("interval.zig").Interval;

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

    pub fn getIntervals(self: Pattern, allocator: std.mem.Allocator) ![]const Interval {
        const strings = switch (self) {
            .major => &[_][]const u8{ "P1", "M2", "M3", "P4", "P5", "M6", "M7", "P8" },
            .natural_minor => &[_][]const u8{ "P1", "M2", "m3", "P4", "P5", "m6", "m7", "P8" },
            .harmonic_minor => &[_][]const u8{ "P1", "M2", "m3", "P4", "P5", "m6", "M7", "P8" },
            .melodic_minor => &[_][]const u8{ "P1", "M2", "m3", "P4", "P5", "M6", "M7", "P8" },
            .pentatonic_major => &[_][]const u8{ "P1", "M2", "M3", "P5", "M6", "P8" },
            .pentatonic_minor => &[_][]const u8{ "P1", "m3", "P4", "P5", "m7", "P8" },
            .chromatic => &[_][]const u8{ "P1", "m2", "M2", "m3", "M3", "P4", "A4", "P5", "m6", "M6", "m7", "M7", "P8" },
            .dorian => &[_][]const u8{ "P1", "M2", "m3", "P4", "P5", "M6", "m7", "P8" },
            .phrygian => &[_][]const u8{ "P1", "m2", "m3", "P4", "P5", "m6", "m7", "P8" },
            .lydian => &[_][]const u8{ "P1", "M2", "M3", "A4", "P5", "M6", "M7", "P8" },
            .mixolydian => &[_][]const u8{ "P1", "M2", "M3", "P4", "P5", "M6", "m7", "P8" },
            .locrian => &[_][]const u8{ "P1", "m2", "m3", "P4", "d5", "m6", "m7", "P8" },
            .whole_tone => &[_][]const u8{ "P1", "M2", "M3", "A4", "A5", "A6", "P8" },
        };

        var interval_list = try std.ArrayList(Interval).initCapacity(allocator, strings.len);
        errdefer interval_list.deinit();

        for (strings) |str| {
            const interval = try Interval.fromString(str);
            try interval_list.append(interval);
        }

        return interval_list.toOwnedSlice();
    }

    pub fn getName(self: Pattern) []const u8 {
        return switch (self) {
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
};
