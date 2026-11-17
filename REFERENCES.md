# References

The technical documents behind the projects, and where to find them. Nothing here is copied into this
repository: the books and datasheets belong to their publishers, so each entry gives a title and a source
instead. Where a document and a reference emulator disagree, test on the real machine if you can. The
lessons in the chapters say which source settled each question.

## How to read the scans

Most of the MSX books below are scans with no text layer, so text search finds nothing. Read them as page
images (render a page, or pull the embedded image out of the PDF). The exceptions are noted. An agent can
read a page image directly; give it the PDF page number, not the printed one, because the two differ by the
front matter.

## MSX, MSX2, MSX2+ and turbo R

All of these are on File Hunter's download site (`download.file-hunter.com`), under the folder given.

| Document | Folder | Language | Use it for |
|---|---|---|---|
| MSX turbo R Technical Hand Book (ASCII) | `Books/JP` | Japanese, the original | R800 and its DRAM mode, the S1990 (system timer, VDP wait), PCM, YJK (chapter 4.6), the instruction timing table (appendix A) |
| MSX turbo R Technical Hand Book, English translation (`MsxTurboRTechnicalHandBook_EN.pdf`) | `Books/EN` | English | The same, translated |
| MSX turbo R Technical Hand Book, Portuguese OCR | `Books/PT` | Portuguese | Has a text layer, so it can be searched |
| MSX2+ Powerful Usage (English translation) | `Books/EN` | English | MSX2+ and V9958 programming: YJK, horizontal scroll, MSX-Music |
| Yamaha V9958 Technical Data Book | `Manuals` | English | What the V9958 adds to the V9938: R#25 to R#27, YJK and YAE, the WAIT function. An `[OCR]` copy with a text layer is next to it |
| V9958 Registers | `Manuals` | English | A register summary |
| Yamaha V9938 MSX-Video Technical Data Book (Aug 1985) | `Books/EN` | English | The MSX2 video chip: screen modes, sprites, the command engine, timing |
| MSX2 Technical Handbook (ASCII), `MSX_2_Technical_Handbook.zip` | `Books/EN` | English | BIOS, slots and subslots, VDP, PSG, disk |
| MSX2 Hardware Specification v5.2 | `Books/EN` | English | Machine-level details of the MSX2 standard |
| The MSX Red Book | `Books/EN/The MSX Red Book` | English | MSX1 BIOS and hardware |
| MSX-Datapack Vol. 1 to 3 (ASCII) | `Books/JP` | Japanese | ASCII's official system data for MSX2, MSX2+ and turbo R; the definitive BIOS and hardware tables |
| R800 User's Manual | `Books/EN` and `Manuals` | English | The turbo R CPU, its instructions and timing |
| Z80 User's Manual (Zilog) | `Manuals` | English | The Z80 instruction set |
| General Instrument AY-3-8910 | `Manuals` | English | The PSG |
| Yamaha YM2413 (OPLL) | `Manuals` | English | MSX-Music (FM-PAC) |
| Yamaha YMF278B (OPL4) and its Application Manual | `Manuals` | English | Moonsound |
| Yamaha V9990 Application Manual | `Manuals` | English | The GFX9000 video chip |
| Panasonic FS-A1GT Technical Guide | `Manuals` | Japanese | The turbo R machine itself |

Online:

- Grauw's MSX Assembly Page (`map.grauw.nl`): articles and tidied-up chip documentation, including the
  V9938 and V9958.
- The MSX Resource Center wiki (`www.msx.org/wiki`).
- openMSX (`github.com/openMSX/openMSX`), the reference emulator for AmiMSX. Its source, and its Tcl
  console for watchpoints and register logs, answered most timing questions. Use `debug set_watchpoint`
  in scripts.

## Amstrad CPC and CPC Plus

- CPCWiki (`www.cpcwiki.eu`): the hardware pages (Gate Array, CRTC types, the Plus ASIC, the PPI and the
  PSG) and links to scans of Amstrad's own manuals.
- Arnold's own source (`github.com/z00p/arnold-amiga`, derived from Kevin Thacker's Arnold).

## PC Engine / TurboGrafx-16

- The PC Engine wiki on nesdev (`pce.nesdev.org`), for example the CPU memory map page.
- Mesen 2 (`github.com/SourMesen/Mesen2`), the reference emulator for AmiPCEngine. Its `Core/PCE` sources
  cover the VDC, VCE, PSG and the CD-ROM unit (SCSI bus, ADPCM, CD audio, Arcade Card).
- PC Engine BIOS offsets (`stum.de/2025/pcenginebiosoffsets/`).

## Game Boy and Game Boy Color

- Pan Docs (`gbdev.io/pandocs`): the standard Game Boy and Game Boy Color hardware reference.

## The Amiga side

- Amiga Hardware Reference Manual, 3rd edition: the OCS/ECS custom chips and the CIAs
  (AGA is not in it).
- The AmigaOS 3.2 NDK (Hyperion): includes and autodocs for the OS the projects run under.
- Emu68 (`github.com/michalsc/Emu68`): the PiStorm's 68k JIT; see chapter 10 for what its timing means
  for emulators.
