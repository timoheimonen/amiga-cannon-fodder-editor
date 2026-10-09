; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        include "fodders.i"
        include "layout.i"
        include "module.i"
        include "session.i"
        include "metadata.i"
        include "authoring_recovery.i"
        include "ui.i"

        section .text,code
        xdef editor_resident_start
        xdef editor_bootstrap
        xdef editor_boot_marker
        xdef editor_resident_end

editor_resident_start:
editor_bootstrap:
        move.l  #EDITOR_BOOT_MARKER_VALUE,editor_boot_marker
        clr.l   session_custom_mode
        clr.w   SESSION_SNAPSHOT_VALID
        ; Replay the displaced entry jump; no stack or disk service is needed.
        jmp     main_initialise
        dcb.b   EDITOR_BOOT_MARKER_OFFSET-(*-editor_resident_start),0
editor_boot_marker:
        dc.l    0
        xdef editor_backend_call
editor_backend_call:
        ifne editor_backend_call-editor_resident_start-$24
        fail "WHD backend veneer ABI moved"
        endif
        jmp     0
        include "module_dispatch.s"
        include "campaign.s"
        include "policy.s"
        include "session.s"
        include "orchestration.s"
        include "authoring_recovery.s"
        include "recovery_prompt.s"
        include "session_bridge.s"
        include "native_read.s"
        include "audio_publish.s"
        include "keyboard.s"
editor_resident_end:
