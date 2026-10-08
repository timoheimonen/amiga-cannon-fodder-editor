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
        include "private.i"
        include "state.i"
AUR_VALIDATE_ONLY equ 1
AUR_PHASE_PAGES equ 1
AUR_VALIDATION_PAGE equ 1
PAYLOAD_DIAGNOSTICS equ 1
        section .text,code
        xdef vald_start,vald_entry,vald_end,vald_scan,vald_current
; Fixed load-base anchor: X+PCREL(pc) reads the absolute address X
; PC-relatively from module code.
module_pc_base:
PCREL   equ module_pc_base-EDITOR_MODULE_BASE
vald_start:
        dc.l MODULE_MAGIC
        dc.w MODULE_ABI,MODULE_HEADER_BYTES
        dc.l VALD_ID,EDITOR_MODULE_BASE
        dc.l vald_end-vald_start,vald_entry-vald_start,0,0
vald_entry:
        movem.l d1-d7/a0-a6,-(sp)
        move.w #REQ_ACTION_UNENTERED,EDITOR_SESSION_BASE+REQ_ACTION
        cmpi.w #MODULE_ABI,d0
        bne .bad
        cmpa.l #EDITOR_SESSION_BASE,a0
        bne .bad
        bsr vdm_begin
        bne .return
        tst.w AUR_BASE+AUR_PAGE_CANDIDATE
        beq.s .focus_resume
        bsr vdm_scan_mission
        bne.s .failed
.page:
        bsr vdm_read_page
        bne.s .failed
        bsr vdm_check
        bne.s .failed
        moveq #0,d0
        bsr edtr_modal
        tst.w d0
        bmi.s .failed
        beq.s .cancel
        cmpi.w #1,d0
        beq.s .page
        bsr vdm_jump
        bne.s .failed
        move.b E7_PHASE,d0
        cmp.b AUR_BASE+AUR_SELECTED,d0
        bne.s .cross_phase
.focus_resume:
        bsr vdm_apply_focus
        bne.s .failed
        moveq #1,d7
        bra.s .finish
.cross_phase:
        moveq #0,d0
        move.b E7_PHASE,d0
        addq.w #AUR_CONTINUE_PHASE_SELECT,d0
        move.w #AUR_PAGE_MENU,AUR_BASE+AUR_PAGE_KIND
        move.w d0,AUR_BASE+AUR_PAGE_CANDIDATE
        clr.l VDM_MAGIC
        lea vdm_menu_request(pc),a0
        bra.s .dispatch
.cancel:
        moveq #0,d7
        bra.s .finish
.failed:
        moveq #EDTR_VISUAL_ERROR,d7
.finish:
        bsr vdm_owner
        bne.s .blocked
        clr.l VDM_MAGIC
        move.w d7,EDITOR_SESSION_BASE+REQ_LAST_RESULT
        move.l #VALD_ID,EDITOR_SESSION_BASE+REQ_RESULT_ID
        lea vdm_editor_request(pc),a0
.dispatch:
        lea EDITOR_SESSION_BASE+REQ_NAME,a1
        moveq #5,d1
.request:
        move.l (a0)+,(a1)+
        dbf d1,.request
        move.w #REQ_ACTION_DISPATCH,EDITOR_SESSION_BASE+REQ_ACTION
        moveq #0,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
.bad:
        moveq #EDTR_STATE_ERROR,d0
        bra.s .return
.blocked:
        jsr wait_frame
        bra.s .blocked
open_owner:
        bra vdm_owner
vdm_menu_request:
        dc.b "cf_menu.mod",0,0,0,0,0
        dc.l MENU_MODULE_ID,EDITOR_SERIALIZER_BYTES
vdm_editor_request:
        dc.b "cf_editor.mod",0,0,0
        dc.l EDTR_MODULE_ID,EDITOR_SERIALIZER_BYTES
        include "core.s"
        include "emit.s"
        include "service.s"
        include "stage.s"
        include "mission.s"
        include "list.s"
        include "../storage/payload.s"
        include "../dialog/page.s"
        include "../dialog/dialog.s"
        include "../dialog/text.s"
        include "../editor/page_bounds.s"
        include "../editor/aur.s"
        include "../controller/text.s"
        include "../storage/read.s"
        include "../storage/manifest.s"
vald_end:
        ifgt vald_end-vald_start-EDITOR_SERIALIZER_BYTES+VD_PRIVATE_BYTES
        fail "VALD code overlaps private tail"
        endif
