const rl = @import("raylib");

const MidiOutput = @import("midi/output.zig").MidiOutput;
const Piano = @import("ui/piano.zig").Piano;

pub fn main() !void {
    var piano = Piano.init();
    const screen_width = piano.width();
    const screen_height = piano.height() + 100;

    rl.setConfigFlags(.flag_window_highdpi);
    rl.initWindow(screen_width, screen_height, "ClefCraft");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    var midi_output = try MidiOutput.init("ClefCraft");
    defer midi_output.deinit();

    while (!rl.windowShouldClose()) {
        const mouse_x = rl.getMouseX();
        const mouse_y = rl.getMouseY();
        const is_mouse_pressed = rl.isMouseButtonDown(rl.MouseButton.mouse_button_left);

        try piano.update(mouse_x, mouse_y, is_mouse_pressed, &midi_output);

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.light_gray);

        piano.draw();
        rl.drawFPS(15, screen_height - 30);
    }
}

pub const MidiMessage = struct {
    status: u8,
    data1: u8,
    data2: u8,
};

// Send a Note On message.
pub fn noteOn(self: *MidiOutput, channel: u4, note: u7, velocity: u7) !void {
    const status = 0x90 | @as(u8, @intCast(channel));
    const data = [_]u8{ status, note, velocity };
    try self.sendMessage(&data);
}

// Send a Note Off message.
pub fn noteOff(self: *MidiOutput, channel: u4, note: u7, velocity: u7) !void {
    const status = 0x80 | @as(u8, @intCast(channel));
    const data = [_]u8{ status, note, velocity };
    try self.sendMessage(&data);
}
