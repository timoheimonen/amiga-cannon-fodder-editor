; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

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
        include "../editor/state.i"
        include "ui.i"
        include "dialog.i"
AUR_VALIDATE_ONLY equ 1
OPN_DRIVE equ EDITOR_UI_BASE
OPN_SELECTED equ EDITOR_UI_BASE+2
OPN_COUNT equ EDITOR_UI_BASE+4
OPN_TOP equ EDITOR_UI_BASE+6
OPN_DISK_ID equ EDITOR_UI_BASE+8
OPN_DISK_NAME equ EDITOR_UI_BASE+24
OPN_FREE_BYTES equ EDITOR_UI_BASE+56
OPN_FREE_RECORDS equ EDITOR_UI_BASE+60
OPN_DIRECTORY_CRC equ EDITOR_UI_BASE+64
OPN_STATUS equ EDITOR_UI_BASE+68
OPN_NAME equ EDITOR_UI_BASE+72
OPN_TEXT equ EDITOR_UI_BASE+160
; Row and field of the last click on a mission.
OPN_CLICK equ EDITOR_UI_BASE+240
OPN_NAMES equ OPEN_STAGE_MANIFEST
OPN_ROWS equ OPN_NAMES+2400
OPN_ROW_BYTES equ 68

        section .text,code
        xdef open_start,open_entry,open_end,open_owner
        xdef open_before_commit,open_published,open_browser_ready,open_before_stage
; Fixed load-base anchor: X+PCREL(pc) reads the absolute address X
; PC-relatively from module code.
module_pc_base:
PCREL   equ module_pc_base-EDITOR_MODULE_BASE
open_start:
        dc.l MODULE_MAGIC
        dc.w MODULE_ABI,MODULE_HEADER_BYTES
        dc.l OPEN_MODULE_ID,EDITOR_MODULE_BASE
        dc.l open_end-open_start,open_entry-open_start,0,0
open_entry:
        movem.l d1-d7/a0-a6,-(sp)
        move.w #REQ_ACTION_UNENTERED,EDITOR_SESSION_BASE+REQ_ACTION
        cmpi.w #MODULE_ABI,d0
        bne open_bad
        cmpa.l #EDITOR_SESSION_BASE,a0
        bne open_bad
        bsr open_owner
        bne open_return
        lea EDITOR_UI_BASE+PCREL(pc),a0
        moveq #63,d0
.clear:
        clr.l (a0)+
        dbf d0,.clear
        move.w AUR_BASE+AUR_DRIVE,OPN_DRIVE
open_refresh:
        ; Discard the previous catalog authority before inspecting the directory again.
        ; Failed inspection must not display its name, identity or capacity.
        lea OPN_SELECTED+PCREL(pc),a0
        moveq #16,d0
.clear_disk:
        clr.l (a0)+
        dbf d0,.clear_disk
        move.w #-1,OPN_STATUS
        moveq #STORAGE_READ_INVALID,d0
        tst.w OPN_DRIVE
        bne.s open_browser_ready
        clr.l STORAGE_CONTEXT+STORAGE_READ_CANCEL
        lea STORAGE_CONTEXT+PCREL(pc),a0
        bsr storage_inspect_disk
        tst.w d0
        bne.s open_browser_ready
        lea STORAGE_CONTEXT+8+PCREL(pc),a0
        lea OPN_DISK_ID+PCREL(pc),a1
        moveq #14,d0
.inspect:
        move.l (a0)+,(a1)+
        dbf d0,.inspect
        bsr open_catalog
        bne.s open_catalog_failed
        ; A mission is checked when it is opened, not when it is selected.
        clr.w OPN_STATUS
        bsr open_page
        beq.s open_browser_ready
open_catalog_failed:
        clr.w OPN_COUNT
        move.w #-1,OPN_STATUS
open_browser_ready:
        moveq #0,d0
        moveq #0,d1
        bsr edtr_modal
        tst.w d0
        bmi open_failed
        beq open_cancel
        cmpi.w #3,d0
        beq.s open_refresh
        cmpi.w #4,d0
        beq open_new
        cmpi.w #5,d0
        beq open_files
        ; Open stages and checks the whole package of the selection.
        move.w OPN_SELECTED+PCREL(pc),d0
        lsl.w #4,d0
        lea OPN_NAMES+PCREL(pc),a0
        adda.w d0,a0
        lea OPN_NAME+PCREL(pc),a1
        moveq #3,d0
.name:
        move.l (a0)+,(a1)+
        dbf d0,.name
        bsr open_candidate
        beq.s .staged
        ; A mission that cannot be opened stays selected, marked Blocked. The
        ; candidate shared its space with the catalog, so rebuild that.
        bsr open_catalog
        bne.s open_catalog_failed
        bsr open_page
        bne.s open_catalog_failed
        move.w #-1,OPN_STATUS
        bra.s open_browser_ready
.staged:
        bsr open_owner
        bne open_failed
open_before_commit:
        lea OPEN_STAGE_MAP+PCREL(pc),a0
        lea map_file_buffer,a1
        moveq #0,d0
        move.w OPEN_STAGE_METADATA+CFMD_MAP_BYTES+PCREL(pc),d0
        bsr os_copy
        lea OPEN_STAGE_SPT+PCREL(pc),a0
        lea EDITOR_SPT_BASE+PCREL(pc),a1
        move.w #EDITOR_SPT_BYTES,d0
        bsr os_copy
        lea OPEN_STAGE_METADATA+PCREL(pc),a0
        lea EDITOR_METADATA_BASE+PCREL(pc),a1
        move.w #EDITOR_METADATA_BYTES,d0
        bsr os_copy
        lea EDITOR_UNDO_BASE+PCREL(pc),a0
        move.w #(EDITOR_UNDO_BYTES+EDITOR_MANIFEST_BYTES)/4-1,d0
.history:
        clr.l (a0)+
        dbf d0,.history
        lea OPEN_STAGE_MANIFEST+PCREL(pc),a0
        lea EDITOR_MANIFEST_BASE,a1
        move.w OPEN_STAGE_METADATA+CFMD_MANIFEST_BYTES+PCREL(pc),d0
        bsr os_copy
        lea AUR_BASE,a5
        lea EDITOR_METADATA_BASE+PCREL(pc),a6
        lea AUR_SOURCE_BYTES(a5),a0
        moveq #15,d0
.tail:
        clr.l (a0)+
        dbf d0,.tail
        move.w OPN_DRIVE,AUR_DRIVE(a5)
        lea OPN_DISK_ID+PCREL(pc),a0
        lea AUR_DISK_ID(a5),a1
        moveq #11,d0
.disk:
        move.l (a0)+,(a1)+
        dbf d0,.disk
        moveq #0,d0
        move.w CFMD_MANIFEST_BYTES(a6),d0
        move.l d0,AUR_SOURCE_BYTES(a5)
        move.l CFMD_MANIFEST_CRC(a6),AUR_SOURCE_CRC(a5)
        move.l CFMD_ID(a6),AUR_SOURCE_ID(a5)
        move.w CFMD_REVISION(a6),AUR_SOURCE_REVISION(a5)
        lea CFMD_MANIFEST_NAME(a6),a0
        lea AUR_SOURCE_NAME(a5),a1
        moveq #3,d0
.source:
        move.l (a0)+,(a1)+
        dbf d0,.source
        move.b CFMD_PHASE_COUNT(a6),AUR_PHASE_COUNT(a5)
        move.w #-1,AUR_OBJECT_INDEX(a5)
        lea AUR_PHASE_MAP(a5),a0
        moveq #0,d0
.mapping:
        moveq #-1,d1
        cmp.b AUR_PHASE_COUNT(a5),d0
        bhs.s .unused
        move.b d0,d1
.unused:
        move.b d1,(a0)+
        addq.w #1,d0
        cmpi.w #6,d0
        blo.s .mapping
        move.w #AUR_HAS_SOURCE|AUR_PAGE_PENDING,AUR_FLAGS(a5)
        clr.l AUR_CAMERA_X(a5)
        clr.w AUR_TOOL(a5)
        move.w #AUR_PAGE_OPEN,AUR_PAGE_KIND(a5)
        move.w #AUR_PAGE_NONE,AUR_PAGE_CANDIDATE(a5)
        move.w #EDTR_OPEN,AUR_ORIGIN(a5)
        clr.l STORAGE_READY
open_published:
        moveq #3,d7
        bra.s open_finish
; New keeps the current draft and directory until the ordinary guarded picker commits.
open_new:
        bsr open_owner
        bne open_blocked
        move.l #AUR_PAGE_MENU*$10000+AUR_CONTINUE_NEW,AUR_BASE+AUR_PAGE_KIND
        lea open_menu_request(pc),a0
        bra.s open_dispatch
open_files:
        bsr open_owner
        bne open_blocked
        move.w #FILES_REQUEST_TAG,SAVE_CONTEXT
        move.w OPN_DRIVE+PCREL(pc),SAVE_CONTEXT+2
        ; Files starts at the mission selected here.
        lea SAVE_CONTEXT+4,a1
        moveq #3,d0
.none:
        clr.l (a1)+
        dbf d0,.none
        tst.w OPN_COUNT
        beq.s .request
        move.w OPN_SELECTED+PCREL(pc),d0
        lsl.w #4,d0
        lea OPN_NAMES+PCREL(pc),a0
        adda.w d0,a0
        lea SAVE_CONTEXT+4,a1
        moveq #3,d0
.name:
        move.l (a0)+,(a1)+
        dbf d0,.name
.request:
        move.w #AUR_PAGE_FILES,AUR_BASE+AUR_PAGE_KIND
        lea open_files_request(pc),a0
        bra.s open_dispatch
open_cancel:
        moveq #0,d7
        bra.s open_finish
open_failed:
        moveq #EDTR_VISUAL_ERROR,d7
open_finish:
        bsr.s open_owner
        bne.s open_blocked
        move.w d7,EDITOR_SESSION_BASE+REQ_LAST_RESULT
        move.l #OPEN_MODULE_ID,EDITOR_SESSION_BASE+REQ_RESULT_ID
        lea open_editor_request(pc),a0
open_dispatch:
        lea EDITOR_SESSION_BASE+REQ_NAME+PCREL(pc),a1
        moveq #5,d1
.request:
        move.l (a0)+,(a1)+
        dbf d1,.request
        move.w #REQ_ACTION_DISPATCH,EDITOR_SESSION_BASE+REQ_ACTION
        moveq #0,d0
open_return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
open_bad:
        moveq #EDTR_STATE_ERROR,d0
        bra.s open_return
open_blocked:
        jsr wait_frame
        bra.s open_blocked
open_candidate:
        lea OPN_NAME+PCREL(pc),a0
        bsr open_request
        lea STORAGE_CONTEXT+PCREL(pc),a0
        moveq #0,d0
open_before_stage:
        bra open_stage
open_owner:
        bsr aur_validate
        bne.s .return
        lea AUR_BASE,a0
        moveq #AUR_ERROR_REQUEST,d0
        btst #3,AUR_FLAGS+1(a0)
        beq.s .return
        cmpi.w #AUR_PAGE_OPEN,AUR_PAGE_KIND(a0)
        bne.s .return
        cmpi.w #AUR_PAGE_NONE,AUR_PAGE_CANDIDATE(a0)
        bne.s .return
        tst.w AUR_TRANSPORT_STATUS(a0)
        bne.s .return
        tst.l EDITOR_SESSION_BASE+REQ_RESULT_ID
        bne.s .return
        tst.w EDITOR_SESSION_BASE+REQ_LAST_RESULT
        bne.s .return
        moveq #0,d0
.return:
        tst.w d0
        rts
open_files_request:
        dc.b "cf_files.mod",0,0,0,0
        dc.l FILES_MODULE_ID,EDITOR_SERIALIZER_BYTES
open_menu_request:
        dc.b "cf_menu.mod",0,0,0,0,0
        dc.l MENU_MODULE_ID,EDITOR_SERIALIZER_BYTES
open_editor_request:
        dc.b "cf_editor.mod",0,0,0
        dc.l EDTR_MODULE_ID,EDITOR_SERIALIZER_BYTES
        include "catalog.s"
DIALOG_LIST_CLICKS equ 1
        include "dialog.s"
        include "../dialog/dialog.s"
        include "stage.s"
        include "../editor/page_bounds.s"
        include "../editor/aur.s"
        include "../controller/text.s"
        include "../storage/read.s"
        include "../storage/manifest.s"
        include "../storage/payload.s"
open_end:
        ifgt open_end-open_start-(EDITOR_SERIALIZER_BYTES-OPEN_RESERVED_BYTES)
        fail "Open code overlaps reserved candidate data"
        endif
