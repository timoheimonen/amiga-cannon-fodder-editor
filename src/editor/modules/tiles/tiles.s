; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; TILE overlay: bounded tile palette and by-value selection receipt.
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
        include "page.i"
        include "ui.i"
PAYLOAD_STRUCTURAL_ONLY equ 1
        section .text,code
        xdef tiles_start,tiles_entry,tiles_end
        xdef tile_before_view,tile_after_view,tile_idle,tile_before_release
        xdef tile_after_release,tile_publish,tile_owner,tile_input,tile_render
        xdef tile_bar_refresh,tile_grid_cell

; Fixed load-base anchor: X+PCREL(pc) reads the absolute address X
; PC-relatively from module code.
module_pc_base:
PCREL   equ module_pc_base-EDITOR_MODULE_BASE
tiles_start:
        dc.l MODULE_MAGIC
        dc.w MODULE_ABI,MODULE_HEADER_BYTES
        dc.l TILE_MODULE_ID,EDITOR_MODULE_BASE
        dc.l tiles_end-tiles_start,tiles_entry-tiles_start,0,0

tiles_entry:
        movem.l d1-d7/a0-a6,-(sp)
        ; An entered but unqualified source cannot fall through to campaign.
        move.w #REQ_ACTION_UNENTERED,EDITOR_SESSION_BASE+REQ_ACTION
        cmpi.w #MODULE_ABI,d0
        bne tile_bad_entry
        cmpa.l #EDITOR_SESSION_BASE,a0
        bne tile_bad_entry
        bsr tile_owner
        bne tile_return
        clr.l STORAGE_CONTEXT+STORAGE_READ_CANCEL
        bsr tile_epoch
        bne tile_return
        ; The transport has just checked the Custom marker while loading this
        ; page; it reads no storage, so it does not list Custom again.
        bsr tile_owner
        bne tile_return
        ; Reader WORK0..863 and IO64..143 are dead before display ownership.
        lea page_top,a0
        moveq #(page_state_end-page_top)/2-1,d0
.state:
        clr.w (a0)+
        dbra d0,.state
        move.w AUR_BASE+AUR_TILE,page_hover
        moveq #0,d0
        move.w page_hover,d0
        divu #PAGE_COLS,d0
        cmpi.w #PAGE_LAST_TOP,d0
        bls.s .top
        moveq #PAGE_LAST_TOP,d0
.top:
        move.w d0,page_top
        move.w #AUR_PAGE_NONE,page_choice
        bsr tile_bar_prepare
        bne tile_preflight_error
tile_before_view:
        bsr enter_view
tile_after_view:
        move.w #1,edtr_view_live
        bsr tile_render
        tst.w page_error
        bne tile_render_error
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
        move.w native_raw_key,d0
        cmpi.w #$4C,d0
        beq.s .drain
        cmpi.w #$4D,d0
        beq.s .drain
        clr.w native_last_key
        clr.w native_left_pressed
        clr.w native_right_pressed
tile_idle:
        jsr wait_frame
        jsr editor_pointer_update
        bsr tile_input
        tst.w page_error
        bne.s tile_render_error
        cmpi.w #1,d0
        beq.s tile_selected
        cmpi.w #2,d0
        beq.s tile_cancelled
        bra.s tile_idle
tile_selected:
        moveq #0,d7
        bra.s tile_leave
tile_cancelled:
        moveq #PAGE_CANCEL,d7
        bra.s tile_leave
tile_render_error:
        moveq #PAGE_RENDER_ERROR,d7
        move.w #AUR_PAGE_NONE,page_choice
tile_leave:
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
tile_before_release:
        bsr exit_view
        clr.w edtr_view_live
tile_after_release:
        bsr.s tile_owner
        bne.s tile_return
        ; No fallible operation follows this publication. Error -41 is an
        ; explicit entered error, which EDTR refuses with the draft intact.
tile_publish:
        move.w page_choice,AUR_BASE+AUR_PAGE_CANDIDATE
        move.w d7,EDITOR_SESSION_BASE+REQ_LAST_RESULT
        move.l #TILE_MODULE_ID,EDITOR_SESSION_BASE+REQ_RESULT_ID
        lea tile_editor_request(pc),a0
        lea EDITOR_SESSION_BASE+REQ_NAME,a1
        moveq #5,d1
.request:
        move.l (a0)+,(a1)+
        dbra d1,.request
        move.w #REQ_ACTION_DISPATCH,EDITOR_SESSION_BASE+REQ_ACTION
        move.w d7,d0
tile_return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
tile_preflight_error:
        moveq #PAGE_RENDER_ERROR,d0
        bra.s tile_return
tile_bad_entry:
        moveq #EDTR_STATE_ERROR,d0
        bra.s tile_return

tile_owner:
        bsr aur_validate
        bne.s .return
        moveq #AUR_ERROR_REQUEST,d0
        btst #3,AUR_BASE+AUR_FLAGS+1
        beq.s .return
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

tile_epoch:
        moveq #STORAGE_READ_CANCELLED,d0
        tst.l STORAGE_CONTEXT+STORAGE_READ_CANCEL
        bne.s .return
        moveq #4,d0
        moveq #0,d0
.return:
        tst.w d0
        rts

tile_editor_request:
        dc.b "cf_editor.mod",0,0,0
        dc.l EDTR_MODULE_ID,EDITOR_SERIALIZER_BYTES

        include "page.s"
        include "../editor/ink.s"
        include "../editor/page_view.s"
        include "../editor/page_bounds.s"
        include "../editor/aur.s"
        include "../controller/text.s"
        include "../storage/read.s"
        include "../storage/payload.s"
tiles_end:
        ifgt tiles_end-tiles_start-EDITOR_SERIALIZER_BYTES
        fail "TILE exceeds installable16KiB cap"
        endif
