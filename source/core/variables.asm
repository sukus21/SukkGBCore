INCLUDE "hardware.inc"
INCLUDE "entitysystem.inc"

;Allocate 256 bytes for the stack, just to be safe
stack_size equ $100
SECTION "STACK", WRAM0[$D000 - stack_size]
    w_stack_begin:: ds stack_size ;Top of stack
    w_stack:: ds $00 ;Base of stack
    ASSERT w_stack_begin + stack_size == $D000 ;Make sure things work out
;



SECTION "VARIABLE INITIALIZATION", ROMX

; Initializes ALL variables.
variables_init::
    
    ;Copy WRAM0 variables
    ld hl, w_variables ;Start of variable space
    ld bc, var_w0 ;Initial variable data
    ld de, var_w0_end - var_w0 ;Data length
    call memcopy

    ;Copy WRAM1 variables
    ld hl, w_entsys ;Start of variable space
    ld bc, var_w1 ;Initial variable data
    ld de, var_w1_end - var_w1 ;Data length
    call memcopy

    ;Copy HRAM variables
    ld hl, h_variables ;Start of variable space
    ld bc, var_h ;Initial variable data
    ld de, var_h_end - var_h ;Data length
    call memcopy

    ;Return
    ret
;



; Contains the initial values of all variables in WRAM0.
var_w0:
    LOAD "WRAM0 VARIABLES", WRAM0, ALIGN[8]
        w_variables:

        ;Tile update queue
        w_screen_update_list_count:: db $00
        w_screen_update_list_head:: db $02
        w_screen_update_list::
            REPT $7F
            dw $FFFF
            ENDR
        ;

        ;Sprite stuff
        w_oam_mirror::
            REPT $A4
            db $00
            ENDR
        
        ASSERT low(w_oam_mirror) == 0

        ;Collision coordinate buffer
        w_intro_color_buffer::
        w_collision_buffer:: dw $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000
        ;

        ;Palette shenanigans
        w_palette_used:: db $00 ;Light palette
        w_palette_buffer:: 
            dw $0000, $0000, $0000, $0000
            dw $0000, $0000, $0000, $0000
            dw $0000, $0000, $0000, $0000
            dw $0000, $0000, $0000, $0000
            dw $0000, $0000, $0000, $0000
            dw $0000, $0000, $0000, $0000
            dw $0000, $0000, $0000, $0000
            dw $0000, $0000, $0000, $0000

            dw $0000, $0000, $0000, $0000
            dw $0000, $0000, $0000, $0000
            dw $0000, $0000, $0000, $0000
            dw $0000, $0000, $0000, $0000
            dw $0000, $0000, $0000, $0000
            dw $0000, $0000, $0000, $0000
            dw $0000, $0000, $0000, $0000
            dw $0000, $0000, $0000, $0000
        ;

        ;Entity creation variables
        w_entalloc_buffer::
        w_entalloc_x:: db $00
        w_entalloc_y:: db $00
        w_entalloc_type:: db $00
        w_entalloc_tag:: db $00
        w_entalloc_extra_count:: db $00
        w_entalloc_extra:: ds 32

        ;That intro thing
        w_intro_state:: db $00
        w_intro_timer:: db $00
        ;
    ENDL
    var_w0_end:
;

;Contains initial values for all entities.
var_w1:
    LOAD "WRAM1 VARIABLES", WRAMX, ALIGN[8]
        
        ;Regular entities
        w_entsys::
            REPT entity_count
                
                ;Execute
                IF !DEF(w_entsys_execute)
                    w_entsys_execute::
                ENDC
                w_entsys_execute_\@:
                jr @+(66 - 2) ;By default, entity is disabled
                ld de, (@ & $FFC0) | entity_variables ;Load DE with entity data pointer
                ld b, $FF ;Bank in which entity's code is stored
                ld hl, $FFFF ;Code address
                call bank_call_0 ;Bank switch and jump
                jr @+(66 - 15) ;Go to next entity

                ;Allocate
                IF !DEF(w_entsys_alloc)
                    
                    ; Loops through each entity in WRAMX.
                    ; Crash screen appears if no entity slots are free.
                    ;
                    ; Output:
                    ; `hl`: Starting address of free entity
                    w_entsys_alloc::
                    ;
                ENDC
                w_entity_alloc_\@:
                nop 
                nop 
                ld hl, (@ & $FFC0) | entity_pointer
                ret 

                ;Collision
                IF !DEF(w_entsys_collision)
                    w_entsys_collision::
                ENDC
                w_entity_collision_\@:
                jr @+(66 - 2)
                and a, c
                jr z, @+(66 - 5) ;Jump if collision mask doesn't match
                ld de, (@ & $FFC0) | entity_variables ;Load own variables
                ld hl, $40 + (@ & $FFC0) | entity_collision ;Store next entity address in HL
                ret

                ;Variables
                w_entsys_variables_\@:
                w_entity_state_\@: db $00
                w_entity_x_\@: dw $000C
                w_entity_y_\@: dw $0006
                w_entity_status_\@: db $00
                w_entity_hspp_\@: db $00
                w_entity_vspp_\@: db $00
                w_entity_type_\@: db $00
                w_entity_tag_\@: db $00
                w_entity_sprite_\@: db $00
                w_entity_health_\@: db $00
                
                ;Slack
                ds entity_variable_slack
            ENDR
        ;

        ;Terminator entity
        w_entsys_terminator::
            
            ;Execute
            w_entsys_terminator_execute::
            ret 
            ds 14

            ;Allocate
            w_entsys_terminator_alloc::
            ld h, $FF
            ret 
            ds 3

            ;Collision
            w_entsys_terminator_collision::
            ld d, $FF
            ret
            ds 12

            ;Variables
            ds 28
        ;
    ENDL
    var_w1_end:
;

; Contains the initial values for all HRAM variables.
var_h:
    LOAD "HRAM VARIABLES", HRAM
        h_variables::

        ;OAM DMA routine in HRAM
        h_dma_routine::
            
            ;Initialize OAM DMA
            ld a, HIGH(w_oam_mirror)
            ldh [rDMA], a

            ;Wait until transfer is complete
            ld a, 40
            .wait
            dec a
            jr nz, .wait

            ;Return
            ret
        ;

        ;Input
        h_input:: db $FF
        h_input_pressed:: db $00
        ;

        ;Important system variables
        h_setup:: db $FF
        h_is_color:: db $FF
        h_bank_number:: db $01
        h_sprite_slot:: db $01
        ;

        ;Shadow scrolling registers
        h_scx:: db $00
        h_scy:: db $00

        ;RNG stuff
        h_rng::
        h_rng_seed:: db $7E, $B2
        h_rng_out:: db $00, $00
        ;
    ENDL
    var_h_end:
;