const std = @import("std");

const Coord = @import("coord.zig").Coord;
const MidiOutput = @import("../midi/output.zig").MidiOutput;
const Mouse = @import("mouse.zig").Mouse;
const Piano = @import("piano.zig").Piano;
const KeySignature = @import("../theory/key_signature.zig").KeySignature;
// const KeySignatures = @import("key_signatures.zig").KeySignatures;
// const Intervals = @import("intervals.zig").Intervals;
// const Scales = @import("scales.zig").Scales;
// const Chords = @import("chords.zig").Chords;

pub const Application = struct {
    state: State,
    key_sig: KeySignature,
    piano: Piano,

    pub const State = enum {
        key_signatures,
        intervals,
        scales,
        chords,
    };

    pub fn init(allocator: std.mem.Allocator, padding: i32) !Application {
        const key_sig = try KeySignature.init(
            allocator,
            .{ .letter = .c, .accidental = null },
            .major,
        );

        const piano = try Piano.init(Coord{ .x = padding, .y = 100 });

        return Application{
            .state = .key_signatures,
            .key_sig = key_sig,
            .piano = piano,
        };
    }

    pub fn update(self: *Application, mouse: Mouse, midi_output: *MidiOutput) !void {
        try self.piano.update(mouse, midi_output);
    }

    // Draw the UI elements based on the current application state.
    pub fn draw(self: Application) void {
        // switch (self.state) {
        //     .key_signatures => KeySignatures.draw(),
        //     .intervals => Intervals.draw(),
        //     .scales => Scales.draw(),
        //     .chords => Chords.draw(),
        // }

        self.piano.draw(self.key_sig);
    }
};
