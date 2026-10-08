; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; WHD raw CFMO transport. A0=EDITOR_IO_BASE, with NAME[16],ID.l,CAPACITY.l.
; Writes only SIZE.l at+24, private+32..63 (payload CRC at+40), the requested
; module bank and the shared Slave ListFiles buffer. Does not touch
; WORK/READBACK/Undo/AUR. D0=status, other registers preserved. The resident
; validates the CFMO header and compares the payload CRC before entry.
;
; The first load checks the whole Custom directory: listing, names, case-
; folded duplicates, CFEDITOR and CFSDISK, and the marker before and after
; loading. Later loads trust that check and load the module by name until
; the file service clears whd_directory_checked (any write or delete, and any
; failed operation); a load that goes wrong falls back to the full check,
; which reports the failure as before. The payload CRC of each module is
; computed on its first load after a full check; when it matches the module
; header, the module's name, size and CRC are remembered, and later loads of
; it publish that CRC without reading the payload again.
WHD_MODULE_ENTRIES equ 20
WHD_ENTRY_SIZE  equ 16
WHD_ENTRY_CRC   equ 20
WHD_ENTRY_BYTES equ 24
WHD_MODULE_MARKER_CRC equ EDITOR_IO_BASE+32
WHD_MODULE_COUNT equ EDITOR_IO_BASE+36
WHD_MODULE_FOUND equ EDITOR_IO_BASE+38
whd_module_transport:
        movem.l d1-d7/a0-a6,-(sp)
        moveq #10,d0
        cmpa.l #EDITOR_IO_BASE,a0
        bne whd_module_return
        clr.l EDITOR_IO_BASE+MODULE_IO_SIZE
        move.l MODULE_IO_CAPACITY(a0),d1
        cmpi.l #EDITOR_MODULE_BYTES,d1
        beq.s .capacity
        cmpi.l #EDITOR_SERIALIZER_BYTES,d1
        bne whd_module_return
.capacity:
        tst.b (a0)
        beq whd_module_return
        moveq #14,d5
.name:
        move.b (a0)+,d0
        beq.s .padding
        bsr fs_valid_character
        bne whd_module_invalid
        dbf d5,.name
        bra whd_module_invalid
.padding:
        lea EDITOR_IO_BASE+16,a1
.zeros:
        cmpa.l a1,a0
        bhs.s .admitted
        tst.b (a0)+
        bne whd_module_invalid
        bra.s .zeros
.admitted:
        lea whd_directory_checked(pc),a0
        tst.b (a0)
        bne whd_module_cached
whd_module_list:
        ; A full check forgets every remembered module.
        lea whd_module_count(pc),a0
        clr.w (a0)
        lea fs_names(pc),a0
        move.w #599,d1
.clear: clr.l (a0)+
        dbf d1,.clear
        lea fs_directory_name(pc),a0
        lea fs_names(pc),a1
        move.l #2400,d0
        movea.l resload(pc),a2
        jsr resload_ListFiles(a2)
        tst.l d1
        bne whd_module_media
        tst.l d0
        beq whd_module_media
        cmpi.l #150,d0
        bhi whd_module_media
        move.w d0,WHD_MODULE_COUNT
        clr.w WHD_MODULE_FOUND
        lea fs_names(pc),a4
        moveq #0,d6
.record:
        movea.l a4,a3
        moveq #14,d5
        tst.b (a3)
        beq whd_module_corrupt
.char:
        lea fs_names_end(pc),a0
        cmpa.l a0,a3
        bhs whd_module_corrupt
        move.b (a3)+,d0
        beq.s .duplicates
        bsr fs_valid_character
        bne whd_module_corrupt
        dbf d5,.char
        bra whd_module_corrupt
.duplicates:
        ; Earlier records were bounded above; compare before moving to their
        ; nextNUL. A folded duplicate is rejected even if unrelated to target.
        lea fs_names(pc),a5
        move.w d6,d7
        beq.s .selected
.prior:
        movea.l a4,a0
        movea.l a5,a1
        bsr fs_compare
        beq whd_module_corrupt
.next_prior:
        tst.b (a5)+
        bne.s .next_prior
        subq.w #1,d7
        bne.s .prior
.selected:
        movea.l a4,a0
        lea fs_campaign_name(pc),a1
        bsr fs_compare
        beq whd_module_media
        movea.l a4,a0
        lea fs_marker_name(pc),a1
        bsr fs_compare
        bne.s .target
        cmpi.l #$43464544,(a4)
        bne whd_module_media
        cmpi.l #$49544f52,4(a4)
        bne whd_module_media
        bset #1,WHD_MODULE_FOUND+1
.target:
        movea.l a4,a0
        lea EDITOR_IO_BASE,a1
        bsr fs_compare
        bne.s .next
        bset #0,WHD_MODULE_FOUND+1
.next:
        movea.l a3,a4
        addq.w #1,d6
        cmp.w WHD_MODULE_COUNT,d6
        bne .record
        cmpi.w #3,WHD_MODULE_FOUND
        bne whd_module_absent
        bsr whd_module_identity
        bne whd_module_return
        move.l d1,WHD_MODULE_MARKER_CRC
        bsr whd_module_path
        lea fs_names+64(pc),a0
        movea.l resload(pc),a2
        jsr resload_GetFileSize(a2)
        cmpi.l #MODULE_HEADER_BYTES+2,d0
        blo whd_module_size
        cmp.l EDITOR_IO_BASE+MODULE_IO_CAPACITY,d0
        bhi whd_module_size
        btst #0,d0
        bne whd_module_size
        move.l d0,EDITOR_IO_BASE+MODULE_IO_SIZE
        moveq #0,d1
        lea fs_names+64(pc),a0
        lea EDITOR_MODULE_BASE,a1
        jsr resload_LoadFileOffset(a2)
        tst.l d1
        bne whd_module_absent
        tst.l d0
        beq whd_module_absent
        lea fs_names+64(pc),a0
        jsr resload_GetFileSize(a2)
        cmp.l EDITOR_IO_BASE+MODULE_IO_SIZE,d0
        bne whd_module_media
        bsr whd_module_identity
        bne whd_module_return
        cmp.l WHD_MODULE_MARKER_CRC,d1
        bne whd_module_media
        ; The resident compares this table CRC with the module header.
whd_module_crc:
        lea EDITOR_MODULE_BASE+MODULE_HEADER_BYTES,a0
        move.l EDITOR_IO_BASE+MODULE_IO_SIZE,d1
        subi.l #MODULE_HEADER_BYTES,d1
        bsr fs_crc32
        move.l d0,EDITOR_IO_BASE+MODULE_IO_PAYLOAD_CRC
        cmp.l EDITOR_MODULE_BASE+MODULE_CRC_OFFSET,d0
        bne.s .checked
        bsr.s whd_module_remember
.checked:
        lea whd_directory_checked(pc),a0
        st (a0)
        moveq #0,d0
whd_module_return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
whd_module_invalid: moveq #10,d0
        bra.s whd_module_return
whd_module_media: moveq #11,d0
        bra.s whd_module_return
whd_module_corrupt: moveq #12,d0
        bra.s whd_module_return
whd_module_absent: moveq #3,d0
        bra.s whd_module_return
whd_module_size: moveq #15,d0
        bra.s whd_module_return

; Remember the module just loaded: name, size and payload CRC, while there is
; room. Uses D0-D1/A0-A1.
whd_module_remember:
        lea whd_module_count(pc),a1
        move.w (a1),d1
        cmpi.w #WHD_MODULE_ENTRIES,d1
        bhs.s .return
        addq.w #1,(a1)
        mulu #WHD_ENTRY_BYTES,d1
        lea whd_module_entries(pc),a0
        adda.w d1,a0
        lea EDITOR_IO_BASE,a1
        move.l (a1)+,(a0)+
        move.l (a1)+,(a0)+
        move.l (a1)+,(a0)+
        move.l (a1)+,(a0)+
        move.l EDITOR_IO_BASE+MODULE_IO_SIZE,(a0)+
        move.l EDITOR_IO_BASE+MODULE_IO_PAYLOAD_CRC,(a0)
.return:
        rts

; A3 = the remembered entry of the requested name, or 0. Uses D0-D1.
whd_module_find:
        lea whd_module_entries(pc),a3
        move.w whd_module_count(pc),d1
        bra.s .test
.entry:
        move.l (a3),d0
        cmp.l EDITOR_IO_BASE,d0
        bne.s .next
        move.l 4(a3),d0
        cmp.l EDITOR_IO_BASE+4,d0
        bne.s .next
        move.l 8(a3),d0
        cmp.l EDITOR_IO_BASE+8,d0
        bne.s .next
        move.l 12(a3),d0
        cmp.l EDITOR_IO_BASE+12,d0
        beq.s .return
.next:
        lea WHD_ENTRY_BYTES(a3),a3
.test:
        dbf d1,.entry
        suba.l a3,a3
.return:
        rts

; Load the module by name after an earlier full check: a remembered module
; with its remembered size and CRC, another one with its size and a fresh
; CRC. Anything unexpected clears the check and repeats it, which reports
; the failure.
whd_module_cached:
        bsr whd_module_path
        movea.l resload(pc),a2
        bsr.s whd_module_find
        move.l a3,d0
        beq.s .measure
        move.l WHD_ENTRY_SIZE(a3),d0
        cmp.l EDITOR_IO_BASE+MODULE_IO_CAPACITY,d0
        bhi.s .full
        move.l d0,EDITOR_IO_BASE+MODULE_IO_SIZE
        moveq #0,d1
        lea fs_names+64(pc),a0
        lea EDITOR_MODULE_BASE,a1
        jsr resload_LoadFileOffset(a2)
        tst.l d1
        bne.s .full
        tst.l d0
        beq.s .full
        move.l WHD_ENTRY_CRC(a3),EDITOR_IO_BASE+MODULE_IO_PAYLOAD_CRC
        moveq #0,d0
        bra whd_module_return
.measure:
        lea fs_names+64(pc),a0
        jsr resload_GetFileSize(a2)
        cmpi.l #MODULE_HEADER_BYTES+2,d0
        blo.s .full
        cmp.l EDITOR_IO_BASE+MODULE_IO_CAPACITY,d0
        bhi.s .full
        btst #0,d0
        bne.s .full
        move.l d0,EDITOR_IO_BASE+MODULE_IO_SIZE
        moveq #0,d1
        lea fs_names+64(pc),a0
        lea EDITOR_MODULE_BASE,a1
        jsr resload_LoadFileOffset(a2)
        tst.l d1
        bne.s .full
        tst.l d0
        bne whd_module_crc
.full:
        clr.l EDITOR_IO_BASE+MODULE_IO_SIZE
        lea whd_directory_checked(pc),a0
        sf (a0)
        bra whd_module_list

whd_module_path:
        lea fs_names+64(pc),a1
        move.l #$43757374,(a1)+
        move.w #$6f6d,(a1)+
        move.b #'/',(a1)+
        lea EDITOR_IO_BASE,a0
        moveq #15,d1
.copy:  move.b (a0)+,(a1)+
        beq.s .return
        dbf d1,.copy
.return: rts

; D0=status, D1=CRC of complete64-byte CFDI. No game scratch beyond IO.
whd_module_identity:
        lea whd_marker_path(pc),a0
        movea.l resload(pc),a2
        jsr resload_GetFileSize(a2)
        cmpi.l #64,d0
        bne .media
        moveq #0,d1
        lea whd_marker_path(pc),a0
        lea fs_names(pc),a1
        jsr resload_LoadFileOffset(a2)
        tst.l d1
        bne .media
        tst.l d0
        beq .media
        lea fs_names(pc),a4
        cmpi.l #$43464449,(a4)
        bne .media
        cmpi.l #$00010010,4(a4)
        bne .media
        cmpi.l #48,8(a4)
        bne .media
        lea 16(a4),a0
        moveq #48,d1
        bsr fs_crc32
        cmp.l 12(a4),d0
        bne .media
        move.l 16(a4),d0
        or.l 20(a4),d0
        or.l 24(a4),d0
        or.l 28(a4),d0
        beq .media
        lea 32(a4),a0
        moveq #31,d1
        moveq #0,d2
        moveq #0,d3
.char:  move.b (a0)+,d0
        tst.w d2
        bne.s .pad
        tst.b d0
        beq.s .zero
        cmpi.b #32,d0
        blo .media
        cmpi.b #126,d0
        bhi .media
        addq.w #1,d3
        bra.s .next
.zero:  moveq #1,d2
.pad:   tst.b d0
        bne .media
.next:  dbf d1,.char
        tst.w d2
        beq .media
        tst.w d3
        beq .media
        lea fs_names(pc),a0
        moveq #64,d1
        bsr fs_crc32
        move.l d0,d1
        moveq #0,d0
        rts
.media: moveq #11,d0
        rts
whd_marker_path: dc.b "Custom/CFEDITOR",0
        even

; Nonzero while the full check of the last load still holds.
whd_directory_checked:
        dc.b 0
        even
; Modules loaded and checked since that full check.
whd_module_count:
        dc.w 0
whd_module_entries:
        dcb.b WHD_MODULE_ENTRIES*WHD_ENTRY_BYTES,0
