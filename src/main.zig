const std = @import("std");

const rl = @import("raylib");

const Application = @import("ui/application.zig").Application;
const Coord = @import("ui/coord.zig").Coord;
const MidiOutput = @import("midi/output.zig").MidiOutput;
const Mouse = @import("ui/mouse.zig").Mouse;
const Piano = @import("ui/piano.zig").Piano;

const app_name = "ClefCraft";
const margin = 16;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var midi_output = try MidiOutput.init(app_name);
    defer midi_output.deinit();

    var mouse = Mouse{};
    var app = Application.init();
    var piano = try Piano.init(allocator, Coord{ .x = margin, .y = 100 });

    const screen_width = piano.width() + (margin * 2);
    const screen_height = piano.height() + 140;

    rl.setConfigFlags(.flag_window_highdpi);
    rl.initWindow(screen_width, screen_height, app_name);
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        mouse.update();
        app.update(mouse);
        try piano.update(mouse, &midi_output);

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.light_gray);

        app.draw();
        piano.draw();
        rl.drawFPS(margin, screen_height - 29);
    }
}
