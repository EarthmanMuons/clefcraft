const Mouse = @import("mouse.zig").Mouse;
// const KeySignatures = @import("key_signatures.zig").KeySignatures;
// const Intervals = @import("intervals.zig").Intervals;
// const Scales = @import("scales.zig").Scales;
// const Chords = @import("chords.zig").Chords;

pub const Application = struct {
    state: State,

    pub const State = enum {
        key_signatures,
        intervals,
        scales,
        chords,
    };

    pub fn init() Application {
        return Application{ .state = .key_signatures };
    }

    pub fn update(self: *Application, mouse: Mouse) void {
        _ = self;
        _ = mouse;
    }

    // Draw the UI elements based on the current application state.
    pub fn draw(self: Application) void {
        _ = self;
        // switch (self.state) {
        //     .key_signatures => KeySignatures.draw(),
        //     .intervals => Intervals.draw(),
        //     .scales => Scales.draw(),
        //     .chords => Chords.draw(),
        // }
    }
};
