const std = @import("std");
const log = std.log.scoped(.tonality_selector);
const rl = @import("raylib");
const rg = @import("raygui");

const Coord = @import("coord.zig").Coord;
const Mouse = @import("mouse.zig").Mouse;
const Note = @import("../theory/note.zig").Note;
const Tonality = @import("../theory/tonality.zig").Tonality;

pub const TonalitySelector = struct {
    pos: Coord,
    selected_tonality: Tonality,

    const note_button_width = 40;
    const note_button_height = 40;
    const mode_button_width = 60;
    const mode_button_height = 40;
    const button_spacing = 2;
    const font_size = 20;

    const NoteButton = struct {
        label: [*:0]const u8,
        note: Note,
        x: i32,
        y: i32,
    };

    const ModeButton = struct {
        label: [*:0]const u8,
        mode: Tonality.Mode,
        x: i32,
        y: i32,
    };

    const buttons = blk: {
        @setEvalBranchQuota(3000);
        const sharps = [_]NoteButton{
            .{ .label = "C#", .note = .{ .midi = 61, .name = .{ .ltr = .c, .acc = .sharp } }, .x = 1, .y = 0 },
            .{ .label = "D#", .note = .{ .midi = 63, .name = .{ .ltr = .d, .acc = .sharp } }, .x = 2, .y = 0 },
            .{ .label = "F#", .note = .{ .midi = 66, .name = .{ .ltr = .f, .acc = .sharp } }, .x = 4, .y = 0 },
            .{ .label = "G#", .note = .{ .midi = 68, .name = .{ .ltr = .g, .acc = .sharp } }, .x = 5, .y = 0 },
            .{ .label = "A#", .note = .{ .midi = 70, .name = .{ .ltr = .a, .acc = .sharp } }, .x = 6, .y = 0 },
        };
        const naturals = [_]NoteButton{
            .{ .label = "C", .note = .{ .midi = 60, .name = .{ .ltr = .c, .acc = .natural } }, .x = 1, .y = 1 },
            .{ .label = "D", .note = .{ .midi = 62, .name = .{ .ltr = .d, .acc = .natural } }, .x = 2, .y = 1 },
            .{ .label = "E", .note = .{ .midi = 64, .name = .{ .ltr = .e, .acc = .natural } }, .x = 3, .y = 1 },
            .{ .label = "F", .note = .{ .midi = 65, .name = .{ .ltr = .f, .acc = .natural } }, .x = 4, .y = 1 },
            .{ .label = "G", .note = .{ .midi = 67, .name = .{ .ltr = .g, .acc = .natural } }, .x = 5, .y = 1 },
            .{ .label = "A", .note = .{ .midi = 69, .name = .{ .ltr = .a, .acc = .natural } }, .x = 6, .y = 1 },
            .{ .label = "B", .note = .{ .midi = 71, .name = .{ .ltr = .b, .acc = .natural } }, .x = 7, .y = 1 },
        };
        const flats = [_]NoteButton{
            .{ .label = "Cb", .note = .{ .midi = 59, .name = .{ .ltr = .c, .acc = .flat } }, .x = 0, .y = 2 },
            .{ .label = "Db", .note = .{ .midi = 61, .name = .{ .ltr = .d, .acc = .flat } }, .x = 1, .y = 2 },
            .{ .label = "Eb", .note = .{ .midi = 63, .name = .{ .ltr = .e, .acc = .flat } }, .x = 2, .y = 2 },
            .{ .label = "Gb", .note = .{ .midi = 66, .name = .{ .ltr = .g, .acc = .flat } }, .x = 4, .y = 2 },
            .{ .label = "Ab", .note = .{ .midi = 68, .name = .{ .ltr = .a, .acc = .flat } }, .x = 5, .y = 2 },
            .{ .label = "Bb", .note = .{ .midi = 70, .name = .{ .ltr = .b, .acc = .flat } }, .x = 6, .y = 2 },
        };
        break :blk sharps ++ naturals ++ flats;
    };

    const mode_buttons = [_]ModeButton{
        .{ .label = "Major", .mode = .major, .x = 8, .y = 0 },
        .{ .label = "Minor", .mode = .minor, .x = 8, .y = 1 },
    };

    pub fn init(pos: Coord, initial_tonality: Tonality) TonalitySelector {
        return .{
            .pos = pos,
            .selected_tonality = initial_tonality,
        };
    }

    pub fn update(self: *TonalitySelector, mouse: Mouse) void {
        for (buttons) |button| {
            if (self.isButtonClicked(button.x, button.y, mouse)) {
                self.selected_tonality.tonic = button.note;
                log.debug("tonality set to {} {s} ({}♯ / {}♭)", .{
                    button.note.fmtPitchClass(),
                    @tagName(self.selected_tonality.mode),
                    self.selected_tonality.accidentals().sharps,
                    self.selected_tonality.accidentals().flats,
                });
            }
        }

        for (mode_buttons) |button| {
            if (self.isModeButtonClicked(button.x, button.y, mouse)) {
                self.selected_tonality.mode = button.mode;
                log.debug("tonality set to {} {s} ({}♯ / {}♭)", .{
                    self.selected_tonality.tonic.fmtPitchClass(),
                    @tagName(button.mode),
                    self.selected_tonality.accidentals().sharps,
                    self.selected_tonality.accidentals().flats,
                });
            }
        }
    }

    pub fn draw(self: TonalitySelector) void {
        for (buttons) |button| {
            _ = self.drawNoteButton(button);
        }

        for (mode_buttons) |button| {
            _ = self.drawModeButton(button);
        }
    }

    fn drawNoteButton(self: TonalitySelector, button: NoteButton) bool {
        const x_offset: i32 = if (button.note.name.acc != .natural) note_button_width / 2 else 0;
        const x = self.pos.x + x_offset + @as(i32, @intCast(button.x)) * (note_button_width + button_spacing);
        const y = self.pos.y + @as(i32, @intCast(button.y)) * (note_button_height + button_spacing);

        const is_selected = self.selected_tonality.tonic.isEnharmonic(button.note) and
            (button.note.name.acc == self.selected_tonality.tonic.name.acc);

        const rect = rl.Rectangle{
            .x = @floatFromInt(x),
            .y = @floatFromInt(y),
            .width = note_button_width,
            .height = note_button_height,
        };

        if (is_selected) {
            rg.guiSetState(@intFromEnum(rg.GuiState.state_focused));
        } else {
            rg.guiSetState(@intFromEnum(rg.GuiState.state_normal));
        }

        // rg.guiSetStyle(rg.GuiControl.button, rg.GuiProperty.text_size, font_size);
        return rg.guiButton(rect, button.label) == 1;
    }

    fn drawModeButton(self: TonalitySelector, button: ModeButton) bool {
        const x_offset: i32 = note_button_width / 2;
        const x = self.pos.x + x_offset + @as(i32, @intCast(button.x)) * (note_button_width + button_spacing);
        const y_offset: i32 = mode_button_height / 2;
        const y = self.pos.y + y_offset + @as(i32, @intCast(button.y)) * (note_button_height + button_spacing);

        const is_selected = self.selected_tonality.mode == button.mode;

        const rect = rl.Rectangle{
            .x = @floatFromInt(x),
            .y = @floatFromInt(y),
            .width = mode_button_width,
            .height = mode_button_height,
        };

        if (is_selected) {
            rg.guiSetState(@intFromEnum(rg.GuiState.state_focused));
        } else {
            rg.guiSetState(@intFromEnum(rg.GuiState.state_normal));
        }

        // rg.guiSetStyle(@intFromEnum(rg.GuiControl.button), rg.GuiProperty.text_size, font_size);
        return rg.guiButton(rect, button.label) == 1;
    }

    fn isButtonClicked(self: TonalitySelector, x_index: i32, y_index: i32, mouse: Mouse) bool {
        const x_offset: i32 = if (y_index != 1) note_button_width / 2 else 0;
        const x = self.pos.x + x_offset + x_index * (note_button_width + button_spacing);
        const y = self.pos.y + y_index * (note_button_height + button_spacing);

        return mouse.is_pressed_left and
            mouse.pos.x >= x and
            mouse.pos.x <= x + note_button_width and
            mouse.pos.y >= y and
            mouse.pos.y <= y + note_button_height;
    }

    fn isModeButtonClicked(self: TonalitySelector, x_index: i32, y_index: i32, mouse: Mouse) bool {
        const x_offset: i32 = note_button_width / 2;
        const x = self.pos.x + x_offset + x_index * (note_button_width + button_spacing);
        const y_offset: i32 = mode_button_height / 2;
        const y = self.pos.y + y_offset + y_index * (note_button_height + button_spacing);

        return mouse.is_pressed_left and
            mouse.pos.x >= x and
            mouse.pos.x <= x + mode_button_width and
            mouse.pos.y >= y and
            mouse.pos.y <= y + mode_button_height;
    }
};
