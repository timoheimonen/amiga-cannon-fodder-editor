; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

TPL_DRIVE       equ EDITOR_UI_BASE+118
TPL_READ_KIND   equ EDITOR_UI_BASE+120
TPL_RESULT      equ EDITOR_UI_BASE+122
TPL_DIRECTORY_CRC equ EDITOR_UI_BASE+124
        xdef template_import,template_import_prompt,template_import_idle
        xdef template_import_staged

; Qualified second New pass only, with BRW1 and captured campaign, no AUR1.
; Failed MAP/SPT/metadata staging is disposable; return through CTRL so the
; resident lifecycle restores campaign state. Never publish authored authority.
template_import:
        movem.l d1-d7/a0-a6,-(sp)
        move.w BROWSER_TEMPLATE_MISSION,d0
        move.w BROWSER_TEMPLATE_PHASE,d1
        bsr template_lookup
        bmi tpli_return
        cmp.w BROWSER_TEMPLATE_MAP,d0
        bne tpli_bad
        lea EDITOR_METADATA_BASE,a0
        move.w BROWSER_TEMPLATE_MISSION,d0
        move.w BROWSER_TEMPLATE_PHASE,d1
        bsr template_metadata
        bne tpli_return
        bsr new_fade_own
        clr.w TPL_READ_KIND
        clr.w TPL_DRIVE
        bsr template_loading
        moveq #3,d7
tpli_scan:
        bsr template_import_read
        tst.l d0
        bpl.s tpli_map
        cmpi.l #-4,d0
        beq tpli_finish
        addq.w #1,TPL_DRIVE
        dbf d7,tpli_scan
        clr.w TPL_DRIVE
tpli_retry:
        bsr template_import_prompt
        bne tpli_cancel
        bsr template_loading
        bsr template_import_read
        tst.l d0
        bpl.s tpli_read
        cmpi.l #-4,d0
        beq tpli_finish
        bra.s tpli_retry
tpli_read:
        tst.w TPL_READ_KIND
        bne.s tpli_spt
tpli_map:
        move.l TR_DIRECTORY_CRC,TPL_DIRECTORY_CRC
        lea EDITOR_READBACK_BASE,a0
        lea map_file_buffer,a1
        move.l #EDITOR_READBACK_BYTES,d1
        bsr template_rnc_unpack
        tst.l d0
        bmi.s tpli_retry
        move.w d0,EDITOR_METADATA_BASE+CFMD_MAP_BYTES
        move.w #1,TPL_READ_KIND
        bsr template_import_read
        cmpi.l #-4,d0
        beq.s tpli_finish
        tst.l d0
        bmi.s tpli_retry
tpli_spt:
        move.l TR_DIRECTORY_CRC,d1
        cmp.l TPL_DIRECTORY_CRC,d1
        beq.s tpli_spt_verified
        clr.w TPL_READ_KIND
        bra.s tpli_retry
tpli_spt_verified:
        move.w d0,EDITOR_METADATA_BASE+CFMD_SPT_BYTES
        lea EDITOR_READBACK_BASE,a0
        lea EDITOR_SPT_BASE,a1
        move.w d0,d1
        subq.w #1,d1
tpli_copy:
        move.b (a0)+,(a1)+
        dbf d1,tpli_copy
        move.w #EDITOR_SPT_BYTES,d1
        sub.w d0,d1
        beq.s tpli_crc
        subq.w #1,d1
tpli_clear_spt:
        clr.b (a1)+
        dbf d1,tpli_clear_spt
tpli_crc:
        lea map_file_buffer,a0
        moveq #0,d1
        move.w EDITOR_METADATA_BASE+CFMD_MAP_BYTES,d1
        bsr read_crc32
        move.l d0,EDITOR_METADATA_BASE+CFMD_MAP_CRC
        lea EDITOR_SPT_BASE,a0
        moveq #0,d1
        move.w EDITOR_METADATA_BASE+CFMD_SPT_BYTES,d1
        bsr read_crc32
        move.l d0,EDITOR_METADATA_BASE+CFMD_SPT_CRC
        clr.l STORAGE_READY
        moveq #0,d0
template_import_staged:
tpli_finish:
        move.w d0,TPL_RESULT
        bsr dialog_close
        bsr dialog_release
        bsr new_fade_restore
        move.w TPL_RESULT,d0
        ext.l d0
        bne.s tpli_return
        ; Publish a clean empty history only now, while no authored
        ; authority exists yet.
        lea EDITOR_UNDO_BASE,a0
        move.w #(EDITOR_UNDO_BYTES+EDITOR_MANIFEST_BYTES)/4-1,d1
tpli_clear_undo:
        clr.l (a0)+
        dbf d1,tpli_clear_undo
tpli_return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.l d0
        rts
tpli_cancel:
        moveq #-4,d0
        bra.s tpli_finish
tpli_bad:
        moveq #-1,d0
        bra.s tpli_return

; Only standard-track helper owns payload writes. Native select is bounded
; and cannot load data. D0=positive count or transport status; preserve others.
template_import_read:
        movem.l d1-d7/a0-a6,-(sp)
        move.w TPL_DRIVE,d1
        moveq #-1,d3
        movea.l d3,a0
        moveq #0,d0
        jsr sensi_disk_command
        tst.w d0
        bne.s .bad
        move.w BROWSER_TEMPLATE_MAP,d0
        move.w TPL_READ_KIND,d1
        bsr template_read_file
        bra.s .return
.bad:
        moveq #-6,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.l d0
        rts

; "Loading template", open while the files are read. Closes any open dialog.
template_loading:
        movem.l d0/d2/a0,-(sp)
        bsr dialog_close
        lea dlg_template_loading(pc),a0
        moveq #0,d2
        bsr dialog_open
        movem.l (sp)+,d0/d2/a0
        rts

; The game-disk prompt: Z and D0=0 Retry, D0=1 Cancel. Closes it again.
template_import_prompt:
        bsr dialog_close
        lea dlg_template_disk2(pc),a0
        cmpi.w #36,BROWSER_TEMPLATE_MAP
        bls.s .open
        lea dlg_template_disk3(pc),a0
.open:
        moveq #0,d2
        bsr dialog_open
        bne.s tplp_cancelled
template_import_idle:
        jsr wait_frame
        bsr dialog_poll
        bmi.s template_import_idle
tplp_chosen:
        move.w d0,-(sp)
        bsr dialog_close
        bsr dialog_release
        move.w (sp)+,d0
        eori.w #1,d0
        rts
tplp_cancelled:
        moveq #1,d0
        rts

dlg_template_loading:
        dc.w 80,40,UI_SELECT
        dc.l tpl_title,tpl_loading_body
        dc.w -1,-1,0
tpl_loading_body:
        dc.w UI_TEXT,16,98,288,UI_INK,UI_LEFT
        dc.b "Loading the original phase from the game disk.",0
        even
        dc.w UI_END
