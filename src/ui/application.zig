const std = @import("std");
const log = std.log.scoped(.application);

const Coord = @import("coord.zig").Coord;
const MidiInput = @import("../midi/input.zig").MidiInput;
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
    midi_input: MidiInput,

    pub fn init(padding: i32) !Application {
        const piano = try Piano.init(Coord{ .x = padding, .y = 156 });
        const tonality = Tonality.init(try Note.fromString("C4"), .major);
        const tonality_selector = TonalitySelector.init(Coord{ .x = padding, .y = 16 }, tonality);
        const midi_input = try MidiInput.init();

        return .{
            .piano = piano,
            .tonality = tonality,
            .tonality_selector = tonality_selector,
            .midi_input = midi_input,
        };
    }

    pub fn deinit(self: *Application) void {
        self.midi_input.deinit();
    }

    pub fn update(self: *Application, mouse: Mouse, midi_output: *MidiOutput) !void {
        self.tonality_selector.update(mouse);
        self.tonality = self.tonality_selector.selected_tonality;
        try self.piano.update(mouse, midi_output);
    }

    pub fn draw(self: *const Application) void {
        self.tonality_selector.draw();
        self.piano.draw(self.tonality);
    }

    pub fn setupMidiInput(self: *Application) !void {
        try self.midi_input.openPort(1, "ClefCraft Input");
        self.midi_input.setCallback(midiCallback, self);
        log.debug("MIDI input setup completed", .{});
    }

    fn midiCallback(timestamp: f64, message: []const u8, user_data: ?*anyopaque) void {
        _ = timestamp;
        const self: *Application = @ptrCast(@alignCast(user_data.?));

        if (message.len >= 3) {
            const status = message[0];
            const note: u7 = @truncate(message[1]);
            const velocity = message[2];

            log.debug("MIDI message: status={x:0>2}, note={}, velocity={}", .{ status, note, velocity });

            switch (status & 0xF0) {
                0x90 => { // Note On
                    self.piano.setKeyState(note, velocity > 0);
                },
                0x80 => { // Note Off
                    self.piano.setKeyState(note, false);
                },
                else => {
                    log.debug("Unhandled MIDI status: 0x{x:0>2}", .{status});
                },
            }
        } else {
            log.debug("Received incomplete MIDI message", .{});
        }
    }
};
