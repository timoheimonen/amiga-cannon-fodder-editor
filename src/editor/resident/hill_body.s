; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        include "fodders.i"
        include "layout.i"
        include "authoring_recovery.i"
        include "ui.i"

EDITOR_HILL_BODY_BYTES equ 192
        section .text,code
        xdef editor_hill_body_start,editor_hill_body_end
        xdef editor_hill_draw_actions,editor_browser_request
        xdef editor_disk_prompt_title,editor_disk_prompt_options

editor_hill_body_start:
; The EDITOR and CUSTOM disks: the hill's own LOAD disk drawn twice, then
; the Slave writes their labels. Returns to the caller of the top bar.
editor_hill_draw_actions:
        moveq   #HILL_DISK,d0
        moveq   #0,d1
        moveq   #HILL_EDITOR_X,d2
        moveq   #0,d3
        jsr     native_draw_sprite
        moveq   #HILL_DISK,d0
        moveq   #0,d1
        move.w  #HILL_CUSTOM_X,d2
        moveq   #0,d3
        jsr     native_draw_sprite
        moveq   #HILL_OPERATION,d0
        jmp     EDITOR_BACKEND_ENTRY
        dcb.b   (native_browser_request-native_hill_body)-(*-editor_hill_body_start),0

; Read-only controller constants. The request name alone uses C termination.
editor_browser_request:
        dc.b    "cf_browser.mod",0,0
        dc.l    $42524f57
        dc.l    16384
editor_disk_prompt_title:
        dc.b    "CHECK CUSTOM DIR",$ff,0,0
editor_disk_prompt_options:
        dc.b    "OK     CANCEL",$ff
        even
editor_hill_constants_end:
        include "hill_font.s"
        xdef editor_authoring_title
editor_authoring_title:
        dc.b    "RESTORE EDITOR",$FF
        even
editor_hill_body_used_end:
        dcb.b   EDITOR_HILL_BODY_BYTES-(*-editor_hill_body_start),0
editor_hill_body_end:
        ifne editor_browser_request-editor_hill_body_start-(native_browser_request-native_hill_body)
        fail "Browser request address differs from resident contract"
        endif
        ifne editor_disk_prompt_title-editor_hill_body_start-(native_editor_prompt_title-native_hill_body)
        fail "Prompt title address differs from resident contract"
        endif
        ifne editor_disk_prompt_options-editor_hill_body_start-(native_editor_prompt_options-native_hill_body)
        fail "Prompt options address differs from resident contract"
        endif
        ifne editor_hill_font_exchange-editor_hill_body_start-(native_editor_hill_font-native_hill_body)
        fail "Hill font helper address differs from resident contract"
        endif
        ifne editor_authoring_title-editor_hill_body_start-(native_authoring_title-native_hill_body)
        fail "Authoring title address differs from resident contract"
        endif
