const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.pitch);

const utils = @import("utils.zig");

const letter_count = 7;
const semitones_per_octave = @import("constants.zig").music_theory.semitones_per_octave;

/// The chosen notational spelling for a pitch class.
///
/// Multiple distinct spellings can refer to the same pitch class, for example, F♯ and G♭.
pub const Pitch = struct {
    letter: Letter,
    accidental: ?Accidental,

    /// Creates a `Pitch` from a pitch class using the default accidental mapping.
    ///
    /// 0:C, 1:C♯, 2:D, 3:D♯, 4:E, 5:F, 6:F♯, 7:G, 8:G♯, 9:A, 10:A♯, 11:B
    pub fn fromPitchClass(pitch_class: i32) Pitch {
        assert(0 <= pitch_class and pitch_class < semitones_per_octave);

        const letter = Letter.fromPitchClass(pitch_class);
        const accidental: ?Accidental = switch (pitch_class) {
            1, 3, 6, 8, 10 => .sharp,
            else => null,
        };

        return Pitch{ .letter = letter, .accidental = accidental };
    }

    /// Returns the pitch class of the current `Pitch`.
    pub fn pitchClass(self: Pitch) i32 {
        const base_pitch_class = self.letter.pitchClass();
        const adjustment = if (self.accidental) |acc| acc.pitchAdjustment() else 0;

        return utils.wrap(base_pitch_class + adjustment, semitones_per_octave);
    }

    /// Returns a text representation of the current `Pitch` as a string.
    pub fn asText(self: Pitch) []const u8 {
        const pitch_names = [_][]const u8{
            "A",   "B",   "C",   "D",   "E",   "F",   "G",
            "Abb", "Bbb", "Cbb", "Dbb", "Ebb", "Fbb", "Gbb",
            "Ab",  "Bb",  "Cb",  "Db",  "Eb",  "Fb",  "Gb",
            "A#",  "B#",  "C#",  "D#",  "E#",  "F#",  "G#",
            "Ax",  "Bx",  "Cx",  "Dx",  "Ex",  "Fx",  "Gx",
        };

        const base_index = @as(usize, @intCast(@intFromEnum(self.letter)));

        var adjustment: usize = 0;
        if (self.accidental) |acc| {
            adjustment = switch (acc) {
                .natural => 0,
                .double_flat => 7,
                .flat => 14,
                .sharp => 21,
                .double_sharp => 28,
            };
        }

        return pitch_names[base_index + adjustment];
    }

    /// Renders a format string for the `Pitch` type.
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

/// The alphabetic label portion of a `Pitch`.
pub const Letter = enum {
    a,
    b,
    c,
    d,
    e,
    f,
    g,

    /// Returns a `Letter` based on the given pitch class.
    pub fn fromPitchClass(pitch_class: i32) Letter {
        assert(0 <= pitch_class and pitch_class < semitones_per_octave);

        return switch (pitch_class) {
            0, 1 => .c,
            2, 3 => .d,
            4 => .e,
            5, 6 => .f,
            7, 8 => .g,
            9, 10 => .a,
            11 => .b,
            else => unreachable,
        };
    }

    /// Returns the pitch class of the current `Letter`.
    pub fn pitchClass(self: Letter) i32 {
        return switch (self) {
            .c => 0,
            .d => 2,
            .e => 4,
            .f => 5,
            .g => 7,
            .a => 9,
            .b => 11,
        };
    }

    /// Returns a `Letter` that is offset from the current letter by the given amount.
    pub fn offsetBy(self: Letter, amount: i32) Letter {
        const current_idx = @intFromEnum(self);
        const result_idx = @mod(current_idx + amount, letter_count);
        return @enumFromInt(result_idx);
    }

    /// Returns a text representation of the current `Letter` as a string.
    pub fn asText(self: Letter) []const u8 {
        return switch (self) {
            .a => "A",
            .b => "B",
            .c => "C",
            .d => "D",
            .e => "E",
            .f => "F",
            .g => "G",
        };
    }

    /// Renders a format string for the `Letter` type.
    pub fn format(
        self: Letter,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        const output = self.asText();
        try writer.print("{s}", .{output});
    }
};

/// The optional symbol portion of a `Pitch`, which indicates a semitone alteration.
pub const Accidental = enum {
    double_flat,
    flat,
    natural,
    sharp,
    double_sharp,

    /// Returns a pitch adjustment based on the current `Accidental`.
    pub fn pitchAdjustment(self: Accidental) i32 {
        return switch (self) {
            .double_flat => -2,
            .flat => -1,
            .natural => 0,
            .sharp => 1,
            .double_sharp => 2,
        };
    }

    /// Returns an `Accidental` based on the given pitch adjustment.
    pub fn fromPitchAdjustment(adjustment: i32) !?Accidental {
        return switch (adjustment) {
            -2 => .double_flat,
            -1 => .flat,
            0 => null, // prefer no explicit natural symbol
            1 => .sharp,
            2 => .double_sharp,
            else => return error.InvalidAdjustment,
        };
    }

    /// Returns an ASCII text representation of the current `Accidental` as a string.
    pub fn asText(self: Accidental) []const u8 {
        return switch (self) {
            .double_flat => "bb",
            .flat => "b",
            .natural => "",
            .sharp => "#",
            .double_sharp => "##",
        };
    }

    /// Returns a Unicode symbol representation of the current `Accidental` as a string.
    pub fn asSymbol(self: Accidental) []const u8 {
        return switch (self) {
            .double_flat => "𝄫",
            .flat => "♭",
            .natural => "♮",
            .sharp => "♯",
            .double_sharp => "𝄪",
        };
    }

    /// Renders a format string for the `Accidental` type.
    pub fn format(
        self: Accidental,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        const output = self.asSymbol();
        try writer.print("{s}", .{output});
    }
};

pub fn distanceBetween(letter1: Letter, letter2: Letter) i32 {
    const pos1: i32 = @intFromEnum(letter1);
    const pos2: i32 = @intFromEnum(letter2);

    return utils.wrap(pos2 - pos1, letter_count);
}
