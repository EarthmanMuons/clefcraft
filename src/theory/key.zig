const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.key);

const Note = @import("note.zig").Note;

pub const Key = struct {
    tonic: Note,
    mode: Mode,

    pub const Mode = enum {
        major,
        minor,
    };
};
