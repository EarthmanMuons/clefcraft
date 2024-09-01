const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.scale);
const testing = std.testing;

const c = @import("constants.zig");
const Interval = @import("interval.zig").Interval;
const Note = @import("note.zig").Note;
const ScaleType = @import("scale_type.zig").ScaleType;

pub const Scale = struct {
    tonic: Note,
    scale_type: ScaleType,

    pub fn init(tonic: Note, scale_type: ScaleType) Scale {
        return .{ .tonic = tonic, .scale_type = scale_type };
    }

    pub fn notes(self: Scale, allocator: std.mem.Allocator) ![]Note {
        var result = try allocator.alloc(Note, self.scale_type.intervals.len + 1);
        errdefer allocator.free(result);

        result[0] = self.tonic;
        for (self.scale_type.intervals, 1..) |interval, i| {
            result[i] = try interval.applyTo(self.tonic);
        }

        return result;
    }

    pub fn contains(self: Scale, note: Note) bool {
        const semitones = @mod(@as(i16, note.midi) - self.tonic.midi, c.sem_per_oct);
        return for (self.scale_type.intervals) |interval| {
            if (interval.semitones() == semitones) break true;
        } else false;
    }

    // /// Find common tones between two scales
    // pub fn commonTones(self: Scale, other: Scale) Scale {}

    // pub fn commonTones(self: Scale, other: Scale, allocator: std.mem.Allocator) !Scale {
    //     var common_intervals = std.ArrayList(Interval).init(allocator);
    //     defer common_intervals.deinit();

    //     for (self.scale_type.intervals) |interval| {
    //         const note = try interval.applyTo(self.tonic);
    //         if (other.contains(note)) {
    //             try common_intervals.append(interval);
    //         }
    //     }

    //     return Scale.init(self.tonic, ScaleType.init(try common_intervals.toOwnedSlice(), "Common Tones"));
    // }

    // /// Find tones that are in one scale but not the other
    // pub fn uncommonTones(self: Scale, other: Scale) Scale {}

    // pub fn uncommonTones(self: Scale, other: Scale, allocator: std.mem.Allocator) !Scale {
    //     var uncommon_intervals = std.ArrayList(Interval).init(allocator);
    //     defer uncommon_intervals.deinit();

    //     for (self.scale_type.intervals) |interval| {
    //         const note = try interval.applyTo(self.tonic);
    //         if (!other.contains(note)) {
    //             try uncommon_intervals.append(interval);
    //         }
    //     }

    //     return Scale.init(self.tonic, ScaleType.init(try uncommon_intervals.toOwnedSlice(), "Uncommon Tones"));
    // }

    /// Transpose the scale by a given interval
    pub fn transpose(self: Scale, interval: Interval) !Scale {
        const new_tonic = try interval.applyTo(self.tonic);
        return Scale.init(new_tonic, self.scale_type);
    }

    /// Get the scale degree of a note (1-based, returns null if note is not in scale)
    pub fn degreeOf(self: Scale, note: Note) ?u8 {
        const semitones = @mod(@as(i16, note.midi) - self.tonic.midi, c.sem_per_oct);
        for (self.scale_type.intervals, 0..) |interval, i| {
            if (interval.semitones() == semitones) {
                return @intCast(i + 1);
            }
        }
        return null;
    }

    /// Get the note for a given scale degree (1-based)
    pub fn nthDegree(self: Scale, n: u8) !?Note {
        if (n == 0 or n > self.scale_type.intervals.len + 1) return null;
        if (n == 1) return self.tonic;
        return self.scale_type.intervals[n - 2].applyTo(self.tonic);
    }

    pub fn major(tonic: Note) Scale {
        return Scale.init(tonic, ScaleType.major);
    }

    pub fn naturalMinor(tonic: Note) Scale {
        return Scale.init(tonic, ScaleType.natural_minor);
    }

    /// Print all notes in the scale for debugging purposes
    pub fn debugPrint(self: Scale, allocator: std.mem.Allocator) !void {
        const scale_notes = try self.notes(allocator);
        defer allocator.free(scale_notes);

        std.debug.print("{} scale: ", .{self});
        for (scale_notes, 0..) |note, i| {
            if (i > 0) std.debug.print(", ", .{});
            std.debug.print("{}", .{note});
        }
        std.debug.print("\n", .{});
    }

    pub fn format(
        self: Scale,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{} {s}", .{ self.tonic, self.scale_type.name });
    }
};

test "creation and usage" {
    // const c4 = try Note.fromString("C4");
    // const db4 = try Note.fromString("Db4");

    // try Scale.major(c4).debugPrint(std.testing.allocator);
    // try Scale.major(db4).debugPrint(std.testing.allocator);
    // // Using direct initialization
    // const major_scale_db = Scale.init(db4, ScaleTypes.major);
    // try major_scale_db.debugPrint(std.testing.allocator);

    // const chromatic_scale_c = Scale.init(c4, ScaleTypes.chromatic);
    // try chromatic_scale_c.debugPrint(std.testing.allocator);

    // // Test note spelling
    // const f_sharp4 = try Note.fromString("F#4");
    // const g_flat4 = try Note.fromString("Gb4");

    // try std.testing.expectEqual(f_sharp4, try major_scale_c.getSpelling(f_sharp4));
    // try std.testing.expectEqual(f_sharp4, try major_scale_c.getSpelling(g_flat4));

    // // Test user-defined scale
    // const custom_intervals = &[_]Interval{ Interval.M2, Interval.M3, Interval.P5 };
    // const custom_scale_type = ScaleType.init(custom_intervals, "Custom");
    // const custom_scale = Scale.init(c4, custom_scale_type);
    // try custom_scale.debugPrint(std.testing.allocator);
}

// test "Scale additional methods" {
//     const allocator = std.testing.allocator;

//     const c4 = try Note.fromString("C4");
//     const f4 = try Note.fromString("F4");

//     const c_major = Scale.init(c4, ScaleTypes.major);
//     const f_major = Scale.init(f4, ScaleTypes.major);

//     // Test commonTones
//     const common = try c_major.commonTones(f_major, allocator);
//     defer allocator.free(common.scale_type.intervals);
//     try common.debugPrint(allocator);

//     // Test uncommonTones
//     const uncommon = try c_major.uncommonTones(f_major, allocator);
//     defer allocator.free(uncommon.scale_type.intervals);
//     try uncommon.debugPrint(allocator);

//     // Test transpose
//     const g_major = try c_major.transpose(Interval.P5);
//     try g_major.debugPrint(allocator);

//     // Test degreeOf
//     const e4 = try Note.fromString("E4");
//     try std.testing.expectEqual(@as(?u8, 3), c_major.degreeOf(e4));
//     try std.testing.expectEqual(@as(?u8, null), c_major.degreeOf(f4));

//     // Test nthDegree
//     const third_degree = try c_major.nthDegree(3);
//     try std.testing.expectEqual(e4, third_degree.?);
//     try std.testing.expectEqual(@as(?Note, null), try c_major.nthDegree(8));
// }

// const c4 = try Note.fromString("C4");

// // Create a C major scale using default options (interval-based spelling)
// const c_major_default = Scale.init(c4, ScaleType.major, .{});

// // Create a C major scale with key-based spelling
// const c_major_key = Scale.init(c4, ScaleType.major, .{
//     .spelling = Spelling.Context.init(.key_based).withTonality(Tonality.C),
// });

// // Create a scale with custom spelling function
// fn customSpelling(note: Note, scale: Scale) Note {
//     // Custom spelling logic here
//     return note;
// }
// const custom_scale = Scale.init(c4, ScaleType.major, .{
//     .spelling = Spelling.Context.init(.custom).withCustomFn(customSpelling),
// });

// // Test spelling
// const f_sharp4 = try Note.fromString("F#4");

// const spelled_default = try c_major_default.getSpelling(f_sharp4);
// const spelled_key = try c_major_key.getSpelling(f_sharp4);
// const spelled_custom = try custom_scale.getSpelling(f_sharp4);
