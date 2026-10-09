; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        include "layout.i"
        include "module.i"
        include "session.i"
        include "fodders.i"
        include "metadata.i"
        include "payload.i"
        include "storage_read.i"
        include "storage.i"
        include "browser.i"
        include "save.i"
        include "authoring.i"
        include "../editor/state.i"
        include "ui.i"
        include "dialog.i"
STORAGE_INSPECT_ONLY equ 1
AUR_VALIDATE_ONLY equ 1
AUR_PHASE_ADDITIONS equ 1

PAYLOAD_STRUCTURAL_ONLY equ 1
        section .text,code
        xdef template_start,template_entry,template_end,template_owner
        xdef template_before_commit,template_published,template_custom_retry
        xdef template_original_retry,template_before_stage
; Fixed load-base anchor: X+PCREL(pc) reads the absolute address X
; PC-relatively from module code.
module_pc_base:
PCREL   equ module_pc_base-EDITOR_MODULE_BASE
template_start:
        dc.l MODULE_MAGIC
        dc.w MODULE_ABI,MODULE_HEADER_BYTES
        dc.l TEMPLATE_MODULE_ID,EDITOR_MODULE_BASE
        dc.l template_end-template_start,template_entry-template_start,0,0
template_entry:
        movem.l d1-d7/a0-a6,-(sp)
        lea -TPL_SNAPSHOT_BYTES(sp),sp
        move.l sp,TPL_OWNER_FRAME
        move.w #REQ_ACTION_UNENTERED,EDITOR_SESSION_BASE+REQ_ACTION
        cmpi.w #MODULE_ABI,d0
        bne template_bad
        cmpa.l #EDITOR_SESSION_BASE,a0
        bne template_bad
        bsr template_owner
        bne template_return
        bsr template_append_admit
        bne template_return
        bsr template_snapshot
        bsr template_select_custom
        bne template_return
        bsr template_source_pin
        bne template_failed
        clr.l TPL_PICK_PHASE
        clr.w TPL_PHASE
        move.w #24,TPL_COUNT
        clr.w TPL_DRIVE
        moveq #0,d0
        moveq #0,d1
        bsr edtr_modal
        tst.w d0
        bmi template_failed
        beq template_cancel
        move.w TPL_MISSION+PCREL(pc),d0
        move.w TPL_PHASE+PCREL(pc),d1
        bsr template_lookup
        bmi template_failed
        move.w d0,TPL_MAP
template_scan_original:
        moveq #3,d7
.scan:
        bsr template_try_stage
        tst.l d0
        beq.s template_candidate
        cmpi.l #-4,d0
        beq template_cancel
        addq.w #1,TPL_DRIVE
        andi.w #3,TPL_DRIVE
        dbf d7,.scan
template_original_retry:
        moveq #1,d0
        moveq #0,d1
        bsr edtr_modal
        tst.w d0
        bmi template_failed
        beq template_cancel
        bra.s template_scan_original

template_candidate:
        ; Compressed input is dead. Preserve SPT/CFMD while Custom directory
        ; inspection owns WORK. READBACK retains the validated candidate MAP.
        lea TPL_STAGE_SPT+PCREL(pc),a0
        lea TPL_PACKED_BASE+PCREL(pc),a1
        move.w #EDITOR_SPT_BYTES/2-1,d0
.spt:
        move.w (a0)+,(a1)+
        dbf d0,.spt
        lea TPL_STAGE_METADATA+PCREL(pc),a0
        move.w #EDITOR_METADATA_BYTES/2-1,d0
.meta:
        move.w (a0)+,(a1)+
        dbf d0,.meta
template_check_custom:
        bsr template_select_custom
        beq.s template_restore_candidate
template_custom_retry:
        moveq #2,d0
        moveq #0,d1
        bsr edtr_modal
        tst.w d0
        bmi template_failed
        beq template_cancel
        bra.s template_check_custom

template_restore_candidate:
        lea TPL_PACKED_BASE+PCREL(pc),a0
        lea TPL_STAGE_SPT+PCREL(pc),a1
        move.w #EDITOR_SPT_BYTES/2-1,d0
.spt:
        move.w (a0)+,(a1)+
        dbf d0,.spt
        lea TPL_STAGE_METADATA+PCREL(pc),a1
        move.w #EDITOR_METADATA_BYTES/2-1,d0
.meta:
        move.w (a0)+,(a1)+
        dbf d0,.meta
        bsr template_owner
        bne template_failed
        moveq #4,d0
        bsr template_snapshot_check
        bne template_failed
        cmpi.w #AUR_CONTINUE_PHASE_TEMPLATE,AUR_BASE+AUR_PAGE_CANDIDATE
        bne.s .metadata_ready
        bsr template_append_metadata
.metadata_ready:
        ; All validation and directory checks precede the canonical write boundary.
template_before_commit:
        move.w TPL_CUSTOM_DRIVE+PCREL(pc),AUR_BASE+AUR_DRIVE
        lea TPL_STAGE_MAP+PCREL(pc),a0
        lea map_file_buffer,a1
        move.w TPL_STAGE_METADATA+CFMD_MAP_BYTES+PCREL(pc),d0
        lsr.w #1,d0
        subq.w #1,d0
.map:
        move.w (a0)+,(a1)+
        dbf d0,.map
        lea TPL_STAGE_SPT+PCREL(pc),a0
        lea EDITOR_SPT_BASE+PCREL(pc),a1
        move.w #EDITOR_SPT_BYTES/2-1,d0
.spt:
        move.w (a0)+,(a1)+
        dbf d0,.spt
        lea TPL_STAGE_METADATA+PCREL(pc),a0
        lea EDITOR_METADATA_BASE+PCREL(pc),a1
        move.w #EDITOR_METADATA_BYTES/4-1,d0
        cmpi.w #AUR_CONTINUE_PHASE_TEMPLATE,AUR_BASE+AUR_PAGE_CANDIDATE
        bne.s .metadata
        moveq #63,d0
.metadata:
        move.l (a0)+,(a1)+
        dbf d0,.metadata
        lea EDITOR_UNDO_BASE+PCREL(pc),a0
        move.w #(EDITOR_UNDO_BYTES+EDITOR_MANIFEST_BYTES)/4-1,d0
        cmpi.w #AUR_CONTINUE_PHASE_TEMPLATE,AUR_BASE+AUR_PAGE_CANDIDATE
        bne.s .history
        move.w #EDITOR_UNDO_BYTES/4-1,d0
.history:
        clr.l (a0)+
        dbf d0,.history
        cmpi.w #AUR_CONTINUE_PHASE_TEMPLATE,AUR_BASE+AUR_PAGE_CANDIDATE
        beq template_append_publish
        lea AUR_BASE+AUR_SOURCE_BYTES+PCREL(pc),a0
        moveq #15,d0
.tail:
        clr.l (a0)+
        dbf d0,.tail
        move.l #-1,AUR_BASE+AUR_PHASE_MAP
        move.w #-1,AUR_BASE+AUR_PHASE_MAP+4
        move.w #-1,AUR_BASE+AUR_OBJECT_INDEX
        move.b #1,AUR_BASE+AUR_PHASE_COUNT
        move.w #AUR_DIRTY|AUR_PAGE_PENDING,AUR_BASE+AUR_FLAGS
        clr.l AUR_BASE+AUR_CAMERA_X
        clr.w AUR_BASE+AUR_TOOL
        move.w #AUR_PAGE_TEMPLATE,AUR_BASE+AUR_PAGE_KIND
        move.w #AUR_PAGE_NONE,AUR_BASE+AUR_PAGE_CANDIDATE
        move.w #EDTR_NEW,AUR_BASE+AUR_ORIGIN
        move.w map_file_buffer+84,d0
        subi.w #19,d0
        lsr.w #1,d0
        move.w d0,AUR_BASE+AUR_CAMERA_X
        move.w map_file_buffer+86,d0
        subi.w #12,d0
        lsr.w #1,d0
        move.w d0,AUR_BASE+AUR_CAMERA_Y
        clr.l STORAGE_READY
template_published:
        moveq #3,d7
        bra.s template_finish
template_cancel:
        moveq #0,d7
        bra.s template_finish
template_failed:
        moveq #EDTR_VISUAL_ERROR,d7
template_finish:
        bsr template_owner
        bne.s template_blocked
        move.w d7,EDITOR_SESSION_BASE+REQ_LAST_RESULT
        move.l #TEMPLATE_MODULE_ID,EDITOR_SESSION_BASE+REQ_RESULT_ID
        lea template_editor_request(pc),a0
        lea EDITOR_SESSION_BASE+REQ_NAME+PCREL(pc),a1
        moveq #5,d1
.request:
        move.l (a0)+,(a1)+
        dbf d1,.request
        move.w #REQ_ACTION_DISPATCH,EDITOR_SESSION_BASE+REQ_ACTION
        moveq #0,d0
template_return:
        clr.l TPL_OWNER_FRAME
        lea TPL_SNAPSHOT_BYTES(sp),sp
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
template_bad:
        moveq #EDTR_STATE_ERROR,d0
        bra.s template_return
template_blocked:
        jsr wait_frame
        bra.s template_blocked

template_try_stage:
        move.w TPL_MISSION+PCREL(pc),d0
        move.w TPL_PHASE+PCREL(pc),d1
        move.w TPL_DRIVE+PCREL(pc),d2
template_before_stage:
        bra template_stage

template_select_custom:
        clr.w TPL_CUSTOM_DRIVE
template_inspect_custom:
        moveq #STORAGE_READ_INVALID,d0
        tst.w TPL_CUSTOM_DRIVE
        bne.s .return
        clr.l STORAGE_CONTEXT+STORAGE_READ_CANCEL
        lea STORAGE_CONTEXT+PCREL(pc),a0
        bsr storage_inspect_disk
        tst.w d0
        bne.s .return
        lea STORAGE_CONTEXT+STORAGE_INSPECT_DISK_ID+PCREL(pc),a0
        lea AUR_BASE+AUR_DISK_ID+PCREL(pc),a1
        moveq #3,d1
        moveq #4,d0
.id:
        cmpm.l (a0)+,(a1)+
        bne.s .return
        dbf d1,.id
        tst.w TPL_SOURCE_QUALIFIED
        beq.s .qualified
        move.l TPL_SOURCE_DIRECTORY+PCREL(pc),d1
        cmp.l STORAGE_CONTEXT+STORAGE_INSPECT_DIRECTORY_CRC+PCREL(pc),d1
        bne.s .return
.qualified:
        moveq #0,d0
.return:
        tst.w d0
        rts

template_owner:
        bsr aur_validate
        bne.s .return
        moveq #AUR_ERROR_REQUEST,d0
        btst #3,AUR_BASE+AUR_FLAGS+1+PCREL(pc)
        beq.s .return
        cmpi.w #AUR_PAGE_TEMPLATE,AUR_BASE+AUR_PAGE_KIND
        bne.s .return
        ; Shared page bounds admit NONE or the exact append continuation.
        tst.w AUR_BASE+AUR_TRANSPORT_STATUS
        bne.s .return
        tst.l EDITOR_SESSION_BASE+REQ_RESULT_ID
        bne.s .return
        tst.w EDITOR_SESSION_BASE+REQ_LAST_RESULT
        bne.s .return
        moveq #0,d0
.return:
        tst.w d0
        rts
template_editor_request:
        dc.b "cf_editor.mod",0,0,0
        dc.l EDTR_MODULE_ID,EDITOR_SERIALIZER_BYTES
        include "append.s"
        include "dialog.s"
        include "../dialog/dialog.s"
        include "../dialog/text.s"
        include "../dialog/template_list.s"
        include "stage.s"
        include "metadata.s"
        include "read.s"
        include "rnc.s"
        include "../editor/page_bounds.s"
        include "../editor/aur.s"
        include "../controller/text.s"
        include "../storage/read.s"
        include "../storage/payload.s"
template_end:
        ifgt template_end-template_start-(EDITOR_SERIALIZER_BYTES-TPL_PACKED_BYTES)
        fail "Template code overlaps reserved packed data"
        endif
        ifgt EXIT_UI+EXIT_UI_BYTES-TPL_STAGE_SPT
        fail "Dialog scratch overlaps the staged template"
        endif
