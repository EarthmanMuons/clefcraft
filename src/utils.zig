const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.utils);

const Letter = @import("pitch.zig").Letter;

pub fn letterDistance(start: Letter, target: Letter) i32 {
    const start_pos = @as(i32, @intCast(@intFromEnum(start)));
    const target_pos = @as(i32, @intCast(@intFromEnum(target)));
    const letter_count = @typeInfo(Letter).Enum.fields.len;

    return wrap(target_pos - start_pos, letter_count);
}

// Wraps the value within the range [0, limit).
pub fn wrap(value: i32, limit: i32) i32 {
    return @mod(value + limit, limit);
}

test "letterDistance()" {
    try std.testing.expectEqual(0, letterDistance(Letter.A, Letter.A));
    try std.testing.expectEqual(1, letterDistance(Letter.A, Letter.B));
    try std.testing.expectEqual(2, letterDistance(Letter.A, Letter.C));

    try std.testing.expectEqual(1, letterDistance(Letter.G, Letter.A));
    try std.testing.expectEqual(6, letterDistance(Letter.A, Letter.G));
    try std.testing.expectEqual(6, letterDistance(Letter.B, Letter.A));
}

test "wrap()" {
    try std.testing.expectEqual(0, wrap(0, 7));
    try std.testing.expectEqual(1, wrap(1, 7));
    try std.testing.expectEqual(2, wrap(2, 7));
    try std.testing.expectEqual(3, wrap(3, 7));
    try std.testing.expectEqual(4, wrap(4, 7));
    try std.testing.expectEqual(5, wrap(5, 7));
    try std.testing.expectEqual(6, wrap(6, 7));

    try std.testing.expectEqual(0, wrap(7, 7));
    try std.testing.expectEqual(1, wrap(8, 7));
    try std.testing.expectEqual(2, wrap(9, 7));

    try std.testing.expectEqual(6, wrap(-1, 7));
    try std.testing.expectEqual(5, wrap(-2, 7));
    try std.testing.expectEqual(4, wrap(-3, 7));
}
