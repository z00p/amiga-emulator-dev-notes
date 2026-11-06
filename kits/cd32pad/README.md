# CD32 pad kit

A small, self-contained routine that reads a CD32 pad (or a pad adapter in its CD32 mode) by driving the joystick port directly. It is for programs that take over the machine, and for programs that run with the operating system but need a read that works on fast CPUs. The lessons behind it are in [chapter 05](../../chapters/05-input.md).

| File | What it is |
|---|---|
| `cd32pad.s` | 68000 asm (Devpac / vasm `-devpac` syntax), from AmiMSX 4.1.1 and later. It reads port 2, port 1 or both in one call and returns 7 buttons as 1 = pressed. A plain joystick reads as `$00`. |
| `cd32pad.c`, `cd32pad.h` | The same protocol in C (amiga-gcc), from Arnold for the Amiga. It reads one port per call and returns 7 buttons plus the 2 ID bits. `cd32pad_dirs()` gives the directions. |
| `cd32test.c` | A Shell tool that prints the raw bits and the directions as they change: `cd32test [port] [seconds]`, port 2 by default. |
| `build.sh` | Builds `cd32test` with amiga-gcc and assemble-checks `cd32pad.s` with vasm. |

## How they have been tested

- **The C read:** in Arnold on a PiStorm A1200 with a KTRL CD32 pad.
- **The asm read:** in AmiMSX, with a KTRL CD32 pad, an original CD32 pad and a Mega Multi adapter in CD32 mode.
- **These standalone copies:** they build and assemble cleanly with no warnings. Run `cd32test` with your own pads before you depend on the read.

## Using it

Call the read once a frame, for a port the user has set to "CD32 pad". Reading twice a frame also works. Take the directions from `JOY0DAT`/`JOY1DAT` as usual; they read the same in both modes.

If the operating system is running, call the read with interrupts off, as `cd32pad.c` does, or allocate the pot bits with `potgo.resource` first. Do not fall back to lowlevel.library's `ReadJoyPort()` on a fast CPU: on a PiStorm it saw the pad but only ever reported red.

## Licence

MIT, see [LICENSE](LICENSE). Unlike the excerpts in the chapters, which keep their projects' terms, this kit may be used in any program. A credit in your documentation would be nice.
