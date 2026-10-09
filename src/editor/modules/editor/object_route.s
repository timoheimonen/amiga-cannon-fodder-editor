; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; OBJV uses the ordinary by-value page receipt, with candidate NONE.
; Tool 2 enters the live object view. A terrain tool requests one object Undo
; while retaining that tool; the checked object publisher returns result 0.
edtr_request_object:
        move.l #$000AFFFF,-(sp)
        bra edtr_request_page
edtr_object_released:
        move.l #$000AFFFF,-(sp)
        bra edtr_page_released

; The matching receipt has been validated and consumed exactly once. No live
; display or terrain operation exists. D7 is the typed result, not a pointer.
edtr_object_result:
        tst.w d7
        beq.s .cancel
        bmi.s .message
        ; The receipt has admitted exact actions1..8, with tool2 required.
        move.w d7,d0
        add.w d0,d0
        lea .actions(pc),a0
        move.w 0(a0,d0.w),d0
        jmp 0(a0,d0.w)
.actions:
        dc.w .cancel-.actions
        dc.w edtr_save_released-.actions
        dc.w edtr_menu_released-.actions
        dc.w .tiles-.actions
        dc.w edtr_palette_released-.actions
        dc.w .terrain_undo-.actions
        dc.w .tool-.actions
        dc.w edtr_validation_released-.actions
        dc.w edtr_test_released-.actions
.tool:
        ; Result 6: an explicit tool switch.
        bra edtr_acquire_view
.terrain_undo:
        clr.l TERRAIN_OP
        bsr terrain_context
        bsr tu_undo
        cmpi.w #1,d0
        bne edtr_recovery_blocked
        bsr aur_mark_edited
        bra edtr_acquire_view
.tiles:
        move.l #$0001FFFF,-(sp)
        bra edtr_page_released
.cancel:
        ; A completed one-shot Undo retains its terrain tool. An unentered
        ; canceled live OBJV must recover terrain without immediately retrying.
        ; Keep the selected object type; only live Object changes to Paint.
        cmpi.w #2,AUR_BASE+AUR_TOOL
        bne edtr_acquire_view
        clr.w AUR_BASE+AUR_TOOL
        bra edtr_acquire_view
.message:
        move.w d7,d1
        bra edtr_message_released

; Terrain input releases its acquired view before publishing the same request.
edtr_request_palette:
        move.l #$000bffff,-(sp)
        bra edtr_request_page

; Existing OBJV result4 arrives with its view already released.
edtr_palette_released:
        move.l #$000bffff,-(sp)
        bra edtr_page_released
