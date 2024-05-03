const rl = @import("raylib");

const Note = @import("../note.zig").Note;

const key_count = 88;
const key_spacing = 2;
const key_width_black = 16;
const key_width_white = 26;
const key_height_black = 100;
const key_height_white = 160;

pub const Piano = struct {
    keys: [key_count]Key,

    pub fn init() Piano {
        var keys = [_]Key{.{}} ** key_count;

        for (&keys, 0..) |*key, index| {
            key.is_black = isBlackKey(index);
            key.midi_number = 21 + @as(i32, @intCast(index)); // A0:21, C8:108
            key.pos_x = @intFromFloat(getKeyX(index));
            key.pos_y = 0;
            key.width = if (key.is_black) key_width_black else key_width_white;
            key.height = if (key.is_black) key_height_black else key_height_white;
        }

        return Piano{ .keys = keys };
    }

    pub fn width(_: Piano) i32 {
        const key_count_white = 52;
        return key_count_white * (key_width_white + key_spacing) - key_spacing;
    }

    pub fn height(_: Piano) i32 {
        return key_height_white;
    }

    pub fn update(self: *Piano, mouse_x: i32, mouse_y: i32, is_mouse_pressed: bool) void {
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

    pub fn draw(self: *const Piano) void {
        // Draw the white keys first, then the black keys on top.
        for (self.keys) |key| if (!key.is_black) key.draw();
        for (self.keys) |key| if (key.is_black) key.draw();
    }
};

const Key = struct {
    is_black: bool = false,
    midi_number: i32 = 0,
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
        const main_color = self.color();
        const border_color = rl.Color.dark_gray;

        switch (self.state) {
            .released => {
                rl.drawRectangle(self.pos_x, self.pos_y, self.width, self.height, main_color);
            },
            .hovered, .pressed => {
                const gradient_color = if (self.is_black) rl.Color.black else rl.Color.white;
                rl.drawRectangleGradientV(
                    self.pos_x,
                    self.pos_y,
                    self.width,
                    self.height,
                    main_color,
                    gradient_color,
                );
            },
        }
        rl.drawRectangleLines(self.pos_x, self.pos_y, self.width, self.height, border_color);

        // Label the key with the note name if it's pressed.
        if (self.state == .pressed) {
            const note = Note.fromMidi(self.midi_number);
            const note_name = note.pitch.asText();

            // raylib's drawText() function requires a '0' sentinel.
            const note_name_z: [:0]const u8 = @ptrCast(note_name);

            const rect_width = key_width_white - 2;
            const rect_height = 22;
            const rect_x = self.pos_x + @divFloor(self.width - rect_width, 2);
            const rect_y = self.pos_y + self.height - rect_height - 5;

            const rect = rl.Rectangle{
                .x = @floatFromInt(rect_x),
                .y = @floatFromInt(rect_y),
                .width = @floatFromInt(rect_width),
                .height = @floatFromInt(rect_height),
            };

            const roundness = 0.4;
            const segments = 4;
            rl.drawRectangleRounded(rect, roundness, segments, rl.Color.orange);

            const font_size = 14;
            const text_x = (rect_x + (rect_width - font_size) / 2) - 1;
            const text_y = (rect_y + (rect_height - font_size) / 2) + 1;
            rl.drawText(
                note_name_z,
                text_x,
                text_y,
                font_size,
                rl.Color.dark_gray,
            );
        }
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
