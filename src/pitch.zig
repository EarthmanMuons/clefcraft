const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.pitch);

const utils = @import("utils.zig");

const constants = @import("constants.zig");
const semitones_per_octave = constants.semitones_per_octave;

pub const Pitch = struct {
    letter: Letter,
    accidental: ?Accidental,

    // Creates a pitch from a pitch class using the default accidental mapping.
    // 0:C, 1:C♯, 2:D, 3:D♯, 4:E, 5:F, 6:F♯, 7:G, 8:G♯, 9:A, 10:A♯, 11:B
    pub fn fromPitchClass(pitch_class: i32) Pitch {
        const default_accidental: ?Accidental = switch (pitch_class) {
            1, 3, 6, 8, 10 => .Sharp,
            else => null,
        };

        return Pitch.fromPitchClassWithAccidental(pitch_class, default_accidental);
    }

    // Creates a pitch from a pitch class and an optional accidental.
    pub fn fromPitchClassWithAccidental(pitch_class: i32, accidental: ?Accidental) Pitch {
        assert(0 <= pitch_class and pitch_class < semitones_per_octave);

        const letter = Letter.fromPitchClass(pitch_class);
        return Pitch{ .letter = letter, .accidental = accidental };
    }

    // Returns the pitch class of the current pitch.
    pub fn pitchClass(self: Pitch) i32 {
        const base_pitch_class = self.letter.pitchClass();
        const adjustment = if (self.accidental) |acc| acc.pitchAdjustment() else 0;

        return utils.wrap(base_pitch_class + adjustment, semitones_per_octave);
    }

    // Formats the pitch as a string.
    pub fn format(
        self: Pitch,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try self.letter.format(fmt, options, writer);
        if (self.accidental) |acc| {
            try acc.format(fmt, options, writer);
        }
    }
};

pub const Letter = enum {
    A,
    B,
    C,
    D,
    E,
    F,
    G,

    // Creates a letter from the given pitch class.
    pub fn fromPitchClass(pitch_class: i32) Letter {
        assert(0 <= pitch_class and pitch_class < semitones_per_octave);

        return switch (pitch_class) {
            0...1 => .C,
            2...3 => .D,
            4 => .E,
            5...6 => .F,
            7...8 => .G,
            9...10 => .A,
            11 => .B,
            else => unreachable,
        };
    }

    // Returns the pitch class for the current letter.
    pub fn pitchClass(self: Letter) i32 {
        return switch (self) {
            .C => 0,
            .D => 2,
            .E => 4,
            .F => 5,
            .G => 7,
            .A => 9,
            .B => 11,
        };
    }

    // Creates a letter from the current letter and an offset value.
    pub fn offset(self: Letter, offset_val: i32) Letter {
        const start_val = @intFromEnum(self);
        const result = @mod(start_val + offset_val, 7);
        return @enumFromInt(result);
    }

    // Formats the letter as a string.
    pub fn format(
        self: Letter,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        const letter = switch (self) {
            .A => "A",
            .B => "B",
            .C => "C",
            .D => "D",
            .E => "E",
            .F => "F",
            .G => "G",
        };
        try writer.print("{s}", .{letter});
    }
};

pub const Accidental = enum {
    DoubleFlat,
    Flat,
    Natural,
    Sharp,
    DoubleSharp,

    // Returns a pitch adjustment based on the current accidental.
    pub fn pitchAdjustment(self: Accidental) i32 {
        return switch (self) {
            .DoubleFlat => -2,
            .Flat => -1,
            .Natural => 0,
            .Sharp => 1,
            .DoubleSharp => 2,
        };
    }

    pub fn fromPitchAdjustment(adjustment: i32) !?Accidental {
        return switch (adjustment) {
            -2 => .DoubleFlat,
            -1 => .Flat,
            0 => null,
            1 => .Sharp,
            2 => .DoubleSharp,
            else => return error.InvalidAdjustment,
        };
    }

    // Formats the accidental as a string.
    pub fn format(
        self: Accidental,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        const symbol = switch (self) {
            .DoubleFlat => "𝄫",
            .Flat => "♭",
            .Natural => "♮",
            .Sharp => "♯",
            .DoubleSharp => "𝄪",
        };
        try writer.print("{s}", .{symbol});
    }
};

test "offset()" {
    try std.testing.expectEqual(Letter.A, Letter.A.offset(0));
    try std.testing.expectEqual(Letter.B, Letter.A.offset(1));
    try std.testing.expectEqual(Letter.C, Letter.A.offset(2));
    try std.testing.expectEqual(Letter.A, Letter.A.offset(7));
    try std.testing.expectEqual(Letter.B, Letter.A.offset(8));
    try std.testing.expectEqual(Letter.C, Letter.B.offset(1));
    try std.testing.expectEqual(Letter.B, Letter.C.offset(-1));
    try std.testing.expectEqual(Letter.A, Letter.C.offset(-2));
}
