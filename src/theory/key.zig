const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.key);

const Note = @import("note.zig").Note;

pub const Key = struct {
    tonic: Note,
    mode: KeyMode,
};

pub const KeyMode = enum {
    major,
    minor,
};
