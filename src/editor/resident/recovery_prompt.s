; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        xdef editor_recovery_prompt,editor_recovery_prompt_end,editor_resource_prompt

; Enter at an owned stopped-phase boundary: gameplay IRQ disabled, no
; renderer/fader/native main-loop continuation or module callbacks. Source cache
; and incoming descriptor/masks must be valid; four planes and text modes zero.
; A zero descriptor during native reconstruction owns no incoming masks.
; UI record bytes0..35 and both bitmap middle top bands are caller-owned.
; UI36..39 holds the live EDTR asset stack anchor and is preserved.
; Live authoring and committed RETURN release both complete display buffers.
; D0=0 retry (including periodic scan),1 cancel. Other registers/SP survive.
; editor_resource_prompt accepts D0.w=3 for the named game-resource prompt;
; the default entry selects the Custom directory or restore-editor presentation.
editor_recovery_prompt:
        moveq   #0,d0
editor_resource_prompt:
        move.w  d0,-(sp)
        movem.l d1-d7/a0-a6,-(sp)
        lea     editor_resident_start+(EDITOR_UI_BASE-EDITOR_RESIDENT_BASE)(pc),a4
        ; Publish, font exchange and the disk prompt preserve this address base.
        lea     native_display_offsets,a6
        move.l  native_descriptor_table-native_display_offsets(a6),(a4)
        move.w  native_mask_mode-native_display_offsets(a6),4(a4)
        move.w  native_cursor_active-native_display_offsets(a6),6(a4)
        move.l  native_cursor_offsets-native_display_offsets(a6),20(a4)
        move.w  native_copper_wrap_wait.w,34(a4)
        move.w  native_copper_color0.w,32(a4)
        clr.w   native_copper_color0.w
        move.w  #$FFDF,native_copper_wrap_wait.w
        clr.l   native_cursor_offsets-native_display_offsets(a6)
        move.w  #-1,native_cursor_active-native_display_offsets(a6)
        movea.l a6,a0
        lea     8(a4),a1
        moveq   #2,d0
.save_offsets:
        move.l  (a0),(a1)+
        clr.l   (a0)+
        dbra    d0,.save_offsets
        lea     native_copper_color6.w,a0
        lea     24(a4),a1
        moveq   #3,d0
.save_colors:
        move.w  (a0),(a1)+
        move.w  #$DDD,(a0)
        addq.l  #4,a0
        dbra    d0,.save_colors
        jsr     native_publish_display
        jsr     native_editor_hill_font
        move.w  56(sp),d0
        bsr     editor_disk_prompt_kind
        move.w  d0,-(sp)
        jsr     native_editor_hill_font
        movea.l a6,a0
        lea     8(a4),a1
        moveq   #2,d0
.restore_offsets:
        move.l  (a1)+,(a0)+
        dbra    d0,.restore_offsets
        lea     native_copper_color6.w,a0
        lea     24(a4),a1
        moveq   #3,d0
.restore_colors:
        move.w  (a1)+,(a0)
        addq.l  #4,a0
        dbra    d0,.restore_colors
        move.w  32(a4),native_copper_color0.w
        move.w  34(a4),native_copper_wrap_wait.w
        move.l  20(a4),native_cursor_offsets-native_display_offsets(a6)
        move.w  6(a4),native_cursor_active-native_display_offsets(a6)
        jsr     native_publish_display
        move.w  4(a4),native_mask_mode-native_display_offsets(a6)
        move.l  (a4),native_descriptor_table-native_display_offsets(a6)
        beq.s   .no_masks
        movea.l (a4),a5
        jsr     native_font_masks
.no_masks:
        move.w  (sp)+,d0
        movem.l (sp)+,d1-d7/a0-a6
        addq.l  #2,sp
        tst.w   d0
        rts
editor_recovery_prompt_end:
