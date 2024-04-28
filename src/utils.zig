const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.utils);

/// Wraps the value within the range [0, limit).
pub fn wrap(value: i32, limit: i32) i32 {
    return @mod(value + limit, limit);
}
