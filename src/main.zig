const std = @import("std");

const rl = @import("raylib");

const Application = @import("ui/application.zig").Application;
const Coord = @import("ui/coord.zig").Coord;
const MidiOutput = @import("midi/output.zig").MidiOutput;
const Mouse = @import("ui/mouse.zig").Mouse;

const padding = 16; // pixels

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var mouse: Mouse = .{};
    var app = try Application.init(allocator, padding);
    const app_name = "ClefCraft";

    var midi_output = try MidiOutput.init(app_name);
    defer midi_output.deinit();

    const window_width = app.piano.width() + (padding * 2);
    const window_height = app.piano.height() + 140;

    rl.setConfigFlags(.flag_window_highdpi);
    rl.initWindow(window_width, window_height, app_name);
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        mouse.update();
        try app.update(mouse, &midi_output);

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.light_gray);
        app.draw();
        rl.drawFPS(padding, window_height - 29);
    }
}
