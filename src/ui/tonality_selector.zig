const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");

const Coord = @import("coord.zig").Coord;
const Mouse = @import("mouse.zig").Mouse;
const Note = @import("../theory/note.zig").Note;
const Tonality = @import("../theory/tonality.zig").Tonality;

pub const TonalitySelector = struct {
    pos: Coord,
    selected_tonality: Tonality,

    const button_width = 40;
    const button_height = 30;
    const button_spacing = 5;

    const NoteButton = struct {
        label: [*:0]const u8,
        note: Note,
    };

    const natural_notes = [_]NoteButton{
        .{ .label = "C", .note = .{ .midi = 60, .name = .{ .ltr = .c, .acc = .natural } } },
        .{ .label = "D", .note = .{ .midi = 62, .name = .{ .ltr = .d, .acc = .natural } } },
        .{ .label = "E", .note = .{ .midi = 64, .name = .{ .ltr = .e, .acc = .natural } } },
        .{ .label = "F", .note = .{ .midi = 65, .name = .{ .ltr = .f, .acc = .natural } } },
        .{ .label = "G", .note = .{ .midi = 67, .name = .{ .ltr = .g, .acc = .natural } } },
        .{ .label = "A", .note = .{ .midi = 69, .name = .{ .ltr = .a, .acc = .natural } } },
        .{ .label = "B", .note = .{ .midi = 71, .name = .{ .ltr = .b, .acc = .natural } } },
    };

    const sharp_notes = [_]NoteButton{
        .{ .label = "C#", .note = .{ .midi = 61, .name = .{ .ltr = .c, .acc = .sharp } } },
        .{ .label = "D#", .note = .{ .midi = 63, .name = .{ .ltr = .d, .acc = .sharp } } },
        .{ .label = "F#", .note = .{ .midi = 66, .name = .{ .ltr = .f, .acc = .sharp } } },
        .{ .label = "G#", .note = .{ .midi = 68, .name = .{ .ltr = .g, .acc = .sharp } } },
        .{ .label = "A#", .note = .{ .midi = 70, .name = .{ .ltr = .a, .acc = .sharp } } },
    };

    const flat_notes = [_]NoteButton{
        .{ .label = "Db", .note = .{ .midi = 61, .name = .{ .ltr = .d, .acc = .flat } } },
        .{ .label = "Eb", .note = .{ .midi = 63, .name = .{ .ltr = .e, .acc = .flat } } },
        .{ .label = "Gb", .note = .{ .midi = 66, .name = .{ .ltr = .g, .acc = .flat } } },
        .{ .label = "Ab", .note = .{ .midi = 68, .name = .{ .ltr = .a, .acc = .flat } } },
        .{ .label = "Bb", .note = .{ .midi = 70, .name = .{ .ltr = .b, .acc = .flat } } },
    };

    pub fn init(pos: Coord, initial_tonality: Tonality) TonalitySelector {
        return .{
            .pos = pos,
            .selected_tonality = initial_tonality,
        };
    }

    pub fn update(self: *TonalitySelector, mouse: Mouse) void {
        // Update natural note buttons
        for (natural_notes, 0..) |note_button, i| {
            if (self.isButtonClicked(@as(i32, @intCast(i)), 1, mouse)) {
                self.selected_tonality = Tonality.init(note_button.note, self.selected_tonality.mode);
            }
        }

        // Update sharp note buttons
        for (sharp_notes, 0..) |note_button, i| {
            if (self.isButtonClicked(@as(i32, @intCast(i)) * 2 + 1, 0, mouse)) {
                self.selected_tonality = Tonality.init(note_button.note, self.selected_tonality.mode);
            }
        }

        // Update flat note buttons
        for (flat_notes, 0..) |note_button, i| {
            if (self.isButtonClicked(@as(i32, @intCast(i)) * 2 + 1, 2, mouse)) {
                self.selected_tonality = Tonality.init(note_button.note, self.selected_tonality.mode);
            }
        }

        // Update major/minor toggle
        if (self.isButtonClicked(7, 1, mouse)) {
            self.selected_tonality = Tonality.init(self.selected_tonality.tonic, switch (self.selected_tonality.mode) {
                .major => .minor,
                .minor => .major,
            });
        }
    }

    pub fn draw(self: TonalitySelector) void {
        // Draw natural note buttons
        for (natural_notes, 0..) |note_button, i| {
            _ = self.drawButton(note_button, @as(i32, @intCast(i)), 1);
        }

        // Draw sharp note buttons
        for (sharp_notes, 0..) |note_button, i| {
            _ = self.drawButton(note_button, @as(i32, @intCast(i)) * 2 + 1, 0);
        }

        // Draw flat note buttons
        for (flat_notes, 0..) |note_button, i| {
            _ = self.drawButton(note_button, @as(i32, @intCast(i)) * 2 + 1, 2);
        }

        // Draw major/minor toggle
        _ = self.drawButton(.{
            .label = if (self.selected_tonality.mode == .major) "Major" else "Minor",
            .note = self.selected_tonality.tonic,
        }, 7, 1);
    }

    fn drawButton(self: TonalitySelector, note_button: NoteButton, x_index: i32, y_index: i32) bool {
        const x = self.pos.x + x_index * (button_width + button_spacing);
        const y = self.pos.y + y_index * (button_height + button_spacing);

        const is_selected = self.selected_tonality.tonic.isEnharmonic(note_button.note);

        const rect = rl.Rectangle{
            .x = @floatFromInt(x),
            .y = @floatFromInt(y),
            .width = button_width,
            .height = button_height,
        };

        if (is_selected) {
            rg.guiSetState(@intFromEnum(rg.GuiState.state_focused));
        } else {
            rg.guiSetState(@intFromEnum(rg.GuiState.state_normal));
        }

        return rg.guiButton(rect, note_button.label) == 1;
    }

    fn isButtonClicked(self: TonalitySelector, x_index: i32, y_index: i32, mouse: Mouse) bool {
        const x = self.pos.x + x_index * (button_width + button_spacing);
        const y = self.pos.y + y_index * (button_height + button_spacing);

        return mouse.is_pressed_left and
            mouse.pos.x >= x and
            mouse.pos.x <= x + button_width and
            mouse.pos.y >= y and
            mouse.pos.y <= y + button_height;
    }
};
