const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.pitch);

const Note = @import("note.zig").Note;

// Musical pitch representation using Scientific Pitch Notation.
pub const Pitch = struct {
    note: Note,
    octave: i8,
};
