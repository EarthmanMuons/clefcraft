const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.note);
const testing = std.testing;

const c = @import("constants.zig");

pub const Note = struct {
    midi: u7,
    name: Spelling,

    pub const Spelling = struct {
        let: Letter,
        acc: Accidental,
    };

    pub const Letter = enum { c, d, e, f, g, a, b };
    pub const Accidental = enum { double_flat, flat, natural, sharp, double_sharp };

    pub fn init(let: Letter, acc: Accidental, oct: i8) !Note {
        const base: i16 = switch (let) {
            .c => 0,
            .d => 2,
            .e => 4,
            .f => 5,
            .g => 7,
            .a => 9,
            .b => 11,
        };
        const offset: i16 = switch (acc) {
            .double_flat => -2,
            .flat => -1,
            .natural => 0,
            .sharp => 1,
            .double_sharp => 2,
        };
        const oct_semis = (@as(i16, oct) + 1) * c.semis_per_oct;
        const midi = base + offset + oct_semis;
        if (midi < 0 or midi > c.midi_max) {
            return error.NoteOutOfRange;
        }
        return .{ .midi = @intCast(midi), .name = .{ .let = let, .acc = acc } };
    }

    pub fn fromFrequency(freq: f64) Note {
        assert(freq > 0);
        const a4_freq = 440.0;
        const a4_midi = 69;
        const midi_float = a4_midi + c.semis_per_oct * @log2(freq / a4_freq);
        const midi: u7 = @intFromFloat(@round(midi_float));
        return Note.fromMidi(midi);
    }

    pub fn fromMidi(midi: u7) Note {
        return .{ .midi = midi, .name = spellWithSharps(midi) };
    }

    pub fn fromString(str: []const u8) !Note {
        if (str.len == 0) return error.EmptyString;

        var iter = (try std.unicode.Utf8View.init(str)).iterator();

        const let: Letter = switch (iter.nextCodepoint().?) {
            'C', 'c' => .c,
            'D', 'd' => .d,
            'E', 'e' => .e,
            'F', 'f' => .f,
            'G', 'g' => .g,
            'A', 'a' => .a,
            'B', 'b' => .b,
            else => return error.InvalidLetter,
        };

        var acc: Accidental = .natural;
        if (iter.nextCodepoint()) |cp| {
            switch (cp) {
                '𝄫' => acc = .double_flat,
                '♭', 'b' => {
                    acc = .flat;
                    if (iter.nextCodepoint()) |next_cp| {
                        if (next_cp == cp) {
                            acc = .double_flat;
                        } else {
                            // Move iterator back if it's not a double flat.
                            iter.i -= try std.unicode.utf8CodepointSequenceLength(next_cp);
                        }
                    }
                },
                '♯', '#' => {
                    acc = .sharp;
                    if (iter.nextCodepoint()) |next_cp| {
                        if (next_cp == cp) {
                            acc = .double_sharp;
                        } else {
                            // Move iterator back if it's not a double sharp.
                            iter.i -= try std.unicode.utf8CodepointSequenceLength(next_cp);
                        }
                    }
                },
                '𝄪', 'x' => acc = .double_sharp,
                else => {
                    // Move iterator back if it's not an accidental.
                    iter.i -= try std.unicode.utf8CodepointSequenceLength(cp);
                },
            }
        }

        const oct_str = str[iter.i..];
        if (oct_str.len == 0) return error.MissingOctave;

        const oct = std.fmt.parseInt(i8, oct_str, 10) catch return error.InvalidOctave;

        return Note.init(let, acc, oct);
    }

    pub fn frequency(self: Note) f64 {
        const a4_freq = 440.0;
        const a4_midi = 69;
        const midi: f64 = @floatFromInt(self.midi);
        return a4_freq * @exp2((midi - a4_midi) / c.semis_per_oct);
    }

    pub fn octave(self: Note) i8 {
        const oct = @divFloor(@as(i8, self.midi), c.semis_per_oct) - 1;

        // Handle octave boundary edge cases to maintain Scientific Pitch Notation.
        const offset: i8 = switch (self.name.acc) {
            .flat, .double_flat => if (self.name.let == .c) 1 else 0,
            .natural => 0,
            .sharp, .double_sharp => if (self.name.let == .b) -1 else 0,
        };

        return oct + offset;
    }

    pub fn pitchClass(self: Note) u4 {
        return @intCast(@mod(self.midi, c.semis_per_oct));
    }

    pub fn isEnharmonic(self: Note, other: Note) bool {
        return self.midi == other.midi;
    }

    pub fn spellWithSharps(midi: u7) Spelling {
        const pc = @mod(midi, c.semis_per_oct);
        return switch (pc) {
            0 => .{ .let = .c, .acc = .natural },
            1 => .{ .let = .c, .acc = .sharp },
            2 => .{ .let = .d, .acc = .natural },
            3 => .{ .let = .d, .acc = .sharp },
            4 => .{ .let = .e, .acc = .natural },
            5 => .{ .let = .f, .acc = .natural },
            6 => .{ .let = .f, .acc = .sharp },
            7 => .{ .let = .g, .acc = .natural },
            8 => .{ .let = .g, .acc = .sharp },
            9 => .{ .let = .a, .acc = .natural },
            10 => .{ .let = .a, .acc = .sharp },
            11 => .{ .let = .b, .acc = .natural },
            else => unreachable,
        };
    }

    pub fn spellWithFlats(midi: u7) Spelling {
        const pc = @mod(midi, c.semis_per_oct);
        return switch (pc) {
            0 => .{ .let = .c, .acc = .natural },
            1 => .{ .let = .d, .acc = .flat },
            2 => .{ .let = .d, .acc = .natural },
            3 => .{ .let = .e, .acc = .flat },
            4 => .{ .let = .e, .acc = .natural },
            5 => .{ .let = .f, .acc = .natural },
            6 => .{ .let = .g, .acc = .flat },
            7 => .{ .let = .g, .acc = .natural },
            8 => .{ .let = .a, .acc = .flat },
            9 => .{ .let = .a, .acc = .natural },
            10 => .{ .let = .b, .acc = .flat },
            11 => .{ .let = .b, .acc = .natural },
            else => unreachable,
        };
    }

    // pub fn respell(self: Note, ???) Note { }

    pub fn format(
        self: Note,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{c}{s}{d}", .{
            std.ascii.toUpper(@tagName(self.name.let)[0]),
            switch (self.name.acc) {
                .double_flat => "𝄫",
                .flat => "♭",
                .natural => "",
                .sharp => "♯",
                .double_sharp => "𝄪",
            },
            self.octave(),
        });
    }
};

test "initialization" {
    try testing.expectError(error.NoteOutOfRange, Note.init(.c, .flat, -1));
    try testing.expectEqual(0, (try Note.init(.c, .natural, -1)).midi);
    try testing.expectEqual(21, (try Note.init(.a, .natural, 0)).midi);
    try testing.expectEqual(58, (try Note.init(.c, .double_flat, 4)).midi);
    try testing.expectEqual(59, (try Note.init(.c, .flat, 4)).midi);
    try testing.expectEqual(60, (try Note.init(.c, .natural, 4)).midi);
    try testing.expectEqual(61, (try Note.init(.c, .sharp, 4)).midi);
    try testing.expectEqual(62, (try Note.init(.c, .double_sharp, 4)).midi);
    try testing.expectEqual(69, (try Note.init(.a, .natural, 4)).midi);
    try testing.expectEqual(108, (try Note.init(.c, .natural, 8)).midi);
    try testing.expectEqual(127, (try Note.init(.g, .natural, 9)).midi);
    try testing.expectError(error.NoteOutOfRange, Note.init(.g, .sharp, 9));
}

test "properties" {
    const c4 = try Note.init(.c, .natural, 4);
    try testing.expectEqual(Note.Letter.c, c4.name.let);
    try testing.expectEqual(Note.Accidental.natural, c4.name.acc);
    try testing.expectEqual(4, c4.octave());
    try testing.expectEqual(0, c4.pitchClass());

    const cs4 = try Note.init(.c, .sharp, 4);
    try testing.expectEqual(Note.Letter.c, cs4.name.let);
    try testing.expectEqual(Note.Accidental.sharp, cs4.name.acc);
    try testing.expectEqual(4, cs4.octave());
    try testing.expectEqual(1, cs4.pitchClass());

    const df4 = try Note.init(.d, .flat, 4);
    try testing.expectEqual(Note.Letter.d, df4.name.let);
    try testing.expectEqual(Note.Accidental.flat, df4.name.acc);
    try testing.expectEqual(4, df4.octave());
    try testing.expectEqual(1, df4.pitchClass());
}

test "basic parsing" {
    try testing.expectEqual(0, (try Note.fromString("C-1")).midi);
    try testing.expectEqual(60, (try Note.fromString("C4")).midi);
    try testing.expectEqual(69, (try Note.fromString("A4")).midi);
}

test "Unicode support" {
    try testing.expectEqual(58, (try Note.fromString("C𝄫4")).midi);
    try testing.expectEqual(58, (try Note.fromString("C♭♭4")).midi);
    try testing.expectEqual(59, (try Note.fromString("C♭4")).midi);
    try testing.expectEqual(61, (try Note.fromString("C♯4")).midi);
    try testing.expectEqual(62, (try Note.fromString("C♯♯4")).midi);
    try testing.expectEqual(62, (try Note.fromString("C𝄪4")).midi);
}

test "ASCII support" {
    try testing.expectEqual(58, (try Note.fromString("Cbb4")).midi);
    try testing.expectEqual(59, (try Note.fromString("Cb4")).midi);
    try testing.expectEqual(61, (try Note.fromString("C#4")).midi);
    try testing.expectEqual(62, (try Note.fromString("C##4")).midi);
    try testing.expectEqual(62, (try Note.fromString("Cx4")).midi);
}

test "parser error handling" {
    try testing.expectError(error.EmptyString, Note.fromString(""));
    try testing.expectError(error.InvalidLetter, Note.fromString("H4"));
    try testing.expectError(error.MissingOctave, Note.fromString("C"));
    try testing.expectError(error.InvalidOctave, Note.fromString("C#X"));
    try testing.expectError(error.NoteOutOfRange, Note.fromString("C-2"));
    try testing.expectError(error.NoteOutOfRange, Note.fromString("G10"));
}

test "frequencies" {
    const epsilon = 0.01;
    try testing.expectApproxEqAbs(8.175799, (try Note.init(.c, .natural, -1)).frequency(), epsilon);
    try testing.expectApproxEqAbs(27.50000, (try Note.init(.a, .natural, 0)).frequency(), epsilon);
    try testing.expectApproxEqAbs(261.6256, (try Note.init(.c, .natural, 4)).frequency(), epsilon);
    try testing.expectApproxEqAbs(440.0000, (try Note.init(.a, .natural, 4)).frequency(), epsilon);
    try testing.expectApproxEqAbs(4186.009, (try Note.init(.c, .natural, 8)).frequency(), epsilon);
    try testing.expectApproxEqAbs(12543.85, (try Note.init(.g, .natural, 9)).frequency(), epsilon);

    try testing.expectEqual(0, (Note.fromFrequency(8.175799).midi));
    try testing.expectEqual(21, (Note.fromFrequency(27.50000).midi));
    try testing.expectEqual(60, (Note.fromFrequency(261.6256).midi));
    try testing.expectEqual(69, (Note.fromFrequency(440.0000).midi));
    try testing.expectEqual(108, (Note.fromFrequency(4186.009).midi));
    try testing.expectEqual(127, (Note.fromFrequency(12543.85).midi));
}

test "formatting" {
    try testing.expectFmt("C𝄫4", "{}", .{try Note.init(.c, .double_flat, 4)});
    try testing.expectFmt("C♭4", "{}", .{try Note.init(.c, .flat, 4)});
    try testing.expectFmt("C4", "{}", .{try Note.init(.c, .natural, 4)});
    try testing.expectFmt("C♯4", "{}", .{try Note.init(.c, .sharp, 4)});
    try testing.expectFmt("C𝄪4", "{}", .{try Note.init(.c, .double_sharp, 4)});
}
