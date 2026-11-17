# CD32 pad kit

A small, self-contained routine that reads a CD32 pad (or a pad adapter in its CD32 mode) by driving the joystick port directly. It is for programs that take over the machine, and for programs that run with the operating system but need a read that works on fast CPUs. The lessons behind it are in [chapter 05](../../chapters/05-input.md).

| File | What it is |
|---|---|
| `cd32pad.s` | 68000 asm (Devpac / vasm `-devpac` syntax). Written for the AmiMSX 4.x update (4.1.1 and later); it is not part of Juan Antonio Gómez Gálvez's original AmiMSX, which has no CD32 read. It reads port 2, port 1 or both in one call and returns 7 buttons as 1 = pressed. A plain joystick reads as `$00`. |
| `cd32read.s` | Two readers in one routine, from FAmiga 1.00 (Afrotechmods): `cd32pad.s` with the image clock, the 35-read latch, the two ID bits and a second clock, the "low clock", chosen per port. `cd32pads` is FAmiga's once-a-frame caller (interrupts off through exec, the plain-joystick rule). vasm Motorola syntax (`vasmm68k_mot -Fhunk`). See [Two readers, picked per port](#two-readers-picked-per-port). |
| `cd32pad.c`, `cd32pad.h` | The same protocol in C (amiga-gcc), from Arnold for the Amiga. It reads one port per call and returns 7 buttons plus the 2 ID bits. `cd32pad_dirs()` gives the directions. |
| `cd32test.c` | A Shell tool that prints the raw bits and the directions as they change: `cd32test [port] [seconds]`, port 2 by default. |
| `build.sh` | Builds `cd32test` with amiga-gcc and assemble-checks `cd32pad.s` with vasm. |

## How they have been tested

- **The asm read:** in AmiMSX with a KTRL CD32 pad, and this file on its own, called from a Shell tool with the operating system running, on a PiStorm A1200 with the KTRL in port 2 (red, blue and play each seen on their own).
- **The C read:** on the same A1200 and KTRL pad with `cd32test`: the ID bit at rest and each button on its own. This is the version with the volatile fix below; the first published version did not work (see the next section).
- **These standalone copies:** they build and assemble cleanly with no warnings. Run `cd32test` with your own pads before you depend on the read. A held button that shows as every bit at once means the pad is not in CD32 mode, or the read never put it there.

## The compiler trap in the C read

The NDK's `struct Custom` is not declared `volatile`. Written as `custom.potgo = 0x6f00` and `custom.potinp`, gcc -O2 removes the write that pulls pin 5 low (a later POTGO write overwrites it, so the compiler treats the first as dead), and reads POTINP once for all nine bits. The pad never enters CD32 mode, and a held button reads as every bit at once. The first version of this kit had that bug. The fix is one line, with every chip register then reached through it:

    #define CUSTOM ((volatile struct Custom *)&custom)

If you adapt the C, check the compiled code (`m68k-amigaos-objdump -d`) for the POTGO write and for one POTINP read per bit.

## Using it

Call the read once a frame, for a port the user has set to "CD32 pad". Reading twice a frame also works. Take the directions from `JOY0DAT`/`JOY1DAT` as usual; they read the same in both modes.

If the operating system is running, call the read with interrupts off, as `cd32pad.c` does, or allocate the pot bits with `potgo.resource` first. Do not fall back to lowlevel.library's `ReadJoyPort()` on a fast CPU: on a PiStorm it saw the pad but only ever reported red.

## Two readers, picked per port

No single read suits every pad. `cd32read.s` reads each port one of two ways in the same call:

- **The kit's reader** ("CD32 pad" in FAmiga's menu): pin 6 idles high and each clock pulse goes low, then high.
- **The low clock** ("KTRL CD32+"): pin 6 idles low and each pulse goes high, then low.

Call it with `d0.b` = the ports to read (bit 1 port 2, bit 0 port 1) and `d1.b` = the ones among them to read with the low clock. It returns nine bits a port in `d0.l`/`d1.l`: the seven buttons in this kit's order, then the pad's two ID bits (a CD32 pad answers bit 7 = 0, bit 8 = 1).

Results on real pads (JOYTEST in FAmiga 0.96/0.97):

| Pad | Kit's reader | Low clock |
|---|---|---|
| KTRL CD32 (first model) | right every time | about one read in four wrong |
| KTRL CD32+ | 12 wrong in 640, most passing the ID check | 0 wrong in 640 |
| Mega Multi adapter, CD32 mode, 3-button Mega Drive pad | wrong | right on B, C and A |

FAmiga also tried telling pads apart from their ID bits, and it was not reliable. So let the player choose the read per port, in the menu or the settings file, and say in the documentation to try the other one if a held button flickers or drops. Keep the kit's reader as the default.

`cd32read` changes since `cd32pad.s` (all explained in comments marked `[CHANGE n]` in the file):
- the image clock: pin 6 is written from a copy of the port byte instead of toggled with `eor` on the register, so FS-UAE and WinUAE's pad emulation can follow it;
- the latch wait is 35 CIA reads (about 50 µs, the C version's figure) instead of 200, and both waits are words in memory (`_cd32_latch`, `_cd32_clock`). **Set `_cd32_latch` to 200**: AmiGameBoy found a KTRL CD32 pad whose green, yellow and play buttons flicker at 35 and are solid at 200, and the Mega Multi adapter needs 200 with the low clock (chapter 05, [A pad test in every build](../../chapters/05-input.md#a-pad-test-in-every-build-amigameboy));
- the two ID bits are read too;
- the plain-joystick rule and the interrupt switch-off move to the caller (`cd32pads`).

The low clock's idea (pin 6 low before pin 5 falls, short high pulses, the ID bits checked after the buttons) came from Keir Fraser's Amiga Test Kit (`testkit/joymouse.c`, public domain) and AROS's lowlevel.library. No code was copied from either; the instructions are FAmiga's own.

## Licence

MIT, see [LICENSE](LICENSE). `cd32read.s`: FAmiga's changes and the `cd32pads` caller come with no conditions (Afrotechmods: "use them any way you like, no credit or licence needed"); the routine they change is this kit's, under its MIT licence. Crediting Afrotechmods and FAmiga is still the decent thing to do. Unlike the excerpts in the chapters, which keep their projects' terms, this kit may be used in any program. A credit in your documentation would be nice.
