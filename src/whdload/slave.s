; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Host the 1 MiB Chip-memory executable. Preserve the original chained-sector
; loader and ILBM streaming decoder, replacing the physical track transport.
; Custom files are served from the Custom directory through the fixed
; backend veneer in the shared resident.

        include "whdload_api.i"
        include "fodderc.i"
        include "layout.i"
        include "storage_read.i"
        include "module.i"
        include "ui.i"
        include "fodders.i"
        include "dialog.i"

base:
        moveq #-1,d0
        rts
        dc.b "WHDLOADS"
        dc.w 17
        dc.w WHDLF_ClearMem
        dc.l $100000
        dc.l 0
        dc.w start-base
        dc.w 0,0
        dc.b 0,$59
expmem:
        dc.l DIALOG_EXPMEM_BYTES        ; ws_ExpMem, replaced by its address
        dc.w title-base
        dc.w copyright-base
        dc.w information-base
        dc.w 0
        dc.l 0
        dc.w 0,0
title: dc.b "Cannon Fodder",0
copyright: dc.b "1993 Sensible Software / Virgin",0
information: dc.b "In-Game Level Editor V1.0",10,"by Timo Heimonen",0
        even
resload: dc.l 0

start:
        lea resload(pc),a1
        move.l a0,(a1)
        movea.l a0,a2
        lea main_name(pc),a0
        jsr resload_GetFileSize(a2)
        cmp.l #MAIN_SIZE,d0
        bne wrong_version
        lea main_name(pc),a0
        lea main_base,a1
        jsr resload_LoadFile(a2)
        cmp.l #MAIN_SIZE,d0
        bne wrong_version
        cmpi.l #$4ef9000a,main_base
        bne wrong_version
        cmpi.l #$33fc0003,disk_read_track
        bne wrong_version
        cmpi.l #$4eb90008,hill_wait_call
        bne wrong_version
        cmpi.l #$610002a6,disk_write_track
        bne wrong_version
        lea read_track(pc),a0
        move.w #$4ef9,disk_read_track
        move.l a0,disk_read_track+2
        lea write_track(pc),a0
        move.w #$4ef9,disk_write_track
        move.l a0,disk_write_track+2
        cmpi.w #$4ef9,EDITOR_RESIDENT_BASE+$24
        bne wrong_version
        tst.l EDITOR_RESIDENT_BASE+$26
        bne wrong_version
        lea whd_service_dispatch(pc),a0
        move.l a0,EDITOR_RESIDENT_BASE+$26
        jsr resload_FlushCache(a2)
        jmp main_base

wrong_version:
        pea TDREASON_WRONGVER
        move.l resload(pc),-(sp)
        addq.l #resload_Abort,(sp)
        rts

; Drives 0-2 are Disk.1-3. Drive 3 is the campaign save disk: SaveDisk holds
; its 160 decoded native tracks of 12 sectors, indexed by logical track.
SAVE_DRIVE      equ 3
SAVE_TRACKS     equ 160
SAVE_TRACK_BYTES equ 12*512

; D0.b: linear track; callers can leave other D0 bits set.
; Return the decoded track at disk_scratch+$14.
; Keep the original track reader's A4 result and zero/Z success convention.
read_track:
        movem.l d1-d3/a0-a3,-(sp)
        and.l #$ff,d0
        cmp.w #160,d0
        bhs .error
        move.w d0,disk_current_track
        moveq #0,d2
        move.w disk_drive,d2
        cmp.w #SAVE_DRIVE,d2
        beq .save
        bhi .absent
        addq.w #1,d2
        mulu.w #11*512,d0
        move.l #11*512,d1
        movea.l disk_scratch,a0
        lea $14(a0),a0
        movea.l resload(pc),a2
        jsr resload_DiskLoad(a2)
        tst.l d0
        beq .error
        movem.l (sp)+,d1-d3/a0-a3
        movea.l disk_scratch,a4
        ; A standard-sector track never carries the native magic.
        clr.l 8(a4)
        moveq #0,d0
        rts
.save:
        bsr save_disk_present
        bne .absent
        mulu.w #SAVE_TRACK_BYTES,d0
        move.l d0,d1
        move.l #SAVE_TRACK_BYTES,d0
        lea save_name(pc),a0
        movea.l disk_scratch,a1
        lea $14(a1),a1
        movea.l resload(pc),a2
        jsr resload_LoadFileOffset(a2)
        tst.l d1
        bne .error
        tst.l d0
        beq .error
        movem.l (sp)+,d1-d3/a0-a3
        movea.l disk_scratch,a4
        ; Leave the decoded native header as the original track decoder does:
        ; SOS6 marks a twelve-sector track, followed by its logical track word.
        move.l #$534f5336,8(a4)
        move.w disk_current_track,$12(a4)
        moveq #0,d0
        rts
.absent:
        movem.l (sp)+,d1-d3/a0-a3
        jmp disk_no_media
.error:
        movem.l (sp)+,d1-d3/a0-a3
        jmp disk_read_error

; Replaces sensi_write_track. D0.b: linear track; the decoded track is at
; disk_scratch+$14. Only the save disk is writable: Disk.1-3 return the
; native write-protect error before anything is written.
write_track:
        movem.l d1-d3/a0-a3,-(sp)
        and.l #$ff,d0
        cmp.w #SAVE_TRACKS,d0
        bhs.s .error
        move.w d0,disk_current_track
        cmpi.w #SAVE_DRIVE,disk_drive
        bne.s .protected
        bsr.s save_disk_present
        bne.s .absent
        mulu.w #SAVE_TRACK_BYTES,d0
        move.l d0,d1
        move.l #SAVE_TRACK_BYTES,d0
        lea save_name(pc),a0
        movea.l disk_scratch,a1
        lea $14(a1),a1
        movea.l resload(pc),a2
        jsr resload_SaveFileOffset(a2)
        tst.l d1
        bne.s .error
        tst.l d0
        beq.s .error
        movem.l (sp)+,d1-d3/a0-a3
        movea.l disk_scratch,a4
        moveq #0,d0
        rts
.protected:
        movem.l (sp)+,d1-d3/a0-a3
        jmp disk_write_protected
.absent:
        movem.l (sp)+,d1-d3/a0-a3
        jmp disk_no_media
.error:
        movem.l (sp)+,d1-d3/a0-a3
        jmp disk_read_error

; Z set when SaveDisk exists with its exact size. Preserves D0.
save_disk_present:
        move.l d0,-(sp)
        lea save_name(pc),a0
        movea.l resload(pc),a2
        jsr resload_GetFileSize(a2)
        cmp.l #SAVE_TRACKS*SAVE_TRACK_BYTES,d0
        movem.l (sp)+,d0
        rts

main_name: dc.b "Main.bin",0
save_name: dc.b "SaveDisk",0
        even

; Only the fixed read context may enter the shared file service. Module
; transport separately admits exactly its loader context at IO0, and the text
; service draws only into the target its caller names.
whd_service_dispatch:
        cmpi.w #KEY_STORE_OPERATION,d0
        beq key_store
        cmpi.w #KEY_EVENT_OPERATION,d0
        beq key_event
        cmpi.w #KEY_HOLD_OPERATION,d0
        beq key_hold
        cmpi.w #UI_OPERATION,d0
        beq ui_service
        cmpi.w #DIALOG_OPERATION,d0
        beq dialog_service
        cmpi.w #HILL_OPERATION,d0
        beq hill_service
        cmpi.w #CRC_OPERATION,d0
        beq fs_crc32
        cmpi.w #5,d0
        beq.s .transport
        cmpa.l #EDITOR_IO_BASE+64,a0
        bne.s .invalid
        bsr fs_service
        bra.s .keys
.transport:
        bsr whd_module_transport
.keys:
        ; A key released while WHDLoad ran the OS (listings, loads, writes)
        ; stays held for the game, which then ignores the next press of that
        ; key and keeps scrolling with a held arrow. Return with no key held.
        clr.w native_raw_key
        clr.w native_key_previous
        clr.w native_last_key
        tst.w d0
        rts
.invalid:
        moveq #10,d0
        rts
        include "file_service.s"
        include "module_transport.s"
        include "ui_service.s"
        include "dialog_service.s"
        include "hill_service.s"
        include "key_service.s"
