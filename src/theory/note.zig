const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.note);
const testing = std.testing;

const note_names = @import("note_names.zig");

// The number of semitones per octave.
const pitch_classes = 12;

pub const Note = struct {
    letter: Letter,
    accidental: ?Accidental,

    pub fn pitchClass(self: Note) u4 {
        const base_class = switch (self.letter) {
            .c => 0,
            .d => 2,
            .e => 4,
            .f => 5,
            .g => 7,
            .a => 9,
            .b => 11,
        };
        const adjustment = if (self.accidental) |acc| acc.pitchAdjustment() else 0;

        const result = @mod(base_class + adjustment, pitch_classes);
        return @intCast(result);
    }

    pub fn toString(self: Note) []const u8 {
        return self.toCustomString(.{});
    }

    pub fn toCustomString(self: Note, options: StringOptions) []const u8 {
        const note_table = switch (options.naming) {
            .fixed_do => switch (options.encoding) {
                .ascii => &note_names.solfege_ascii,
                .unicode => &note_names.solfege_unicode,
            },
            .german => &note_names.german,
            .latin => switch (options.encoding) {
                .ascii => &note_names.latin_ascii,
                .unicode => &note_names.latin_unicode,
            },
        };

        const base_index = @as(usize, @intFromEnum(self.letter));
        const adjustment: usize = if (self.accidental) |acc| switch (acc) {
            .double_flat => 7,
            .flat => 14,
            .natural => 21,
            .sharp => 28,
            .double_sharp => 35,
        } else 0; // no accidental

        return note_table[base_index + adjustment];
    }

    pub fn format(
        self: Note,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        const str = self.toString();
        try writer.print("Note({s})", .{str});
    }
};

pub const Letter = enum { c, d, e, f, g, a, b };

pub const Accidental = enum {
    double_flat,
    flat,
    natural,
    sharp,
    double_sharp,

    pub fn pitchAdjustment(self: Accidental) i8 {
        return switch (self) {
            .double_flat => -2,
            .flat => -1,
            .natural => 0,
            .sharp => 1,
            .double_sharp => 2,
        };
    }

    pub fn fromString(str: []const u8) !Accidental {
        const AccidentalMapping = struct {
            symbols: []const []const u8,
            accidental: Accidental,
        };

        const mappings = [_]AccidentalMapping{
            .{ .symbols = &[_][]const u8{""}, .accidental = null },
            .{ .symbols = &[_][]const u8{ "𝄫", "bb" }, .accidental = .double_flat },
            .{ .symbols = &[_][]const u8{ "♭", "b" }, .accidental = .flat },
            .{ .symbols = &[_][]const u8{ "♮", "n" }, .accidental = .natural },
            .{ .symbols = &[_][]const u8{ "♯", "#" }, .accidental = .sharp },
            .{ .symbols = &[_][]const u8{ "𝄪", "x", "##" }, .accidental = .double_sharp },
        };

        for (mappings) |mapping| {
            for (mapping.symbols) |symbol| {
                if (std.mem.eql(u8, str, symbol)) {
                    return mapping.accidental;
                }
            }
        }

        return error.InvalidAccidental;
    }
};

pub const StringOptions = struct {
    naming: NamingSystem = .latin,
    encoding: Encoding = .unicode,
};

pub const NamingSystem = enum {
    fixed_do,
    german,
    latin,
};

pub const Encoding = enum {
    ascii,
    unicode,
};

test "Note.toString - default options" {
    const note1 = Note{ .letter = .a, .accidental = null };
    const note2 = Note{ .letter = .b, .accidental = .flat };
    const note3 = Note{ .letter = .c, .accidental = .sharp };
    const note4 = Note{ .letter = .d, .accidental = .natural };

    try testing.expectEqualStrings("A", note1.toString());
    try testing.expectEqualStrings("B♭", note2.toString());
    try testing.expectEqualStrings("C♯", note3.toString());
    try testing.expectEqualStrings("D♮", note4.toString());
}
