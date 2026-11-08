# Working with Claude on Amiga projects

*Reading notes.* Chapter 08 is the how-to: briefs, locks, the coordination file, budgets and review rounds. This chapter is about the partnership itself: what the agent is good at, where it needs checking, what only the human tester can do, and what changes when several agent sessions share a machine, a repository and an allowance. The examples come from all three projects, mostly from October and November 2026. "The agent" is a Claude session working on one project; "the tester" is the person who owns the machines, plays the builds and decides what ships.

## 1. What the agent does well, and where it needs checking

### Fast at reading and running, confident when it is wrong

**Problem.** An agent reads a disassembly, a 70 KB chapter or a week of commit history in seconds, scripts a test rig and runs a regression tier overnight. It also states a wrong conclusion in the same confident tone as a right one, and it believes its own reports more than it should. The speed is real; the confidence is not evidence.

**What it does well, in these projects.**
- Reading what the code really does: the objdump of a C function, a JIT translation, a game's own input routine traced in the reference emulator.
- Building and running rigs: WinUAE key scripts, headless hosts with per-frame checksums, burst captures against the reference emulator (chapter 06).
- Checking numbers across documents. The Arnold session, reviewing AmiPCEngine's sound chapter, noticed a timer comment that used 227.5 colour clocks per line (NTSC's average) on a PAL screen. With PAL's 227 the period error is 0.36%, not the intended 0.2% (docs commit 38dbfcd).
- Doing the dull, exact jobs: release checklists, archive comparisons file by file, privacy scrubs.

**Where it needs checking.** The four cases below have the same shape: a plausible account, stated firmly, which a measurement would have overturned at once.

### An afternoon spent blaming the hardware before reading the compiled code

**Problem.** Arnold's CD32 read, in C, returned all bits clear or all bits set on the PiStorm A1200, and the pad never answered as a CD32 pad.

**Before.** The agent and the tester worked through the likely hardware causes one at a time: the pad, the port, the adapter, the delays between clock pulses, the USB mouse, Emu68's CIA timing. Each step took a hardware round trip (plug in, run, photograph). Two other signals made it look like hardware. lowlevel.library reported the pad as a "CD32" type, which tells you nothing about whether a hand-written read works. And AmiMSX's read, which keeps the plain two-button read alongside the CD32 one, showed fire 1 and fire 2 working on the same pad, which looked like proof that the pad was fine. Only Start, which exists only in CD32 mode, showed that AmiMSX's own CD32 read worked and Arnold's didn't.

**After.** The objdump of the C function at its release flags (`-m68040 -O2`): no store of 0x6F00 to POTGO, and one read of POTINP for all nine bits. The NDK's `struct Custom` is not `volatile`, so gcc removed the write that puts the pad in CD32 mode as a dead store. One line fixed it:

```c
#define CUSTOM ((volatile struct Custom *)&custom)
...
CUSTOM->potgo = 0x6f00;                   /* pin 5 low: CD32 mode */
...
if (!(CUSTOM->potinp & 0x4000)) bits |= 1u << i;
```

*Source: Arnold for the Amiga 1.7.1, src/amiga/amiga_joy.c (GPL-2.0).*

**Why.** An agent ranks causes by how often they turn up in its experience, and "flaky pad on a fast CPU" is common. It ranked "my own code does not do what it says" too low, although checking that was the cheapest test available: one objdump, no hardware.

**Evidence.** After the fix: the pad's ID bit at rest, and each of the seven buttons on its own in the test tool; the tester then played with every button working in Arnold. The fix shipped as Arnold 1.7.1, its only change. The details are in chapter 05 and the CD32 kit.

**Lesson.** When a C hardware read fails like a hardware fault, read the compiled code first. More generally: ask the agent for the cheapest test that would prove its current theory wrong, and run that before the next hardware round trip.

**Look up.** Chapter 05, "CD32 pads from C, with the operating system running (Arnold)"; [kits/cd32pad](../kits/cd32pad/README.md), "The compiler trap in the C read".

### Argued is not measured

**Problem.** In AmiPCEngine 1.4's lag work, the plan's first step was "measure first": press at frame F, find the first frame whose picture changes. The agent skipped it, built the fix (start each emulated frame at the guest's vertical blank line, `NO_VBLUNIT`) from a reading of the code, ran the regressions, and wrote in the shared docs that the fix "saves one whole frame". The other two projects had measured their equivalents. A review of the docs a day later caught it.

**After.** The measurement was done: a test switch applies a scripted press where the real pad is read, and a checksum of every composed frame finds the first changed picture. It gave frame P+1 with the fix and P+2 without, in three titles. The reasoning had been right. Two details were wrong: the doc said the game's answer shows in the same emulated frame (it shows in the next, the game's own frame), and a claim that "about two frames were the emulator's" had never been measured. Both were corrected.

**Lesson.** An argument from the code can be right and still not be evidence. In notes and docs, keep "measured" and "argued" apart, and do the plan's measuring step even when the answer seems obvious.

**Look up.** AmiPCEngine commits 529f488, a8f3975; chapter 05, "Cutting input lag (AmiPCEngine)".

### A perfect match is as suspicious as a total failure

**Problem.** The AmiPCEngine agent compared WinUAE grabs of eight titles with a fix on and off and reported "identical" to the tester. Every grab was of the Workbench: five test configurations still mounted an old worktree's folder, so the program never started.

**After.** The agent found the fault itself on its next check, told the tester that the earlier report was void, and fixed the configurations. The rule since: before reporting a comparison, look at one grab, or check for a file that only the program writes (Arnold's rig waits for a "done" file written at QUIT).

**Lesson.** Look at the data before reading the summary figure.

**Look up.** AmiPCEngine commit 3bfff46; chapter 06, "A grab of the wrong screen compares equal".

### "Validate first": a wrong answer caught before it was acted on

**Problem.** Asked what AmiMSX could learn from the other projects' late start (moving the input read and emulation closer to the display), the agent concluded it gained nothing on AGA live drawing: "about 100 lines of slack, the slowest frames take 163". The tester said to go ahead and drop the idea.

**After.** Going back over the frame order before writing it up, the agent found it had mixed up the render, which must stay at the tick, with the input read and emulation, which take a tenth of a frame and are free to move. It told the tester before acting. The answer was "go ahead but validate first". A simulation on the tester's real A1200 frame logs gave about 15 ms less lag at the median, with 0.2 to 0.9% of frames late, and the change went in (AmiMSX dbe8a5f).

**Lesson.** The agent's reasoning about timing is a hypothesis until it has been run against real frame data, and that applies to "no gain" as much as to "a gain". A tester's "validate first" is cheap insurance; an agent that finds its own mistake should say so before acting, not after.

**Look up.** Chapter 05, "Controller lag: measure the frame, then reorder it (AmiMSX)".

## 2. The tester and the agent

The agent cannot see the TV, hear the speakers or hold the pad. Everything that exists for the player (smoothness, lag that can be felt, sound, the controller) needs a verdict from the tester on the real machine and display chain. The agent's job is to make that verdict cheap to give and easy to trust: clearly named builds, one question at a time, and exact instructions.

### The log said fine, the eye said no

**Problem.** AmiMSX on the PiStorm A1200, 5 Nov 2026. With Smooth Display (the double buffer) off, the timing log looked good: the render took 76 beam lines at the median and 163 at the 99th percentile, with 6 of 728 frames late. By a simple beam-race model the drawing stayed ahead of the beam, so the agent proposed dropping the double buffer and saving a frame of lag.

**After.** The agent sent the tester a pair of presets named for what they were, rather than dropping the feature on the strength of the log. The verdict: with Smooth Display off the scrolling was jittery, "a deal breaker". The cause never showed in the log, and the double buffer stayed.

**Lesson.** A log measures the emulator's timing, not the picture that reaches the TV through a scaler. Anything that exists for the picture needs a verdict by eye on the real display chain before it goes.

**Look up.** Chapter 05, "A faster path is not a better one until someone has looked at it".

### Scripted input tests the emulator, not the pad read

**Problem.** AmiPCEngine's CD32 pad mode built the PC Engine pad byte with its two nibbles swapped: the d-pad drove I, II, Select and Run, and the buttons drove the d-pad. Joystick mode read fire 2 from the wrong pin and held Right down, so the bat in a bat-and-ball game drifted. Both had passed every scripted test: the key scripts write the pad byte directly, and the emulated CD32 pad in the test rig never answered.

**After.** The tester found both faults within a few minutes, with a real pad on a CD32 adapter. Both were fixed behind `NO_JOYFIX` (28 Oct).

**Lesson.** Anything between the port and the emulator's pad byte needs a real controller, and the tester's first five minutes with one are worth more than any script.

### Give the tester a test they can do, and a tool that records it

**Problem.** Pad tests over the network: the agent starts a test tool on the A1200, the tester presses buttons. The first runs of a short sampler (about 80 frames, 1.6 s) caught nothing, because the tester pressed after the agent's "go" and the sampler had already finished. A later run printed its results to a console the remote shell never returned.

**After.** A protocol, written into the agent's notes: one button per run; hold it *before* the run starts; blue first, because it is the first bit out and a short latch wait or a missing clock edge loses it first. Results go to a file (`Run tool >RAM:log` puts the redirection on the program, not on `Run`), the file is copied to the share, and the agent reads it rather than a photo of the screen.

**Lesson.** The tester's time and attention are the scarce resource. Before asking for a run, check that the tool will record something useful whatever the timing of the press, and say exactly what to press, in what order, and when.

### Named builds, and verdicts that change

**Problem.** Feel tests are noisy. In Arnold's 1.8 lag work the tester tried two builds named for what they did, with the late start off and on. Late start off felt "much more responsive", although the late start measured about 4 ms quicker from stick to picture. A later round with neutral names ("Preset A", "Preset B") gave the slight edge to the late start, in line with the measurement.

**After.** Neither verdict was treated as final on its own. The plan is to turn the late start on by default in 1.8, behind its switch, and it stays open to the tester's next verdict. When AmiMSX's agent later suggested neutral names for its own test round, the tester answered: "I prefer the named build tests you do." The projects have used named builds since.

**Lesson.** Blind A/B is a tool, not a rule, and the tester chooses how they test. Some testers judge better knowing which build is which. Treat one feel verdict as one data point: repeat it, put it next to the measurement, and say where they disagree.

**Look up.** Arnold `STATUS.md`, "1.8 plan"; chapter 05, "Controller lag: the frame boundary and a late start (Arnold)".

## 3. Claude at the Amiga's keyboard (amimcp)

With a small agent running on the A1200 (amimcp, described in chapter 06, "Real hardware over the network"), the agent can work on the real machine from the PC: run shell commands, copy and read files, take screenshots, send keys and mouse clicks, run ARexx. In practice that is good for four jobs:

- **Installs and updates.** Copy a program over, check its version, list what it replaced, start it once and look at the screen. The agent does this faster than a person at the keyboard and writes down what it changed.
- **File moves.** Copies in small, verified pieces, with the file count and byte total compared against the source (chapter 11, "Run big data from local disk, and copy it in small pieces").
- **Screenshots of Workbench.** A quick look at what a window or a requester says, without walking to the machine.
- **Scripted runs.** The agent writes a script, runs a test build with a key script and a log, and reads the log from the share afterwards. Chapter 06 and chapter 10 cover the timing runs.

It is the same machine the tester uses, so the work comes with rules.

### The rules before touching the machine

- **Look before you act.** List the screens first. A full-screen program in front means the machine is in use, whatever the remote shell says. Read the coordination file (chapter 08) and add a line before a run: what, how long, and that you will leave it at Workbench.
- **Never break a full-screen program.** Quit it with its own key (Esc, a menu). Ctrl-C leaves a 3D program's last frame frozen on screen and can block the next one until a reboot (chapter 11, appendix), and the capture cannot show whether a program that has taken over the screen has really stopped.
- **One command at a time.** The agent runs one command at a time and gives up waiting after a time limit. Start anything long with `Run` from a script and poll its log, rather than holding the shell.
- **Send only commands you have read about.** See the first lesson below.
- **Leave it at Workbench.** Close what you opened, remove temporary assigns and files, and write "done" in the coordination file.

### One guess at a program's ARexx port stopped the agent

**Problem.** The A1200, 4 Nov 2026. A third-party dock program had been installed and drew nothing that could be seen. The agent wanted it closed, saw that it had an ARexx port, and sent it `QUIT`. The program never answered. ARexx has no time limit, so the command never came back, and the agent on the Amiga was busy with it: every later call (a shell command, a screenshot, even the break request) timed out after 30 seconds. The machine itself still answered a ping.

**After.** Only the tester could clear it, by restarting the machine. The agent now sends a command to another program's ARexx port only if the program's own guide documents it, and otherwise asks the tester to close the program by hand.

**Lesson.** The agent cannot cancel a call that is waiting on another program. An unknown command is not a harmless probe: if the other side never replies, the agent is stuck and the machine needs a person.

**Look up.** Chapter 11, "After a reboot the network may stay down", for what to do once the machine is back.

### A grey screenshot is not a failed run

**Problem.** A third-party game emulator on the A1200, 2 and 5 Nov 2026. It draws on the machine's own chipset screen, not on the RTG Workbench, and the remote screenshot showed plain grey for the whole run. The program's own log, written to a file on the machine, said 60.5 frames a second and a clean quit for five test games.

**After.** The agent stopped treating the screenshot as the test. It started the program with `Run` from a script, waited a fixed time, sent Esc, and read the program's log, which records its own speed, sound underruns and how it ended. The tester looked at the real screen for the picture.

**Lesson.** Remote capture reads the screen the operating system knows about. A program that opens its own screen, or takes over the hardware, is invisible to it. Judge such a program by its log, and keep the tester's eyes for what the log cannot say (chapter 11, "Driving the screen remotely").

### What the agent cannot do from here

It cannot see the TV, hear the speakers or hold the pad (section 2). It cannot show a windowed 3D program: the capture of one comes out as an empty grey window. And it cannot reach the machine after a reboot until someone chooses "Go Online" on the Amiga, then connects the share. When a run needs a reboot, say so first and agree who brings it back.

### Keeping the token and the addresses out of anything public

The agent is a remote shell on the home network, protected by a token. The token and the machine's address belong in the local configuration and in private notes, not in a repository, a commit message, a release note or a chapter like this one. The release routine runs a scrub step that replaces local paths and names before anything is pushed, and a search for private details (the token, addresses, local paths) is part of the release check. Write "the A1200", "the share" and "the tester" in anything that goes out.

## 4. Several sessions, one repository

Three emulator sessions, an FPGA core session and a machine-setup session shared one docs repository, one WinUAE installation, one A1200 and one plan allowance. Chapter 08 has the mechanics: the WinUAE lock and the coordination file. These are the lessons from the shared git checkouts.

### A sweeping commit took another session's work

**Problem.** Sessions work in the same checkout of a shared repository at the same time. On 25 Oct 2026 one session committed with `git commit -a`, and the commit included another session's edits that had not been committed yet.

**Before.**

```
git commit -a -m "..."
```

**After.**

```
git add path/to/my_file.asm path/to/my_notes.md
git diff --cached --stat        # only my files?
git commit -m "..."
```

**Why.** `-a`, `git add -A` and a bare `git stash` act on the whole working tree, which in a shared checkout holds everybody's work in progress. Name your own paths. Never use `reset --hard` or a bare `stash` there either: the other session's work is not in any commit yet, so it is simply lost.

### Staging into one index collided; commit only your own hunks

**Problem.** In the docs repository, three sessions added to the same chapters on the same day. Staging is shared too: one session's `git add` of a chapter replaced another session's staged copy of it, and a commit could then carry text its author had not written or reviewed.

**After.** Each session commits HEAD plus only its own text. In practice: check that `git diff --cached` is empty before starting; stage only your own hunks; or build the commit in a temporary index (`GIT_INDEX_FILE`, `git read-tree HEAD`, add your own blobs, `git commit-tree`, `git update-ref`), so the shared index is never touched. Then tell the other sessions what you committed.

**Lesson.** In a shared checkout, the index and the working tree belong to everyone. Message before you touch a file someone else is editing.

### A script that emptied a chapter

**Problem.** The AmiPCEngine session's patch script opened a chapter for writing and then failed while building the insert, which left the file empty. It was restored from HEAD at once and the other sessions were told. Nothing was lost, because nobody had uncommitted work in that file.

**After.** Build the new text completely in memory, check it, and only then open the file to write it.

### Cross-reviews find what the author cannot

**Problem.** Each session reads its own chapter with its own assumptions. A round in which every project reviewed the others' chapters (6 Nov 2026) found slips that none of the authors had seen, such as the PAL/NTSC timer constant in section 1.

**Lesson.** Plan a cross-review round before a docs release, and give each reviewer the other projects' chapters, not their own. Corrections go back through the author, or are marked as the reviewer's.

## 5. Provenance and licences

The agent can trace where any line came from much faster than a person can. The human decides what may be shared. Every project here mixes code from several sources, and each kind has its own rule.

### Ask who wrote that exact part, not who wrote the project

**Problem.** Another emulator author asked for CD32 pad code that was known to work. The obvious source was AmiMSX, which is freeware by its original author with a community 4.x update. Sharing its code under a different licence would need the original author's permission.

**After.** Before anything was shared, the agent checked the history: the CD32 read was new code written for the 4.x update (4.1.1 and later), and the original AmiMSX has no CD32 read. So the person who wrote it could offer it under MIT, with no permission needed from the original author. The kit's README now says so plainly, and the C version from Arnold is MIT by the same person.

**Lesson.** The licence depends on who wrote the lines being shared. The agent can dig that out of the history; the human decides what to offer.

**Look up.** Docs commit a050026; [kits/cd32pad](../kits/cd32pad/README.md).

### Each source has its own rule

These are the rules the projects work by. An agent should be briefed on them before it writes any code or docs:

| Source | Rule |
|---|---|
| Arnold's core (Kevin Thacker, GPL-2.0, released for the Amiga with his blessing) | Changes go out as a patch series against upstream, with the source; excerpts are marked GPL-2.0. |
| AmiMSX and AmiPCEngine (freeware by Juan Antonio Gómez Gálvez, with z00p for AmiPCEngine) | Quoted with permission, marked per excerpt (STYLE.md). |
| A framework written for these projects (rtgfw) | MIT, kept as a separate work in its own repository, vendored unchanged; the GPL host uses it but does not relicense it. |
| Other emulators kept for reference (other CPC and MSX emulators, ROM disassemblies) | Read to understand, never copied or quoted; describe the behaviour in your own words. |
| Operating-system drivers and kernel code read to understand hardware (a GPL-3.0 HDMI audio driver, Linux display code) | Use the driver only through its public interface (AHI); never ship it or copy from it. Reading is fine, copying is not. |
| Commercial games, cartridges and disks | Never in a repository or a cloud upload; test lists name titles, not files. |
| Notes or tools another developer shares privately | Used privately. Nothing about them goes into public docs until their author agrees, and then in your own words, credited. |

**Lesson.** Licences are decided once, by the human, and then applied every time by the agent. Write them down where every session reads them; an agent that has to rediscover them will eventually guess.

### Privacy is part of provenance

The public text names no testers or owners and gives no local paths, addresses, tokens or private collections (STYLE.md). The release scripts end with a scrub that searches the staged public tree for the patterns that would give these away, and a release does not go out until the search comes back empty.

## 6. Budgets

The plan allowance (a 5-hour window and a weekly limit, shared by every session) is the project's real schedule. Chapter 08, "Usage budgets and cut-offs", has the rules for launching agents.

**What changed with experience.**
- **Check before, and during.** The agent checks usage before a long job and again at natural stopping points, and pauses there rather than being cut off mid-step. A cut-off mid-step costs more than the pause, even with work-in-progress commits.
- **Plan around the weekly reset.** Large writing jobs, this chapter among them, were scheduled for after the weekly reset, and small fixes were done before it.
- **Spend the tester's time as carefully as tokens.** A hardware round trip costs the tester minutes and attention. Batch the questions, test on the PC first, and send a build only when it is the one you would ship.
- **Unattended work goes where it costs least.** A job that needs no local network or hardware (a long analysis, a review of a chapter) can run unattended on a separate allowance; anything that touches the A1200, the share or WinUAE stays in an interactive session.

**Lesson.** A budget is a planning input, not a surprise. Say what a job will cost before starting it, and stop at a point where the work can be picked up again.
