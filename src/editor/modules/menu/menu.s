; Cannon Fodder In-Game Level Editor V1.0
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
AUR_INCOMPLETE_RECOVERY equ 1
AUR_PHASE_CONTINUATIONS equ 1
MENU_DIALOG_TITLE equ 4
MENU_DIALOG_NEW equ 5
MENU_DIALOG_ASSETS equ 6
MENU_DIALOG_PHASE equ 7
MENU_DIALOG_PHASE_TITLE equ 8
MENU_TITLE equ EDITOR_SERIAL_WORK_BASE+512

PAYLOAD_STRUCTURAL_ONLY equ 1
        section .text,code
        xdef menu_start,menu_entry,menu_end,menu_owner,menu_publish
        xdef menu_before_title_commit,menu_after_title_commit
; Fixed load-base anchor: X+PCREL(pc) reads the absolute address X
; PC-relatively from module code.
module_pc_base:
PCREL   equ module_pc_base-EDITOR_MODULE_BASE
menu_start:
        dc.l MODULE_MAGIC
        dc.w MODULE_ABI,MODULE_HEADER_BYTES
        dc.l MENU_MODULE_ID,EDITOR_MODULE_BASE
        dc.l menu_end-menu_start,menu_entry-menu_start,0,0
menu_entry:
        movem.l d1-d7/a0-a6,-(sp)
        move.w #REQ_ACTION_UNENTERED,EDITOR_SESSION_BASE+REQ_ACTION
        cmpi.w #MODULE_ABI,d0
        bne menu_bad
        cmpa.l #EDITOR_SESSION_BASE,a0
        bne menu_bad
        bsr menu_owner
        bne menu_return
        clr.l STORAGE_CONTEXT+STORAGE_READ_CANCEL
        bsr menu_epoch
        bne menu_return
        lea STORAGE_CONTEXT,a0
        bsr storage_inspect_disk
        tst.w d0
        bne menu_return
        bsr menu_epoch
        bne menu_return
        cmpi.w #AUR_PAGE_MESSAGE,AUR_BASE+AUR_PAGE_KIND
        bhs.s menu_dialog
        move.w AUR_BASE+AUR_PAGE_CANDIDATE,d6
        cmpi.w #AUR_PAGE_NONE,d6
        beq.s menu_again
        move.w #AUR_PAGE_NONE,AUR_BASE+AUR_PAGE_CANDIDATE
        cmpi.w #MENU_PHASE_SETTINGS,d6
        beq menu_phase
        cmpi.w #AUR_CONTINUE_PHASE_SELECT,d6
        bhs menu_replace
        ; New may also arrive from live Open with a retained dirty draft.
        ; Its ordinary guard still authorizes every replacement.
        cmpi.w #AUR_CONTINUE_NEW,d6
        beq menu_new
        cmpi.w #AUR_HAS_SOURCE|AUR_PAGE_PENDING,AUR_BASE+AUR_FLAGS
        bne menu_fail
        cmpi.w #AUR_CONTINUE_OPEN,d6
        beq menu_open_dispatch
        cmpi.w #AUR_CONTINUE_TEMPLATE,d6
        beq menu_template_dispatch
        bra menu_new_picker
menu_dialog:
        clr.w edtr_view_live
        moveq #EDTR_DIALOG_MESSAGE,d0
        move.w AUR_BASE+AUR_PAGE_CANDIDATE,d1
        cmpi.w #AUR_PAGE_MESSAGE,AUR_BASE+AUR_PAGE_KIND
        beq.s .show
        moveq #EDTR_DIALOG_LARGE,d0
        moveq #0,d1
.show:
        bsr edtr_modal
        move.w d0,d7
        bra menu_finish
menu_again:
        clr.w edtr_view_live
        moveq #EDTR_DIALOG_MENU,d0
        tst.w AUR_BASE+AUR_ASSET_STATE
        beq.s .ready
        moveq #MENU_DIALOG_ASSETS,d0
.ready:
        moveq #0,d1
        bsr edtr_modal
        tst.w d0
        bmi menu_fail
        beq menu_cancel
        cmpi.w #EDTR_CHOICE_SAVE,d0
        beq menu_save
        cmpi.w #EDTR_CHOICE_DISCARD,d0
        beq.s menu_exit
        cmpi.w #3,d0
        beq menu_resize
        cmpi.w #7,d0
        beq menu_save_as
        cmpi.w #4,d0
        beq menu_new
        cmpi.w #5,d0
        beq menu_template
        cmpi.w #6,d0
        beq menu_open
        cmpi.w #8,d0
        beq menu_phase_list
        ; Unavailable actions leave every authored owner unchanged.
        moveq #EDTR_ASSET_UNPROVED,d1
menu_message:
        clr.w edtr_view_live
        moveq #EDTR_DIALOG_MESSAGE,d0
        bsr edtr_modal
        tst.w d0
        bmi menu_fail
        bra.s menu_again
menu_exit:
        move.w AUR_BASE+AUR_FLAGS,d0
        andi.w #AUR_HAS_SOURCE|AUR_DIRTY,d0
        cmpi.w #AUR_HAS_SOURCE,d0
        beq.s menu_close
        clr.w edtr_view_live
        moveq #EDTR_DIALOG_UNSAVED,d0
        moveq #0,d1
        bsr edtr_modal
        tst.w d0
        bmi menu_fail
        beq menu_again
        cmpi.w #EDTR_CHOICE_DISCARD,d0
        beq.s menu_close
        ; The Save service alone can qualify this continuation.
        bsr menu_release_request
        move.w #1,AUR_BASE+AUR_EXIT_REQUEST
        moveq #0,d0
        bra.s menu_prepare_save
menu_close:
        moveq #2,d7
        bra menu_finish
menu_save:
        bsr menu_release_request
        moveq #0,d0
menu_prepare_save:
        bsr aur_prepare_save
        tst.w d0
        bne.s menu_save_error
        lea menu_save_request(pc),a0
        bra menu_dispatch
menu_save_error:
        clr.w AUR_BASE+AUR_EXIT_REQUEST
        move.w #AUR_PAGE_MENU,AUR_BASE+AUR_PAGE_KIND
        move.w #AUR_PAGE_NONE,AUR_BASE+AUR_PAGE_CANDIDATE
        ori.w #AUR_PAGE_PENDING,AUR_BASE+AUR_FLAGS
        move.w d0,d1
        bra menu_message
menu_save_as:
        ; The picker edits private NUL text. Canonical FF text changes only
        ; after acceptance and complete display restoration.
        lea EDITOR_METADATA_BASE+CFMD_TITLE,a0
        lea MENU_TITLE,a1
        moveq #63,d0
.title:
        move.b (a0)+,d1
        cmpi.b #$FF,d1
        beq.s .terminate
        move.b d1,(a1)+
        dbf d0,.title
        bra menu_fail
.terminate:
        clr.b (a1)
        lea MENU_TITLE,a0
        moveq #63,d0
        move.w #TITLE_HILL_WIDTH,d1
        move.w #320,d2
        bsr text_picker_begin
        tst.w d0
        beq.s .picker_ready
        ; An imported title may use glyphs outside this picker projection.
        ; Offer an empty private proposal without altering that source.
        clr.b MENU_TITLE
        lea MENU_TITLE,a0
        moveq #63,d0
        move.w #TITLE_HILL_WIDTH,d1
        move.w #320,d2
        bsr text_picker_begin
        tst.w d0
        bne menu_title_error
.picker_ready:
        clr.w edtr_view_live
        moveq #MENU_DIALOG_TITLE,d0
        moveq #0,d1
        bsr edtr_modal
        tst.w d0
        bmi menu_fail
        cmpi.w #1,d0
        bne menu_again
        bsr menu_owner
        bne menu_fail
        bsr menu_epoch
        bne.s menu_fail
menu_before_title_commit:
        lea MENU_TITLE,a0
        lea EDITOR_METADATA_BASE+CFMD_TITLE,a1
.compare_title:
        move.b (a0)+,d0
        beq.s .compare_end
        cmp.b (a1)+,d0
        beq.s .compare_title
        bra.s .title_changed
.compare_end:
        cmpi.b #$FF,(a1)
        beq.s .title_compared
.title_changed:
        clr.b E7_TESTED
.title_compared:
        lea EDITOR_METADATA_BASE+CFMD_TITLE,a1
        moveq #15,d0
.clear:
        clr.l (a1)+
        dbf d0,.clear
        lea MENU_TITLE,a0
        lea EDITOR_METADATA_BASE+CFMD_TITLE,a1
.copy:
        move.b (a0)+,d0
        beq.s .end
        move.b d0,(a1)+
        bra.s .copy
.end:
        move.b #$FF,(a1)
        ori.w #AUR_DIRTY,AUR_BASE+AUR_FLAGS
menu_after_title_commit:
        bsr.s menu_release_request
        moveq #1,d0
        bra menu_prepare_save
menu_title_error:
        moveq #EDTR_VISUAL_ERROR,d1
        bra menu_message
menu_resize:
        move.w #AUR_PAGE_RESIZE,AUR_BASE+AUR_PAGE_KIND
        lea menu_resize_request(pc),a0
        bra.s menu_dispatch
menu_cancel:
        moveq #0,d7
        tst.w AUR_BASE+AUR_ASSET_STATE
        beq.s menu_finish
        moveq #4,d7
        bra.s menu_finish
menu_fail:
        moveq #EDTR_VISUAL_ERROR,d7
menu_finish:
        bsr.s menu_owner
        bne.s menu_blocked
menu_publish:
        move.w d7,EDITOR_SESSION_BASE+REQ_LAST_RESULT
        move.l #MENU_MODULE_ID,EDITOR_SESSION_BASE+REQ_RESULT_ID
        lea menu_editor_request(pc),a0
menu_dispatch:
        lea EDITOR_SESSION_BASE+REQ_NAME,a1
        moveq #5,d1
.request:
        move.l (a0)+,(a1)+
        dbf d1,.request
        move.w #REQ_ACTION_DISPATCH,EDITOR_SESSION_BASE+REQ_ACTION
        moveq #0,d0
menu_return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
menu_bad:
        moveq #EDTR_STATE_ERROR,d0
        bra.s menu_return
menu_blocked:
        jsr wait_frame
        bra.s menu_blocked
menu_release_request:
        clr.l AUR_BASE+AUR_PAGE_KIND
        andi.w #$FFFF-AUR_PAGE_PENDING,AUR_BASE+AUR_FLAGS
        rts
menu_owner:
        bsr aur_validate
        bne.s .return
        moveq #AUR_ERROR_REQUEST,d0
        btst #3,AUR_BASE+AUR_FLAGS+1
        beq.s .return
        cmpi.w #AUR_PAGE_MENU,AUR_BASE+AUR_PAGE_KIND
        beq.s .kind_ok
        cmpi.w #AUR_PAGE_MESSAGE,AUR_BASE+AUR_PAGE_KIND
        blo.s .return
.kind_ok:
        ; aur_validate has already bounded the menu candidate.

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
menu_epoch:
        moveq #4,d0
        moveq #0,d0
.return:
        tst.w d0
        rts
menu_open:
        moveq #AUR_CONTINUE_OPEN,d6
        bra.s menu_replace
menu_template:
        moveq #AUR_CONTINUE_TEMPLATE,d6
menu_replace:
        move.w AUR_BASE+AUR_FLAGS,d0
        andi.w #AUR_HAS_SOURCE|AUR_DIRTY,d0
        cmpi.w #AUR_HAS_SOURCE,d0
        beq.s menu_replace_dispatch
        clr.w edtr_view_live
        moveq #0,d1
        cmpi.w #AUR_CONTINUE_PHASE_BLANK,d6
        blo.s .guard
        moveq #0,d0
        move.b AUR_BASE+AUR_SELECTED,d0
        lea AUR_BASE+AUR_PHASE_MAP,a0
        cmpi.b #$FF,0(a0,d0.w)
        bne.s .guard
        ; An FF phase has no source backing to retain after another append.
        moveq #1,d1
.guard:
        moveq #EDTR_DIALOG_UNSAVED,d0
        bsr edtr_modal
        tst.w d0
        bmi menu_fail
        beq.s menu_replace_cancel
        cmpi.w #EDTR_CHOICE_DISCARD,d0
        beq.s menu_replace_dispatch
        bsr menu_release_request
        move.w d6,AUR_BASE+AUR_EXIT_REQUEST
        moveq #0,d0
        bra menu_prepare_save
menu_replace_cancel:
        cmpi.w #AUR_CONTINUE_PHASE_SELECT,d6
        blo menu_again
menu_phase_list:
        moveq #-1,d6
        bra.s menu_phase_dispatch
menu_replace_dispatch:
        cmpi.w #AUR_CONTINUE_PHASE_TEMPLATE,d6
        bne.s .ordinary
        move.w d6,AUR_BASE+AUR_PAGE_CANDIDATE
        bra.s menu_template_dispatch
.ordinary:
        cmpi.w #AUR_CONTINUE_PHASE_SELECT,d6
        bhs.s menu_phase_dispatch
        cmpi.w #AUR_CONTINUE_TEMPLATE,d6
        beq.s menu_template_dispatch
menu_open_dispatch:
        move.w #AUR_PAGE_OPEN,AUR_BASE+AUR_PAGE_KIND
        lea menu_open_request(pc),a0
        bra menu_dispatch
menu_open_request:
        dc.b "cf_open.mod",0,0,0,0,0
        dc.l OPEN_MODULE_ID,EDITOR_SERIALIZER_BYTES
menu_template_dispatch:
        move.w #AUR_PAGE_TEMPLATE,AUR_BASE+AUR_PAGE_KIND
        lea menu_template_request(pc),a0
        bra menu_dispatch
menu_template_request:
        dc.b "cf_tmpl.mod",0,0,0,0,0
        dc.l TEMPLATE_MODULE_ID,EDITOR_SERIALIZER_BYTES
menu_phase_dispatch:
        move.w #AUR_PAGE_PHASE,AUR_BASE+AUR_PAGE_KIND
        move.w d6,AUR_BASE+AUR_PAGE_CANDIDATE
        lea menu_phase_request(pc),a0
        bra menu_dispatch
menu_phase_request:
        dc.b "cf_phase.mod",0,0,0,0
        dc.l PHASE_MODULE_ID,EDITOR_SERIALIZER_BYTES
menu_editor_request:
        dc.b "cf_editor.mod",0,0,0
        dc.l EDTR_MODULE_ID,EDITOR_SERIALIZER_BYTES
menu_save_request:
        dc.b "cf_save.mod",0,0,0,0,0
        dc.l SAVE_MODULE_ID,EDITOR_SERIALIZER_BYTES
menu_resize_request:
        dc.b "cf_resize.mod",0,0,0
        dc.l RESIZE_MODULE_ID,EDITOR_SERIALIZER_BYTES
        include "modal.s"
        include "../dialog/dialog.s"
        include "../dialog/text.s"
        include "../dialog/standard.s"
        include "../dialog/new_mission.s"
        include "title.s"
        include "new.s"
        include "../editor/new_stage.s"
        include "../browser/picker.s"
        include "../editor/page_bounds.s"
        include "../editor/aur.s"
        include "../editor/tested.s"
        include "../controller/text.s"
        include "../storage/read.s"
        include "../storage/payload.s"
        include "../phase/service.s"
        include "phase.s"
menu_end:
        ifgt menu_end-menu_start-EDITOR_SERIALIZER_BYTES
        fail "Menu exceeds installable code partition"
        endif
