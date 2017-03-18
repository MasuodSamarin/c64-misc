;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; Bitmap Multicolor plotter
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

; Use 1 to enable raster lines
DEBUG = 1

.segment "CODE"

        sei

        jsr clear_screen                ; clear screen

        lda #0
        sta $d020                       ; border color
        sta $d021                       ; background color

        lda #%00111011                  ; bitmap on
        sta $d011

        lda #%00011000                  ; no scroll, multi color,40-cols
        sta $d016

        lda #%00011100                  ; bitmap = $2000, screen $0400,
        sta $d018

        lda #$7f                        ; turn off cia interrups
        sta $dc0d
        sta $dd0d

        lda #01                         ; enable raster irq
        sta $d01a

        lda #$35
        sta $01                         ; No BASIC, no KERNAL. Yes IO

        ldx #<irq_vector                ; setup IRQ vector
        ldy #>irq_vector
        stx $fffe
        sty $ffff

        lda #50
        sta $d012                       ; trigger IRQ at beginning of border

        lda $dc0d                       ; ack possible interrupts
        lda $dd0d
        asl $d019

        cli

main_loop:
        lda sync
        beq main_loop
        dec sync

.if DEBUG=1
        inc $d020
.endif

        jsr shift_sin_table
        jsr do_plotter

.if DEBUG=1
        dec $d020
.endif

        jmp main_loop


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; clear_screen
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc clear_screen

        ldx #0                          ; clear bitmap area
        lda #$00
@l0:
        .repeat 32, XX
                sta $2000 + $0100 * XX, x
        .endrepeat

        dex
        bne @l0

        ldx #0                          ; screen RAM colors #1 & #2. bitmask 01 & 10
        lda #$12                        ; white / red
@l1:    sta $0400, x
        sta $0500, x
        sta $0600, x
        sta $06e8, x
        dex
        bne @l1

        ldx #0                          ; color #3: bitmask 11
        lda #$03
@l2:    sta $d800, x
        sta $d900, x
        sta $da00, x
        sta $dae8, x
        dex
        bne @l2

        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void plot(int x, int y, a=color)
; uses $f8/$f9 as tmp variable
; modifies Y
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.macro PLOT_PIXEL
        lda table_y_lo, y
        sta $f8

        lda table_y_hi, y
        sta $f9

        ldy table_x_lo, x

        lda ($f8), y
        eor table_mask, x
        sta ($f8), y
.endmacro

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; do_plotter
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc do_plotter

        ldx #0

@l0:
        lda sin_table, x
        tay

        PLOT_PIXEL

        inx
        bne @l0

        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; shift_sin_table
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc shift_sin_table

        ldx sin_table

        .repeat 255, XX
                lda sin_table + XX + 1
                sta sin_table + XX + 0
        .endrepeat

        stx sin_table + 255

        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; irq_vector
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc irq_vector
        pha                             ; saves A, X, Y
        txa
        pha
        tya
        pha

        asl $d019                       ; clears raster interrupt

        inc sync

        pla                             ; restores A, X, Y
        tay
        pla
        tax
        pla
        rti                             ; restores previous PC, status

.endproc


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; address = (table_y + table_x) % table_x_mask
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
BITMAP_ADDR = $2000
table_y_lo:
        .repeat 25, YY
                .byte <(BITMAP_ADDR + 0 + 320 * YY)
                .byte <(BITMAP_ADDR + 1 + 320 * YY)
                .byte <(BITMAP_ADDR + 2 + 320 * YY)
                .byte <(BITMAP_ADDR + 3 + 320 * YY)
                .byte <(BITMAP_ADDR + 4 + 320 * YY)
                .byte <(BITMAP_ADDR + 5 + 320 * YY)
                .byte <(BITMAP_ADDR + 6 + 320 * YY)
                .byte <(BITMAP_ADDR + 7 + 320 * YY)
        .endrepeat

table_y_hi:
        .repeat 25, YY
                .byte >(BITMAP_ADDR + 0 + 320 * YY)
                .byte >(BITMAP_ADDR + 1 + 320 * YY)
                .byte >(BITMAP_ADDR + 2 + 320 * YY)
                .byte >(BITMAP_ADDR + 3 + 320 * YY)
                .byte >(BITMAP_ADDR + 4 + 320 * YY)
                .byte >(BITMAP_ADDR + 5 + 320 * YY)
                .byte >(BITMAP_ADDR + 6 + 320 * YY)
                .byte >(BITMAP_ADDR + 7 + 320 * YY)
        .endrepeat

table_x_lo:
        .repeat 40, XX
                .byte <(XX * 8)
                .byte <(XX * 8)
                .byte <(XX * 8)
                .byte <(XX * 8)
                .byte <(XX * 8)
                .byte <(XX * 8)
                .byte <(XX * 8)
                .byte <(XX * 8)
        .endrepeat

table_x_hi:
        .repeat 40, XX
                .byte >(XX * 8)
                .byte >(XX * 8)
                .byte >(XX * 8)
                .byte >(XX * 8)
                .byte >(XX * 8)
                .byte >(XX * 8)
                .byte >(XX * 8)
                .byte >(XX * 8)
        .endrepeat

table_mask:
        .repeat 40
                .byte %11000000
                .byte %11000000
                .byte %00110000
                .byte %00110000
                .byte %00001100
                .byte %00001100
                .byte %00000011
                .byte %00000011
        .endrepeat

table_mask_neg:
        .repeat 40
                .byte %00111111
                .byte %00111111
                .byte %11001111
                .byte %11001111
                .byte %11110011
                .byte %11110011
                .byte %11111100
                .byte %11111100
        .endrepeat

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; variables
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
sync:
        .byte 0

sin_table:
; autogenerated table: easing_table_generator.py -s128 -m199 -aTrue -r bezier:0,0.02,0.98,1
.byte   0,  0,  1,  1,  1,  2,  2,  3
.byte   3,  4,  5,  6,  7,  8,  9, 10
.byte  11, 12, 13, 14, 15, 17, 18, 20
.byte  21, 22, 24, 26, 27, 29, 30, 32
.byte  34, 36, 38, 39, 41, 43, 45, 47
.byte  49, 51, 53, 55, 57, 59, 62, 64
.byte  66, 68, 70, 72, 75, 77, 79, 81
.byte  84, 86, 88, 90, 93, 95, 97,100
.byte 102,104,106,109,111,113,115,118
.byte 120,122,124,127,129,131,133,135
.byte 137,140,142,144,146,148,150,152
.byte 154,156,158,160,161,163,165,167
.byte 169,170,172,173,175,177,178,179
.byte 181,182,184,185,186,187,188,189
.byte 190,191,192,193,194,195,196,196
.byte 197,197,198,198,198,199,199,199
; reversed
.byte 199,199,198,198,198,197,197,196
.byte 196,195,194,193,192,191,190,189
.byte 188,187,186,185,184,182,181,179
.byte 178,177,175,173,172,170,169,167
.byte 165,163,161,160,158,156,154,152
.byte 150,148,146,144,142,140,137,135
.byte 133,131,129,127,124,122,120,118
.byte 115,113,111,109,106,104,102,100
.byte  97, 95, 93, 90, 88, 86, 84, 81
.byte  79, 77, 75, 72, 70, 68, 66, 64
.byte  62, 59, 57, 55, 53, 51, 49, 47
.byte  45, 43, 41, 39, 38, 36, 34, 32
.byte  30, 29, 27, 26, 24, 22, 21, 20
.byte  18, 17, 15, 14, 13, 12, 11, 10
.byte   9,  8,  7,  6,  5,  4,  3,  3
.byte   2,  2,  1,  1,  1,  0,  0,  0
