; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

MENU_NEW_FAMILY equ EDITOR_UI_BASE+96
MENU_NEW_WIDTH  equ EDITOR_UI_BASE+98
MENU_NEW_HEIGHT equ EDITOR_UI_BASE+100
MENU_NEW_TEXT   equ EDITOR_UI_BASE+104
        xdef menu_new,menu_new_picker,menu_new_commit,menu_new_published

; An unsaved guard authorizes abandoning old data only after candidate success.
menu_new:
        move.w AUR_BASE+AUR_FLAGS,d0
        andi.w #AUR_HAS_SOURCE|AUR_DIRTY,d0
        cmpi.w #AUR_HAS_SOURCE,d0
        beq.s menu_new_picker
        clr.w edtr_view_live
        moveq #EDTR_DIALOG_UNSAVED,d0
        moveq #0,d1
        bsr edtr_modal
        tst.w d0
        bmi menu_fail
        beq menu_cancel
        cmpi.w #EDTR_CHOICE_DISCARD,d0
        beq.s menu_new_picker
        bsr menu_release_request
        move.w #AUR_CONTINUE_NEW,AUR_BASE+AUR_EXIT_REQUEST
        moveq #0,d0
        bra menu_prepare_save
menu_new_picker:
        clr.w MENU_NEW_FAMILY
        move.w #19,MENU_NEW_WIDTH
        move.w #15,MENU_NEW_HEIGHT
        clr.w edtr_view_live
        moveq #MENU_DIALOG_NEW,d0
        moveq #0,d1
        bsr edtr_modal
        tst.w d0
        bmi menu_fail
        beq menu_cancel
        ; The bitmap snapshot is released before READBACK becomes MAP staging.
        bsr menu_owner
        bne menu_fail
        bsr menu_epoch
        bne menu_fail
        moveq #0,d0
        move.w MENU_NEW_FAMILY,d0
        moveq #0,d1
        move.w MENU_NEW_WIDTH,d1
        moveq #0,d2
        move.w MENU_NEW_HEIGHT,d2
        bsr new_draft_stage
        tst.w d0
        bne menu_fail
        lea NEW_STAGE_MAP,a0
        moveq #0,d0
        move.w NEW_STAGE_METADATA+CFMD_MAP_BYTES,d0
        lea NEW_STAGE_SPT,a1
        moveq #10,d1
        lea NEW_STAGE_METADATA,a2
        lea AUR_VALIDATION,a3
        lea AUR_VALIDATION_WORK,a4
        bsr cf_payload_validate
        tst.w d0
        bne menu_fail
        bsr menu_owner
        bne menu_fail
        bsr menu_epoch
        bne menu_fail
        ; No fallible operation follows the first canonical write. The typed
        ; receipt makes EDTR rebuild terrain assets before acquiring its view.
menu_new_commit:
        lea NEW_STAGE_MAP,a0
        lea map_file_buffer,a1
        move.w NEW_STAGE_METADATA+CFMD_MAP_BYTES,d0
        lsr.w #1,d0
        subq.w #1,d0
.map:
        move.w (a0)+,(a1)+
        dbf d0,.map
        lea NEW_STAGE_SPT,a0
        lea EDITOR_SPT_BASE,a1
        move.w #EDITOR_SPT_BYTES/2-1,d0
.spt:
        move.w (a0)+,(a1)+
        dbf d0,.spt
        lea NEW_STAGE_METADATA,a0
        lea EDITOR_METADATA_BASE,a1
        move.w #EDITOR_METADATA_BYTES/4-1,d0
.metadata:
        move.l (a0)+,(a1)+
        dbf d0,.metadata
        lea EDITOR_UNDO_BASE,a0
        move.w #(EDITOR_UNDO_BYTES+EDITOR_MANIFEST_BYTES)/4-1,d0
.history:
        clr.l (a0)+
        dbf d0,.history
        lea AUR_BASE+AUR_SOURCE_BYTES,a0
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
        move.w #AUR_PAGE_MENU,AUR_BASE+AUR_PAGE_KIND
        move.w #AUR_PAGE_NONE,AUR_BASE+AUR_PAGE_CANDIDATE
        move.w #EDTR_NEW,AUR_BASE+AUR_ORIGIN
        move.w MENU_NEW_WIDTH,d0
        subi.w #19,d0
        lsr.w #1,d0
        move.w d0,AUR_BASE+AUR_CAMERA_X
        move.w MENU_NEW_HEIGHT,d0
        subi.w #12,d0
        lsr.w #1,d0
        move.w d0,AUR_BASE+AUR_CAMERA_Y
        clr.l STORAGE_READY
menu_new_published:
        moveq #3,d7
        bra menu_finish

; The New dialog itself is shared with the controller (dialog/new_mission.s).
NEW_DIALOG_FAMILY   equ MENU_NEW_FAMILY
NEW_DIALOG_WIDTH    equ MENU_NEW_WIDTH
NEW_DIALOG_HEIGHT   equ MENU_NEW_HEIGHT

menu_new_step:
        bsr dialog_poll
        bmi edtr_modal_idle
        bsr new_dialog_event
        bmi edtr_modal_idle
        move.w d0,EXIT_CHOICE
        bra edtr_modal_finish
