const std = @import("std");
const rtmidi = @import("rtmidi");

pub const MidiInput = struct {
    midi_in: *rtmidi.In,
    callback_fn: ?*const fn (f64, []const u8, ?*anyopaque) void,

    pub fn init() !MidiInput {
        var midi_in = rtmidi.In.createDefault() orelse return error.MidiInCreateFailed;
        errdefer midi_in.destroy();

        return MidiInput{
            .midi_in = midi_in,
            .callback_fn = null,
        };
    }

    pub fn deinit(self: *MidiInput) void {
        self.midi_in.destroy();
    }

    pub fn openPort(self: *MidiInput, port: usize, port_name: [:0]const u8) !void {
        self.midi_in.openPort(port, port_name);
    }

    pub fn setCallback(self: *MidiInput, comptime callback: fn (f64, []const u8, ?*anyopaque) void, user_data: ?*anyopaque) void {
        self.callback_fn = callback;
        self.midi_in.setCallback(callback, user_data);
    }

    pub fn cancelCallback(self: *MidiInput) void {
        self.midi_in.cancelCallback();
        self.callback_fn = null;
    }
};
