const rl = @import("raylib");

const key_count = 88;
const key_spacing = 2;
const key_width_black = 16;
const key_width_white = 28;
const key_height_black = 100;
const key_height_white = 160;

pub fn main() anyerror!void {
    const key_count_white = 52;
    const screen_width = key_count_white * (key_width_white + key_spacing) - key_spacing;
    const screen_height = key_height_white + 100;

    rl.initWindow(screen_width, screen_height, "ClefCraft");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    var keys = [_]Key{.{}} ** key_count;

    for (&keys, 0..) |*key, index| {
        key.is_black = isBlackKey(index);
        key.pos_x = @intFromFloat(getKeyX(index));
        key.pos_y = 0;
        key.width = if (key.is_black) key_width_black else key_width_white;
        key.height = if (key.is_black) key_height_black else key_height_white;
    }

    while (!rl.windowShouldClose()) {
        const mouse_x = rl.getMouseX();
        const mouse_y = rl.getMouseY();
        const is_mouse_pressed = rl.isMouseButtonDown(rl.MouseButton.mouse_button_left);

        var hovered_key: ?*Key = null;

        // Find the hovered key, prioritizing black keys due to the overlap.
        for (&keys) |*key| {
            if (key.is_black and key.isHovered(mouse_x, mouse_y)) {
                hovered_key = key;
                break;
            }
        }

        if (hovered_key == null) {
            for (&keys) |*key| {
                if (!key.is_black and key.isHovered(mouse_x, mouse_y)) {
                    hovered_key = key;
                    break;
                }
            }
        }

        // Update all of the key states.
        for (&keys) |*key| {
            switch (key.state) {
                .Released => {
                    if (key == hovered_key) {
                        key.state = .Hovered;
                    }
                },
                .Hovered => {
                    if (key != hovered_key) {
                        key.state = .Released;
                    } else if (is_mouse_pressed) {
                        key.state = .Pressed;
                    }
                },
                .Pressed => {
                    if (!is_mouse_pressed) {
                        key.state = if (key == hovered_key) .Hovered else .Released;
                    }
                },
            }

            // TODO: Handle MIDI input and update key.state accordingly
        }

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.light_gray);
        rl.drawFPS(15, 200);

        // Draw the white keys first, then the black keys on top.
        for (&keys) |key| if (!key.is_black) key.draw();
        for (&keys) |key| if (key.is_black) key.draw();
    }
}

fn isBlackKey(index: usize) bool {
    return switch (index % 12) {
        1, 4, 6, 9, 11 => true,
        else => false,
    };
}

fn getKeyX(index: usize) f64 {
    var pos_x: f64 = 0;

    // Accumulate the width of white keys up to our index.
    for (0..index) |key| {
        if (!isBlackKey(key)) {
            pos_x += key_width_white + key_spacing;
        }
    }

    // Black keys are centered between the previous and next white key.
    if (isBlackKey(index)) {
        pos_x -= (key_width_black + key_spacing) / 2.0;
    }

    return pos_x;
}

const Key = struct {
    is_black: bool = false,
    state: KeyState = .Released,
    pos_x: i32 = 0,
    pos_y: i32 = 0,
    width: i32 = 0,
    height: i32 = 0,

    fn color(self: Key) rl.Color {
        return switch (self.state) {
            .Released => if (self.is_black) rl.Color.black else rl.Color.white,
            .Hovered => if (self.is_black) rl.Color.gray else rl.Color.light_gray,
            .Pressed => rl.Color.sky_blue,
        };
    }

    fn draw(self: Key) void {
        if (self.state == .Hovered) {
            if (self.is_black) {
                rl.drawRectangleGradientV(
                    self.pos_x,
                    self.pos_y,
                    self.width,
                    self.height,
                    self.color(),
                    rl.Color.black,
                );
            } else {
                rl.drawRectangleGradientV(
                    self.pos_x,
                    self.pos_y,
                    self.width,
                    self.height,
                    self.color(),
                    rl.Color.white,
                );
            }
        } else {
            rl.drawRectangle(self.pos_x, self.pos_y, self.width, self.height, self.color());
        }
        rl.drawRectangleLines(self.pos_x, self.pos_y, self.width, self.height, rl.Color.dark_gray);
    }

    fn isHovered(self: Key, mouse_x: i32, mouse_y: i32) bool {
        return mouse_x >= self.pos_x and mouse_x <= self.pos_x + self.width and
            mouse_y >= self.pos_y and mouse_y <= self.pos_y + self.height;
    }
};

const KeyState = enum {
    Released,
    Hovered,
    Pressed,
};
