const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.pitch);

const utils = @import("utils.zig");

const constants = @import("constants.zig");
const semitones_per_octave = constants.semitones_per_octave;

pub const Pitch = struct {
    letter: Letter,
    accidental: ?Accidental,

    // Creates a pitch from a pitch class.
    pub fn fromPitchClass(pitch_class: i32) Pitch {
        assert(0 <= pitch_class and pitch_class < semitones_per_octave);

        // Mapping of a pitch class to its default pitch.
        // 0:C, 1:C♯, 2:D, 3:D♯, 4:E, 5:F, 6:F♯, 7:G, 8:G♯, 9:A, 10:A♯, 11:B
        const mapping = [_]Pitch{
            Pitch{ .letter = .C, .accidental = null },
            Pitch{ .letter = .C, .accidental = Accidental.Sharp },
            Pitch{ .letter = .D, .accidental = null },
            Pitch{ .letter = .D, .accidental = Accidental.Sharp },
            Pitch{ .letter = .E, .accidental = null },
            Pitch{ .letter = .F, .accidental = null },
            Pitch{ .letter = .F, .accidental = Accidental.Sharp },
            Pitch{ .letter = .G, .accidental = null },
            Pitch{ .letter = .G, .accidental = Accidental.Sharp },
            Pitch{ .letter = .A, .accidental = null },
            Pitch{ .letter = .A, .accidental = Accidental.Sharp },
            Pitch{ .letter = .B, .accidental = null },
        };

        return mapping[@intCast(pitch_class)];
    }

    // Returns the pitch class of the pitch.
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

    // Returns the pitch class for the pitch letter.
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

    // Formats the pitch letter as a string.
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

    // Returns the pitch adjustment for the accidental.
    pub fn pitchAdjustment(self: Accidental) i32 {
        return switch (self) {
            .DoubleFlat => -2,
            .Flat => -1,
            .Natural => 0,
            .Sharp => 1,
            .DoubleSharp => 2,
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
