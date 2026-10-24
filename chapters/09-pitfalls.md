# Pitfalls checklist

One line per pitfall, with the lesson that explains it. Read the lesson before applying the line.

## Display

- A page or mode switch the game makes in the border must reach the copper list that is on screen, not only the next frame's list. Check it with a live-view freeze. ([A page switch shown a frame late (Barbarian's fighters vanish every second frame)](02-display-on-aga.md#a-page-switch-shown-a-frame-late-barbarians-fighters-vanish-every-second-frame))
- Put DDFSTRT on a fetch-unit boundary for the FMODE in use; a scroll that jumps by the fetch width is the symptom. ([The 32-bit fetch applies the scroll delay modulo 32, from the middle of a unit](02-display-on-aga.md#the-32-bit-fetch-applies-the-scroll-delay-modulo-32-from-the-middle-of-a-unit))
- Never derive a frame-wide register (the bitplane-enable word) from the last write of the emulated frame. Sample it where the display starts. ([One frame-wide register written by every R#1 write](02-display-on-aga.md#one-frame-wide-register-written-by-every-r1-write))
- Blank part of a frame by switching to a border-coloured palette bank, not by turning bitplane DMA off. ([Blanking a few lines in the middle of the picture](02-display-on-aga.md#blanking-a-few-lines-in-the-middle-of-the-picture))
- On a split line emit the bitplane pointers and BPLCON0 first and the colours after. ([Two bitmap modes in one frame (SCREEN 8 over SCREEN 5)](02-display-on-aga.md#two-bitmap-modes-in-one-frame-screen-8-over-screen-5))
- Two modes with different plane layouts need separate buffers, and the commands' results must be flushed to VRAM when a mode is left. ([Two bitmap modes in one frame (SCREEN 8 over SCREEN 5)](02-display-on-aga.md#two-bitmap-modes-in-one-frame-screen-8-over-screen-5))
- Map palette levels with a table to the nearest reference level, and check them against exact register values, not through a capture path that changes colours. ([3-bit levels to 4-bit nibbles: white was $EEE](02-display-on-aga.md#3-bit-levels-to-4-bit-nibbles-white-was-eee))
- Measure the real display window before sizing an edge mask or a crop. ([The window was exactly the picture, and the mask offsets hid 10 and 12 dots](02-display-on-aga.md#the-window-was-exactly-the-picture-and-the-mask-offsets-hid-10-and-12-dots))
- Restore BEAMCON0 (PAL/NTSC) and any other write-only display register on every exit path, from the system's own setting, then RemakeDisplay. A program that leaves NTSC timing behind breaks the next program's PAL screens. ([A 60 Hz game left the Amiga in NTSC timing after quitting](02-display-on-aga.md#a-60-hz-game-left-the-amiga-in-ntsc-timing-after-quitting))

## CPU core

- No stack in handlers, or in anything they call: A7 may be a table pointer. Save registers in memory. ([A7 is a table pointer, not a stack](03-cpu-cores.md#a7-is-a-table-pointer-not-a-stack))
- If the core indexes with D1.L, keep the high word of D1 zero in every handler. ([D1's high word must stay zero](03-cpu-cores.md#d1s-high-word-must-stay-zero))
- Take a pending interrupt after the instruction that follows EI, not at the end of the line. ([A pending interrupt is taken after the instruction following EI, not at the end of the line](03-cpu-cores.md#a-pending-interrupt-is-taken-after-the-instruction-following-ei-not-at-the-end-of-the-line))
- A stack pointer can point into ROM: build it from the read pointer. A read-modify-write instruction needs both the read and the write pointer. ([The stack pointer in ROM: POP and RET read tables](03-cpu-cores.md#the-stack-pointer-in-rom-pop-and-ret-read-tables))
- Capture the flags immediately after the instruction that produces them: a 68k MOVE changes the CCR. Do not charge many cycles in one block. ([A MOVE changes the flags you are about to save](03-cpu-cores.md#a-move-changes-the-flags-you-are-about-to-save))
- Implement every parameter of a command (the logical operation of LINE), or a game that uses it will show the gap. ([A command that ignored the logical operation (VDP LINE)](03-cpu-cores.md#a-command-that-ignored-the-logical-operation-vdp-line))
- Never read host state (the beam) for an emulated register: it makes runs unrepeatable. ([Repeatable runs: `LD A,R` from emulated time](06-testing.md#repeatable-runs-ld-ar-from-emulated-time))
- Write branches to labels, never as `*+n`, and have the build refuse the pattern. ([Hand-counted branches break when the layout changes](07-toolchains-release.md#hand-counted-branches-break-when-the-layout-changes))
- A video-chip command that finishes instantly is a timing change: games pace mid-frame work on the busy flag. Keep drawing at once, but report busy for the real duration. ([A command that finishes instantly moves the game's mid-screen work up the frame](03-cpu-cores.md#a-command-that-finishes-instantly-moves-the-games-mid-screen-work-up-the-frame))
- Measure instruction costs; do not only read them. An empty macro argument cost DAA four cycles since 4.0. ([A generated test cartridge and a trace of the line counter find cost bugs that reading the code missed](03-cpu-cores.md#a-generated-test-cartridge-and-a-trace-of-the-line-counter-find-cost-bugs-that-reading-the-code-missed))

## Input

- Drive pin 6 high before pin 5 falls when reading a CD32 pad. ([Drive pin 6 high before pin 5 falls](05-input.md#drive-pin-6-high-before-pin-5-falls))
- Do not auto-detect a pad by identification bits; give each port an option, and reject the all-buttons-pressed pattern. ([Auto-detection by identification bits failed on real pads](05-input.md#auto-detection-by-identification-bits-failed-on-real-pads))
- Read the pad from code that uses no stack. ([A7 is a table pointer, not a stack](03-cpu-cores.md#a7-is-a-table-pointer-not-a-stack))
- Scripted test runs must ignore the host's keyboard, mouse and joysticks. ([Scripted runs must ignore the host's input](05-input.md#scripted-runs-must-ignore-the-hosts-input))

## Testing

- A snapshot taken after the render hides every race with the beam. Keep a live-view freeze for display faults. ([A SNAP freezes after the render, which is the one moment that is always consistent](06-testing.md#a-snap-freezes-after-the-render-which-is-the-one-moment-that-is-always-consistent))
- A key script that skips a screen never tests it. Write one that stays on the screen under test. ([A script that skips the screen under test](06-testing.md#a-script-that-skips-the-screen-under-test))
- Use exact-register captures (GDI output) for colour work; a boosted capture path hides real errors. ([WinUAE's default output boosts contrast and saturation](06-testing.md#winuaes-default-output-boosts-contrast-and-saturation))
- Make runs repeatable before trusting a pixel comparison, and mark captures that still vary. ([Repeatable runs: `LD A,R` from emulated time](06-testing.md#repeatable-runs-ld-ar-from-emulated-time))
- A stale baseline reports noise as change. Compare with the previous release's run. ([The tiers, baselines and the "varies" status](06-testing.md#the-tiers-baselines-and-the-varies-status))
- A cycle-exact 68030 in the emulator is not a fast CPU. Keep the real-hardware loop and put a build reference in every report. ([Use both loops, and keep a build reference that ties them together](06-testing.md#use-both-loops-and-keep-a-build-reference-that-ties-them-together))
- Do not let a product feature and the harness share a signal (the audio filter keeps the power LED lit). ([The power LED is the harness's signal](06-testing.md#the-power-led-is-the-harnesss-signal))
- Chain the run behind the lock's `mkdir` with `&&`, hold the lock at most 15 minutes, and run long tiers in chunks. ([A lock made with `mkdir`, and the one-character mistake that deleted another session's lock](08-agent-workflow.md#a-lock-made-with-mkdir-and-the-one-character-mistake-that-deleted-another-sessions-lock))
- Put debug code behind conditional assembly and check that the release build is byte-identical. ([Debug code must leave the release build byte-identical](07-toolchains-release.md#debug-code-must-leave-the-release-build-byte-identical))
- After a timing change, run a control build with the change switched off before calling any capture change a regression. ([A control build separates a timing change from a regression](06-testing.md#a-control-build-separates-a-timing-change-from-a-regression))
- Real-time grabs are scheduled in wall-clock seconds while key scripts count MSX frames; below full speed the two drift apart. ([Live window grabs run on the wall clock, the key script on MSX frames](06-testing.md#live-window-grabs-run-on-the-wall-clock-the-key-script-on-msx-frames))
- A V9938 line is 63.695 microseconds, not 64. ([Use the frame event and the vertical-retrace flag, not the interrupt probe](06-testing.md#use-the-frame-event-and-the-vertical-retrace-flag-not-the-interrupt-probe))

- A program started with `Run` does not get the remote shell's `Stack`; put `Stack` and the program in a script and `Execute` it. ([A program started with Run does not get the shell's stack](11-test-machine.md#a-program-started-with-run-does-not-get-the-shells-stack))
- Brackets in a path are wildcards for `Copy`/`List`: escape them with `'` in a source, reach a destination through an assign. ([Brackets are wildcards for Copy and List](11-test-machine.md#brackets-are-wildcards-for-copy-and-list))
- Remote screenshots do not show windowed MiniGL output, and SDL programs ignore injected mouse moves; test 3D full screen and drive SDL menus with keys. ([Driving the screen remotely](11-test-machine.md#driving-the-screen-remotely))
- Never Break a MiniGL program; one 3D context at a time. ([One 3D context at a time, and never Break a 3D program](11-test-machine.md#one-3d-context-at-a-time-and-never-break-a-3d-program))
- Record the CM4 clock with every performance figure; a weak supply forces a lower clock. ([A marginal power supply looks like random resets under load](11-test-machine.md#a-marginal-power-supply-looks-like-random-resets-under-load))

## Sound and performance

*To be written (Arnold).*
