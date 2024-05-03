const rl = @import("raylib");

const Piano = @import("ui/piano.zig").Piano;

pub fn main() !void {
    var piano = Piano.init();
    const screen_width = piano.width();
    const screen_height = piano.height() + 100;

    rl.initWindow(screen_width, screen_height, "ClefCraft");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        const mouse_x = rl.getMouseX();
        const mouse_y = rl.getMouseY();
        const is_mouse_pressed = rl.isMouseButtonDown(rl.MouseButton.mouse_button_left);

        piano.update(mouse_x, mouse_y, is_mouse_pressed);

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.light_gray);

        piano.draw();
        rl.drawFPS(15, screen_height - 30);
    }
}
