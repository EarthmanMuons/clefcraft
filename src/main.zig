const std = @import("std");

const rl = @import("raylib");

const Coord = @import("ui/coord.zig").Coord;
const MidiOutput = @import("midi/output.zig").MidiOutput;
const Piano = @import("ui/piano.zig").Piano;
const Mouse = @import("ui/mouse.zig").Mouse;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const piano_pos = Coord{ .x = 16, .y = 100 };
    var piano = try Piano.init(allocator, piano_pos);
    const screen_width = piano.width() + (piano_pos.x * 2);
    const screen_height = piano.height() + 140;

    rl.setConfigFlags(.flag_window_highdpi);
    rl.initWindow(screen_width, screen_height, "ClefCraft");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    var midi_output = try MidiOutput.init("ClefCraft");
    defer midi_output.deinit();

    var mouse = Mouse{};

    while (!rl.windowShouldClose()) {
        mouse.update();
        try piano.update(mouse, &midi_output);

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.light_gray);

        piano.draw();
        rl.drawFPS(16, screen_height - 29);
    }
}
