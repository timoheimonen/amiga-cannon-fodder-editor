; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        xdef editor_hill_click,editor_browser_dispatch,editor_copy_request
        xdef editor_request_loop,editor_disk_prompt,editor_disk_prompt_wait
        xdef editor_prompt_bar
        xdef editor_orchestration_start,editor_orchestration_end
        xdef editor_resource_retry,editor_disk_prompt_kind

editor_orchestration_start:
; Recruitment click entry. Logical rectangles use the native cursor +16 offset.
editor_hill_click:
        clr.w   FODDERS_LOAD_FLAG
        ; The EDITOR and CUSTOM disks with their labels; pointer X is the
        ; bitmap X less 16. Rows match the LOAD and SAVE disks.
        cmpi.w  #4,native_mouse_y
        blo.s   .native
        cmpi.w  #26,native_mouse_y
        bhi.s   .native
        move.w  native_mouse_x,d0
        subi.w  #HILL_EDITOR_X+8-HILL_LABEL_WIDTH/2-16,d0
        cmpi.w  #HILL_LABEL_WIDTH,d0
        blo.s   .editor
        subi.w  #HILL_CUSTOM_X-HILL_EDITOR_X,d0
        cmpi.w  #HILL_LABEL_WIDTH,d0
        bhs.s   .native
        moveq   #2,d0
        bra.s   .selected
.editor:
        moveq   #1,d0
.selected:
        movem.l d1-d7/a0-a6,-(sp)
        clr.w   native_save_flag
        lea     editor_resident_start+(EDITOR_SESSION_BASE-EDITOR_RESIDENT_BASE)(pc),a4
        move.w  d0,REQ_PURPOSE(a4)
        clr.l   REQ_RESULT_ID(a4)
        bsr     editor_prompt_release
        bsr.s   editor_browser_dispatch
        moveq   #0,d0
        cmpi.w  #2,REQ_ACTION(a4)
        bne.s   .return
        move.w  (a4),d1
        subq.w  #1,d1
        lsr.w   #1,d1
        bne.s   .return
        moveq   #1,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w   d0
        rts
.native:
        jmp     native_click_continue

; Action2/mode1 returns nonzero through the native hill caller; all module
; frames are already returned. Custom gameplay preparation remains separate.
editor_browser_dispatch:
        move.w  sensi_selected_drive,REQ_OLD_DRIVE(a4)
        lea     native_browser_request,a0
        moveq   #0,d6
editor_copy_request:
        lea     REQ_NAME(a4),a1
        moveq   #5,d0
.request:
        move.l  (a0)+,(a1)+
        dbra    d0,.request
editor_request_loop:
        ; The installed Custom directory is the only module source. A failed
        ; admission prompts for a retry and never changes the original resource drive.
        clr.w   REQ_DRIVE(a4)
        move.w  #-1,REQ_ACTION(a4)
        lea     REQ_NAME(a4),a0
        move.l  REQ_ID(a4),d1
        move.l  REQ_CAPACITY(a4),d2
        bsr     editor_custom_module_dispatch
        move.w  d0,REQ_STATUS(a4)
        tst.w   REQ_ACTION(a4)
        bmi.s   .whd_failed
        cmpi.w  #1,REQ_ACTION(a4)
        beq.s   editor_request_loop
        bra.s   .done
.whd_failed:
        tst.w   d6
        beq.s   .hill_prompt
        bsr     editor_recovery_prompt
        bra.s   .prompt_return
.hill_prompt:
        bsr.s   editor_disk_prompt
.prompt_return:
        tst.w   d0
        beq.s   editor_request_loop
        bsr     editor_authoring_live
        beq     editor_authoring_cancel
        clr.w   REQ_ACTION(a4)
        move.w  #-10,REQ_STATUS(a4)
.done:
        move.w  REQ_OLD_DRIVE(a4),d1

; Native command 0 is the only unprotected engine disk operation here. It
; changes drive/cache state only, retaining scratch and the directory cap.
editor_select_drive:
        movem.l d1-d7/a0-a6,-(sp)
        moveq   #-1,d3
        movea.l d3,a0
        moveq   #0,d0
        jsr     sensi_disk_command
        movem.l (sp)+,d1-d7/a0-a6
        tst.w   d0
        rts
editor_request_loop_end:

; Enter only while the caller owns the installed hill font pixels.
; Module returns must restore that same hill-resource state before requesting
; another overlay. No callbacks into an evictable module are retained.
editor_disk_prompt:
        moveq   #0,d0
editor_disk_prompt_kind:
        clr.w   native_last_key
        tst.w   d0
        bne.s   .draw_prompt
        moveq   #1,d0
        bsr     editor_authoring_live
        bne.s   .draw_prompt
        cmpi.l  #RECOVERY_EDITOR_ID,EDITOR_SESSION_BASE+REQ_ID
        bne.s   .draw_prompt
        moveq   #2,d0
.draw_prompt:
        bsr     editor_prompt_bar
.release:
        bsr.s   editor_prompt_release
        moveq   #99,d7
.press:
        bsr.s   editor_wait_frame
        cmpi.w  #$C5,native_last_key
        beq.s   .cancel
        tst.w   native_left_pressed
        bne.s   .clicked
        dbra    d7,.press
        bra.s   .retry
.clicked:
        clr.w   native_left_pressed
        cmpi.w  #14,native_mouse_y
        blo.s   .release
        cmpi.w  #26,native_mouse_y
        bhi.s   .release
        move.w  native_mouse_x,d0
        subi.w  #73,d0
        cmpi.w  #27,d0
        blo.s   .retry
        subi.w  #67,d0
        cmpi.w  #74,d0
        bhs.s   .release
.cancel:
        moveq   #1,d0
        bra.s   .finish
.retry:
        moveq   #0,d0
.finish:
        clr.w   native_last_key
        move.w  d0,-(sp)
        bsr.s   editor_prompt_release
        moveq   #0,d0
        bsr.s   editor_prompt_bar
        move.w  (sp)+,d0
        rts
editor_disk_prompt_wait equ .press
editor_prompt_release:
        bsr.s   editor_wait_frame
        tst.w   native_left_down
        bne.s   editor_prompt_release
        clr.w   native_left_pressed
        rts
editor_disk_prompt_end:
editor_wait_frame:
        jmp wait_frame

; D0=0 redraws normal actions, 1 asks to check the Custom directory, 2 restores the editor,
; and 3 names the game disk for custom terrain or original campaign return. Other
; drawing modes, masks and registers are restored before returning to caller.
editor_prompt_bar:
        movem.l d0-d7/a0-a6,-(sp)
        move.w  native_mask_mode,-(sp)
        move.l  display_draw_buffer,-(sp)
        move.l  native_text_x_width,-(sp)
        move.l  native_text_y_height,-(sp)
        move.w  d0,-(sp)
        clr.w   native_mask_mode
        lea     native_hill_font_table,a5
        jsr     native_font_masks
        move.w  (sp),d0
        bsr.s   editor_prompt_one_bar
        move.l  display_visible_buffer,display_draw_buffer
        move.w  (sp)+,d0
        bsr.s   editor_prompt_one_bar
        bsr.s   editor_wait_blitter
        move.w  #-1,native_mask_mode
        lea     native_hill_animation_table,a5
        jsr     native_font_masks
        move.l  (sp)+,native_text_y_height
        move.l  (sp)+,native_text_x_width
        move.l  (sp)+,display_draw_buffer
        move.w  (sp)+,native_mask_mode
        movem.l (sp)+,d0-d7/a0-a6
        rts
editor_wait_blitter:
        btst    #6,amiga_dmacon_read
        bne.s   editor_wait_blitter
        rts
editor_prompt_one_bar:
        move.w  d0,-(sp)
        bsr.s   editor_wait_blitter
        movea.l display_draw_buffer,a0
        bsr     editor_authoring_live
        beq.s   .clear_display
        cmpi.w  #SESSION_EVENT_RETURN,session_event
        bne.s   .band
.clear_display:
        ; Released authoring/return bitmaps contain transient font material.
        jsr     native_clear_display_buffer
        bra.s   .cleared
.band:
        addq.l  #4,a0
        moveq   #3,d7
.plane:
        moveq   #26,d6
.row:
        moveq   #7,d5
.long:
        clr.l   (a0)+
        dbra    d5,.long
        addq.l  #8,a0
        dbra    d6,.row
        adda.w  #$2828-27*40,a0
        dbra    d7,.plane
.cleared:
        move.w  (sp)+,d0
        tst.w   d0
        bne.s   .prompt
        jmp     native_hill_body
.prompt:
        subq.w  #1,d0
        beq.s   .ordinary
        subq.w  #1,d0
        beq.s   .authoring
        lea     editor_resident_start+(native_insert_disk_text-EDITOR_RESIDENT_BASE)(pc),a0
        moveq   #94,d2
        moveq   #0,d3
        bsr.s   .draw
        lea     editor_resident_start+(native_disk2_suffix-EDITOR_RESIDENT_BASE)(pc),a0
        ; Reconstruction loads SPT before replacing the former custom MAP.
        bsr.s   editor_test_custom_mode
        bne.s   .custom_disk
        cmpi.w  #36,native_map_index
        blt.s   .game_number
        bra.s   .disk3
.custom_disk:
        ; Admitted Interior/Moor prefixes have 'n'/'o' as their second byte.
        move.b  map_file_buffer+1,d0
        subi.b  #'n',d0
        cmpi.b  #1,d0
        bhi.s   .game_number
.disk3:
        adda.w  #native_disk3_suffix-native_disk2_suffix,a0
.game_number:
        move.w  #166,d2
        moveq   #0,d3
        bsr.s   .draw
        bsr.s   editor_test_custom_mode
        beq.s   .authoring_options
        bra.s   .ordinary_options
.authoring:
        lea     native_authoring_title,a0
        moveq   #81,d2
        moveq   #0,d3
        bsr.s   .draw
 .authoring_options:
        lea     editor_resident_start+(native_authoring_ok-EDITOR_RESIDENT_BASE)(pc),a0
        bra.s   .options
.ordinary:
        lea     native_editor_prompt_title,a0
        moveq   #60,d2
        moveq   #0,d3
        bsr.s   .draw
 .ordinary_options:
        lea     native_editor_prompt_options,a0
.options:
        moveq   #89,d2
        moveq   #14,d3
.draw:
        lea     editor_resident_start+(native_hill_widths-EDITOR_RESIDENT_BASE)(pc),a2
        moveq   #13,d0
        bra     editor_resident_start+(native_draw_text-EDITOR_RESIDENT_BASE)
editor_orchestration_end:

; Native resource errors use the permanent component's prompt-aware entry.
editor_resource_retry equ native_resource_retry_body

; Preserve all registers and X; callers consume the mode word's NZVC.
editor_test_custom_mode:
        tst.w   session_custom_mode
        rts
