const Interval = @import("interval.zig").Interval;

pub const ScaleType = struct {
    intervals: []const Interval,
    name: []const u8,

    pub fn init(intervals: []const Interval, name: []const u8) ScaleType {
        return .{ .intervals = intervals, .name = name };
    }

    pub const major = init(&.{ Interval.M2, Interval.M3, Interval.P4, Interval.P5, Interval.M6, Interval.M7 }, "Major");
    pub const natural_minor = init(&.{ Interval.M2, Interval.m3, Interval.P4, Interval.P5, Interval.m6, Interval.m7 }, "Natural Minor");

    pub fn all() []const ScaleType {
        return &.{
            major,
            natural_minor,
        };
    }
};
