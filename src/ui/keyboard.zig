const rl = @import("raylib");

const key_count = 88;
const key_spacing = 2;
const key_width_black = 16;
const key_width_white = 26;
const key_height_black = 100;
const key_height_white = 160;

pub const Keyboard = struct {
    keys: [key_count]Key,

    pub fn init() Keyboard {
        var keys = [_]Key{.{}} ** key_count;

        for (&keys, 0..) |*key, index| {
            key.is_black = isBlackKey(index);
            key.pos_x = @intFromFloat(getKeyX(index));
            key.pos_y = 0;
            key.width = if (key.is_black) key_width_black else key_width_white;
            key.height = if (key.is_black) key_height_black else key_height_white;
        }

        return Keyboard{ .keys = keys };
    }

    pub fn width(_: Keyboard) i32 {
        const key_count_white = 52;
        return key_count_white * (key_width_white + key_spacing) - key_spacing;
    }

    pub fn height(_: Keyboard) i32 {
        return key_height_white;
    }

    pub fn update(self: *Keyboard, mouse_x: i32, mouse_y: i32, is_mouse_pressed: bool) void {
        var hovered_key: ?*Key = null;

        // Find the hovered key, prioritizing black keys due to the overlap.
        for (&self.keys) |*key| {
            if (key.is_black and key.isHovered(mouse_x, mouse_y)) {
                hovered_key = key;
                break;
            }
        }
        if (hovered_key == null) {
            for (&self.keys) |*key| {
                if (!key.is_black and key.isHovered(mouse_x, mouse_y)) {
                    hovered_key = key;
                    break;
                }
            }
        }

        // Update all of the key states.
        for (&self.keys) |*key| {
            switch (key.state) {
                .released => {
                    if (key == hovered_key) {
                        key.state = .hovered;
                    }
                },
                .hovered => {
                    if (key != hovered_key) {
                        key.state = .released;
                    } else if (is_mouse_pressed) {
                        key.state = .pressed;
                    }
                },
                .pressed => {
                    if (!is_mouse_pressed) {
                        key.state = if (key == hovered_key) .hovered else .released;
                    }
                },
            }

            // TODO: Handle MIDI input and update key.state accordingly
        }
    }

    pub fn draw(self: *const Keyboard) void {
        // Draw the white keys first, then the black keys on top.
        for (self.keys) |key| if (!key.is_black) key.draw();
        for (self.keys) |key| if (key.is_black) key.draw();
    }
};

const Key = struct {
    is_black: bool = false,
    state: KeyState = .released,
    pos_x: i32 = 0,
    pos_y: i32 = 0,
    width: i32 = 0,
    height: i32 = 0,

    fn color(self: Key) rl.Color {
        return switch (self.state) {
            .released => if (self.is_black) rl.Color.black else rl.Color.white,
            .hovered => if (self.is_black) rl.Color.gray else rl.Color.light_gray,
            .pressed => rl.Color.sky_blue,
        };
    }

    fn draw(self: Key) void {
        if (self.state == .hovered) {
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
    released,
    hovered,
    pressed,
};

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

    // Center the black keys between the surrounding white keys.
    if (isBlackKey(index)) {
        pos_x -= (key_width_black + key_spacing) / 2.0;

        // Nudge group ends for a more realistic layout.
        pos_x += switch (index % 12) {
            1, 6 => 2,
            4, 9 => -2,
            else => 0,
        };
    }

    return pos_x;
}
