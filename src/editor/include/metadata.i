; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

CFMD_MAGIC              equ $43464D44
CFMD_ABI                equ 1
CFMD_RECORD_BYTES       equ $100
CFMD_OUTPUT_BYTES       equ $200
CFMD_PARSE_BYTES        equ $200
CFMD_ID                 equ $08
CFMD_GENERATION         equ $0C
CFMD_REVISION           equ $10
CFMD_RECRUITS           equ $12
CFMD_PHASE_COUNT        equ $14
CFMD_PHASE_INDEX        equ $15
CFMD_OBJECTIVE_COUNT    equ $16
CFMD_OBJECTIVE_MASK     equ $17
CFMD_AGGRESSION_MIN     equ $18
CFMD_AGGRESSION_MAX     equ $19
CFMD_RANK               equ $1A
CFMD_GRENADES           equ $1B
CFMD_ROCKETS            equ $1C
CFMD_FLAGS              equ $1D
CFMD_MANIFEST_BYTES     equ $1E
CFMD_MANIFEST_CRC       equ $20
CFMD_MAP_BYTES          equ $24
CFMD_SPT_BYTES          equ $26
CFMD_MAP_CRC            equ $28
CFMD_SPT_CRC            equ $2C
CFMD_OBJECTIVES         equ $30
CFMD_MANIFEST_NAME      equ $38
CFMD_MAP_NAME           equ $48
CFMD_SPT_NAME           equ $58
CFMD_TITLE              equ $68
CFMD_PHASE_TITLE        equ $A8
CFMD_ENEMY_GRENADES_BIT equ 0
CFMD_OVERVIEW_BIT       equ 1
CFMD_COUNTDOWN_BIT      equ 2

CFMI_ERROR_ARGUMENT     equ -1
CFMI_ERROR_HEADER       equ -2
CFMI_ERROR_CRC          equ -3
CFMI_ERROR_JSON         equ -4
CFMI_ERROR_SCHEMA       equ -5
CFMI_ERROR_RANGE        equ -6
CFMI_ERROR_REFERENCE    equ -7
CFMI_ERROR_PHASE        equ -8
