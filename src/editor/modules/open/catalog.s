; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Rebuild names only from the qualified directory fingerprint. Neither the
; canonical draft nor the authoring record is scratch. The stage and catalog
; share the reserved overlay tail at different times.
open_catalog:
        clr.w OPN_COUNT
        moveq #2,d2
        bsr storage_read_track
        tst.w d0
        bne .return
        movea.l sensi_track_scratch_pointer,a0
        lea 20(a0),a0
        move.l #6144,d1
        bsr read_crc32
        cmp.l OPN_DIRECTORY_CRC+PCREL(pc),d0
        bne.s .changed
        movea.l sensi_track_scratch_pointer,a4
        lea 52(a4),a4
        moveq #0,d6
        move.w #150,d7
        sub.w OPN_FREE_RECORDS+PCREL(pc),d7
        lea OPN_NAMES+PCREL(pc),a3
.next:
        cmp.w d7,d6
        bhs.s .done
        movea.l a4,a0
        lea STORAGE_CONTEXT+PCREL(pc),a1
        moveq #15,d1
.fold:
        move.b (a0)+,d0
        cmpi.b #'A',d0
        blo.s .copy
        cmpi.b #'Z',d0
        bhi.s .copy
        ori.b #32,d0
.copy:
        move.b d0,(a1)+
        dbf d1,.fold
        lea STORAGE_CONTEXT+PCREL(pc),a0
        cmpi.l #$2E636D69,8(a0)
        bne.s .skip
        bsr read_valid_target
        tst.w d0
        bne.s .skip
        lea STORAGE_CONTEXT+PCREL(pc),a0
        moveq #3,d1
.name:
        move.l (a0)+,(a3)+
        dbf d1,.name
        addq.w #1,OPN_COUNT
.skip:
        lea 32(a4),a4
        addq.w #1,d6
        bra.s .next
.done:
        moveq #0,d0
.return:
        tst.w d0
        rts
.changed:
        moveq #STORAGE_READ_MEDIA,d0
        bra.s .return

; A0=name16. Disk ID is private browser authority, independent of old AUR.
open_request:
        lea STORAGE_CONTEXT+PCREL(pc),a1
        moveq #3,d0
.name:
        move.l (a0)+,(a1)+
        dbf d0,.name
        lea OPN_DISK_ID+PCREL(pc),a0
        moveq #3,d0
.id:
        move.l (a0)+,(a1)+
        dbf d0,.id
        moveq #11,d0
.clear:
        clr.l (a1)+
        dbf d0,.clear
        move.l #4096,STORAGE_CONTEXT+STORAGE_READ_CAPACITY
        rts

; Parse only visible manifests for title/count/OK. Full package validation is
; performed separately for the selected mission, including unselected phases.
; Titles are measured against the title entry limit, so every accepted title
; is listed; the dialog row shows at most 27 characters of it.
open_page:
        move.w OPN_SELECTED+PCREL(pc),d0
        andi.w #$FFFC,d0
        move.w d0,OPN_TOP
        moveq #0,d7
.row:
        move.w d7,d0
        mulu #OPN_ROW_BYTES,d0
        lea OPN_ROWS+PCREL(pc),a4
        adda.w d0,a4
        moveq #16,d0
.clear:
        clr.l (a4)+
        dbf d0,.clear
        lea -OPN_ROW_BYTES(a4),a4
        move.w OPN_TOP+PCREL(pc),d0
        add.w d7,d0
        cmp.w OPN_COUNT+PCREL(pc),d0
        bhs .done
        lsl.w #4,d0
        lea OPN_NAMES+PCREL(pc),a0
        adda.w d0,a0
        bsr.s open_request
        lea STORAGE_CONTEXT+PCREL(pc),a0
        bsr storage_read_entry
        tst.w d0
        bne.s .damaged
        move.l read_directory_crc,d0
        cmp.l OPN_DIRECTORY_CRC+PCREL(pc),d0
        bne .changed
        lea EDITOR_READBACK_BASE+PCREL(pc),a0
        move.l STORAGE_CONTEXT+STORAGE_READ_RESULT_BYTES+PCREL(pc),d0
        lea STORAGE_CONTEXT+PCREL(pc),a1
        moveq #0,d1
        lea EDITOR_SERIAL_WORK_BASE+PCREL(pc),a2
        lea EDITOR_SERIAL_WORK_BASE+512+PCREL(pc),a3
        bsr cfmi_parse
        tst.w d0
        bne.s .damaged
        move.w #1,66(a4)
        move.b EDITOR_SERIAL_WORK_BASE+CFMD_PHASE_COUNT,65(a4)
        lea EDITOR_SERIAL_WORK_BASE+CFMD_TITLE+PCREL(pc),a0
        moveq #0,d0
.length:
        cmpi.b #$FF,(a0,d0.w)
        beq.s .project
        addq.w #1,d0
        cmpi.w #63,d0
        blo.s .length
.project:
        movea.l a4,a1
        moveq #0,d1
        move.w #TITLE_HILL_WIDTH,d2
        moveq #1,d3
        bsr text_preflight
        tst.w d0
        bne.s .fallback
        movea.l a4,a0
.terminate:
        cmpi.b #$FF,(a0)+
        bne.s .terminate
        clr.b -1(a0)
        bra.s .next
.damaged:
        lea .damaged_title(pc),a0
        bra.s .title
.fallback:
        lea .long_title(pc),a0
.title:
        movea.l a4,a1
.copy:
        move.b (a0)+,(a1)+
        bne.s .copy
.next:
        addq.w #1,d7
        cmpi.w #4,d7
        blo .row
.done:
        moveq #0,d0
        rts
.changed:
        moveq #STORAGE_READ_MEDIA,d0
        rts
.damaged_title: dc.b "DAMAGED",0
.long_title: dc.b "LONG TITLE",0
        even
