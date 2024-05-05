pub const theory = struct {
    const chromatic_pitches = []const u8{
        "A",
        "A#",
        "Bb",
        "B",
        "C",
        "C#",
        "Db",
        "D",
        "D#",
        "Eb",
        "E",
        "F",
        "F#",
        "Gb",
        "G",
        "G#",
        "Ab",
    };

    const sharp_pitches = []const u8{
        "A",
        "A#",
        "B",
        "C",
        "C#",
        "D",
        "D#",
        "E",
        "F",
        "F#",
        "G",
        "G#",
    };

    const flat_pitches = [_][]const u8{
        "A",
        "Bb",
        "B",
        "C",
        "Db",
        "D",
        "Eb",
        "E",
        "F",
        "Gb",
        "G",
        "Ab",
    };

    pub const semitones_per_octave = 12;

    pub const notes_per_octave = 7;
};
