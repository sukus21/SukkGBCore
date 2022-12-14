INCLUDE "hardware.inc"
INCLUDE "color.inc"

SECTION "SETUP", ROM0

; Supposed to run first thing when the game starts.
; Lives in ROM0.
setup::

    ;Is this GBC hardware?
    ld sp, w_stack

    ;Write 1 to WRAM1
    ld hl, _RAMBANK
    ld a, 1
    ldh [rSVBK], a
    ld [hl], 1

    ;Write 0 to WRAM2
    inc a
    ldh [rSVBK], a
    ld [hl], 0

    ;Try to read 1 back from WRAM1
    dec a
    ldh [rSVBK], a
    ld a, [hl]

    ;What did we get?
    ldh [h_is_color], a
    cp a, 0
    jr z, .is_DMG
        
        ;CGB machine
        ld b, b
        jr .is_CGB

    .is_DMG
        ;DMG machine
        ld b, b
        ;fallthrough

    .is_CGB

    ;Does game require GBC functionality?
    ld a, [$0143]
    cp a, CART_COMPATIBLE_GBC
    jr nz, :+

        ;Game DOES require GBC functionality
        ldh a, [h_is_color]
        cp a, 0
        jr z, @+1 ;rst v_error
    :

    ;Set setup variable to true
    ld a, 1
    ldh [h_setup], a
    
    ;Do my intro with the logo
    call intro


; Skip GBC detection and RNG reset.
; Lives in ROM0.
.partial::
    
    ;Wait for Vblank
    di
    xor a
    ldh [rIF], a
    ld a, IEF_VBLANK
    ldh [rIE], a
    halt 

    ;Disable LCD
    ld hl, rLCDC
    res LCDCB_ON, [hl]

    ;Reset stack pointer
    ld sp, w_stack

    ;Check if RNG seed should be saved
    ldh a, [h_setup]
    cp a, 0
    push af
    jr z, .rngskip

        ;Save RNG values to stack
        ld hl, h_rng
        ld a, [hl+]
        ld b, a
        ld a, [hl+]
        ld c, a
        ld a, [hl+]
        ld d, a
        ld e, [hl]

        ;Stack shuffling
        pop af
        push bc
        push de
        push af
    .rngskip

    ;Setup ALL variables
    ld hl, variables_init
    ld b, bank(variables_init)
    call bank_call_0

    ;Put RNG seed back maybe
    pop af
    jr z, .rngignore
        
        ;Retrieve RNG values from stack
        pop de
        pop bc
        ld hl, h_rng
        ld a, b
        ld [hl+], a
        ld a, c
        ld [hl+], a
        ld a, d
        ld [hl+], a
        ld [hl], e
    .rngignore

    ;Jump to main
    jp main
;