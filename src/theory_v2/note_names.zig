// This file contains lookup tables for various note naming systems.
// Each table is structured as follows:
//
// [7 x 5] array where:
// - Each row represents a letter (C, D, E, F, G, A, B)
// - Each column represents an accidental in this order:
//   2. Double Flat
//   3. Flat
//   4. Natural
//   5. Sharp
//   6. Double Sharp

pub const german = [_][]const u8{
    "Ceses", "Deses", "Eses",  "Feses", "Geses", "Ases",  "Heses",
    "Ces",   "Des",   "Es",    "Fes",   "Ges",   "As",    "B",
    "C",     "D",     "E",     "F",     "G",     "A",     "H",
    "Cis",   "Dis",   "Eis",   "Fis",   "Gis",   "Ais",   "His",
    "Cisis", "Disis", "Eisis", "Fisis", "Gisis", "Aisis", "Hisis",
};

pub const latin_ascii = [_][]const u8{
    "Cbb", "Dbb", "Ebb", "Fbb", "Gbb", "Abb", "Bbb",
    "Cb",  "Db",  "Eb",  "Fb",  "Gb",  "Ab",  "Bb",
    "C",   "D",   "E",   "F",   "G",   "A",   "B",
    "C#",  "D#",  "E#",  "F#",  "G#",  "A#",  "B#",
    "C##", "D##", "E##", "F##", "G##", "A##", "B##",
};

pub const latin_unicode = [_][]const u8{
    "C𝄫", "D𝄫", "E𝄫", "F𝄫", "G𝄫", "A𝄫", "B𝄫",
    "C♭",  "D♭",  "E♭",  "F♭",  "G♭",  "A♭",  "B♭",
    "C",     "D",     "E",     "F",     "G",     "A",     "B",
    "C♯",  "D♯",  "E♯",  "F♯",  "G♯",  "A♯",  "B♯",
    "C𝄪", "D𝄪", "E𝄪", "F𝄪", "G𝄪", "A𝄪", "B𝄪",
};

pub const solfege_ascii = [_][]const u8{
    "Dobb", "Rebb", "Mibb", "Fabb", "Solbb", "Labb", "Tibb",
    "Dob",  "Reb",  "Mib",  "Fab",  "Solb",  "Lab",  "Tib",
    "Do",   "Re",   "Mi",   "Fa",   "Sol",   "La",   "Ti",
    "Do#",  "Re#",  "Mi#",  "Fa#",  "Sol#",  "La#",  "Ti#",
    "Do##", "Re##", "Mi##", "Fa##", "Sol##", "La##", "Ti##",
};

pub const solfege_unicode = [_][]const u8{
    "Do𝄫", "Re𝄫", "Mi𝄫", "Fa𝄫", "Sol𝄫", "La𝄫", "Ti𝄫",
    "Do♭",  "Re♭",  "Mi♭",  "Fa♭",  "Sol♭",  "La♭",  "Ti♭",
    "Do",     "Re",     "Mi",     "Fa",     "Sol",     "La",     "Ti",
    "Do♯",  "Re♯",  "Mi♯",  "Fa♯",  "Sol♯",  "La♯",  "Ti♯",
    "Do𝄪", "Re𝄪", "Mi𝄪", "Fa𝄪", "Sol𝄪", "La𝄪", "Ti𝄪",
};
