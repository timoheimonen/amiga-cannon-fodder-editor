; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Persistent context; trusted controller code publishes lifecycle state.
; Only resident code captures or restores the main-lifecycle stack anchor.
session_custom_mode         equ EDITOR_SESSION_BASE
session_event               equ EDITOR_SESSION_BASE+2
; Mode/event are one lifecycle longword. Native mode has event zero except
; during checked RETURN; pre-hill rollback clears both words together.
SESSION_RESERVED            equ EDITOR_SESSION_BASE+4
session_stack_anchor        equ EDITOR_SESSION_BASE+8
session_outcome_sr          equ EDITOR_SESSION_BASE+12
session_outcome_no_squad    equ EDITOR_SESSION_BASE+14
session_outcome_success     equ EDITOR_SESSION_BASE+16
session_outcome_failure     equ EDITOR_SESSION_BASE+18
SESSION_SNAPSHOT_VALID      equ EDITOR_SESSION_BASE+20
SESSION_SNAPSHOT_TAG        equ $534E
SESSION_EVENT_HILL          equ 1
SESSION_EVENT_OUTCOME       equ 2
SESSION_EVENT_RETURN        equ 3

; Byte offsets relative to the ABI 2 module context pointer in A0.
REQ_NAME                    equ 24
REQ_ID                      equ 40
REQ_CAPACITY                equ 44
REQ_ACTION                  equ 48
REQ_STATUS                  equ 50
REQ_DRIVE                   equ 52
REQ_OLD_DRIVE               equ 54
REQ_PURPOSE                 equ 56
REQ_LAST_RESULT             equ 58
REQ_RESULT_ID               equ 60
REQ_ACTION_UNENTERED        equ -1
REQ_ACTION_RETURN           equ 0
REQ_ACTION_DISPATCH         equ 1
REQ_ACTION_PREPARE          equ 2
REQ_PURPOSE_EDITOR          equ 1
REQ_PURPOSE_PLAY            equ 2
REQ_PURPOSE_TEST            equ 4

; The first 96 bytes hold controller state; the remaining 288 hold retry state.
SESSION_CHECKPOINT_BASE     equ EDITOR_SESSION_BASE+96
SESSION_CHECKPOINT_VALID    equ EDITOR_SESSION_BASE+288
SESSION_CHECKPOINT_TAG      equ $434B5031
SESSION_CHECKPOINT_END      equ EDITOR_SESSION_BASE+384
        ifgt SESSION_CHECKPOINT_END-EDITOR_SESSION_BASE-EDITOR_SESSION_BYTES
        fail "Session checkpoint exceeds persistent context"
        endif
