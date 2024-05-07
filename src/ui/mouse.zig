const rl = @import("raylib");

pub const Mouse = struct {
    pos_x: i32 = 0,
    pos_y: i32 = 0,
    is_pressed_left: bool = false,
    is_pressed_right: bool = false,

    pub fn update(self: *Mouse) void {
        self.pos_x = rl.getMouseX();
        self.pos_y = rl.getMouseY();
        self.is_pressed_left = rl.isMouseButtonDown(rl.MouseButton.mouse_button_left);
        self.is_pressed_right = rl.isMouseButtonPressed(rl.MouseButton.mouse_button_right);
    }
};
