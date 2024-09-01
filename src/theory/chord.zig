const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.chord);
const testing = std.testing;

const Note = @import("note.zig").Note;

pub const Chord = struct {
    root: Note,
};
