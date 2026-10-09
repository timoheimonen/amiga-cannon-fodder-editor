; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

SAVE_MODULE_ID              equ $53565231
SAVE_MAGIC                  equ $53565231
SAVE_ABI                    equ 1
SAVE_CONTEXT_BYTES          equ 128
SAVE_CONTEXT                equ EDITOR_IO_BASE+352
SAVE_FLAGS                  equ 8
SAVE_DRIVE                  equ 10
SAVE_SOURCE_PHASES          equ 12
SAVE_PHASE_COUNT            equ 18
SAVE_SELECTED               equ 19
SAVE_DISK_ID                equ 20
SAVE_SOURCE_NAME            equ 36
SAVE_SOURCE_ID              equ 52
SAVE_SOURCE_BYTES           equ 56
SAVE_SOURCE_BODY_CRC        equ 60
SAVE_GENERATION             equ 64
SAVE_TARGET_ID              equ 68
SAVE_REVISION               equ 72
SAVE_STATUS                 equ 74
SAVE_STAGE                  equ 76
SAVE_PROCESSED              equ 78
SAVE_RESULT_BYTES           equ 80
SAVE_RESULT_BODY_CRC        equ 84
SAVE_READY                  equ 88
SAVE_CANCEL                 equ 92
SAVE_CLEANUP_STATUS         equ 96
SAVE_PRIVATE                equ 98

SAVE_HAS_SOURCE             equ 1
SAVE_AS_NEW                 equ 2
SAVE_KNOWN_FLAGS            equ 3
SAVE_CURRENT_SOURCE         equ $FF
SAVE_DIRECTORY_FULL         equ 1
SAVE_DISK_FULL              equ 2
SAVE_WRITE_PROTECTED        equ 5
SAVE_CLEANUP_PENDING        equ 1
SAVE_OUTPUT_CAPACITY        equ 3584
SAVE_SPT_SCRATCH             equ EDITOR_MANIFEST_BASE+SAVE_OUTPUT_CAPACITY
SAVE_ENCODER_STATE          equ EDITOR_SERIAL_WORK_BASE+864
SAVE_WRITE_WORK             equ EDITOR_SERIAL_WORK_BASE+992
SAVE_CANDIDATE              equ EDITOR_SERIAL_WORK_BASE+1032
SAVE_PARSER_WORK            equ EDITOR_READBACK_BASE+4096

SAVE_PREFLIGHT_RESULT       equ EDITOR_IO_BASE+480
SAVE_PREFLIGHT_BYTES        equ 32
SAVE_FREE_RECORDS           equ 0
SAVE_FREE_SECTORS           equ 2
SAVE_LIVE_RECORDS           equ 4
SAVE_PREFLIGHT_STATUS       equ 6
SAVE_DIRECTORY_CRC          equ 8
SAVE_PREFLIGHT_READY        equ 12

SAVE_STAGE_ARGUMENT         equ 1
SAVE_STAGE_PREFLIGHT        equ 2
SAVE_STAGE_MANIFEST         equ 3
SAVE_STAGE_VALIDATE         equ 4
SAVE_STAGE_CAPACITY         equ 5
SAVE_STAGE_PAYLOAD_WRITE    equ 6
SAVE_STAGE_PAYLOAD_VERIFY   equ 7
SAVE_STAGE_MANIFEST_WRITE   equ 8
SAVE_STAGE_MANIFEST_VERIFY  equ 9
SAVE_STAGE_COMMIT           equ 10
SAVE_STAGE_CLEANUP          equ 11

        ifne SAVE_CONTEXT+SAVE_CONTEXT_BYTES-SAVE_PREFLIGHT_RESULT
        fail "Save context overlaps preflight result"
        endif
        ifne SAVE_PREFLIGHT_RESULT+SAVE_PREFLIGHT_BYTES-EDITOR_IO_BASE-EDITOR_IO_BYTES
        fail "Save I/O partition exceeds resident budget"
        endif
        ifne SAVE_CANDIDATE+CFMD_RECORD_BYTES-EDITOR_SERIAL_WORK_BASE-EDITOR_SERIAL_WORK_BYTES
        fail "Save candidate exceeds serializer scratch"
        endif
        ifgt SAVE_SPT_SCRATCH+512-EDITOR_MANIFEST_BASE-EDITOR_MANIFEST_BYTES
        fail "Save manifest and SPT scratch overlap another owner"
        endif
