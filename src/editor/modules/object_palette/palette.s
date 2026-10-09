; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Object palette with a bounded catalog and by-value selection receipt.
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
        include "private.i"
        include "ui.i"
STORAGE_INSPECT_ONLY equ 1
AUR_VALIDATE_ONLY equ 1
OBJECT_ANCHOR_ENABLED equ 1
PAYLOAD_STRUCTURAL_ONLY equ 1
        section .text,code
        xdef opal_start,opal_entry,opal_end
        xdef pal_before_view,pal_after_view,pal_idle,pal_before_release
        xdef pal_after_release,pal_publish,pal_owner,pal_input,pal_render
        xdef pal_preview,pal_catalog

; Fixed load-base anchor: X+PCREL(pc) reads the absolute address X
; PC-relatively from module code.
module_pc_base:
PCREL   equ module_pc_base-EDITOR_MODULE_BASE
opal_start:
        dc.l MODULE_MAGIC
        dc.w MODULE_ABI,MODULE_HEADER_BYTES
        dc.l OPAL_MODULE_ID,EDITOR_MODULE_BASE
        dc.l opal_end-opal_start,opal_entry-opal_start,0,0

opal_entry:
        movem.l d1-d7/a0-a6,-(sp)
        ; An entered but unqualified source cannot fall through to campaign.
        move.w #REQ_ACTION_UNENTERED,EDITOR_SESSION_BASE+REQ_ACTION
        cmpi.w #MODULE_ABI,d0
        bne pal_bad_entry
        cmpa.l #EDITOR_SESSION_BASE,a0
        bne pal_bad_entry
        bsr pal_owner
        bne pal_return
        clr.l STORAGE_CONTEXT+STORAGE_READ_CANCEL
        bsr pal_epoch
        bne pal_return
        ; The transport has just checked the Custom marker while loading this
        ; page; it reads no storage, so it does not list Custom again.
        bsr pal_owner
        bne pal_return
        ; Reader WORK0..863 and IO64..143 are dead before display ownership.
        lea pal_category,a0
        moveq #(pal_state_end-pal_category)/2-1,d0
.state:
        clr.w (a0)+
        dbra d0,.state
        move.w #AUR_PAGE_NONE,page_choice
        move.w AUR_BASE+AUR_OBJECT_TYPE,d0
        bsr pal_initial
        bsr edtr_prepare_font
        tst.w d0
        bne pal_return
        bsr object_anchor_prepare
        bsr pal_prepare
pal_before_view:
        lea preview_state,a0
        move.w #PV_STATE_SIZE/2-1,d0
.preview_clear:
        clr.w (a0)+
        dbra d0,.preview_clear
        move.l #PREVIEW_MASK,preview_state+pv_mask_row
        ; Generated opacity masks handle the owned H glyph and native sprites.
        clr.w preview_state+pv_native_masks
        bsr enter_view
pal_after_view:
        move.w #1,edtr_view_live
        bsr pal_render
        tst.w page_error
        bne.s pal_render_error
.drain:
        clr.w native_last_key
        clr.w native_left_pressed
        clr.w native_right_pressed
        jsr wait_frame
        jsr editor_pointer_update
        tst.w native_left_down
        bne.s .drain
        tst.w native_right_down
        bne.s .drain
        ; The page acts on every arrow key while it is held.
        move.w native_raw_key,d0
        subi.w #$4C,d0
        cmpi.w #3,d0
        bls.s .drain
        clr.w native_last_key
        clr.w native_left_pressed
        clr.w native_right_pressed
pal_idle:
        jsr wait_frame
        jsr editor_pointer_update
        bsr pal_input
        tst.w page_error
        bne.s pal_render_error
        cmpi.w #1,d0
        beq.s pal_selected
        cmpi.w #2,d0
        beq.s pal_cancelled
        bra.s pal_idle
pal_selected:
        moveq #0,d7
        bra.s pal_leave
pal_cancelled:
        moveq #PAGE_CANCEL,d7
        bra.s pal_leave
pal_render_error:
        moveq #PAGE_RENDER_ERROR,d7
        move.w #AUR_PAGE_NONE,page_choice
pal_leave:
        ; Close the input edge before restoring the outside graphics owner.
        ; The native pointer's pending-click path may clobber D7.
        move.l d7,-(sp)
.release:
        clr.w native_last_key
        clr.w native_left_pressed
        clr.w native_right_pressed
        jsr wait_frame
        jsr editor_pointer_update
        tst.w native_left_down
        bne.s .release
        tst.w native_right_down
        bne.s .release
        clr.w native_last_key
        move.l (sp)+,d7
pal_before_release:
        lea preview_state,a4
        bsr preview_restore
        bsr exit_view
        clr.w edtr_view_live
pal_after_release:
        bsr.s pal_owner
        bne.s pal_return
        ; No fallible operation follows this publication. Error -41 is an
        ; explicit entered error, which EDTR refuses with the draft intact.
pal_publish:
        move.w page_choice,AUR_BASE+AUR_PAGE_CANDIDATE
        move.w d7,EDITOR_SESSION_BASE+REQ_LAST_RESULT
        move.l #OPAL_MODULE_ID,EDITOR_SESSION_BASE+REQ_RESULT_ID
        lea pal_editor_request(pc),a0
        lea EDITOR_SESSION_BASE+REQ_NAME,a1
        moveq #5,d1
.request:
        move.l (a0)+,(a1)+
        dbra d1,.request
        move.w #REQ_ACTION_DISPATCH,EDITOR_SESSION_BASE+REQ_ACTION
        move.w d7,d0
pal_return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
pal_bad_entry:
        moveq #EDTR_STATE_ERROR,d0
        bra.s pal_return

pal_owner:
        bsr aur_validate
        bne.s .return
        moveq #AUR_ERROR_REQUEST,d0
        btst #3,AUR_BASE+AUR_FLAGS+1
        beq.s .return
        cmpi.w #OPAL_PAGE_KIND,AUR_BASE+AUR_PAGE_KIND
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

pal_epoch:
        moveq #STORAGE_READ_CANCELLED,d0
        tst.l STORAGE_CONTEXT+STORAGE_READ_CANCEL
        bne.s .return
        moveq #4,d0
        moveq #0,d0
.return:
        tst.w d0
        rts

pal_editor_request:
        dc.b "cf_editor.mod",0,0,0
        dc.l EDTR_MODULE_ID,EDITOR_SERIALIZER_BYTES

        include "page.s"
        include "../editor/page_view.s"
        include "font.s"
        include "../editor/font_strip.s"
        include "../editor/ink.s"
        include "../editor/palette.s"
        include "bounds.s"
        include "../editor/aur.s"
        include "../editor/viewport/preview.s"
        include "../editor/object_parts.s"
        include "../editor/object_anchor.s"
        include "catalog.i"
        include "../storage/read.s"
        include "../storage/payload.s"
opal_end:
        ifgt opal_end-opal_start-EDITOR_SERIALIZER_BYTES
        fail "OPAL exceeds installable16KiB cap"
        endif
