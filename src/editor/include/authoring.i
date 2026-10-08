; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; AUR1 authoring record shared by the editor, page overlays and resident recovery.
AUR_BASE             equ EDITOR_IO_BASE+224
AUR_BYTES            equ 128
AUR_PAYLOAD_BYTES    equ 112
AUR_MAGIC            equ $41555231
AUR_VERSION          equ 1
AUR_FLAGS            equ 6
AUR_DRIVE            equ 8
AUR_CAMERA_X         equ 10
AUR_CAMERA_Y         equ 12
AUR_TOOL             equ 14
AUR_DISK_ID          equ 16
AUR_DISK_NAME        equ 32
AUR_SOURCE_BYTES     equ 64
AUR_SOURCE_CRC       equ 68
AUR_SOURCE_ID        equ 72
AUR_SOURCE_NAME      equ 76
AUR_SOURCE_REVISION  equ 92
AUR_TILE             equ 94
AUR_OBJECT_TYPE      equ 96
AUR_OBJECT_INDEX     equ 98
AUR_UNDO_NEXT        equ 100
AUR_UNDO_COUNT       equ 102
AUR_PHASE_MAP        equ 104
AUR_PHASE_COUNT      equ 110
AUR_SELECTED         equ 111
AUR_TRANSPORT_STATUS equ 112
AUR_TRANSPORT_ID     equ 114
; Continuation retained until a matching entered SAVE result is consumed.
AUR_EXIT_REQUEST     equ 118
AUR_CONTINUE_EXIT    equ 1
AUR_CONTINUE_NEW     equ 2
AUR_CONTINUE_TEMPLATE equ 3
AUR_CONTINUE_OPEN    equ 4
; Page receipt, assigned only while PAGE_PENDING is set.
AUR_PAGE_KIND        equ 120
AUR_PAGE_CANDIDATE   equ 122
AUR_PAGE_TILES       equ 1
AUR_PAGE_FILL        equ 2
AUR_PAGE_RESIZE      equ 3
AUR_PAGE_MENU        equ 4
AUR_PAGE_TEMPLATE    equ 5
AUR_PAGE_OPEN        equ 6
AUR_PAGE_FILES       equ 7
AUR_PAGE_MESSAGE     equ 8
AUR_PAGE_LARGE       equ 9
AUR_PAGE_OBJECT_VIEW equ 10
AUR_PAGE_OBJECT_PALETTE equ 11
OBJECT_PALETTE_MODULE_ID equ $4f50414c
OBJECT_VIEW_MODULE_ID equ $4F424A56
AUR_PAGE_NONE        equ $FFFF
TILE_MODULE_ID       equ $54494C45
FILL_MODULE_ID       equ $46494C4C
RESIZE_MODULE_ID     equ $52535A45
MENU_MODULE_ID       equ $4D454E55
TEMPLATE_MODULE_ID   equ $544D504C
OPEN_MODULE_ID       equ $4F50454E
FILES_MODULE_ID      equ $464F5053
FILES_REQUEST_TAG    equ $4C46
AUR_ORIGIN           equ 124
; Zero means assets complete; one retains a draft whose assets need reloading.
AUR_ASSET_STATE      equ 126
AUR_ASSETS_INCOMPLETE equ 1
AUR_HAS_SOURCE       equ 1
AUR_DIRTY            equ 2
AUR_SAVE_PENDING     equ 4
AUR_PAGE_PENDING     equ 8
AUR_KNOWN_FLAGS      equ 15
AUR_ERROR_OWNER      equ -100
AUR_ERROR_STATE      equ -101
AUR_ERROR_SOURCE     equ -102
AUR_ERROR_REQUEST    equ -103
AUR_ERROR_RESULT     equ -104
AUR_ERROR_PAYLOAD    equ -105
AUR_STATUS_UNENTERED equ -32768

; Only initial validation and successful receive use these transient bytes.
AUR_VALIDATION       equ EDITOR_SERIAL_WORK_BASE
AUR_VALIDATION_WORK  equ EDITOR_SERIAL_WORK_BASE+32
AUR_VALIDATION_END   equ EDITOR_SERIAL_WORK_BASE+160
        ifne AUR_BASE+AUR_BYTES-SAVE_CONTEXT
        fail "Authoring record must end before SVR1"
        endif
        ifne AUR_SELECTED+1-AUR_PAYLOAD_BYTES
        fail "Authoring payload must be 112 bytes"
        endif
        ifne AUR_ASSET_STATE+2-AUR_BYTES
        fail "Authoring origin words exceed BRW allocation"
        endif

; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Typed phase-list identity and continuation values.
AUR_PAGE_PHASE equ 12
PHASE_MODULE_ID equ $50484153
AUR_CONTINUE_PHASE_SELECT equ 5
AUR_CONTINUE_PHASE_ADD equ 11
AUR_CONTINUE_PHASE_DELETE equ 17
MENU_PHASE_SETTINGS equ 18
PHL_RESULT_SAME equ 0
PHL_RESULT_MAP equ 1
PHL_RESULT_REPLACED equ 3

; Typed validation, focus and Test state within the fixed session tail.
AUR_PAGE_VALIDATION equ 13
AUR_PAGE_TEST equ 14
VALIDATION_MODULE_ID equ $56414C44
AUR_CONTINUE_PHASE_BLANK equ 19
AUR_CONTINUE_PHASE_TEMPLATE equ 20
E7_CONTEXT equ EDITOR_SESSION_BASE+368
E7_TAG equ $45375631
E7_STAGE equ E7_CONTEXT+4
E7_TESTED equ E7_CONTEXT+5
E7_PHASE equ E7_CONTEXT+6
E7_LOCATION equ E7_CONTEXT+7
E7_X equ E7_CONTEXT+8
E7_Y equ E7_CONTEXT+10
E7_INDEX equ E7_CONTEXT+12
E7_RESERVED equ E7_CONTEXT+14
E7_JUMP_PENDING equ 1
E7_FOCUS_APPLIED equ 2

; Test uses the existing session tail and never preserves an overlay pointer.
AUR_CONTINUE_TEST equ 21
TEST_MODULE_ID equ $54535431
E7_TEST_READY equ 3
E7_TEST_PLAY equ 4
E7_TEST_RELOAD equ 5
E7_TEST_RETURNED equ 6
TEST_ERROR_STATE equ -120
TEST_ERROR_SOURCE equ -121
TEST_ERROR_GAMEPLAY equ -122
TEST_ERROR_TITLE equ -123
TEST_ERROR_CAPACITY equ -124
