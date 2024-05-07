const rl = @import("raylib");

const Coord = @import("coord.zig").Coord;

pub const Mouse = struct {
    pos: Coord = .{ .x = 0, .y = 0 },
    is_pressed_left: bool = false,
    is_pressed_right: bool = false,

    pub fn update(self: *Mouse) void {
        self.pos.x = rl.getMouseX();
        self.pos.y = rl.getMouseY();
        self.is_pressed_left = rl.isMouseButtonDown(rl.MouseButton.mouse_button_left);
        self.is_pressed_right = rl.isMouseButtonPressed(rl.MouseButton.mouse_button_right);
    }
};
