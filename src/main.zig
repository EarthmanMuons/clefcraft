const std = @import("std");

const rl = @import("raylib");
const rg = @import("raygui");

const Application = @import("ui/application.zig").Application;
const Coord = @import("ui/coord.zig").Coord;
const MidiOutput = @import("midi/output.zig").MidiOutput;
const Mouse = @import("ui/mouse.zig").Mouse;

const padding = 16; // pixels

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // const allocator = gpa.allocator();

    var mouse: Mouse = .{};
    // var app = try Application.init(allocator, padding);
    var app = try Application.init(padding);
    const app_name = "ClefCraft";

    try app.setupMidiInput();

    var midi_output = try MidiOutput.init(app_name);
    defer midi_output.deinit();

    const window_width = app.piano.width() + (padding * 2);
    const window_height = app.piano.height() + 196;

    rl.setConfigFlags(rl.ConfigFlags{ .window_highdpi = true });
    rl.initWindow(window_width, window_height, app_name);
    defer rl.closeWindow();

    // // Set the default font size for raygui.
    // rg.guiSetStyle(rg.GuiControl.default, @intFromEnum(rg.GuiDefaultProperty.text_size), 20);

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
