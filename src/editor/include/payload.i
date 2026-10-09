; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

CFVR_MAGIC                 equ $43465652
CFVR_ABI                   equ 1
CFVR_BYTES                 equ 32
CFVR_SCRATCH_BYTES          equ 128
CFVR_ERRORS                equ 8
CFVR_REVIEWS               equ 12
CFVR_WIDTH                 equ 16
CFVR_HEIGHT                equ 18
CFVR_OBJECTS               equ 20
CFVR_TROOP_DEMAND           equ 22
CFVR_MARKERS               equ 24
CFVR_RESOURCE_PAIR         equ 26
CFVR_PHASE                 equ 27

CFVR_ERROR_ARGUMENT        equ -1
CFVR_ERROR_METADATA        equ -2
CFVR_ERROR_LENGTH          equ -3
CFVR_ERROR_CRC             equ -4
CFVR_ERROR_MAP             equ -5
CFVR_ERROR_RESOURCE        equ -6
CFVR_ERROR_SPT             equ -7

CFVR_E_GRID_FLOOR          equ 0
CFVR_E_TILE_RANGE          equ 1
CFVR_E_MARKER_CAPACITY     equ 2
CFVR_E_COMPANION_SUFFIX    equ 3
CFVR_E_BUNDLE_RENDER       equ 4
CFVR_E_BUNDLE_PRIMARY      equ 5
CFVR_E_RUNTIME_SENTINEL    equ 6
CFVR_E_DISABLED_UNOWNED    equ 7
CFVR_E_TRANSFORMED_X       equ 8
CFVR_E_DISABLED_COUNTED    equ 9
CFVR_E_NEGATIVE_Y          equ 10
CFVR_E_PRIMARY_SLOT        equ 11
CFVR_E_NO_TROOP            equ 12
CFVR_E_TROOP_CAPACITY      equ 13
CFVR_E_NO_POSITIVE         equ 14
CFVR_E_LABEL_DEPENDENCIES  equ 15
CFVR_E_MISSING_COMPUTER    equ 16
CFVR_E_MISSING_RESCUE      equ 17
CFVR_E_MISSING_TENT        equ 18
CFVR_E_MISSING_HOME        equ 19
CFVR_E_COUNTDOWN_OVERVIEW  equ 20

CFVR_R_TILE_399            equ 0
CFVR_R_RESERVED_CELL      equ 1
CFVR_R_MARKER_CLASS        equ 2
CFVR_R_MARKER_LOS          equ 3
CFVR_R_OFF_MAP             equ 4
CFVR_R_EMPTY_ENEMY         equ 5
CFVR_R_EMPTY_BUILDING      equ 6
CFVR_R_FACTORY             equ 7
CFVR_R_MULTIPLE_TENTS      equ 8
CFVR_R_CIVILIAN_HOME       equ 9
CFVR_R_PLAYTEST            equ 10
