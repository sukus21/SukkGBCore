INCLUDE "hardware.inc"
INCLUDE "entitysystem.inc"

SECTION "ENTITYSYSTEM", ROM0

; Creates an entity from a given pointer.
; Lives in ROM0.
; 
; Input:
; - `bc`: Entity initialization data
;
; Output:
; - `hl`: Entity variable pointer
entsys_alloc::
    
    ;Find a free entity
    call w_entsys_alloc

    ;Ensure entity validity
    .realloc::
    ld a, h
    cp a, $FF
    jr nz, :+

        ;Entity list is full, crash game
        ld hl, error_entityoverflow
        rst v_error
    :

    ;Copy variable offset to DE
    ld d, h
    ld a, l
    add a, entity_variables
    ld e, a
    push hl

    ;Unclog execution
    xor a
    ld [hl+], a
    ld [hl+], a
    inc l
    inc l
    inc l
    inc l

    ;Set execution code bank
    ld a, [bc]
    ld [hl+], a
    inc l
    inc bc

    ;Set execution code pointer
    ld a, [bc]
    ld [hl+], a
    inc bc
    ld a, [bc]
    ld [hl+], a

    ;Write "jr @+66-2" in alloc section
    ld a, l
    add a, 5
    ld l, a
    ld a, _jr
    ld [hl+], a
    ld [hl], _next

    ;Write collision mask
    ld a, l
    add a, 5
    ld l, a
    ld a, _ldan8
    ld [hl+], a
    inc bc
    ld a, [bc]
    ld [hl+], a

    ;Write destruction code pointer
    ld a, l
    or a, %00111111
    dec a
    dec a
    ld l, a
    inc bc
    ld a, [bc]
    ld [hl+], a
    inc bc
    ld a, [bc]
    ld [hl+], a
    inc bc
    ld a, [bc]
    ld [hl], a

    ;Write coordinates from entalloc data
    push bc
    ld a, l
    and a, %11000000
    or a, entvar_x
    ld l, a
    ld bc, w_entalloc_x
    ld a, [bc] ;read x
    inc bc
    ld [hl+], a ;upper x
    ld [hl], 0 ;lower x
    inc l
    ld a, [bc] ;read y
    inc bc
    ld [hl+], a ;upper y
    ld [hl], 0 ;lower y

    ;Write type and tag
    ld a, l
    sub a, (entvar_y+1) - entvar_type
    ld l, a
    ld a, [bc]
    inc bc
    ld [hl+], a ;type
    ld a, [bc]
    inc bc
    ld [hl], a ;tag

    ;Load extras
    ld a, l
    and a, %11000000
    ld l, a
    ld e, a
    ld a, [bc]
    inc bc
    cp a, 0
    jr z, .doneextra
    ld d, a
    .extraloop

        ;Get offset
        ld a, [bc]
        inc bc
        add a, e
        ld l, a

        ;Get value
        ld a, [bc]
        inc bc
        ld [hl], a

        ;Decrement loop count
        dec d
        jr nz, .extraloop

    .doneextra
    pop bc

    ;Write variable pointer to DE
    ld d, h
    ld a, l
    and a, %11000000
    or a, entity_variables
    ld e, a

    ;Jump to entity initialization code
    inc bc
    ld a, [bc]
    ld l, a
    inc bc
    ld a, [bc]
    ld h, a
    call _hl_

    ;Return
    pop hl
    ret 
;



; Frees an allocated entity.
; Lives in ROM0.
;
; Input: 
; - `hl`: Pointer to entity
;
; Destroys: `af`, `b`
entsys_free::

    ;Switch WRAMX bank
    ld a, bank(w_entsys)
    ldh [rSVBK], a
    .skipbank
    
    ;Save this in B
    ld b, l
    
    ;Stop execution (write "jr @+66-2")
    ld a, _jr
    ld [hl+], a
    ld a, _next
    ld [hl+], a

    ;Re-enable allocation (write "nop" twice)
    ld a, b
    add a, entity_allocate
    ld l, a
    xor a
    ld [hl+], a
    ld [hl+], a

    ;Stop collision (write "jr @+66-2")
    ld a, b
    add a, entity_collision
    ld l, a
    ld a, _jr
    ld [hl+], a
    ld a, _next
    ld [hl+], a

    ;Return
    ld l, b
    ret
;



; Deletes ALL entities currently in the entity system.
; Lives in ROM0.
entsys_clear::
    
    ;Set initial values
    ld hl, w_entsys
    ld de, entity_size
    ld c, entity_count

    ;Call `entsys_free` for each entity
    .loop
        call entsys_free.skipbank
        add hl, de
        dec c
        jr nz, .loop
    
    ;Return
    ret
;



; Damage an entity.
; Decreases entity health, and calls destroy 
; event if entity health reaches 0.
; Lives in ROM0.
;
; Input:
; - `de`: Entity pointer (%xx000000)
; - `c`: Damage to deal
;
; Saves: `hl`
entsys_damage::

    ;Put health pointer into HL
    push hl
    ld h, d
    ld a, e
    or a, entvar_health
    ld l, a

    ;Subtract damage
    ld a, [hl]
    inc c
    sub a, c
    ld [hl], a

    ;Did it reach 0 or below?
    call c, entsys_destroy
    inc [hl]

    ;Return
    pop hl
    ret 
;



; Runs a piece of code from the entity, then frees it.
; Lives in ROM0.
;
; Input:
; - `hl`: Pointer to entity (anywhere)
;
; Destroys: `af`, `bc`, `d`, unknown
;
; Saves: `hl`
entsys_destroy::

    ;Save HL
    push hl
    
    ;Prepare pointer
    ld b, h
    ld c, l
    ld a, l
    and a, %11000000
    ld l, a
    push hl
    or a, %00111111
    ld l, a

    ;Read bank and address
    ld d, [hl]
    dec l
    ld a, [hl-]
    ld l, [hl]
    ld h, a

    ;Call destroy event code
    call bank_call_xd

    ;Free the entity from entsys (if b != 0)
    pop hl
    xor a
    cp a, b
    call nz, entsys_free

    ;Return
    pop hl
    ret 
;



; Checks for a collision with the camera bounding box.
; Any entities collided with get their visibility flag set.
; Lives in ROM0.
entsys_oobcheck::

    ;Prepare camera pseudo-entity
    ;Read camera XXYY position into BC and DE
    ;ld hl, w_camera_position
    ld a, [hl+]
    sub a, 2
    ld b, a
    jr nc, :+
        ld b, 0
    :
    ld a, [hl+]
    ld c, a
    ld a, [hl+]
    sub a, 2
    ld d, a
    jr nc, :+
        ld d, 0
    :
    ld a, [hl+]
    ld e, a

    ;Write those positions to pseudo entity
    ;Write XX and YY
    ;ld hl, w_camera_cull
    push hl
    ld a, b
    ld [hl+], a
    ld a, c
    ld [hl+], a
    ld a, d
    ld [hl+], a
    ld a, e
    ld [hl+], a

    ;Write xx and yy
    ld a, b
    add a, 14
    ld [hl+], a
    ld a, c
    ld [hl+], a
    ld a, d
    add a, 12
    ld [hl+], a
    ld a, e
    ld [hl+], a

    ld hl, w_entsys_collision

    .loop
        ;Load collision mask to check
        ld c, entcolF_visible

        ;Check entity masks
        call _hl_ ;HL points to `w_entsys_collision`.
        ld a, d
        cp a, $FF
        jr z, .quit

        ;Refresh funny value
        pop bc
        push bc
        push de
        push hl

        ;Call collision
        call entsys_collision_RE
        ld b, 0
        jr z, :+
            set entstatB_visible, b
        :
        pop hl
        pop de

        ;Get pointer to visible flag
        ld a, e
        and a, %11000000
        or a, entvar_status
        ld e, a

        ;Set or reset visibility flag
        ld a, [de]
        res entstatB_visible, a
        or a, b
        ld [de], a

        ;Go back in
        jr .loop

    .quit
        
        ;Clean up stack and return
        pop bc
        ret 
;



; Entity collision check.
; Rectangle to entity.
; Lives in ROM0.
;
; Input:
; - `bc`: Rectangle data pointer [XXYYxxyy]
; - `de`: Entity data pointer [-XXYY----WWHH]
;
; Output:
; - `fz`: Result (0 = yes, 1 = no)
;
; Destroys: all
entsys_collision_RE::
    
    ;Load rectangle pointer into HL
    ld h, b
    ld l, c
    inc l
    inc l
    
    ;Load Y-positions into BC
    inc e
    inc e
    inc e
    ld a, [de]
    ld b, a
    inc e
    ld a, [de]
    ld c, a

    ;Comparison #1
    ;cp rect_y, entity_y
    ld a, [hl+]
    cp a, b
    jr nz, :+

        ld a, [hl]
        cp a, c
    :

    jr c, .lesserY

        ;Rectangle is below entity Y-position
        ;Move entity pointer to sub-height
        ld a, e
        add a, 8
        ld e, a
        
        ;Add entity height to Y-position
        ld a, [de]
        dec e
        add a, c
        ld c, a
        ld a, [de]
        adc a, b
        ld b, a

        ;Compare again
        ;cp rect_y, entity_y + entity_height
        dec l ;rect_y
        ld a, [hl+]
        cp a, b
        jr nz, :+

            ld a, [hl]
            cp a, c
        :

        ;Branch maybe
        jr c, .checkx

        ;Otherwise return false
        xor a
        ret 
    ;

    .lesserY

        ;Rectangle is ABOVE entity Y-position
        inc l
        inc l
        inc l ;rect_y2

        ;Compare again
        ;cp rect_y + rect_height, entity_y
        ld a, [hl+]
        cp a, b
        jr nz, :+

            ld a, [hl]
            cp a, c
        :

        ;Branch maybe
        dec l
        dec l
        dec l
        dec l
        jr nc, .checkx

        ;Otherwise return false
        xor a
        ret 
    ;

    .checkx
    
    ;Move entity pointer
    ld a, e
    and a, %11000000
    or a, entvar_x
    ld e, a

    ;Get rectangle X-position
    dec l
    dec l
    dec l
    
    ;Load X-positions into BC
    ld a, [de]
    ld b, a
    inc e
    ld a, [de]
    ld c, a

    ;Comparison #1
    ;cp rect_x, entity_x
    ld a, [hl+]
    cp a, b
    jr nz, :+

        ld a, [hl]
        cp a, c
    :

    jr c, .lesserX

        ;Player is to the left of entity X-position
        ;Move entity pointer to sub-width
        ld a, e
        add a, 8
        ld e, a
        
        ;Add entity width to X-position
        ld a, [de]
        dec e
        add a, c
        ld c, a
        ld a, [de]
        adc a, b
        ld b, a

        ;Compare again
        ;cp rect_x, entity_x + entity_width
        dec l
        ld a, [hl+]
        cp a, b
        jr nz, :+

            ld a, [hl]
            cp a, c
        :

        ;Branch maybe
        jr c, .checkd

        ;Otherwise return false
        xor a
        ret 
    ;

    .lesserX

        ;Rectangle is to the right of entity X-position
        inc l
        inc l
        inc l

        ;Compare again
        ;cp w_player_x, entity_x + entity_width
        ld a, [hl+]
        cp a, b
        jr nz, :+

            ld a, [hl]
            cp a, c
        :

        ;Branch maybe
        dec l
        dec l
        dec l
        dec l
        jr nc, .checkd

        ;Otherwise return false
        xor a
        ret 
    ;
    
    ;Collision was found, reset Z flag and return
    .checkd
    rra
    ret 
;