; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Fixed request and workspace for explicit browser file operations.
BDQ_CONTEXT              equ EDITOR_IO_BASE+352
BDQ_MAGIC                equ $42445131
BDQ_VERSION              equ 1
BDQ_BYTES                equ 128
BDQ_OPERATION            equ 8
BDQ_DRIVE                equ 10
BDQ_CONFIRMED            equ 12
BDQ_RESERVED             equ 14
BDQ_NAME                 equ 16
BDQ_DISK_ID              equ 32
BDQ_DIRECTORY_CRC        equ 48
BDQ_MISSION_ID           equ 52
BDQ_FILE_COUNT           equ 56
BDQ_GENERATION_COUNT     equ 58
BDQ_CANCEL               equ 60
BDQ_STATUS               equ 64
BDQ_ATTEMPTED            equ 66
BDQ_VERIFIED             equ 68
BDQ_REMOVED              equ 70
BDQ_INSTALLED            equ 72
BDQ_PREVIOUS_KEEP        equ 74
BDQ_PREVIOUS_VECTOR      equ 76
BDQ_LIVE_COUNT           equ 80
BDQ_CMI_COUNT            equ 82
BDQ_RECOVERY_COUNT       equ 84
BDQ_SCAN_INDEX           equ 86
BDQ_CLASS_READY          equ 88
BDQ_DELETE               equ 1
BDQ_RECOVER              equ 2

        ifnd LIVE_FILES_CONTEXT
BDQ_SNAPSHOT             equ EDITOR_READBACK_BASE+6144
BDQ_PROTECTED            equ EDITOR_READBACK_BASE+13064
BDQ_SELECTED             equ EDITOR_READBACK_BASE+13084
BDQ_RECOVERY             equ EDITOR_READBACK_BASE+13104
BDQ_RECORDS              equ EDITOR_READBACK_BASE+13124
BDQ_VIEW                 equ EDITOR_READBACK_BASE+14024
        endif
BDQ_MASK_BYTES           equ 20

CF_DELETE_LIBRARY        equ 1
CF_DELETE_GUARDED        equ 1
CF_DELETE_RECORD_SET     equ 1
        ifnd LIVE_FILES_CONTEXT
CF_DELETE_WORK_BASE      equ EDITOR_READBACK_BASE+12288
        endif
CF_DELETE_STATE          equ CF_DELETE_WORK_BASE+652
cf_delete_marker         equ CF_DELETE_STATE
cf_delete_request        equ CF_DELETE_STATE+64
bdq_open_tag             equ CF_DELETE_STATE+100
bdq_identity_valid       equ CF_DELETE_STATE+102
cf_del_set_count         equ CF_DELETE_STATE+104
CF_DELETE_STATE_END      equ CF_DELETE_STATE+106
BDQ_OPEN_TAG             equ $4244
cf_delete_attempted      equ BDQ_CONTEXT+BDQ_ATTEMPTED
cf_delete_verified       equ BDQ_CONTEXT+BDQ_VERIFIED

CF_WRITE_WORK            equ EDITOR_SERIAL_WORK_BASE+1032
CF_WRITE_CANCEL          equ BDQ_CONTEXT+BDQ_CANCEL

        ifgt CF_DELETE_STATE_END-BDQ_PROTECTED
        fail "Browser delete state overlaps catalog masks"
        endif
        ifgt BDQ_VIEW+150*2-EDITOR_READBACK_BASE-EDITOR_READBACK_BYTES
        fail "Browser file catalog exceeds readback budget"
        endif
        ifgt CF_WRITE_WORK+40-EDITOR_SERIAL_WORK_BASE-EDITOR_SERIAL_WORK_BYTES
        fail "Browser shared IRQ workspace exceeds serializer workspace"
        endif
        ifgt BDQ_CONTEXT+BDQ_BYTES-EDITOR_IO_BASE-EDITOR_IO_BYTES
        fail "Browser delete request exceeds resident I/O"
        endif
