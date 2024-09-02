const std = @import("std");

const Coord = @import("coord.zig").Coord;
const MidiOutput = @import("../midi/output.zig").MidiOutput;
const Mouse = @import("mouse.zig").Mouse;
const Note = @import("../theory/note.zig").Note;
const Piano = @import("piano.zig").Piano;
const Tonality = @import("../theory/tonality.zig").Tonality;
const TonalitySelector = @import("tonality_selector.zig").TonalitySelector;

pub const Application = struct {
    piano: Piano,
    tonality: Tonality,
    tonality_selector: TonalitySelector,

    pub fn init(padding: i32) !Application {
        const piano = try Piano.init(Coord{ .x = padding, .y = 100 });
        const tonality = Tonality.init(try Note.fromString("C4"), .major);
        const tonality_selector = TonalitySelector.init(Coord{ .x = padding, .y = 0 }, tonality);

        return .{
            .piano = piano,
            .tonality = tonality,
            .tonality_selector = tonality_selector,
        };
    }

    pub fn update(self: *Application, mouse: Mouse, midi_output: *MidiOutput) !void {
        self.tonality_selector.update(mouse);
        self.tonality = self.tonality_selector.selected_tonality;
        try self.piano.update(mouse, midi_output);
    }

    pub fn draw(self: Application) void {
        self.tonality_selector.draw();
        self.piano.draw(self.tonality);
    }
};
