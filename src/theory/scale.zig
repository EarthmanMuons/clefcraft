const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.scale);
const testing = std.testing;

const c = @import("constants.zig");
const Interval = @import("interval.zig").Interval;
const Note = @import("note.zig").Note;

pub const Scale = struct {
    tonic: Note,
    tones: std.bit_set.IntegerBitSet(c.sem_per_oct),

    pub const Pattern = u12;

    /// Creates a scale from a tonic note and a set of intervals.
    pub fn init(tonic: Note, intervals: []const Interval) Scale {
        var tones = std.bit_set.IntegerBitSet(c.sem_per_oct).initEmpty();
        tones.set(0); // always include the tonic
        for (intervals) |interval| {
            const semitones = interval.semitones();
            tones.set(@intCast(semitones % c.sem_per_oct));
        }
        return .{ .tonic = tonic, .tones = tones };
    }

    /// Creates a scale from a tonic note and binary pattern.
    pub fn fromPattern(tonic: Note, pattern: Pattern) Scale {
        var tones = std.bit_set.IntegerBitSet(c.sem_per_oct).initEmpty();
        for (0..c.sem_per_oct) |i| {
            if ((pattern & (@as(Pattern, 1) << @intCast(i))) != 0) {
                tones.set(@intCast(i));
            }
        }
        return .{ .tonic = tonic, .tones = tones };
    }

    /// Returns all notes in the scale.
    pub fn notes(self: Scale, allocator: std.mem.Allocator) ![]Note {
        var result = std.ArrayList(Note).init(allocator);
        defer result.deinit();

        var iter = self.tones.iterator(.{});
        while (iter.next()) |semitone| {
            const note = Note.fromMidi(@intCast(@as(u8, self.tonic.midi) + semitone));
            try result.append(note);
        }

        // // alternate strategy
        // for (0..c.sem_per_oct) |semitones| {
        //     if (self.tones.isSet(@intCast(semitones))) {
        //         const note = try self.tonic.transposeBy(@intCast(semitones));
        //         try result.append(note);
        //     }
        // }

        return result.toOwnedSlice();
    }

    /// Returns the binary pattern representation of the scale.
    pub fn toPattern(self: Scale) Pattern {
        return @as(Pattern, self.tones.mask);
    }

    /// Checks if a note is in the scale.
    pub fn contains(self: Scale, note: Note) bool {
        const semitones = @mod(note.midi - self.tonic.midi, c.sem_per_oct);
        return self.tones.isSet(@intCast(semitones));
    }

    /// Get the name of the scale (if it's a common scale)
    pub fn name(self: Scale) ?[]const u8 {
        const scale_patterns = .{
            .{ Patterns.major, "Major" },
            // .{ Patterns.natural_minor, "Natural Minor" },
            .{ Patterns.whole_tone, "Whole Tone" },
            .{ Patterns.chromatic, "Chromatic" },
        };

        const rotated_pattern = std.math.rotl(Pattern, self.toPattern(), self.tonic.pitchClass());

        inline for (scale_patterns) |scale| {
            if (scale[0] == rotated_pattern) {
                return scale[1];
            }
        }

        return null;
    }

    /// Find common tones between two scales
    pub fn commonTones(self: Scale, other: Scale) Scale {
        var common = self.tones;
        common.setIntersection(other.tones);
        return .{ .tonic = self.tonic, .tones = common };
    }

    /// Find tones that are in one scale but not the other
    pub fn uncommonTones(self: Scale, other: Scale) Scale {
        var uncommon = self.tones;
        uncommon.toggleSet(other.tones);
        return .{ .tonic = self.tonic, .tones = uncommon };
    }

    /// Transpose the scale by a given interval
    pub fn transpose(self: Scale, interval: Interval) !Scale {
        const new_tonic = try interval.applyTo(self.tonic);
        return .{ .tonic = new_tonic, .tones = self.tones };
    }

    /// Get the scale degree of a note (1-based, returns null if note is not in scale)
    pub fn scaleDegree(self: Scale, note: Note) ?u4 {
        const semitones = @mod(@as(i16, note.midi) - self.tonic.midi, c.sem_per_oct);
        var degree: u4 = 1;

        var iter = self.tones.iterator(.{});
        while (iter.next()) |tone| {
            if (tone == semitones) {
                return degree;
            }
            degree += 1;
        }

        return null;
    }

    /// Get the note for a given scale degree (1-based)
    pub fn noteAtDegree(self: Scale, degree: u4) ?Note {
        if (degree == 0) return null;

        var current_degree: u4 = 1;
        var iter = self.tones.iterator(.{});
        while (iter.next()) |semitone| {
            if (current_degree == degree) {
                return Note.fromMidi(@intCast(@as(u8, self.tonic.midi) + semitone));
            }
            current_degree += 1;
        }

        return null;
    }

    /// Get the correct spelling for a note within the context of this scale
    pub fn getSpelling(self: Scale, note: Note, allocator: std.mem.Allocator) !Note {
        const semitones = @mod(@as(i16, note.midi) - self.tonic.midi, c.sem_per_oct);
        const scale_tones = try self.notes(allocator);
        defer allocator.free(scale_tones);

        for (scale_tones) |scale_note| {
            if (@mod(@as(i16, scale_note.midi) - self.tonic.midi, c.sem_per_oct) == semitones) {
                return scale_note;
            }
        }

        // If the note is not in the scale, return the original note
        return note;
    }

    // Pre-defined scale patterns, the least significant bit represents the lowest pitch class.
    pub const Patterns = struct {
        pub const major = 0b101010110101;
        pub const natural_minor = 0b010110101101;
        pub const whole_tone = 0b010101010101;
        pub const chromatic = 0b111111111111;
    };

    // Pre-defined scale constructors
    pub fn major(tonic: Note) Scale {
        return fromPattern(tonic, Patterns.major);
    }

    pub fn naturalMinor(tonic: Note) Scale {
        return fromPattern(tonic, Patterns.natural_minor);
    }

    pub fn wholeTone(tonic: Note) Scale {
        return fromPattern(tonic, Patterns.whole_tone);
    }

    pub fn chromatic(tonic: Note) Scale {
        return fromPattern(tonic, Patterns.chromatic);
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
        try writer.print("{} {?s}", .{ self.tonic, self.name() });
    }
};

test "Scale initialization and operations" {
    const c4 = try Note.fromString("C4");
    const major_scale = Scale.major(c4);
    try major_scale.debugPrint(std.testing.allocator);

    try testing.expectEqual(@as(Scale.Pattern, 0b101010110101), major_scale.toPattern());
    try testing.expectEqualStrings("Major", major_scale.name().?);

    try Scale.wholeTone(c4).debugPrint(std.testing.allocator);
    try Scale.chromatic(c4).debugPrint(std.testing.allocator);

    try Scale.chromatic(try Note.fromString("Db4")).debugPrint(std.testing.allocator);
    // const e4 = try Note.fromString("E4");
    // const g4 = try Note.fromString("G4");
    // const b4 = try Note.fromString("B4");

    // try testing.expect(major_scale.contains(c4));
    // try testing.expect(major_scale.contains(e4));
    // try testing.expect(major_scale.contains(g4));
    // try testing.expect(!major_scale.contains(b4));

    // try testing.expectEqual(@as(?u4, 1), major_scale.scaleDegree(c4));
    // try testing.expectEqual(@as(?u4, 3), major_scale.scaleDegree(e4));
    // try testing.expectEqual(@as(?u4, 5), major_scale.scaleDegree(g4));
    // try testing.expectEqual(@as(?u4, null), major_scale.scaleDegree(b4));

    // try testing.expectEqual(c4, major_scale.noteAtDegree(1).?);
    // try testing.expectEqual(e4, major_scale.noteAtDegree(3).?);
    // try testing.expectEqual(g4, major_scale.noteAtDegree(5).?);
    // try testing.expectEqual(@as(?Note, null), major_scale.noteAtDegree(8));

    // const a4 = try Note.fromString("A4");
    // const minor_scale = Scale.naturalMinor(a4);

    // const common = major_scale.commonTones(minor_scale);
    // try testing.expectEqual(@as(Scale.Pattern, 0b100001010100), common.toPattern());

    // const uncommon = major_scale.uncommonTones(minor_scale);
    // try testing.expectEqual(@as(Scale.Pattern, 0b001010000011), uncommon.toPattern());

    // const transposed = try major_scale.transpose(Interval.P5);
    // try testing.expectEqualStrings("Major", transposed.name().?);
    // try testing.expect(transposed.contains(try Note.fromString("G4")));

    // // Test note spelling
    // const allocator = std.testing.allocator;
    // const f_sharp = try Note.fromString("F#4");
    // const g_flat = try Note.fromString("Gb4");
    // try testing.expectEqual(f_sharp, try major_scale.getSpelling(f_sharp, allocator));
    // try testing.expectEqual(f_sharp, try major_scale.getSpelling(g_flat, allocator));
}

// test "Pre-defined scales" {
//     const c4 = try Note.fromString("C4");
//     const d4 = try Note.fromString("D4");
//     const e4 = try Note.fromString("E4");
//     const f4 = try Note.fromString("F4");
//     const g4 = try Note.fromString("G4");
//     const a4 = try Note.fromString("A4");
//     const b4 = try Note.fromString("B4");

//     const major = Scale.major(c4);
//     try testing.expectEqualStrings("Major", major.name().?);
//     try testing.expect(major.contains(c4) and major.contains(d4) and major.contains(e4) and
//         major.contains(f4) and major.contains(g4) and major.contains(a4) and
//         major.contains(b4));

//     const minor = Scale.naturalMinor(a4);
//     try testing.expectEqualStrings("Natural Minor", minor.name().?);
//     try testing.expect(minor.contains(a4) and minor.contains(b4) and minor.contains(c4) and
//         minor.contains(d4) and minor.contains(e4) and minor.contains(f4) and
//         minor.contains(g4));

//     const lydian = Scale.lydian(f4);
//     try testing.expectEqualStrings("Lydian", lydian.name().?);
//     try testing.expect(lydian.contains(f4) and lydian.contains(g4) and lydian.contains(a4) and
//         lydian.contains(b4) and lydian.contains(c4) and lydian.contains(d4) and
//         lydian.contains(e4));

//     // Add more tests for other pre-defined scales as needed
// }
