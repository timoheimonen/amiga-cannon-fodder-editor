; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

VALD_ID             equ $56414C44
VD_PRIVATE_BYTES    equ 2048
VD_PRIVATE          equ EDITOR_MODULE_BASE+EDITOR_SERIALIZER_BYTES-VD_PRIVATE_BYTES
VD_OWNER            equ VD_PRIVATE
VD_STAGE_SPT        equ VD_OWNER+512
VD_METADATA         equ VD_STAGE_SPT+432
VD_SUMMARIES        equ VD_METADATA+256
VD_ROWS             equ VD_SUMMARIES+240
VD_CONTEXT          equ VD_ROWS+192
; Inputs: inclusive global first ordinal, global base and capacity1..12.
VD_SKIP             equ VD_CONTEXT
VD_BASE             equ VD_CONTEXT+4
VD_CAPACITY         equ VD_CONTEXT+8
VD_RESERVED         equ VD_CONTEXT+10
; Outputs: exclusive global ordinal, row count, structural status, CFVR32.
VD_TOTAL            equ VD_CONTEXT+12
VD_WRITTEN          equ VD_CONTEXT+16
VD_STATUS           equ VD_CONTEXT+18
VD_ERRORS           equ VD_CONTEXT+20
VD_REVIEWS          equ VD_CONTEXT+24
VD_CONTEXT_END      equ VD_CONTEXT+64
VD_OUTPUT           equ EDITOR_SERIAL_WORK_BASE+864
VD_SCRATCH          equ VD_OUTPUT+32
VD_WORK_END         equ VD_SCRATCH+128
VD_ROW_BYTES        equ 16
VD_MAX_ROWS         equ 12
        ifgt VD_CONTEXT_END-VD_PRIVATE-VD_PRIVATE_BYTES
        fail "VALD private data exceeds reserved tail"
        endif
        ifgt VD_WORK_END-EDITOR_SERIAL_WORK_BASE-EDITOR_SERIAL_WORK_BYTES
        fail "VALD validation scratch exceeds work"
        endif
