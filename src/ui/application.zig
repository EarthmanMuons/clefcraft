const std = @import("std");

const Coord = @import("coord.zig").Coord;
const MidiOutput = @import("../midi/output.zig").MidiOutput;
const Mouse = @import("mouse.zig").Mouse;
const Note = @import("../theory/note.zig").Note;
const Piano = @import("piano.zig").Piano;
const Tonality = @import("../theory/tonality.zig").Tonality;

pub const Application = struct {
    piano: Piano,
    state: State,
    tonality: Tonality,

    pub const State = enum {
        intervals,
        scales,
        chords,
    };

    pub fn init(padding: i32) !Application {
        const c_major = Tonality.init(try Note.fromString("C4"), .major);
        const piano = try Piano.init(Coord{ .x = padding, .y = 100 });

        return .{
            .piano = piano,
            .state = .chords,
            .tonality = c_major,
        };
    }

    pub fn update(self: *Application, mouse: Mouse, midi_output: *MidiOutput) !void {
        try self.piano.update(mouse, midi_output);
    }

    // Draw the UI elements based on the current application state.
    pub fn draw(self: Application) void {
        // switch (self.state) {
        //     .intervals => Intervals.draw(),
        //     .scales => Scales.draw(),
        //     .chords => Chords.draw(),
        // }

        self.piano.draw(self.tonality);
    }
};
