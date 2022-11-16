INCLUDE "hardware.inc"
INCLUDE "entitysystem.inc"
INCLUDE "entities/example.inc"

SECTION "ENTITY WARP", ROMX

;Warp initialization data
entity_warp_init::
    db bank(@) ;Bank ID
    dw entity_example_execute ;Code address
    db entcolF_example ;Collision mask
    dw entity_example_destroy ;Destruction code
    db bank(@) ;Destruction code bank
    dw entity_example_create ;Initialization code
;



; Entity creation code.
;
; Input:
; - `de`: Entity variable pointer
entity_example_create::

    ;Run any code the entity might need when created,
    ;like allocating dynamic memory.

    ;Return
    ret 
;



; Entity destroy event.
;
; Input:
; - `bc`: Entity pointer (anywhere)
;
; Output:
; - `b`: Free entity (`entsys_destroyV_x`)
entity_example_destroy::

    ;Do anything here that an entity might need to do when destroyed,
    ;like free dynamically allocated memory.

    ;Return
    ld b, entsys_destroyV_free ;Free entity
    ret 
;



; Entity execution code.
;
; Input:
; - `de`: Entity variable pointer
entity_example_execute::

    ;Any code an entity needs to execute each frame goes here

    ;Return
    ret
;