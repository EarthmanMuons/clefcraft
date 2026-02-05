## ⚠️ Project Archived

ClefCraft is no longer actively developed.

It was an early exploration of Western music theory analysis, implemented as a
general-purpose library written in Zig, with the intention of eventually
layering a user interface on top.

That work has since been superseded by **WhatChord**, which carries forward the
same core goals in a fully realized, actively maintained mobile application.

👉 **WhatChord:** https://github.com/EarthmanMuons/whatchord

This repository is preserved for historical reference.

# ClefCraft

**Exploration of Western music theory concepts with [Zig][].**

[Zig]: https://ziglang.org/

---

![ClefCraft UI](screenshot.avif "User Interface")

## License

ClefCraft is released under the [Zero Clause BSD License][LICENSE] (SPDX: 0BSD).

Copyright &copy; 2024 [Aaron Bull Schaefer][EMAIL] and contributors

[LICENSE]: https://github.com/EarthmanMuons/clefcraft/blob/main/LICENSE
[EMAIL]: mailto:aaron@elasticdog.com

## Credits

Thank you to the following people:

- [@Not-Nik][] for the [raylib-zig][] bindings to the [raylib][] project, used
  for GUI (Graphical User Interface) support.

- [@ryleelyman][] for the [rtmidi_z][] bindings to the [RtMidi][] project, used
  for MIDI (Musical Instrument Digital Interface) support.

[@Not-Nik]: https://github.com/Not-Nik
[@ryleelyman]: https://github.com/ryleelyman
[raylib-zig]: https://github.com/Not-Nik/raylib-zig
[raylib]: https://github.com/raysan5/raylib
[RtMidi]: https://github.com/thestk/rtmidi
[rtmidi_z]: https://github.com/ryleelyman/rtmidi_z
