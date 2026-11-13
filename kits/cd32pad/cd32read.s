; =============================================================================
; cd32read-annotated.s - FAmiga 1.02's two CD32 pad readers, explained.
;
; THE CODE BELOW IS FAmiga's, INSTRUCTION FOR INSTRUCTION: cd32read and cd32pads
; exactly as src/amiga/input68k.s has them (cd32read-famiga-1.02-exact.s is the
; untouched copy).  Only the comments are new, written for a reader outside
; FAmiga, and the few lines a standalone file needs (the equates, the xref, the
; two data words) are added.  It assembles with vasm (vasmm68k_mot -Fhunk, the
; options FAmiga uses) to the same bytes as the same code inside FAmiga.
;
; WHERE IT CAME FROM
;   cd32read is z00p's ReadCD32Pads (his cd32pad.s, October 2026, MIT licence;
;   his file is in his-original/, the licence in LICENSE.txt).  FAmiga took it
;   in 0.88 and changed it in 0.89 (the image clock), 0.94 (the waits as
;   variables) and 0.96 (nine bits, and the second reader, "the low clock").
;   0.97 made the reader a menu choice per port.  Every change from his
;   routine is marked below as [CHANGE n]; CHANGES.html shows the two side by
;   side and explains each one.
;
;   THE SECOND READER'S IDEA - pin 6 held LOW before pin 5 falls, each button
;   clocked out by a short HIGH pulse, and the pad's two ID bits checked after
;   the seven buttons - was read in two places.  No code was copied from either;
;   the instructions are FAmiga's own, written into z00p's routine:
;     - Amiga Test Kit by Keir Fraser (testkit/joymouse.c, read_gamepad;
;       https://github.com/keirf/amiga-stuff; public domain, the Unlicense);
;     - AROS's lowlevel.library (arch/m68k-amiga/lowlevel/readjoyport.c;
;       https://github.com/aros-development-team/AROS; AROS Public License 1.1),
;       which uses the same clock order.
;   Read for facts only (nothing copied): the first KTRL CD32 pad's firmware
;   (https://github.com/MickGyver/KTRL-CD32, GPL-3.0) - its pad sends the two ID
;   bits after the seven buttons and counts the clock's rising edges.
;
; THE TWO READERS ARE ONE ROUTINE.  Each port is read one way or the other by
; one bit of d1:
;   d1 bit clear - "CD32 pad" in FAmiga's menu: z00p's reader.  Pin 6 idles
;                  HIGH; each clock pulse goes low, then high again.
;   d1 bit set   - "KTRL CD32+" in the menu: the low clock.  Pin 6 idles LOW;
;                  each clock pulse goes high, then low again.
; Everything else - the latch wait, the pulse widths, the nine reads - is the
; same for both.  Both ports can be read in one call, each with its own reader.
;
; THE PROTOCOL (as z00p's notes give it): with pin 5 driven low (POTGO DATxX =
; 0) the pad latches its buttons and puts them on pin 9 (POTINP DATxY), one per
; clock pulse on pin 6 (CIA-A PRA bit 7 for port 2, bit 6 for port 1, made
; outputs): blue, red, yellow, green, right, left, play, then the two ID bits;
; 0 = pressed.  The pad's shift register (a 4021: parallel load while pin 5 is
; high, shift on a rising clock edge once it is low) clocks on pin 6.  Pin 6 is
; put at its idle level and made an output BEFORE pin 5 goes low, so pin 5's
; fall never comes with a clock edge.  Pin 5 has the pot capacitor on it and
; needs time to fall: the latch wait.  Every wait is a CIA read (one E cycle,
; ~1.4 us on any CPU), so the timing is the same on a 68000, an 060 or a
; PiStorm.
;
; HOW IT HAS TESTED (13 November 2026)
;   z00p's KTRL CD32 (first model):   z00p's reader perfect; the low clock about
;                                     one read in four wrong (z00p's JOYTEST
;                                     runs on 0.97).
;   z00p's Mega Multi adapter (CD32 mode, 3-button Mega Drive pad): the low clock
;                                     right on B, C and A; z00p's reader wrong.
;   another tester's KTRL CD32+:      the low clock 0 wrong in 640 reads; z00p's
;                                     reader 12 wrong, most of them passing the
;                                     ID check (JOYTEST on 0.96).
;   So FAmiga keeps both, and the player picks one per port in the menu.
; =============================================================================

        machine 68020           ; (FAmiga's file says so; the code is 68000 code)

CUSTOM          equ     $dff000
POTINP          equ     $016            ; POTGOR: the pot pins as read
POTGO           equ     $034
CIAAPRA         equ     $bfe001         ; bit 7: port 2's pin 6, bit 6: port 1's; low = pressed
CIAADDRA        equ     $bfe201         ; the same bits as outputs (1) while a pad is clocked
LVODisable      equ     -120            ; exec
LVOEnable       equ     -126

        xref    _SysBase

        section .text,code

; -----------------------------------------------------------------------------
; cd32pads - how FAmiga calls the reader once a frame in a game (FAmiga's own
; caller, not part of z00p's routine).
;   in:  d0.b = the ports to read: bit 1 = port 2, bit 0 = port 1
;        d1.b = those among them to read with the LOW CLOCK (the others with
;               z00p's reader)
;   out: d0.b = port 2's seven buttons, d1.b = port 1's (1 = pressed; z00p's
;               bit order: 0 blue, 1 red, 2 yellow, 3 green, 4 right shoulder,
;               5 left shoulder, 6 play).  $00 for a port not asked for, and
;               for all seven at once (a plain joystick, as z00p's routine
;               gives it).
;   Everything else preserved.
; [CHANGE 9] Interrupts are switched off HERE, around the read, with exec's
; Disable/Enable (the OS's mouse handler writes POTGO at the vertical blank).
; z00p's notes leave that to the caller; this is how FAmiga does it.
; [CHANGE 8] The plain-joystick rule (all seven pressed -> $00) is done here,
; after the two ID bits are dropped, instead of inside the reader, so the
; reader can give JOYTEST the raw nine bits.
; -----------------------------------------------------------------------------
cd32pads:
        movem.l d2-d3/a0/a1/a6,-(sp)
        moveq   #3,d2
        and.l   d0,d2                   ; d2 = the ports asked (bits 0-1 only)
        move.l  d1,d3
        and.l   d2,d3                   ; d3 = those among them on the low clock
        move.l  _SysBase,a6
        jsr     LVODisable(a6)          ; interrupts off around the read
        move.l  d2,d0
        move.l  d3,d1
        bsr     cd32read                ; each port with its reader
        move.l  d0,d2                   ; keep the answers in saved registers
        move.l  d1,d3                   ; across Enable (it may change d0/d1)
        jsr     LVOEnable(a6)
        moveq   #$7f,d0
        moveq   #$7f,d1
        and.l   d2,d0                   ; the seven buttons (the ID bits dropped)
        and.l   d3,d1
        cmp.b   #$7f,d0                 ; all seven at once: a plain joystick
        bne.s   .k2
        moveq   #0,d0
.k2:    cmp.b   #$7f,d1
        bne.s   .k1
        moveq   #0,d1
.k1:    movem.l (sp)+,d2-d3/a0/a1/a6
        rts

; -----------------------------------------------------------------------------
; cd32read - z00p's ReadCD32Pads, with FAmiga's changes.
;   in:  d0.b = ports to read: bit 1 = port 2 (joystick port), bit 0 = port 1
;               (mouse port).  A port left out is never driven.
;        d1.b = [CHANGE 2] the ports among them read with the LOW CLOCK.
;   out: d0.l = port 2's answer, d1.l = port 1's.  [CHANGE 7] NINE bits, 1 =
;        pin 9 low (pressed): bit 0 blue, 1 red, 2 yellow, 3 green, 4 right
;        shoulder, 5 left shoulder, 6 play, 7 and 8 the pad's two ID bits (a
;        CD32 pad answers bit 7 = 0, bit 8 = 1).  0 for a port not read.
;   Everything else preserved.  Call with interrupts off: it owns POTGO and
;   CIA-A DDRA bits 6/7 while it runs.  Directions are not read here: take them
;   from JOY0DAT/JOY1DAT as usual.
; -----------------------------------------------------------------------------
cd32read:
        movem.l d2-d6,-(sp)             ; [CHANGE 1] d2-d6 (his: d2-d4): d5 counts the clock wait, d6 holds the low-clock ports
        moveq   #0,d3                   ; d3 = the CIA-A PRA bits to clock (pin 6 of each port read)
        moveq   #0,d6                   ; [CHANGE 2] d6 = those among them on the low clock
        move.w  #$ff00,d4               ; d4 = POTGO: pin 5 low on each port read
        btst    #1,d0
        beq.s   .no2
        move.b  #$80,d3                 ; port 2's clock: PRA bit 7
        and.w   #$6fff,d4               ; port 2: DATRX = 0 (pin 5 low), OUTRY = 0 (pin 9 an input)
        btst    #1,d1                   ; [CHANGE 2] port 2 on the low clock?
        beq.s   .no2
        move.b  #$80,d6
.no2:   btst    #0,d0
        beq.s   .no1
        or.b    #$40,d3                 ; port 1's clock: PRA bit 6
        and.w   #$f6ff,d4               ; port 1: DATLX = 0, OUTLY = 0
        btst    #0,d1                   ; [CHANGE 2] port 1 on the low clock?
        beq.s   .no1
        or.b    #$40,d6
.no1:   moveq   #0,d0
        moveq   #0,d1
        tst.b   d3
        beq     .done                   ; no port asked: nothing is driven
; [CHANGE 3] THE IMAGE CLOCK (FAmiga 0.89).  His routine sets pin 6 with
; or.b d3,CIAAPRA and pulses it with eor.b d3,CIAAPRA - a read-modify-write of
; the port.  Here the port's byte is read ONCE into a register (the image), the
; clock bits are set in it, and every level is WRITTEN from the image.  On real hardware the pulses are the
; same levels at the same times.  The reason was FS-UAE (and WinUAE of the same
; line): in CD32 mode it reads the fire bit as 1 whatever the CIA drives, so the
; eor wrote 0 every time and the emulated pad never saw a rising edge.  It also
; saves one CIA access per edge.
        move.b  CIAAPRA,d2              ; the port's byte as it is: the image
        or.b    d3,d2                   ; every clocked pin 6 high (z00p's idle level) ...
        eor.b   d6,d2                   ; [CHANGE 4] ... and the low clock's back to LOW (d6 is within d3)
        move.b  d2,CIAAPRA              ; pin 6 at its idle level, then an output, held there
        or.b    d3,CIAADDRA             ; while pin 5 falls (no clock edge)
        move.b  d2,CIAAPRA              ; [CHANGE 3] written once more now the pin is an output: UAE's
                                        ; edge detector takes its first level from such a write (on real
                                        ; hardware the level is already there: nothing changes)
        move.w  d4,CUSTOM+POTGO         ; pin 5 low: the pad latches its buttons
        move.b  d2,d4                   ; d4 = the image from here on (the POTGO value is no longer needed)
        move.w  _cd32_latch,d2          ; [CHANGE 5] the latch wait: _cd32_latch CIA reads (35, ~50 us;
        subq.w  #1,d2                   ; his assembly: 200, ~300 us; 35 is the figure his C version uses)
.latch: tst.b   CIAAPRA
        dbf     d2,.latch
        moveq   #9-1,d2                 ; [CHANGE 7] nine bits: the seven buttons and the two ID bits (his: 7)
.bit:   lsr.w   #1,d0                   ; [CHANGE 7] .w (his .b): nine bits; the first out ends in bit 0
        btst    #6,CUSTOM+POTINP        ; port 2's pin 9 (DATRY, bit 14): 1 = released
        beq.s   .lo2
        bset    #8,d0                   ; [CHANGE 7] into bit 8 (his: bit 6)
.lo2:   lsr.w   #1,d1
        btst    #2,CUSTOM+POTINP        ; port 1's pin 9 (DATLY, bit 10)
        beq.s   .lo1
        bset    #8,d1
; One clock pulse a bit.  eor.b d3,d4 flips every clocked pin 6 in the image:
; z00p's reader's lines go high -> low, the low clock's go low -> high.  The
; second flip puts each back at its idle level: that is the edge z00p's pads
; shift on (a rise), and for the low clock the rise came first.
.lo1:   eor.b   d3,d4                   ; [CHANGE 3] the pulse's first half, written from the image
        move.b  d4,CIAAPRA              ; (his: eor.b d3,CIAAPRA)
        move.w  _cd32_clock,d5          ; [CHANGE 6] _cd32_clock CIA reads (3, as his three tst.b),
        subq.w  #1,d5                   ; counted in a loop instead of written out
.wlo:   tst.b   CIAAPRA
        dbf     d5,.wlo
        eor.b   d3,d4                   ; ... and back to idle: the next bit
        move.b  d4,CIAAPRA
        move.w  _cd32_clock,d5          ; [CHANGE 6] the wait before the next bit's read
        subq.w  #1,d5
.whi:   tst.b   CIAAPRA
        dbf     d5,.whi
        dbf     d2,.bit
        move.w  #$ff00,CUSTOM+POTGO     ; pin 5 high: plain joystick mode again
        not.b   d3
        and.b   d3,CIAADDRA             ; pin 6 an input again
        not.w   d0                      ; 1 = pressed (low)
        and.l   #$1ff,d0                ; [CHANGE 7] nine bits kept (his: and.b #$7f)
        not.w   d1
        and.l   #$1ff,d1
; [CHANGE 8] His "all seven at once = a plain joystick -> $00" test is not here:
; cd32pads does it, so JOYTEST can show the raw nine bits.
        not.b   d3                      ; ports not asked for: 0
        btst    #7,d3
        bne.s   .r2
        moveq   #0,d0
.r2:    btst    #6,d3
        bne.s   .done
        moveq   #0,d1
.done:  movem.l (sp)+,d2-d6
        rts

; -----------------------------------------------------------------------------
        section .data,data
; [CHANGE 5, 6] The two waits, in CIA reads (~1.4 us each on any CPU).  From
; FAmiga 0.94 they are words in memory, so a test build could change them;
; FAmiga 1.02 keeps them at 35 and 3.
_cd32_latch:    dc.w    35
_cd32_clock:    dc.w    3
