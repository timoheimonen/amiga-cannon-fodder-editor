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
        include "protocol.i"
        include "state.i"
AUR_VALIDATE_ONLY equ 1
AUR_PHASE_PAGES equ 1
AUR_PHASE_ADDITIONS equ 1
PAYLOAD_STRUCTURAL_ONLY equ 1
        section .text,code
        xdef phase_start,phase_entry,phase_end
        xdef phl_before_map_commit,phl_before_replacement,phl_published
; Fixed load-base anchor: X+PCREL(pc) reads the absolute address X
; PC-relatively from module code.
module_pc_base:
PCREL   equ module_pc_base-EDITOR_MODULE_BASE
phase_start:
        dc.l MODULE_MAGIC
        dc.w MODULE_ABI,MODULE_HEADER_BYTES
        dc.l PHASE_MODULE_ID,EDITOR_MODULE_BASE
        dc.l phase_end-phase_start,phase_entry-phase_start,0,0
phase_entry:
        movem.l d1-d7/a0-a6,-(sp)
        move.w #REQ_ACTION_UNENTERED,EDITOR_SESSION_BASE+REQ_ACTION
        cmpi.w #MODULE_ABI,d0
        bne phl_bad_entry
        cmpa.l #EDITOR_SESSION_BASE,a0
        bne phl_bad_entry
        bsr phl_begin
        bne phl_entry_return
        bsr phl_inspect
        bne phl_failed
        cmpi.w #AUR_PAGE_NONE,PHL_INTENT
        bne phl_replacement
        bsr phl_preview
        bne phl_failed
        bsr phl_valid_map
        bne phl_failed
        bsr phl_check
        bne phl_failed
phl_list_ready:
        moveq #0,d0
        bsr edtr_modal
        tst.w d0
        bmi phl_failed
        beq phl_cancelled
        cmpi.w #1,d0
        beq.s phl_apply
        cmpi.w #3,d0
        bne.s .intent
        move.w #MENU_PHASE_SETTINGS,PHL_INTENT
.intent:
        bsr phl_check
        bne phl_failed
        bsr phl_inspect
        bne phl_failed
        move.w #AUR_PAGE_MENU,AUR_BASE+AUR_PAGE_KIND
        move.w PHL_INTENT,AUR_BASE+AUR_PAGE_CANDIDATE
        clr.l PHL_MAGIC
        lea phl_menu_request(pc),a0
        bra phl_dispatch
phl_apply:
        bsr phl_inspect
        bne phl_failed
        btst #0,PHL_OWNER+AUR_FLAGS+1
        beq.s phl_before_map_commit
        bsr phl_read_source
        bne phl_failed
        moveq #0,d1
        bsr phl_parse_source
        bne phl_failed
phl_before_map_commit:
        bsr phl_commit_map
        cmpi.w #PHL_RESULT_MAP,d0
        bhi phl_failed
        move.w d0,d7
        bra phl_finish
phl_replacement:
        cmpi.w #AUR_CONTINUE_PHASE_BLANK,PHL_INTENT
        beq.s phl_blank
        moveq #0,d0
        move.w PHL_INTENT,d0
        bsr phl_intent_prepare
        tst.w d0
        bmi.s phl_failed
        bsr phl_stage
        bne.s phl_failed
phl_before_replacement:
        bsr phl_commit_replacement
        cmpi.w #PHL_RESULT_REPLACED,d0
        bne.s phl_failed
phl_published:
        move.w d0,d7
        bra.s phl_finish
phl_blank:
        bsr phl_blank_prepare
        bne.s phl_failed
        clr.w PHL_BLANK_FAMILY
        move.w #19,PHL_BLANK_WIDTH
        move.w #15,PHL_BLANK_HEIGHT
        moveq #0,d0
        bsr edtr_modal
        tst.w d0
        bmi.s phl_failed
        beq.s phl_cancelled
        bsr phl_check
        bne.s phl_failed
        bsr phl_inspect
        bne.s phl_failed
        moveq #0,d0
        move.w PHL_BLANK_FAMILY,d0
        moveq #0,d1
        move.w PHL_BLANK_WIDTH,d1
        moveq #0,d2
        move.w PHL_BLANK_HEIGHT,d2
        bsr phl_blank_stage
        tst.w d0
        bne.s phl_failed
        bra.s phl_before_replacement
phl_cancelled:
        moveq #PHL_RESULT_SAME,d7
        bra.s phl_finish
phl_failed:
        ; One bounded entered refusal. All UI owners are already restored.
        moveq #EDTR_VISUAL_ERROR,d7
phl_finish:
        clr.l PHL_MAGIC
        bsr.s phl_owner
        bne.s phl_blocked
        move.w d7,EDITOR_SESSION_BASE+REQ_LAST_RESULT
        move.l #PHASE_MODULE_ID,EDITOR_SESSION_BASE+REQ_RESULT_ID
        lea phl_editor_request(pc),a0
phl_dispatch:
        lea EDITOR_SESSION_BASE+REQ_NAME,a1
        moveq #5,d1
.request:
        move.l (a0)+,(a1)+
        dbf d1,.request
        move.w #REQ_ACTION_DISPATCH,EDITOR_SESSION_BASE+REQ_ACTION
        moveq #0,d0
phl_entry_return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
phl_bad_entry:
        moveq #EDTR_STATE_ERROR,d0
        bra.s phl_entry_return
phl_blocked:
        jsr wait_frame
        bra.s phl_blocked
open_owner:
        bra.s phl_owner
phl_menu_request:
        dc.b "cf_menu.mod",0,0,0,0,0
        dc.l MENU_MODULE_ID,EDITOR_SERIALIZER_BYTES
phl_editor_request:
        dc.b "cf_editor.mod",0,0,0
        dc.l EDTR_MODULE_ID,EDITOR_SERIALIZER_BYTES
        include "service.s"
        include "tested.s"
        include "stage.s"
        include "blank.s"
        include "mission.s"
        include "../editor/new_stage.s"
        include "preview.s"
        include "list.s"
        include "map.s"
        include "../dialog/page.s"
DIALOG_LIST_CLICKS equ 1
        include "../dialog/dialog.s"
        include "../dialog/text.s"
        include "../dialog/new_mission.s"
        include "../editor/page_bounds.s"
        include "../editor/aur.s"
        include "../controller/text.s"
        include "../storage/read.s"
        include "../storage/manifest.s"
        include "../storage/payload.s"
phase_end:
        ifgt phase_end-phase_start-(EDITOR_SERIALIZER_BYTES-PHL_RESERVED)
        fail "Phase code overlaps immutable snapshots"
        endif
