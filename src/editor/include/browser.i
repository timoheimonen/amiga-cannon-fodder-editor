; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

BROWSER_MODULE_ID       equ $42524F57
        ifnd BROWSER_STATE
BROWSER_STATE           equ EDITOR_IO_BASE+224
        endif
BROWSER_STATE_BYTES     equ 128
BROWSER_MAGIC           equ BROWSER_STATE
BROWSER_VERSION         equ BROWSER_STATE+4
BROWSER_PURPOSE         equ BROWSER_STATE+6
BROWSER_DATA_DRIVE      equ BROWSER_STATE+8
BROWSER_SELECTED        equ BROWSER_STATE+10
BROWSER_TOP             equ BROWSER_STATE+12
BROWSER_COUNT           equ BROWSER_STATE+14
BROWSER_DISK_ID         equ BROWSER_STATE+16
BROWSER_DISK_NAME       equ BROWSER_STATE+32
BROWSER_FREE_BYTES      equ BROWSER_STATE+64
BROWSER_FREE_RECORDS    equ BROWSER_STATE+68
BROWSER_RECORDS         equ BROWSER_STATE+70
BROWSER_DIRECTORY_CRC   equ BROWSER_STATE+72
BROWSER_SELECTED_NAME   equ BROWSER_STATE+76
BROWSER_VALIDATION      equ BROWSER_STATE+92
BROWSER_STATUS          equ BROWSER_STATE+94
BROWSER_ERRORS          equ BROWSER_STATE+96
; Nonzero while Play or Edit waits for the check of the selected mission.
BROWSER_ACT             equ BROWSER_STATE+100
BROWSER_DISPLAY_SAFE    equ BROWSER_STATE+104
BROWSER_PAGE_COUNT      equ BROWSER_STATE+106
BROWSER_PAGE_INDEX      equ BROWSER_STATE+108
BROWSER_SCAN_INDEX      equ BROWSER_STATE+110
BROWSER_RESUMING        equ BROWSER_STATE+112
BROWSER_CONTROLLER_STATUS equ BROWSER_STATE+114
BROWSER_PENDING_ID      equ BROWSER_STATE+116
BROWSER_FILES_STATUS    equ BROWSER_STATE+120
BROWSER_FILES_VIEW      equ BROWSER_STATE+122
BROWSER_AUTHORING_OPERATION equ BROWSER_STATE+124
BROWSER_AUTHORING_RESERVED equ BROWSER_STATE+126
BROWSER_AUTHORING_NEW   equ 1
BROWSER_AUTHORING_OPEN  equ 2
BROWSER_STATE_TAG       equ $42525731
BROWSER_CONTROLLER_ID   equ $4354524C

; After accepted New setup, obsolete browser capacity fields carry by-value
; parameters through the two CTRL passes. Open retains the capacity meaning.
BROWSER_NEW_WIDTH       equ BROWSER_STATE+64
BROWSER_NEW_HEIGHT      equ BROWSER_STATE+66
BROWSER_NEW_FAMILY      equ BROWSER_STATE+68
BROWSER_NEW_TAG         equ BROWSER_STATE+70
BROWSER_NEW_VALID       equ $4E57
BROWSER_TEMPLATE_MISSION equ BROWSER_NEW_WIDTH
BROWSER_TEMPLATE_PHASE   equ BROWSER_NEW_HEIGHT
BROWSER_TEMPLATE_MAP     equ BROWSER_NEW_FAMILY
BROWSER_TEMPLATE_VALID   equ $5450

BROWSER_VALID_NONE      equ 0
BROWSER_VALID_INVALID   equ 2
BROWSER_VALID_REVIEW    equ 3
BROWSER_VALID_FAILED    equ 4
BROWSER_VALID_PENDING   equ 5
BROWSER_ROW_OK          equ 0
BROWSER_ROW_DAMAGED     equ 1
BROWSER_ROW_GLYPH       equ 2
BROWSER_ROW_WIDE        equ 3
; Widest title in the hill font. Title entry accepts what the browser shows
; and plays, so both use this one limit.
TITLE_HILL_WIDTH        equ 288

; Raw reads use only the first 4096 readback bytes. Copy directory filenames
; before another read replaces the engine's directory cache.
BROWSER_NAMES           equ EDITOR_READBACK_BASE+4096
BROWSER_NAME_BYTES      equ 16
BROWSER_ROWS            equ BROWSER_NAMES+EDITOR_DIRECTORY_RECORDS*16
BROWSER_ROW_BYTES       equ 72
BROWSER_PAGE_ROWS       equ 4
BROWSER_ROW_TITLE       equ 0
BROWSER_ROW_STATUS      equ 64
BROWSER_ROW_PHASES      equ 66
BROWSER_ROW_WIDTH       equ 68
BROWSER_ROW_RESERVED    equ 70
BROWSER_PARSER_WORK     equ EDITOR_READBACK_BASE+8192

        ifnd LIVE_FILES_CONTEXT
        ifgt BROWSER_STATE+128-EDITOR_IO_BASE-EDITOR_IO_BYTES
        fail "Browser resume record exceeds resident I/O storage"
        endif
        iflt BROWSER_STATE-STORAGE_IO_END
        fail "Browser resume record overlaps storage I/O"
        endif
        endif
        ifgt BROWSER_ROWS+BROWSER_PAGE_ROWS*BROWSER_ROW_BYTES-EDITOR_READBACK_BASE-EDITOR_READBACK_BYTES
        fail "Browser catalog exceeds readback storage"
        endif
        ifgt BROWSER_ROWS+BROWSER_PAGE_ROWS*BROWSER_ROW_BYTES-BROWSER_PARSER_WORK
        fail "Browser catalog overlaps parser scratch"
        endif
        ifgt BROWSER_PARSER_WORK+CFMD_PARSE_BYTES-EDITOR_READBACK_BASE-EDITOR_READBACK_BYTES
        fail "Browser parser scratch exceeds readback storage"
        endif
