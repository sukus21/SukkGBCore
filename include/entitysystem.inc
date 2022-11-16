;Entity system is enitialized in `variables_init`.

;Entity size in bytes
entity_size equ $40
entity_count equ $1F

;Constant values I need
_jr equ $18
_next equ entity_size - 2
_ldan8 equ $3E

;Relative entity pointers
RSRESET
entity_pointer rb 0
entity_execute rb 15
entity_allocate rb 6
entity_collision rb 12
entity_variables rb 28
entity_destroy rb 3
entity_end rb 0

;Entity variables
RSSET entity_variables
entvar_start rb 0
entvar_state rb 1
entvar_x rb 2
entvar_y rb 2
entvar_status rb 1
entvar_hspp rb 1
entvar_vspp rb 1
entvar_type rb 1
entvar_tag rb 1
entvar_sprite rb 1
entvar_health rb 1
entvar_end rb 0
entity_variable_slack equ entity_size - entvar_end
ASSERT entity_end >= entvar_end

;Entity collision mask bits
RSRESET

;Visibility flag, is culled by the culling system.
entcolB_visible rb 1
entcolF_visible equ 1 << entcolB_visible

;Remedy takes damage
entcolB_enemy rb 1
entcolF_enemy equ 1 << entcolB_enemy

;Enemies take damage
entcolB_ally rb 1
entcolF_ally equ 1 << entcolB_ally

;Interactable in overworld
entcolB_interact rb 1
entcolF_interact equ 1 << entcolB_interact

;Warp tile in overworld
entcolB_warp rb 1
entcolF_warp equ 1 << entcolB_warp



;`entvar_status` bits
RSRESET
entstatB_visible rb 1
entstatF_visible equ 1 << entstatB_visible

entstatB_movup rb 1
entstatF_movup equ 1 << entstatB_movup

entstatB_movleft rb 1
entstatF_movleft equ 1 << entstatB_movleft



;`entsys_destroy` flags
entsys_destroyV_free equ $00
entsys_destroyV_keep equ $FF 