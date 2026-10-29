# RTG output: showing a chunky frame through Picasso96

*Reading notes (Arnold, from the RTG framework "rtgfw" that ships in Arnold for the Amiga 1.2).* RTG (retargetable graphics) means showing the frame on a Picasso96 or CyberGraphX screen with the OS alive, instead of taking over the AGA chipset. On the PiStorm A1200 this is the VideoCore output under Picasso96; on BigMig it is the MiSTer RTG (untested so far); in WinUAE it is `uaegfx`. It is opt-in: AGA stays the default output. Times are per CPC frame on a PiStorm32 CM4 A1200 (Emu68, Picasso96 2.495, HDMI 1080p at 60 Hz). Chapter 10 describes the measuring method, and chapter 11 the machine.

The framework is a small C module (`rtgfw`, MIT licence) that Arnold vendors into its tree. Excerpts below are from it (MIT) or from Arnold (GPL-2.0).

## Why RTG: a direct chunky copy instead of chunky-to-planar

### The c2p was 4.3 ms of a 13 ms frame

**Problem.** Arnold draws a CPC frame as one byte per pixel (chunky). The AGA screen needs bitplanes, so each frame went through a chunky-to-planar (c2p) conversion into chip RAM: 4.3 ms a frame on the A1200 in Sonic GX, with 18 to 23 frames of 2250 over the 20 ms budget.

**Before** (AGA path, `Sys_ShowFrame`, Arnold-m68k 1.1): c2p of the changed lines into chip RAM, then a screen-buffer flip.

**After** (RTG path, Arnold 1.2): copy the changed chunky lines to the screen bitmap, one byte a pixel, with no conversion at all:

    /* rtgfw: path A, one 8-bit CLUT screen, only changed lines */
    rtg_set_palette(0, lo, n, colours, RTG_RGB24);   /* changed range only */
    rtg_present(chunky, pitch, line_dirty);          /* dirty lines under one lock */

*Source: Arnold 1.2, `arnold/src/amiga/amiga_sys.c`, RTG branch (GPL-2.0), calling rtgfw (MIT).*

**Why.** An RTG board's memory is not chip RAM. On the VideoCore it is ARM-side memory, written at CPU speed, and an 8-bit CLUT screen needs no conversion. A full CPC 384x272 frame copied in **0.16 ms** (16-bit 0.46 ms, 32-bit 0.44 ms; 37% dirty lines: 0.085 ms); the lock and unlock pair costs about 2 us.

**Evidence** (A1200, Sonic GX key script, SKIP=0, sound on, interleaved runs):

| | core | display part | work | frames > 20 ms |
|---|---|---|---|---|
| AGA (c2p) | 9.0 | 4.4 | 13.5 | 18 to 23 of 2250 |
| RTG, 1x picture | 8.9 | 0.28 | 9.2 | 0 |
| RTG, Hard 50% scanlines | 8.8 | 0.55 | 9.35 | 0 |

The core is the same in every run; only the display part changes. On the key script's spring frames (the whole picture moves) the display part is 0.32 ms against 4.5 ms.

**Look up.** rtgfw `BENCH-RESULTS.md`; Arnold `RTG-PILOT.md`; chapter 10 for the method.

## The 8-bit CLUT path and the palette index

### Keep the emulator's palette indices; load the palette once a frame

**Problem.** An RTG screen in 16 or 32 bits needs every pixel converted through a table, and a changed palette rewrites pixels. An 8-bit CLUT screen needs neither, but only if the whole frame fits one 256-entry palette.

**Approach.** Arnold already folds every mid-frame colour change (a CPC pen changed during the frame, even in the middle of a line) into its own palette index when it draws, so each frame is exact to the pixel and already fits one palette, usually under 64 entries. `Palette_Compact` in `render5.c` frees the entries and renumbers the 32 pens in pen order when an entry at 64 or above is taken, with the colours unchanged (only index numbers differ). The RTG path takes the chunky frame and that palette as they are:

- the changed range of the palette goes to the screen once a frame (`LoadRGB32`, via `rtg_set_palette`);
- the border is colour 0, painted around the picture;
- nothing is converted, and a palette change rewrites no pixels.

A per-line palette record would round raster splits to line starts and draw them wrongly, so none was added. Frames that do not fit (more than 256 distinct colours) would need a 16-bit path with per-line runs; rtgfw has it (`rtg_present_ex`) and it is tested, but no Arnold frame has needed it.

**Evidence.** Headless converter test on the core's own frames (Sonic GX 2300 frames and three other commercial-class games; 49 homebrew cartridges, 1500 frames each): the screen, decoded through the CLUT as the board holds it, against the AGA colours, **0 bad pixels** in 8-bit, 32-bit and RGB565 (compared at 565 precision), with lock failures injected every 61st frame. On the real A1200 and in WinUAE the RTG screen was read back in one lock and compared with Arnold's own frame: identical on every grab.

**Look up.** rtgfw `rtg_x_read_frame`; Arnold `tools/rtg/`; switches `RTGGRAB`, `RTGDEPTH`.

## Single buffer against ChangeScreenBuffer on the VideoCore

### Three screen buffers made every frame wait 8-9 ms

**Problem.** The AGA path uses three screen buffers and `ChangeScreenBuffer`, which returns at once. The same design on the A1200's RTG screen made `rtg_present` block for most of a frame, at every depth.

**Before** (`rtgfw.c`, rtgfw v0, 3 buffers): write the next buffer, then flip.

    /* present_common(), after the lines are written and unlocked */
    if (R.nbuf > 1 && !R.degraded) {
        if (ChangeScreenBuffer(R.scr, R.sb[b])) {
            R.safe_out[b] = R.disp_out[b] = 1;
            R.shown = b;
        } else R.st.flips_refused++;
    }

**After** (Arnold 1.2, `buffers = 1`): one screen bitmap, lines written straight into it under the lock, no flip:

    rtg_o.buffers = 1;              /* no AllocScreenBuffer, no ChangeScreenBuffer */
    ...
    rtg_present(chunky, pitch, line_dirty);   /* lock, write dirty lines, unlock */

*Source: rtgfw `src/rtgfw.c` (MIT); Arnold 1.2 `amiga_sys.c` RTG branch (GPL-2.0).*

**Why.** The VideoCore driver's `ChangeScreenBuffer` waits for the 60 Hz display flip inside the call. The copy (0.16 ms), the lock and the wait for the buffer messages together took under 0.7 ms; the rest was the flip.

**Evidence** (bench, A1200, CPC 384x272): 3 buffers, present blocked **8 to 9 ms** on average (min 1.4 ms, max 15.9 ms) at 8, 16 and 32 bit; `DispMessage`s arrived at 60.0 Hz. With one buffer a full-frame present was 0.29 ms (0.17 ms with nothing dirty), and in Arnold the RTG display part is 0.28 ms on average.

**Cost.** A single buffer written at any time can tear where the refresh crosses the copy. The next section removes that without a flip. In WinUAE `uaegfx` replies to the flip at once, so no such wait shows there: **measure on the real board.**

**A failed lock.** `p96LockBitMap` can fail, and the frame is then skipped. Arnold clears its dirty marks after every present, so the skipped frame's lines must stay owed inside the framework (`rtgc_skip`, commit 2d7d1af); before that fix a skip left a stale picture until the lines changed again. The headless test injects a failure every 61st frame to cover it.

**Look up.** rtgfw commit ab66e76 (bench results); `RTGBUF=3` in Arnold re-enables three buffers for tests.

## No tearing without a flip: write at the vertical blank

### Every flip and every pan spins until the blank

**Problem.** To stop tearing we tried the usual fixes on the A1200: the flip moved into its own task, and two pages swapped with `ScrollVPort`. Each one still cost the emulator a third of the CPU or more, or made frames late.

**Why.** The VideoCore driver busy-waits for the display's vertical blank inside `ChangeScreenBuffer` and inside a pan (`ScrollVPort`), and it holds the board while it spins. A bitmap lock in any other task waits for it. So a flip in a helper task still takes the CPU if the task runs above the emulator, and comes late if it runs below. Two details matter for the fix:
- the wait returns right at the start of the blank (bench: within -5 to +10 us of the predicted time);
- a second pan in the same blank returns in about 30 us, and a pan to the page already shown may return at once.

**Evidence** (rtgbench `FLIP`, A1200, 8-bit CPC frame, CPU left for a spin loop in the first 15 ms of each frame):

| Way to present | CPU left | Late or lost frames |
|---|---|---|
| Single buffer, written at once | 100% | none (but it can tear) |
| 3 buffers, `ChangeScreenBuffer` in the emulator task | 36-38% | none |
| Flip task at the emulator's priority +1 / 0 / -1 | 37% / 72% / 68% | at 0 and -1 |
| Vblank-timed single buffer (below) | 98-99% | none |

### Find the blank with a pan pair, then write just after it

**After** (rtgfw `RTG_F_VBLANK`, commit b25c230; Arnold 1.4 `RTGVBL`, on by default for RTG):

    /* the screen is opened two pages tall (SA_Height = 2 * h); page 1 is never meant to be seen */
    vt_pan_pair();        /* pan to page 1 (spins to the blank), then straight back (about 30 us) */
    ...                   /* 9 anchors 2 ms apart; steps may be 1-3 periods; period = shortest step */
    for (;;) {            /* task at the owner's priority +1 */
        vt_wait_until(next_blank + 50 us);
        write the staged dirty lines;   /* under a semaphore, 0.1-0.8 ms */
        load the CLUT if it changed;
        if (a second since the last anchor) re-anchor at next_blank - 300 us;
    }

*Source: rtgfw `src/rtgfw.c` (MIT).*

`rtg_present` itself only copies the emulator's dirty lines into a staging frame and signals the task.

**Why it works.** A CPC frame takes 0.1-0.8 ms to write and the display takes 16.7 ms to scan. Writing starts 50 us after the blank, so the copy stays ahead of the scan: each refresh shows a frame that is wholly old or wholly new. The pan pair marks the blank without the hidden page ever showing, because the pan back happens inside the same blank. The period is measured rather than assumed, so the same code follows a 50 Hz HDMI output.

**Evidence.**
- Bench: write 0.11-0.25 ms; at most 0.37 ms late; anchor error at most 14 us.
- Arnold, Sonic GX on the Plus, RTG with hard 50% scanlines, 2250 frames: core 8.88 ms (including the write task) against 8.55 ms with direct writes; present 0.25 ms against 0.55 ms; 0 frames over 16 ms.
- A tester compared the two on the same game and judged the vblank-timed mode the best of the set.
- At 1080p50 the period measured 19998 us. Sonic GX ran at 49.9 fps with core 9.03 ms and no frame over 16 ms. In 2250 frames the write was at most 0.94 ms late, and all 45 re-anchors were good (error at most 54 us).

**Cost.** One task, one staging frame the size of the picture, and about 0.3 ms a second for the re-anchor. No palette changes within a frame and no per-line flags in this mode. If calibration finds no steady period (WinUAE's `uaegfx` replies to a pan at once), the framework falls back to direct writes and logs it.

**Look up.** rtgfw `bench/panbench.c` (the pan timing parts) and rtgbench `FLIP`. In Arnold: `RTGVBL=0` for direct writes, and the log line `rtgfw: vblank timing: refresh ... us`.

## Read every mode

### Only the first 128 of 588 modes were looked at

**Problem.** On the A1200, no RTG mode above about 400x300 could be chosen, so the scanline screen could not open at 960x540, and Arnold's menu (which wants a 640-wide 8-bit mode) fell back to the AGA screen. It showed at the first double-click on the real machine; WinUAE, with fewer modes, was fine.

**Before** (`rtgfw.c` and Arnold's menu, 26 Oct 2026 morning): a fixed list of 128.

    #define MAXMODES 128
    ...
    while (nm < MAXMODES && (id = NextDisplayInfo(id)) != INVALID_ID)
        if (mode_info(id, &modes[nm]) && fmt_group(modes[nm].fmt)) nm++;

**After** (commit d465b66 / Arnold `Sys_RtgMenuMode`): room for all of them, allocated on the heap:

    #define MAXMODES 2048          /* VideoCore lists 588; the first 128 are the small ones */
    modes = malloc(MAXMODES * sizeof *modes);

*Source: rtgfw `src/rtgfw.c` (MIT); the same fix in Arnold 1.2 `amiga_sys.c` (GPL-2.0).*

**Why.** The VideoCore driver lists 577 RTG modes (588 in all), small ones first. A "should be enough" limit silently hid every big mode. `NextDisplayInfo` has no count, so the limit must be generous, and the code that picks a mode must say in the log how many it saw.

**Evidence.** `rtgbench MODES` on the A1200 lists 577 modes; the sizes of 768 wide or more are 768x432, 768x576, 796x448, 800x450, 800x480, 800x600, 848x480, 854x480, 960x540, 1024x768, 1280x720, 1366x768, 1600x900 and 1920x1200. After the fix the 960x540 mode opens, the menu opens on a 640-wide RTG mode, and the log line "N RTG modes listed" reads 577.

**Look up.** rtgfw commit d465b66; `results/MODES-a1200-*.txt`.

## Exact integer scaling and scanlines

### Pick the mode the board scales by exactly 2

**Problem.** The 1x picture (384x272) opens in the smallest mode that holds it, 400x300, and the board scales that to 1080p by a non-integer factor. A tester's verdict on the 1x RTG picture was "motion better, colour more intense, graphics blocky", and asked for scanline options, including a blended one like the MiSTer's.

**Approach.** A scanline needs the picture at an even scale, so every CPC pixel is 2x2 and every second row is the scanline. The A1200's HDMI output is 1080p. **960x540 is the only VideoCore mode it scales by exactly 2**, so every scanline comes out the same height. 768x576 scales by 1.875, 800x600 by 1.8 and 1280x720 by 1.5, which gives uneven, beating lines. 960x540 holds 384x270 pixels at 2x, so the top and bottom border line of the 272 are cut (the tallest game known draws rows 2 to 266). Without a 960x540 mode, the smallest mode of at least 768x544 is used, with all 272 lines.

**Hard scanlines: the bank of dimmed colours (8-bit).** The core uses CLUT entries 0 to 127. rtgfw keeps the dimmed copies of those 128 colours in entries 128 to 255, at 25, 50 or 75%. The scanline row is then the normal row with bit 7 set in every byte, which a long store does four pixels at a time:

**Before** (the first version, per-pixel word stores, 0.76 ms a frame).

**After** (`rtg_conv.c`, commit 60d7bf0, two sequential passes of long stores, 0.55 ms):

    /* CLUT8 hard, 2x2: the scanline row is the row | 0x80 per byte */
    for (x = w >> 1; x; x--) { uint32_t v = PAIR8(s[0], s[1]); s += 2; acc |= v; *p++ = v; }
    p = (uint32_t *)(d + dbpr); s = s0;
    for (x = w >> 1; x; x--) { *p++ = PAIR8(s[0], s[1]) | 0x80808080u; s += 2; }
    if (acc & 0x80808080u) c->high_lines++;     /* pens of 128 or more would show undimmed */

*Source: rtgfw `src/rtg_conv.c` (MIT).*

**Why.** The palette is loaded once a frame, as without scanlines, and no pixel is converted. Both rows are written in two sequential passes because the board takes sequential writes best: the same two rows written interleaved in one fused loop were faster for Hard (0.61 ms) but slower for the 32-bit blend (1.11 ms against 0.81 ms), so the framework writes row by row.

**Blended scanlines: the in-between row is an average (32-bit).** The row between two lines is h(upper) + h(lower), with h(c) = c x (100 - pct) / 200 per channel, from two half-dimmed table entries per pen. The sum has no carry between channels. An 8-bit CLUT cannot hold every pair of colours, so this needs a 16 or 32-bit screen. A changed line rewrites its own two rows and the blend row above it. A palette change rewrites the frame in 32-bit; that happened in 2 to 3% of frames in the test games.

**Evidence** (A1200, Sonic GX, RTG present per frame):

| Option | present (avg / worst) | written a frame |
|---|---|---|
| Off, 1x CLUT8 | 0.28 / 0.9 ms | 54 KB |
| Hard, 960x540 CLUT8 | 0.55 / 1.3-2.1 ms | 219 KB |
| Blended, BGRA32 | 0.81 / 1.8-2.9 ms | 916 KB |
| Blended, RGB565PC | 1.19 / 2.7 ms | 458 KB |

Blended in 32-bit is faster than in 16-bit even with twice the bytes: RGB565PC needs a byte swap per pixel. Sonic GX over 2250 frames: 0 frames over 20 ms in 14 of 15 runs. The scaling to 1080p costs the CPU nothing. The converter test (121 cases at 2x and 4x, every format, against a per-pixel reference) and a real-board read-back (lines 1 to 270, Hard and Blended) were exact.

**Look up.** rtgfw commits d465b66, 9550c4f, 60d7bf0; Arnold `SCANLINES.md`; switches `SCANLINES=`, `RTGDEPTH=16`, `SCANMODE=<w>x<h>`.

## Host pens over the picture and the dimmed bank

### An on-screen message drawn in pen 255 was black on an RTG screen with scanlines

**Problem.** On a tester's A1200, on the RTG screen with Hard scanlines (the Arnold RTG preset), the fast-forward symbol and the save state messages never appeared, although the log said `osd: >>` every time. On AGA, and on RTG without scanlines, they showed.

**Before** (`amiga_sys.h`, Arnold-m68k 1.4):

    #define SYS_OSD_PEN 255             /* palette entry the host keeps for the label (yellow) */

**After** (`amiga_sys.h`, commit 6c73e97):

    /* 127, not 255: on an 8-bit RTG screen with scanlines, entries 128-255 are the
     * dimmed copies of 0-127, so 255 showed as entry 127 dimmed */
    #define SYS_OSD_PEN 127

*Source: Arnold-m68k 1.5, `arnold/src/amiga/amiga_sys.h` (GPL-2.0, derived from Kevin Thacker's Arnold).*

**Why.** With Hard scanlines on an 8-bit CLUT screen the framework owns entries 128 to 255 (see "Hard scanlines: the bank of dimmed colours" above): entry 128 + i is entry i dimmed, and the framework loads those entries itself from 0 to 127. The host's yellow in entry 255 was never loaded; the screen showed the dimmed copy of entry 127, which nothing used, so black on black. Any pen the host draws over the picture (messages, labels, test overlays) must be below 128, and reserved in the emulator's palette so the core never hands it to a game colour (`Render_MarkPaletteEntryForHostUse`). The core compacts game colours below 64 at each frame's end, so a reserved 127 costs nothing. On AGA, and on RTG without scanlines, all 256 entries are the host's, which is why only this one setting showed it.

**Evidence.** WinUAE with uaegfx, 8-bit, Hard 50% scanlines (no 960x540 mode there, so 800x600 with the picture at 2x): a key script held the fast-forward key for 400 frames, and the window grabs show the yellow ">>" at the top left for the 1.2 s it was held, 1178 pixels in full yellow on the picture rows and 1178 in the dimmed yellow on the scanline rows. AGA and RTG without scanlines show it as before. On the A1200, pen 255 had shown nothing; the fixed build is still to be confirmed there.

**Look up.** Commit 6c73e97; `SYS_OSD_PEN`; rtgfw `rtgc_set_scan` and `rtgc_clut_colour` (`rtg_conv.c`); option `SCANLINES=`.

## Keeping the menu on RTG

### Open the next screen before closing the old one

**Problem.** With the emulation on RTG and the menu on the AGA screen (or Workbench in between), the picture leaves the RTG output at every Help or reload. To the user it looks like a crash.

**Rule.** Open the menu on an RTG screen too (the smallest 8-bit RTG mode at least 640x256, window centred), and from start-up, not only after the first game. Never leave RTG between screens:

- when the menu is reopened (Help, Continue, Power ON, Reset, loading media, Save Prefs), open the **new** screen first and close the old one after;
- file requesters and error requesters open on the RTG screen too (`ASLFR_Screen`, a requester window on the screen) so they do not drag the display back to Workbench;
- when the RTG screen fails, fall back to AGA once and say so in the menu's status line; do not retry on every Help;
- the setting persists until the user unticks it.

**Evidence.** WinUAE and A1200 runs of the menu (Help, Continue, Power ON, Exit) with a log of every screen open and close: 0 gaps where no screen was open, Exit back to Workbench, and the memory after the run not lower than before.

**Look up.** Arnold `menu_detach` / `menu_free` in `amiga_menu.c`; the `tools/rtg/screens_check.py` log checker.

## Pacing on the E-clock, never on the RTG refresh

**Rule.** Time the emulation exactly as on the AGA path, on the E-clock through `timer.device` (`UNIT_WAITECLOCK`), 50 or 60 Hz switchable at any time with no jump. Never wait for the RTG flip or refresh: Paula and the E-clock stay the master clock and the display must not stall them. A 50 Hz game on a 60 Hz HDMI output shows one frame in five twice, as it does on any 60 Hz AGA display (chapter 04).

**Evidence.** Bench, A1200: 50 Hz pacing standard deviation 4 us (worst 18 us); switching to 60 Hz with a screen open, 24 us (worst 120 us), 0 late frames. The native VBlank still runs under an RTG screen but the RTG screen has none of its own, so "follow the display" is forced to the emulated machine's rate in RTG mode.

A 50 Hz HDMI output removes the judder. On the test machine the Pi's `config.txt` now uses the Emu68 Imager's 1080p50 entry (`hdmi_group=1`, `hdmi_mode=31`), with `disable_overscan=1`. It affects Workbench and everything else. 60 Hz games then drop one frame in six instead. The vblank-timed writes measured the new 20 ms period by themselves.

## What a second emulator needs (AmiMSX)

AmiMSX, a takeover emulator that races the beam, would follow Arnold with a longer list, none of it framework work except the first two lines:

- **An OS-alive play loop.** No `COP1LC`, `BPLxPT`, `BEAMCON0`, `DMACON` display bits or `INTENA` takeover; interrupts stay on; exec vectors only through `AddIntServer` / `SetIntVector`; wait with `timer.device`. `rtg_present` and `rtg_wait_frame` are task-context only (not from a level-3 handler or the CPU core). This is the biggest change.
- **A chunky renderer per VDP mode** (and software sprites in each line) replacing the beam-bound display code. It also removes a whole class of "page switch shown a frame late" bugs, since the frame is complete before it is shown.
- **Palettes as banks.** MSX has at most 7 palettes of 16 colours a frame (an event applies from the next line), so index = 16 x bank + colour fits 256 entries; with even/odd bank sets (2 x 7 x 16) a new frame's CLUT load never changes colours the shown frame still uses. SCREEN 8 over SCREEN 5 needs 256 + 16 entries and a 16-bit run at the split line; YJK modes need a direct 16-bit line input.
- **The module form.** A LoadSeg-able library with a register-ABI jump table suits vasm. It is designed but not built.

## Pitfalls from this chapter

See the RTG items in [chapter 09](09-pitfalls.md#rtg-output).
