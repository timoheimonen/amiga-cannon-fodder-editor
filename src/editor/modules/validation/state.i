; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

VDM_ORIGINAL equ VD_OWNER
VDM_OWNER equ VD_OWNER+384
; One page of issue records, VD_ROW_BYTES each.
VDM_PAGE_ROWS equ 8
VDM_PAGE equ VD_CONTEXT_END
VDM_STATE equ VDM_PAGE+VDM_PAGE_ROWS*VD_ROW_BYTES
VDM_TAG equ $56444D31
VDM_MAGIC equ VDM_STATE
VDM_DIRECTORY equ VDM_STATE+4
VDM_DIRECTORY_VALID equ VDM_STATE+8
VDM_SOURCE_COUNT equ VDM_STATE+10
VDM_PHASE equ VDM_STATE+12
VDM_PAGE_COUNT equ VDM_STATE+14
VDM_SKIP equ VDM_STATE+16
VDM_TOTAL equ VDM_STATE+20
VDM_ERRORS equ VDM_STATE+24
VDM_REVIEWS equ VDM_STATE+28
VDM_FOCUS equ VDM_STATE+32
VDM_TEXT equ VDM_STATE+40
VDM_TEXT_END equ VDM_TEXT+80
VDM_ERROR_STATE equ -124
VDM_ERROR_STALE equ -125
VDM_ERROR_SOURCE equ -126
VDM_RESULT_JUMP equ 4
VDM_SUMMARY_BYTES equ 40
VDS_STATUS equ 0
VDS_BASE equ 4
VDS_TOTAL equ 8
VDS_ERRORS equ 12
VDS_REVIEWS equ 16
VDS_ERROR_BITS equ 20
VDS_REVIEW_BITS equ 24
VDS_SIZE equ 28
; VDM_FOCUS holds the located-issue jump record; only an entered, retired Jump
; publishes it.
        ifgt VDM_TEXT_END-VD_PRIVATE-VD_PRIVATE_BYTES
        fail "VALD mission state exceeds private tail"
        endif
