; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        xdef menu_phase,menu_settings,menu_phase_apply,menu_phase_requalified
        xdef menu_phase_media,menu_phase_inspect

; Nonzero when the settings were opened from the editor menu: Done and
; Cancel then return to the map, otherwise to Mission phases.
MENU_SETTINGS_ORIGIN equ EDITOR_UI_BASE+12

; Internal MENU dialogs retain its existing typed page and exact owner.
; Only the selected CFMD is edited; no phase-list or mapping publication.
menu_settings:
        move.w #1,MENU_SETTINGS_ORIGIN
        bra.s menu_phase_owner
menu_phase:
        clr.w MENU_SETTINGS_ORIGIN
menu_phase_owner:
        bsr menu_owner
        bne menu_fail
        cmpi.l #AUR_PAGE_MENU*65536+AUR_PAGE_NONE,AUR_BASE+AUR_PAGE_KIND
        bne menu_fail
        bsr menu_phase_media
        bne menu_title_error
        bsr phm_begin
        bne menu_title_error
.again:
        clr.w edtr_view_live
        moveq #MENU_DIALOG_PHASE,d0
        moveq #0,d1
        bsr edtr_modal
        tst.w d0
        bmi.s .error
        cmpi.w #1,d0
        beq.s menu_phase_apply
        cmpi.w #3,d0
        bne.s .cancel
        moveq #0,d0
        move.w PHM_FIELD,d0
        bsr phm_title_begin
        bne.s .error
        clr.w edtr_view_live
        moveq #MENU_DIALOG_PHASE_TITLE,d0
        moveq #0,d1
        bsr edtr_modal
        tst.w d0
        bmi.s .error
        bra.s .again
.cancel:
        bsr phm_cancel
        bra.s menu_phase_return
.error:
        bsr phm_cancel
        bra menu_title_error

; edtr_modal has closed its dialog before returning and keeps nothing in
; READBACK. Inspector WORK0..863 overlaps the private metadata snapshots, so
; retain all768 original/draft/AUR bytes in READBACK. Inspection does not
; write READBACK: the file service keeps its state in WORK and the directory
; cache.
menu_phase_apply:
        bsr menu_owner
        bne.s menu_phase_commit_error
        bsr.s menu_phase_inspect
        bne.s menu_phase_commit_error
        bsr.s menu_phase_media
        bne.s menu_phase_commit_error
menu_phase_requalified:
        bsr phm_commit
        tst.w d0
        bmi.s menu_phase_commit_error
menu_phase_return:
        tst.w MENU_SETTINGS_ORIGIN
        beq menu_phase_list
        bra menu_cancel
menu_phase_commit_error:
        bsr phm_cancel
        bra menu_title_error

menu_phase_inspect:
        lea PHM_ORIGINAL,a0
        lea EDITOR_READBACK_BASE,a1
        bsr.s .copy
        clr.l STORAGE_CONTEXT+STORAGE_READ_CANCEL
        lea STORAGE_CONTEXT,a0
        bsr storage_inspect_disk
        move.w d0,d7
        ; Restore unconditionally, including inspection failure and cancellation.
        lea EDITOR_READBACK_BASE,a0
        lea PHM_ORIGINAL,a1
        bsr.s .copy
        move.w d7,d0
        rts
.copy:
        move.w #191,d1
.long:
        move.l (a0)+,(a1)+
        dbf d1,.long
        rts

; Inspect results are useful only for this unchanged drive selection and CFDI.
; Before BEGIN this is MENU's entry inspection, after a cancellation check;
; before COMMIT it is the new inspection after complete modal retirement.
menu_phase_media:
        bsr menu_epoch
        bne.s .return
        moveq #STORAGE_READ_MEDIA,d0
        tst.w AUR_BASE+AUR_DRIVE
        bne.s .return
        cmpi.l #STORAGE_INSPECT_MAGIC,STORAGE_CONTEXT
        bne.s .return
        cmpi.l #1,STORAGE_CONTEXT+STORAGE_READ_READY
        bne.s .return
        lea AUR_BASE+AUR_DISK_ID,a0
        lea STORAGE_CONTEXT+STORAGE_INSPECT_DISK_ID,a1
        moveq #3,d1
.id:
        cmpm.l (a0)+,(a1)+
        bne.s .return
        dbf d1,.id
        moveq #0,d0
.return:
        tst.w d0
        rts

        ifne PHM_OWNER+128-PHM_ORIGINAL-768
        fail "Phase preservation size changed"
        endif
