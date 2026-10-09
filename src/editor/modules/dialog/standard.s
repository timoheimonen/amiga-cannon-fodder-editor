; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Standard dialogs: editor menu, unsaved changes, messages, large change and
; missing terrain graphics. The including module defines EXIT_TEXT (64 bytes)
; and EXIT_NUMBER (32 bytes) in its scratch and includes text.s. With
; DIALOG_LARGE_ONLY set only the large-change confirmation is assembled.
DLG_TOP             equ 52
DLG_HEIGHT          equ 104
DLG_KIND_ASSETS     equ 6

; D7.w dialog kind, D6.w signed status. D0.l=0 open, 10 refused.
dialog_standard_open:
        movem.l d1-d2/a0-a1,-(sp)
        moveq #0,d2
        ifnd DIALOG_LARGE_ONLY
        lea dlg_menu(pc),a0
        tst.w d7
        bne.s .assets
        lea dlg_empty(pc),a1
        btst #1,AUR_BASE+AUR_FLAGS+1
        beq.s .status
        lea dlg_unsaved_status(pc),a1
.status:
        lea EXIT_TEXT,a0
        bsr dialog_copy
        lea dlg_menu(pc),a0
        bra.s .open
.assets:
        lea dlg_assets(pc),a0
        cmpi.w #DLG_KIND_ASSETS,d7
        beq.s .open
        lea dlg_unsaved(pc),a0
        cmpi.w #EDTR_DIALOG_UNSAVED,d7
        bne.s .message
        cmpi.w #1,d6
        bne.s .open
        lea dlg_unsaved_phase(pc),a0
        bra.s .open
.message:
        cmpi.w #EDTR_DIALOG_MESSAGE,d7
        bne.s .large
        lea dlg_messages(pc),a1
.find:
        move.w (a1)+,d0
        beq.s .error
        movea.l (a1)+,a0
        cmp.w d0,d6
        bne.s .find
        bra.s .open
.error:
        bsr.s dialog_status
        lea dlg_error(pc),a0
        bra.s .open
.large:
        endc
        lea dlg_large(pc),a0
.open:
        bsr dialog_open
        movem.l (sp)+,d1-d2/a0-a1
        rts

        ifnd DIALOG_LARGE_ONLY
; "Status n" for D6.w into EXIT_NUMBER.
dialog_status:
        movem.l a0-a1,-(sp)
        lea dlg_status_text(pc),a1
        lea EXIT_NUMBER,a0
        bsr dialog_copy
        move.w d6,d0
        bpl.s .digits
        move.b #'-',(a0)+
        neg.w d0
.digits:
        bsr dialog_number
        movem.l (sp)+,a0-a1
        rts

dlg_messages:
        dc.w EDTR_MARKER_LIMIT
        dc.l dlg_marker_limit
        dc.w OBJECT_LAST_ITEM
        dc.l dlg_last_object
        dc.w OBJECT_NO_ROOM
        dc.l dlg_no_room
        dc.w EDTR_SAVE_FILES
        dc.l dlg_save_files
        dc.w EDTR_SAVE_QUOTA
        dc.l dlg_save_quota
        dc.w EDTR_ASSET_UNPROVED
        dc.l dlg_unavailable
        dc.w 0

; Two columns split near X 152, rows every 20 lines from Y 72; buttons of
; the lower dialogs on Y 128. Settings and Close share the last row. The
; menu's title strip has a second line for the version and the author; the
; panel grows upwards for it, so the buttons keep their places.
DLG_MENU_TOP        equ DLG_TOP-10
dlg_menu:
        dc.w DLG_MENU_TOP,134,UI_SELECT
        dc.l dlg_menu_title,dlg_menu_body
        dc.w 9,0,10
        dc.w 20,72,128,18,4,UI_NORMAL
        dc.l dlg_new_label
        dc.w 156,72,128,18,5,UI_NORMAL
        dc.l dlg_template_label
        dc.w 20,92,128,18,6,UI_NORMAL
        dc.l dlg_open_label
        dc.w 156,92,128,18,1,UI_NORMAL
        dc.l dlg_save_label
        dc.w 20,112,128,18,7,UI_NORMAL
        dc.l dlg_save_as_label
        dc.w 156,112,128,18,3,UI_NORMAL
        dc.l dlg_resize_label
        dc.w 20,132,128,18,8,UI_NORMAL
        dc.l dlg_phases_label
        dc.w 156,132,128,18,2,UI_NORMAL
        dc.l dlg_exit_hill_label
        dc.w 20,152,128,18,9,UI_NORMAL
        dc.l dlg_settings_label
        dc.w 156,152,128,18,0,UI_NORMAL
        dc.l dlg_close_label
dlg_menu_body:
        dc.w UI_RECT,0,DLG_MENU_TOP+13,320,10,UI_SELECT
        dc.w UI_TEXT_AT,148,DLG_MENU_TOP+4,148,UI_ACCENT,UI_RIGHT
        dc.l EXIT_TEXT
        dc.w UI_TEXT,8,DLG_MENU_TOP+14,288,UI_LIGHT,UI_LEFT
        dc.b "V1.1 by Timo Heimonen (timo.heimonen@proton.me)",0
        even
        dc.w UI_END

dlg_unsaved:
        dc.w DLG_TOP,DLG_HEIGHT,UI_SELECT
        dc.l dlg_unsaved_title,dlg_unsaved_body
        dc.w 0,0,3
        dc.w 12,128,88,14,1,UI_NORMAL
        dc.l dlg_save_label
        dc.w 108,128,88,14,2,UI_NORMAL
        dc.l dlg_discard_label
        dc.w 204,128,88,14,0,UI_NORMAL
        dc.l dlg_cancel_label
dlg_unsaved_body:
        dc.w UI_TEXT,16,76,288,UI_INK,UI_LEFT
        dc.b "This mission has changes that are not saved.",0
        even
        dc.w UI_TEXT,16,88,288,UI_INK,UI_LEFT
        dc.b "Save them before you continue?",0
        even
        dc.w UI_END

dlg_unsaved_phase:
        dc.w DLG_TOP,DLG_HEIGHT,UI_SELECT
        dc.l dlg_phase_title,dlg_phase_body
        dc.w 0,0,2
        dc.w 12,128,88,14,1,UI_NORMAL
        dc.l dlg_save_label
        dc.w 204,128,88,14,0,UI_NORMAL
        dc.l dlg_cancel_label
dlg_phase_body:
        dc.w UI_TEXT,16,76,288,UI_INK,UI_LEFT
        dc.b "Save the current changes before a new",0
        even
        dc.w UI_TEXT,16,88,288,UI_INK,UI_LEFT
        dc.b "phase is added to this mission.",0
        even
        dc.w UI_END

dlg_assets:
        dc.w DLG_TOP,DLG_HEIGHT,UI_ERROR
        dc.l dlg_assets_title,dlg_assets_body
        dc.w 2,0,3
        dc.w 12,128,88,14,1,UI_NORMAL
        dc.l dlg_save_label
        dc.w 108,128,88,14,2,UI_NORMAL
        dc.l dlg_exit_label
        dc.w 204,128,88,14,0,UI_NORMAL
        dc.l dlg_retry_label
dlg_assets_body:
        dc.w UI_TEXT,16,76,288,UI_INK,UI_LEFT
        dc.b "Some graphics of this terrain could not be",0
        even
        dc.w UI_TEXT,16,88,288,UI_INK,UI_LEFT
        dc.b "loaded. Save your work, exit to the hill",0
        even
        dc.w UI_TEXT,16,100,288,UI_INK,UI_LEFT
        dc.b "or try loading them again.",0
        even
        dc.w UI_END

dlg_marker_limit:
        dc.w DLG_TOP,DLG_HEIGHT,UI_SELECT
        dc.l dlg_limit_title,dlg_limit_body
        dc.w 0,0,1
        dc.w 116,128,72,14,0,UI_NORMAL
        dc.l dlg_ok_label
dlg_limit_body:
        dc.w UI_TEXT,16,76,288,UI_INK,UI_LEFT
        dc.b "A phase can have at most ten markers.",0
        even
        dc.w UI_END

dlg_last_object:
        dc.w DLG_TOP,DLG_HEIGHT,UI_SELECT
        dc.l dlg_object_title,dlg_object_body
        dc.w 0,0,1
        dc.w 116,128,72,14,0,UI_NORMAL
        dc.l dlg_ok_label
dlg_object_body:
        dc.w UI_TEXT,16,76,288,UI_INK,UI_LEFT
        dc.b "A phase must keep at least one object.",0
        even
        dc.w UI_END

dlg_no_room:
        dc.w DLG_TOP,DLG_HEIGHT,UI_SELECT
        dc.l dlg_no_room_title,dlg_no_room_body
        dc.w 0,0,1
        dc.w 116,128,72,14,0,UI_NORMAL
        dc.l dlg_ok_label
dlg_no_room_body:
        dc.w UI_TEXT,16,76,288,UI_INK,UI_LEFT
        dc.b "This phase has no room for the object.",0
        even
        dc.w UI_TEXT,16,88,288,UI_INK,UI_LEFT
        dc.b "A phase holds at most 43 object parts,",0
        even
        dc.w UI_TEXT,16,100,288,UI_INK,UI_LEFT
        dc.b "30 of them for people and vehicles, and",0
        even
        dc.w UI_TEXT,16,112,288,UI_INK,UI_LEFT
        dc.b "at most eight troops.",0
        even
        dc.w UI_END

dlg_save_files:
        dc.w DLG_TOP,DLG_HEIGHT,UI_ERROR
        dc.l dlg_not_saved_title,dlg_files_body
        dc.w 0,0,1
        dc.w 116,128,72,14,0,UI_NORMAL
        dc.l dlg_ok_label
dlg_files_body:
        dc.w UI_TEXT,16,76,288,UI_INK,UI_LEFT
        dc.b "Custom already holds 150 files, the most it",0
        even
        dc.w UI_TEXT,16,88,288,UI_INK,UI_LEFT
        dc.b "can hold. Delete missions you no longer need",0
        even
        dc.w UI_TEXT,16,100,288,UI_INK,UI_LEFT
        dc.b "and save again.",0
        even
        dc.w UI_TEXT,16,112,288,UI_OK,UI_LEFT
        dc.b "Your changes are still open.",0
        even
        dc.w UI_END

dlg_save_quota:
        dc.w DLG_TOP,DLG_HEIGHT,UI_ERROR
        dc.l dlg_not_saved_title,dlg_quota_body
        dc.w 0,0,1
        dc.w 116,128,72,14,0,UI_NORMAL
        dc.l dlg_ok_label
dlg_quota_body:
        dc.w UI_TEXT,16,76,288,UI_INK,UI_LEFT
        dc.b "The Custom directory has no room left.",0
        even
        dc.w UI_TEXT,16,88,288,UI_INK,UI_LEFT
        dc.b "Delete missions you no longer need and",0
        even
        dc.w UI_TEXT,16,100,288,UI_INK,UI_LEFT
        dc.b "save again.",0
        even
        dc.w UI_TEXT,16,112,288,UI_OK,UI_LEFT
        dc.b "Your changes are still open.",0
        even
        dc.w UI_END

dlg_unavailable:
        dc.w DLG_TOP,DLG_HEIGHT,UI_SELECT
        dc.l dlg_unavailable_title,dlg_unavailable_body
        dc.w 0,0,1
        dc.w 116,128,72,14,0,UI_NORMAL
        dc.l dlg_ok_label
dlg_unavailable_body:
        dc.w UI_TEXT,16,76,288,UI_INK,UI_LEFT
        dc.b "This action is not available here.",0
        even
        dc.w UI_END

dlg_error:
        dc.w DLG_TOP,DLG_HEIGHT,UI_ERROR
        dc.l dlg_error_title,dlg_error_body
        dc.w 0,0,1
        dc.w 116,128,72,14,0,UI_NORMAL
        dc.l dlg_ok_label
dlg_error_body:
        dc.w UI_TEXT,16,76,288,UI_INK,UI_LEFT
        dc.b "The editor could not complete this action.",0
        even
        dc.w UI_TEXT_AT,16,100,288,UI_DIM,UI_LEFT
        dc.l EXIT_NUMBER
        dc.w UI_END
        endc

dlg_large:
        dc.w DLG_TOP,DLG_HEIGHT,UI_SELECT
        dc.l dlg_large_title,dlg_large_body
        dc.w 1,0,2
        dc.w 20,128,128,14,1,UI_NORMAL
        dc.l dlg_continue_label
        dc.w 156,128,128,14,0,UI_NORMAL
        dc.l dlg_cancel_label
dlg_large_body:
        dc.w UI_TEXT,16,76,288,UI_INK,UI_LEFT
        dc.b "This change is too large to undo.",0
        even
        dc.w UI_TEXT,16,88,288,UI_INK,UI_LEFT
        dc.b "Continue and clear the undo history?",0
        even
        dc.w UI_END

dlg_large_title: dc.b "Large change",0
dlg_continue_label: dc.b "_Continue",0
dlg_cancel_label: dc.b "Cancel",0
        ifnd DIALOG_LARGE_ONLY
dlg_menu_title: dc.b "Editor menu",0
dlg_unsaved_status: dc.b "Unsaved changes",0
dlg_empty: dc.b 0
dlg_new_label: dc.b "_New mission...",0
dlg_template_label: dc.b "_Template...",0
dlg_open_label: dc.b "_Open mission...",0
dlg_save_label: dc.b "_Save",0
dlg_save_as_label: dc.b "Save _as...",0
dlg_resize_label: dc.b "_Resize map...",0
dlg_phases_label: dc.b "Mission _phases...",0
dlg_exit_hill_label: dc.b "E_xit to hill",0
dlg_settings_label: dc.b "S_ettings...",0
dlg_close_label: dc.b "_Close",0
dlg_unsaved_title: dc.b "Unsaved changes",0
dlg_discard_label: dc.b "_Don't save",0
dlg_phase_title: dc.b "Save before adding a phase",0
dlg_assets_title: dc.b "Terrain graphics missing",0
dlg_exit_label: dc.b "E_xit",0
dlg_retry_label: dc.b "_Retry",0
dlg_ok_label: dc.b "_OK",0
dlg_limit_title: dc.b "Marker limit",0
dlg_object_title: dc.b "Last object",0
dlg_no_room_title: dc.b "Object not placed",0
dlg_not_saved_title: dc.b "Could not save",0
dlg_unavailable_title: dc.b "Not available",0
dlg_error_title: dc.b "Editor error",0
dlg_status_text: dc.b "Status ",0
        endc
        even
