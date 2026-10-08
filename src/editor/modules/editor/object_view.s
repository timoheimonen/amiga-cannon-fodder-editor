; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Live object authoring overlay: retained viewport and canonical edit transactions.
; Requires the resident/CTRL mode 2 handoff and SPT construction bypass.
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
        include "authoring_recovery.i"
        include "state.i"
        include "dialog.i"
STORAGE_INSPECT_ONLY equ 1
PAYLOAD_STRUCTURAL_ONLY equ 1
AUR_INCOMPLETE_RECOVERY equ 1

AUR_VALIDATE_ONLY equ 1
AUR_OBJECT_VIEW equ 1
AUR_OBJECT_PAGES equ 1
OBJECT_ANCHOR_ENABLED equ 1
OBJECT_ANCHOR_DESC equ parts+48
        section .text,code
; Fixed load-base anchor: X+PCREL(pc) reads the absolute address X
; PC-relatively from module code.
module_pc_base:
PCREL   equ module_pc_base-EDITOR_MODULE_BASE
object_view_start:
        dc.l MODULE_MAGIC
        dc.w MODULE_ABI,MODULE_HEADER_BYTES
        dc.l OBJECT_VIEW_MODULE_ID,EDITOR_MODULE_BASE
        dc.l object_view_end-object_view_start
        dc.l object_view_entry-object_view_start,0,0
        include "object_entry.s"
        include "object_edit.s"
        include "object_hit.s"
        include "object_anchor.s"
        include "object_input.s"
exit_ui_blitter_idle:
        btst #6,amiga_dmacon_read
        bne.s exit_ui_blitter_idle
        rts
edtr_prepare_font:
        bsr.s font_strip_prepare
        bne.s .return
        ; A zero-contrast palette refuses before enter_view installs display.
        bsr terrain_font_palette
        bne.s .return
        bra bar_prepare
.return:
        rts

        include "font_strip.s"
        include "ink.s"
        include "objects.s"
        include "object_parts.s"
        include "view.s"
        include "../storage/read.s"
        include "../storage/payload.s"
        include "aur.s"
        include "tested.s"
        include "page_bounds.s"
        include "object_bar.s"
        include "scroll.s"
        include "palette.s"
        include "pipeline.s"
object_view_end:
        ifne PV_STATE_SIZE-3216
        fail "Object preview scratch extent changed"
        endif
        ifgt edtr_state_end-EDITOR_READBACK_BASE-EDITOR_READBACK_BYTES
        fail "Object graphics state exceeds readback"
        endif
        ifgt edtr_validation_end-EDITOR_SERIAL_WORK_BASE-EDITOR_SERIAL_WORK_BYTES
        fail "Object validation exceeds serial working scratch"
        endif
        ifgt object_view_end-object_view_start-EDITOR_SERIALIZER_BYTES
        fail "Object view exceeds installable 16 KiB"
        endif
