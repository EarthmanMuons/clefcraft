const rtmidi = @import("rtmidi");

pub const MidiOutput = struct {
    output: ?*rtmidi.Out,

    pub fn init() !MidiOutput {
        var output = rtmidi.Out.createDefault() orelse return error.MidiOutFailed;
        output.openVirtualPort("ClefCraft");
        return MidiOutput{ .output = output };
    }

    pub fn deinit(self: *MidiOutput) void {
        if (self.output) |out| {
            out.closePort();
            out.destroy();
        }
    }

    pub fn noteOn(self: *MidiOutput, channel: u4, note: u7, velocity: u7) !void {
        if (self.output) |out| {
            const status = 0x90 | @as(u8, @intCast(channel));
            const data = [_]u8{ status, note, velocity };
            try out.sendMessage(&data);
        }
    }

    pub fn noteOff(self: *MidiOutput, channel: u4, note: u7, velocity: u7) !void {
        if (self.output) |out| {
            const status = 0x80 | @as(u8, @intCast(channel));
            const data = [_]u8{ status, note, velocity };
            try out.sendMessage(&data);
        }
    }
};
