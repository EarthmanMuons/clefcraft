const std = @import("std");
const log = std.log.scoped(.piano);

const rl = @import("raylib");

const Coord = @import("coord.zig").Coord;
const KeySignature = @import("../theory/key_signature.zig").KeySignature;
const MidiOutput = @import("../midi/output.zig").MidiOutput;
const Mouse = @import("mouse.zig").Mouse;

const key_count = 88;
const key_spacing = 2;
const key_width_black = 16;
const key_width_white = 26;
const key_height_black = 100;
const key_height_white = 160;

pub const Piano = struct {
    keys: [key_count]Key,
    key_sig: KeySignature,
    pos: Coord,

    pub fn init(allocator: std.mem.Allocator, pos: Coord) !Piano {
        var keys = [_]Key{.{}} ** key_count;

        for (&keys, 0..) |*key, index| {
            key.is_black = isBlackKey(index);
            key.midi_number = 21 + @as(i32, @intCast(index)); // A0:21, C8:108
            key.pos = Coord{ .x = pos.x + getKeyX(index), .y = pos.y };
            key.width = if (key.is_black) key_width_black else key_width_white;
            key.height = if (key.is_black) key_height_black else key_height_white;
        }

        const default_key_sig = try KeySignature.init(
            allocator,
            .{ .letter = .c, .accidental = null },
            .major,
        );

        return Piano{ .keys = keys, .key_sig = default_key_sig, .pos = pos };
    }

    pub fn width(_: Piano) i32 {
        const key_count_white = 52;
        return key_count_white * (key_width_white + key_spacing) - key_spacing;
    }

    pub fn height(_: Piano) i32 {
        return key_height_white;
    }

    pub fn update(
        self: *Piano,
        mouse: Mouse,
        midi_output: *MidiOutput,
    ) !void {
        var focused_key: ?*Key = null;

        // Find the focused key, prioritizing black keys due to the overlap.
        for (&self.keys) |*key| {
            if (key.is_black and key.isFocused(mouse)) {
                focused_key = key;
                break;
            }
        }
        if (focused_key == null) {
            for (&self.keys) |*key| {
                if (!key.is_black and key.isFocused(mouse)) {
                    focused_key = key;
                    break;
                }
            }
        }

        // Update all of the key states.
        for (&self.keys) |*key| {
            switch (key.state) {
                .disabled => {
                    continue;
                },
                .normal => {
                    if (key == focused_key) {
                        key.state = .focused;
                    }
                },
                .focused => {
                    if (key != focused_key) {
                        key.state = .normal;
                    } else if (mouse.is_pressed_left) {
                        key.state = .pressed;
                    }
                },
                .pressed => {
                    if (!mouse.is_pressed_left) {
                        key.state = if (key == focused_key) .focused else .normal;
                    }
                },
            }

            // Handle MIDI events.
            switch (key.state) {
                .disabled => {
                    continue;
                },
                .pressed => {
                    if (key.state_prev != .pressed) {
                        log.debug("sending message note on for: {}", .{key.midi_number});
                        try midi_output.noteOn(1, @as(u7, @intCast(key.midi_number)), 112);
                    }
                },
                .focused => {
                    if (key.state_prev == .pressed) {
                        log.debug("sending message note off for: {}", .{key.midi_number});
                        try midi_output.noteOff(1, @as(u7, @intCast(key.midi_number)), 0);
                    }
                },
                .normal => {
                    if (key.state_prev == .pressed) {
                        log.debug("sending message note off for: {}", .{key.midi_number});
                        try midi_output.noteOff(1, @as(u7, @intCast(key.midi_number)), 0);
                    }
                },
            }

            // Update the previous key state.
            key.state_prev = key.state;
        }
    }

    pub fn draw(self: *const Piano) void {
        // Draw the white keys first, then the black keys on top.
        for (self.keys) |key| if (!key.is_black) key.draw(self.key_sig);
        for (self.keys) |key| if (key.is_black) key.draw(self.key_sig);

        // Draw subtle red key felt and a fade at the top of all keys.
        rl.drawRectangle(
            self.pos.x,
            self.pos.y,
            self.width(),
            3,
            rl.colorAlpha(rl.Color.maroon, 0.6),
        );
        rl.drawRectangleGradientV(
            self.pos.x,
            self.pos.y,
            self.width(),
            18,
            rl.colorAlpha(rl.Color.black, 0.6),
            rl.colorAlpha(rl.Color.black, 0.0),
        );
    }
};

const Key = struct {
    is_black: bool = false,
    midi_number: i32 = 0,
    state: KeyState = .normal,
    state_prev: KeyState = .normal,
    pos: Coord = .{ .x = 0, .y = 0 },
    width: i32 = 0,
    height: i32 = 0,

    fn color(self: Key) rl.Color {
        return switch (self.state) {
            .normal => if (self.is_black) rl.Color.black else rl.Color.white,
            .focused => if (self.is_black) rl.Color.gray else rl.Color.light_gray,
            .pressed => rl.Color.sky_blue,
            .disabled => if (self.is_black) rl.Color.dark_gray else rl.Color.gray,
        };
    }

    fn draw(self: Key, key_sig: KeySignature) void {
        const border_color = rl.Color.dark_gray;

        switch (self.state) {
            .normal, .disabled => {
                rl.drawRectangle(
                    self.pos.x,
                    self.pos.y,
                    self.width,
                    self.height,
                    self.color(),
                );
            },
            .focused, .pressed => {
                const gradient_color = if (self.is_black) rl.Color.black else rl.Color.white;
                rl.drawRectangleGradientV(
                    self.pos.x,
                    self.pos.y,
                    self.width,
                    self.height,
                    self.color(),
                    gradient_color,
                );
            },
        }
        rl.drawRectangleLines(
            self.pos.x,
            self.pos.y,
            self.width,
            self.height,
            border_color,
        );

        if (self.state == .pressed) {
            self.drawLabel(key_sig, rl.Color.black, true);
        } else if (self.isMiddleC()) {
            self.drawLabel(key_sig, rl.Color.light_gray, false);
        }
    }

    fn drawLabel(
        self: Key,
        key_sig: KeySignature,
        text_color: rl.Color,
        draw_background: bool,
    ) void {
        const note = key_sig.noteFromMidi(self.midi_number);
        const note_name = if (self.state != .pressed and self.isMiddleC()) "C4" else note.pitch.asText();

        // raylib's drawText() function requires a '0' sentinel.
        const note_name_z: [:0]const u8 = @ptrCast(note_name);

        const font_size = 17;
        const text_width = rl.measureText(note_name_z, font_size);

        const rect_width = text_width + 8; // add padding to sides
        const rect_height = 22;
        const rect_x = self.pos.x + @divFloor(self.width - rect_width, 2);
        const rect_y = self.pos.y + self.height - rect_height - 5;

        if (draw_background) {
            const rect = rl.Rectangle{
                .x = @floatFromInt(rect_x),
                .y = @floatFromInt(rect_y),
                .width = @floatFromInt(rect_width),
                .height = @floatFromInt(rect_height),
            };

            const roundness = 0.4;
            const segments = 4;
            rl.drawRectangleRounded(rect, roundness, segments, rl.Color.orange);
        }

        const text_x = rect_x + @divFloor(rect_width - text_width, 2);
        const text_y = (rect_y + (rect_height - font_size) / 2) + 1;
        rl.drawText(
            note_name_z,
            text_x,
            text_y,
            font_size,
            text_color,
        );
    }

    fn isFocused(self: Key, mouse: Mouse) bool {
        if (self.state == .disabled) {
            return false;
        }

        return mouse.pos.x >= self.pos.x and mouse.pos.x <= self.pos.x + self.width and
            mouse.pos.y >= self.pos.y and mouse.pos.y <= self.pos.y + self.height;
    }

    fn isMiddleC(self: Key) bool {
        return self.midi_number == 60;
    }
};

const KeyState = enum {
    normal,
    focused,
    pressed,
    disabled,
};

fn isBlackKey(index: usize) bool {
    return switch (index % 12) {
        1, 4, 6, 9, 11 => true,
        else => false,
    };
}

fn getKeyX(index: usize) i32 {
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

    return @as(i32, @intFromFloat(pos_x));
}
