const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.scale);
const testing = std.testing;

const Interval = @import("interval.zig").Interval;

pub const Scale = struct {};
