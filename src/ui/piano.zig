const std = @import("std");
const log = std.log.scoped(.piano);

const rl = @import("raylib");

const Coord = @import("coord.zig").Coord;
const MidiOutput = @import("../midi/output.zig").MidiOutput;
const Mouse = @import("mouse.zig").Mouse;
const Tonality = @import("../theory/tonality.zig").Tonality;

const key_count = 88;
const key_spacing = 2;
const key_width_black = 16;
const key_width_white = 26;
const key_height_black = 100;
const key_height_white = 160;

pub const Piano = struct {
    keys: [key_count]Key,
    pos: Coord,
    midi_key_states: [128]bool,

    pub fn init(pos: Coord) !Piano {
        var keys = [_]Key{.{}} ** key_count;
        const midi_number_a0 = 21; // the first key on a piano

        for (&keys, 0..) |*key, index| {
            key.midi_number = midi_number_a0 + @as(u7, @intCast(index));
            key.is_black = isBlackKey(index);
            key.pos = .{ .x = pos.x + getKeyX(index), .y = pos.y };
            key.width = if (key.is_black) key_width_black else key_width_white;
            key.height = if (key.is_black) key_height_black else key_height_white;
        }

        return Piano{
            .keys = keys,
            .pos = pos,
            .midi_key_states = [_]bool{false} ** 128,
        };
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
            const midi_pressed = self.midi_key_states[key.midi_number];
            const mouse_pressed = (key == focused_key and mouse.is_pressed_left);

            switch (key.state) {
                .disabled => continue,
                .normal => {
                    if (midi_pressed or mouse_pressed) {
                        key.state = .pressed;
                    } else if (key == focused_key) {
                        key.state = .focused;
                    }
                },
                .focused => {
                    if (midi_pressed or mouse_pressed) {
                        key.state = .pressed;
                    } else if (key != focused_key) {
                        key.state = .normal;
                    }
                },
                .pressed => {
                    if (!midi_pressed and !mouse_pressed) {
                        key.state = if (key == focused_key) .focused else .normal;
                    }
                },
            }

            // Handle MIDI output events.
            if (key.state == .pressed and key.state_prev != .pressed) {
                log.debug("sending message note on for: {}", .{key.midi_number});
                try midi_output.noteOn(1, key.midi_number, 112);
            } else if (key.state != .pressed and key.state_prev == .pressed) {
                log.debug("sending message note off for: {}", .{key.midi_number});
                try midi_output.noteOff(1, key.midi_number, 0);
            }

            // Update the previous key state.
            key.state_prev = key.state;
        }
    }

    pub fn setKeyState(self: *Piano, midi_number: u7, is_pressed: bool) void {
        self.midi_key_states[midi_number] = is_pressed;
        log.debug("MIDI key state changed: number={}, pressed={}", .{ midi_number, is_pressed });
    }

    pub fn draw(self: *const Piano, tonality: Tonality) void {
        // Draw the white keys first, then the black keys on top.
        for (self.keys) |key| if (!key.is_black) key.draw(tonality);
        for (self.keys) |key| if (key.is_black) key.draw(tonality);

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
    midi_number: u7 = 0,
    is_black: bool = false,
    pos: Coord = .{ .x = 0, .y = 0 },
    width: i32 = 0,
    height: i32 = 0,
    state: State = .normal,
    state_prev: State = .normal,

    const State = enum {
        normal,
        focused,
        pressed,
        disabled,
    };

    pub fn setState(self: *Key, new_state: State) void {
        log.debug("Key state change: MIDI number={}, old state={}, new state={}", .{ self.midi_number, self.state, new_state });
        self.state_prev = self.state;
        self.state = new_state;
    }

    fn color(self: Key) rl.Color {
        return switch (self.state) {
            .normal => if (self.is_black) rl.Color.black else rl.Color.white,
            .focused => if (self.is_black) rl.Color.gray else rl.Color.light_gray,
            .pressed => rl.Color.sky_blue,
            .disabled => if (self.is_black) rl.Color.dark_gray else rl.Color.gray,
        };
    }

    fn draw(self: Key, tonality: Tonality) void {
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
            self.drawLabel(tonality, rl.Color.black, true);
        } else if (self.isMiddleC()) {
            self.drawLabel(tonality, rl.Color.light_gray, false);
        }
    }

    fn drawLabel(
        self: Key,
        tonality: Tonality,
        text_color: rl.Color,
        draw_background: bool,
    ) void {
        const note = tonality.spell(self.midi_number);

        // raylib's drawText() function requires a '0' sentinel.
        var note_name_buffer: [8]u8 = undefined;
        const note_name = if (self.state != .pressed and self.isMiddleC())
            std.fmt.bufPrintZ(&note_name_buffer, "C4", .{}) catch unreachable
        else
            std.fmt.bufPrintZ(&note_name_buffer, "{c}", .{note.fmtPitchClass()}) catch unreachable;

        const font_size = 17;
        const text_width = rl.measureText(note_name, font_size);

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
            note_name,
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
