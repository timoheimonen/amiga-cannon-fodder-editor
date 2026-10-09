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

RZ_WIDTH        equ EDITOR_UI_BASE+224
RZ_HEIGHT       equ EDITOR_UI_BASE+226
RZ_MODE         equ EDITOR_UI_BASE+228
RZ_ERROR        equ EDITOR_UI_BASE+230
RZ_INDEX        equ EDITOR_UI_BASE+232
RZ_MASK_LOW     equ EDITOR_UI_BASE+236
RZ_MASK_HIGH    equ EDITOR_UI_BASE+240
RZ_COUNT        equ EDITOR_UI_BASE+244
RZ_CANCEL       equ EDITOR_UI_BASE+246
RZ_SPT          equ EDITOR_SERIAL_WORK_BASE+256
RZ_MAP_BYTES    equ EDITOR_SERIAL_WORK_BASE+704
RZ_MAP_CRC      equ EDITOR_SERIAL_WORK_BASE+708
RZ_SPT_CRC      equ EDITOR_SERIAL_WORK_BASE+712

PAYLOAD_STRUCTURAL_ONLY equ 1
        section .text,code
        xdef resize_start,resize_entry,resize_end,resize_owner
        xdef resize_before_dialog,resize_after_dialog,resize_before_commit
        xdef resize_after_commit,resize_publish,resize_blocked
; Fixed load-base anchor: X+PCREL(pc) reads the absolute address X
; PC-relatively from module code.
module_pc_base:
PCREL   equ module_pc_base-EDITOR_MODULE_BASE
resize_start:
        dc.l MODULE_MAGIC
        dc.w MODULE_ABI,MODULE_HEADER_BYTES
        dc.l RESIZE_MODULE_ID,EDITOR_MODULE_BASE
        dc.l resize_end-resize_start,resize_entry-resize_start,0,0
resize_entry:
        movem.l d1-d7/a0-a6,-(sp)
        move.w #REQ_ACTION_UNENTERED,EDITOR_SESSION_BASE+REQ_ACTION
        cmpi.w #MODULE_ABI,d0
        bne resize_bad_entry
        cmpa.l #EDITOR_SESSION_BASE,a0
        bne resize_bad_entry
        bsr resize_owner
        bne resize_return
        clr.l STORAGE_CONTEXT+STORAGE_READ_CANCEL
        bsr resize_epoch
        bne resize_return
        lea STORAGE_CONTEXT,a0
        bsr storage_inspect_disk
        tst.w d0
        bne resize_return
        bsr resize_epoch
        bne resize_return
        bsr resize_owner
        bne resize_return
        move.w editor_map_width,RZ_WIDTH
        move.w editor_map_height,RZ_HEIGHT
        ; Imported grids may be below the interactive authoring floor.
        cmpi.w #19,RZ_WIDTH
        bhs.s .max_width
        move.w #19,RZ_WIDTH
.max_width:
        cmpi.w #500,RZ_WIDTH
        bls.s .min_height
        move.w #500,RZ_WIDTH
.min_height:
        cmpi.w #15,RZ_HEIGHT
        bhs.s .max_height
        move.w #15,RZ_HEIGHT
.max_height:
        move.l #7500,d0
        divu RZ_WIDTH,d0
        cmp.w RZ_HEIGHT,d0
        bhs.s .dimensions
        move.w d0,RZ_HEIGHT
.dimensions:
        clr.w RZ_MODE
        clr.w RZ_ERROR
        clr.w RZ_INDEX
        clr.w RZ_COUNT
        clr.w RZ_CANCEL
        clr.w edtr_view_live
resize_before_dialog:
        moveq #0,d0
        bsr edtr_modal
resize_after_dialog:
        clr.w edtr_view_live
        tst.w d0
        bmi resize_failed
        beq resize_cancelled
        cmpi.w #2,d0
        beq resize_no_change
        ; Revalidate the unchanged authored owners after graphics restoration.
        ; No stage bytes survive as authority across the modal.
        bsr resize_owner
        bne resize_failed
        bsr resize_epoch
        bne resize_failed
        bsr resize_stage_placements
        tst.l d0
        bmi resize_failed
        move.w RZ_COUNT,d0
        cmp.w RZ_SPT+2,d0
        bne resize_failed
        move.l RZ_MASK_LOW,d0
        cmp.l RZ_SPT+4,d0
        bne resize_failed
        move.l RZ_MASK_HIGH,d0
        cmp.l RZ_SPT+8,d0
        bne resize_failed
        lea map_file_buffer,a0
        moveq #0,d0
        move.w EDITOR_METADATA_BASE+CFMD_MAP_BYTES,d0
        lea EDITOR_READBACK_BASE,a1
        move.l #EDITOR_READBACK_BYTES,d1
        move.w RZ_WIDTH,d2
        move.w RZ_HEIGHT,d3
        move.w AUR_BASE+AUR_TILE,d4
        bsr resize_map_stage
        tst.l d0
        bmi resize_failed
        move.w d0,RZ_MAP_BYTES
        move.l d0,d1
        lea EDITOR_READBACK_BASE,a0
        bsr read_crc32
        move.l d0,RZ_MAP_CRC
        moveq #0,d1
        move.w RZ_SPT,d1
        lea RZ_SPT+12,a0
        bsr read_crc32
        move.l d0,RZ_SPT_CRC
        bsr resize_poll_escape
        bne resize_cancelled
        bsr resize_epoch
        bne resize_failed
        ; Mode 2 IRQs do not consume these authored owners. Publish at IPL0:
        ; no callbacks, I/O, input checks or fallible helpers until complete.
resize_before_commit:
        lea EDITOR_READBACK_BASE,a0
        lea map_file_buffer,a1
        move.w RZ_MAP_BYTES,d0
        lsr.w #1,d0
        subq.w #1,d0
.map:
        move.w (a0)+,(a1)+
        dbf d0,.map
        lea EDITOR_SPT_BASE,a1
        move.w #EDITOR_SPT_BYTES/2-1,d0
.clear_spt:
        clr.w (a1)+
        dbf d0,.clear_spt
        lea RZ_SPT+12,a0
        lea EDITOR_SPT_BASE,a1
        move.w RZ_SPT,d0
        lsr.w #1,d0
        subq.w #1,d0
.spt:
        move.w (a0)+,(a1)+
        dbf d0,.spt
        move.w RZ_MAP_BYTES,EDITOR_METADATA_BASE+CFMD_MAP_BYTES
        move.w RZ_SPT,EDITOR_METADATA_BASE+CFMD_SPT_BYTES
        move.l RZ_MAP_CRC,EDITOR_METADATA_BASE+CFMD_MAP_CRC
        move.l RZ_SPT_CRC,EDITOR_METADATA_BASE+CFMD_SPT_CRC
        lea EDITOR_UNDO_BASE,a0
        move.w #EDITOR_UNDO_BYTES/4-1,d0
.undo:
        clr.l (a0)+
        dbf d0,.undo
        clr.l AUR_BASE+AUR_UNDO_NEXT
        move.w #-1,AUR_BASE+AUR_OBJECT_INDEX
        move.w RZ_WIDTH,d0
        subi.w #19,d0
        cmp.w AUR_BASE+AUR_CAMERA_X,d0
        bhs.s .height
        move.w d0,AUR_BASE+AUR_CAMERA_X
.height:
        move.w RZ_HEIGHT,d0
        subi.w #12,d0
        cmp.w AUR_BASE+AUR_CAMERA_Y,d0
        bhs.s .dirty
        move.w d0,AUR_BASE+AUR_CAMERA_Y
.dirty:
        bsr aur_mark_edited
resize_after_commit:
        moveq #1,d7
        bra.s resize_finish
resize_failed:
        moveq #EDTR_VISUAL_ERROR,d7
        bra.s resize_finish
resize_cancelled:
        moveq #14,d7
        bra.s resize_finish
resize_no_change:
        moveq #0,d7
resize_finish:
        bsr.s resize_owner
        bne.s resize_blocked
resize_publish:
        move.w d7,EDITOR_SESSION_BASE+REQ_LAST_RESULT
        move.l #RESIZE_MODULE_ID,EDITOR_SESSION_BASE+REQ_RESULT_ID
        lea resize_editor_request(pc),a0
        lea EDITOR_SESSION_BASE+REQ_NAME,a1
        moveq #5,d1
.request:
        move.l (a0)+,(a1)+
        dbf d1,.request
        move.w #REQ_ACTION_DISPATCH,EDITOR_SESSION_BASE+REQ_ACTION
        move.l d7,d0
resize_return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
resize_bad_entry:
        moveq #EDTR_STATE_ERROR,d0
        bra.s resize_return
resize_blocked:
        jsr wait_frame
        bra.s resize_blocked
resize_owner:
        bsr aur_validate
        bne.s .return
        moveq #AUR_ERROR_REQUEST,d0
        btst #3,AUR_BASE+AUR_FLAGS+1
        beq.s .return
        cmpi.w #AUR_PAGE_RESIZE,AUR_BASE+AUR_PAGE_KIND
        bne.s .return
        cmpi.w #AUR_PAGE_NONE,AUR_BASE+AUR_PAGE_CANDIDATE
        bne.s .return
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
open_owner:
        bra.s resize_owner
resize_epoch:
        moveq #4,d0
        moveq #0,d0
.return:
        tst.w d0
        rts
resize_stage_placements:
        lea EDITOR_SPT_BASE,a0
        moveq #0,d0
        move.w EDITOR_METADATA_BASE+CFMD_SPT_BYTES,d0
        lea RZ_SPT,a1
        move.l #442,d1
        move.w RZ_WIDTH,d2
        move.w RZ_HEIGHT,d3
        bsr resize_spt_stage
        rts
resize_poll_escape:
        cmpi.w #$C5,native_last_key
        beq.s .cancel
        cmpi.b #$45,native_raw_key+1
        bne.s .return
.cancel:
        move.w #1,RZ_CANCEL
        clr.w EXIT_CHOICE
.return:
        tst.w RZ_CANCEL
        rts
resize_editor_request:
        dc.b "cf_editor.mod",0,0,0
        dc.l EDTR_MODULE_ID,EDITOR_SERIALIZER_BYTES

        include "map.s"
        include "spt.s"
        include "dialog.s"
        include "../object_palette/catalog.i"
; WORK256..715 holds the staged placements while the dialog is open.
EXIT_UI         equ EDITOR_UI_BASE
        include "../dialog/page.s"
        include "../dialog/dialog.s"
        include "../dialog/text.s"
        include "../editor/page_bounds.s"
        include "../editor/aur.s"
        include "../editor/tested.s"
        include "../controller/text.s"
        include "../storage/read.s"
        include "../storage/payload.s"
resize_end:
        ifgt resize_end-resize_start-EDITOR_SERIALIZER_BYTES
        fail "Resize exceeds the installable code bank"
        endif
        ifgt RZ_SPT_CRC+4-EDITOR_SERIAL_WORK_BASE-EDITOR_SERIAL_WORK_BYTES
        fail "Resize staging exceeds serializer scratch"
        endif
        ifgt EXIT_UI+EXIT_UI_BYTES-RZ_WIDTH
        fail "Resize dialog scratch overlaps its state"
        endif
