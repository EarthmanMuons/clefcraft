const rl = @import("raylib");

const Keyboard = @import("ui/keyboard.zig").Keyboard;

pub fn main() !void {
    var keyboard = Keyboard.init();
    const screen_width = keyboard.width();
    const screen_height = keyboard.height() + 100;

    rl.initWindow(screen_width, screen_height, "ClefCraft");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        const mouse_x = rl.getMouseX();
        const mouse_y = rl.getMouseY();
        const is_mouse_pressed = rl.isMouseButtonDown(rl.MouseButton.mouse_button_left);

        keyboard.update(mouse_x, mouse_y, is_mouse_pressed);

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.light_gray);

        keyboard.draw();
        rl.drawFPS(15, screen_height - 30);
    }
}
