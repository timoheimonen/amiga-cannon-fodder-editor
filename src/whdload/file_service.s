; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Slave-side raw Custom directory transport. This file needs layout.i,
; storage_read.i and the resload pointer. All mutable state is caller-owned
; serializer WORK[0:864]; only the ListFiles names buffer is Slave-owned.
FS_CONTEXT      equ EDITOR_SERIAL_WORK_BASE
FS_MODE         equ EDITOR_SERIAL_WORK_BASE+4
FS_COUNT        equ EDITOR_SERIAL_WORK_BASE+6
FS_CRC          equ EDITOR_SERIAL_WORK_BASE+8
FS_INITIAL_CRC  equ EDITOR_SERIAL_WORK_BASE+12
FS_MARKER       equ EDITOR_SERIAL_WORK_BASE+16
FS_INITIAL_MARKER equ EDITOR_SERIAL_WORK_BASE+80
FS_TARGET       equ EDITOR_SERIAL_WORK_BASE+144
FS_REQUEST      equ EDITOR_SERIAL_WORK_BASE+176
FS_PATH         equ EDITOR_SERIAL_WORK_BASE+224
FS_SOURCE       equ EDITOR_SERIAL_WORK_BASE+248
FS_LENGTH       equ EDITOR_SERIAL_WORK_BASE+252
FS_RESULT_CRC   equ EDITOR_SERIAL_WORK_BASE+256
FS_OLD_COUNT    equ EDITOR_SERIAL_WORK_BASE+260
FS_OFFSET       equ EDITOR_SERIAL_WORK_BASE+264
FS_CHUNK        equ EDITOR_SERIAL_WORK_BASE+268
FS_ATTEMPTED    equ EDITOR_SERIAL_WORK_BASE+272
FS_VERIFY       equ EDITOR_SERIAL_WORK_BASE+320

; D0.w operation: 1=inspect, 2=read, 3=create, 4=delete.
; A0=existing resident80-byte request; create A1=immutable source of expected
; byte length. Data never decompresses. Names are canonical generation files.
; D0=status; D1-D7/A0-A6 preserved; READY only on fully verified success.
fs_service:
        movem.l d1-d7/a0-a6,-(sp)
        move.w d0,d7
        ; Creating or deleting changes Custom: the next module load checks it
        ; in full again.
        cmpi.w #3,d0
        blo.s .reading
        lea whd_directory_checked(pc),a2
        sf (a2)
.reading:
        moveq #10,d0
        cmpi.w #1,d7
        blo fs_return
        cmpi.w #4,d7
        bhi fs_return
        move.l a0,d1
        btst #0,d1
        bne fs_return
        cmpa.l #EDITOR_IO_BASE+64,a0
        blo fs_return
        cmpa.l #EDITOR_IO_BASE+EDITOR_IO_BYTES-80,a0
        bhi fs_return
        move.l a0,FS_CONTEXT
        move.w d7,FS_MODE
        move.l a1,FS_SOURCE
        clr.w FS_ATTEMPTED
        clr.l FS_LENGTH
        clr.l FS_RESULT_CRC
        lea STORAGE_READ_RESULT_BYTES(a0),a1
        moveq #6,d1
.clear: clr.l (a1)+
        dbf d1,.clear
        lea FS_REQUEST,a1
        moveq #11,d1
.request: move.l (a0)+,(a1)+
        dbf d1,.request
        cmpi.w #1,d7
        bne.s .request_check
        movea.l FS_CONTEXT,a0
        moveq #18,d1
.inspect_clear: clr.l (a0)+
        dbf d1,.inspect_clear
        bra fs_begin
.request_check:
        lea FS_REQUEST,a0
        bsr fs_valid_target
        bne fs_return
        ; Names are pointer-free padded records, not arbitrary path strings.
        lea FS_REQUEST,a0
        moveq #15,d1
        moveq #0,d2
.padding:
        move.b (a0)+,d3
        tst.w d2
        bne.s .zero_padding
        tst.b d3
        bne.s .padding_next
        moveq #1,d2
.zero_padding:
        tst.b d3
        bne fs_invalid
.padding_next:
        dbf d1,.padding
        moveq #10,d0
        move.l FS_REQUEST+16,d1
        or.l FS_REQUEST+20,d1
        or.l FS_REQUEST+24,d1
        or.l FS_REQUEST+28,d1
        beq fs_return
        tst.w FS_REQUEST+46
        bne fs_return
        cmpi.w #1,FS_REQUEST+44
        bhi fs_return
        cmpi.w #4,d7
        beq fs_begin
        move.l FS_REQUEST+36,d1
        beq fs_return
        cmpi.l #EDITOR_READBACK_BYTES,d1
        bhi fs_return
        cmp.l FS_REQUEST+32,d1
        blo fs_return
        cmpi.w #3,d7
        bne fs_begin
        move.l FS_REQUEST+32,d1
        beq fs_return
        move.l d1,FS_LENGTH
        move.l FS_SOURCE,d2
        add.l d1,d2
        bcs fs_return
        ; Only existing caller-owned MAP/SPT/manifest/readback slices may be
        ; immutable payload sources. No new game or Slave data staging exists.
        move.l FS_SOURCE,d3
        cmpi.l #map_file_buffer,d3
        blo.s .source_spt
        cmpi.l #map_file_buffer+EDITOR_READBACK_BYTES,d2
        bls fs_begin
.source_spt:
        cmpi.l #EDITOR_SPT_BASE,d3
        blo.s .source_manifest
        cmpi.l #EDITOR_SPT_BASE+EDITOR_SPT_BYTES,d2
        bls fs_begin
.source_manifest:
        cmpi.l #EDITOR_MANIFEST_BASE,d3
        blo.s .source_readback
        cmpi.l #EDITOR_MANIFEST_BASE+EDITOR_MANIFEST_BYTES,d2
        bls fs_begin
.source_readback:
        cmpi.l #EDITOR_READBACK_BASE,d3
        blo fs_return
        cmpi.l #EDITOR_READBACK_BASE+EDITOR_READBACK_BYTES,d2
        bhi fs_return

fs_begin:
        bsr fs_cancel
        bne fs_return
        bsr fs_directory
        bne fs_return
        bsr fs_identity
        bne fs_return
        move.l FS_CRC,FS_INITIAL_CRC
        move.w FS_COUNT,FS_OLD_COUNT
        lea FS_MARKER,a0
        lea FS_INITIAL_MARKER,a1
        moveq #15,d1
.pin:   move.l (a0)+,(a1)+
        dbf d1,.pin
        cmpi.w #1,FS_MODE
        beq fs_final
        lea FS_REQUEST,a0
        bsr fs_find
        cmpi.w #3,FS_MODE
        beq fs_create
        move.l a4,d0
        beq fs_absent
        movea.l a4,a0
        lea FS_TARGET,a1
        moveq #7,d1
.target: move.l (a0)+,(a1)+
        dbf d1,.target
        cmpi.w #4,FS_MODE
        beq fs_delete
        move.l FS_TARGET+28,d0
        cmp.l FS_REQUEST+36,d0
        bhi fs_size
        tst.l FS_REQUEST+32
        beq.s .size_ok
        cmp.l FS_REQUEST+32,d0
        bne fs_size
.size_ok:
        move.l d0,FS_LENGTH
        lea FS_TARGET,a0
        bsr fs_path
        lea FS_PATH,a0
        lea EDITOR_READBACK_BASE,a1
        move.l FS_LENGTH,d0
        moveq #0,d1
        bsr fs_load
        bne fs_return
        lea EDITOR_READBACK_BASE,a0
        move.l FS_LENGTH,d1
        bsr fs_crc32
        move.l d0,FS_RESULT_CRC
        btst #0,FS_REQUEST+45
        beq fs_final
        cmp.l FS_REQUEST+40,d0
        bne fs_verify_error
        bra fs_final

fs_create:
        move.l a4,d0
        bne fs_invalid
        cmpi.w #150,FS_COUNT
        beq fs_full
        bsr fs_free_quota
        move.l FS_LENGTH,d1
        addi.l #509,d1
        divu #510,d1
        andi.l #$ffff,d1
        cmp.l d1,d0
        blo fs_quota_full
        movea.l FS_SOURCE,a0
        move.l FS_LENGTH,d1
        bsr fs_crc32
        move.l d0,FS_RESULT_CRC
        btst #0,FS_REQUEST+45
        beq.s .source_valid
        cmp.l FS_REQUEST+40,d0
        bne fs_verify_error
.source_valid:
        ; Freeze the exact expected directory after inserting one new file.
        moveq #0,d0
        move.w FS_COUNT,d0
        lsl.w #5,d0
        lea EDITOR_DIRECTORY_BASE,a1
        adda.w d0,a1
        lea FS_REQUEST,a0
        moveq #3,d1
.name:  move.l (a0)+,(a1)+
        dbf d1,.name
        move.l FS_LENGTH,12(a1)
        addq.w #1,FS_COUNT
        bsr fs_sort_crc
        move.l FS_CRC,FS_INITIAL_CRC
        bsr fs_cancel
        bne fs_return
        lea FS_REQUEST,a0
        bsr fs_path
        lea FS_PATH,a0
        movea.l FS_SOURCE,a1
        move.l FS_LENGTH,d0
        movea.l resload(pc),a2
        move.w #1,FS_ATTEMPTED
        bsr fs_audio_quiet
        jsr resload_SaveFile(a2)
        tst.l d1
        bne fs_io
        tst.l d0
        beq fs_io
        ; Read back in bounded WORK chunks, preserving even a READBACK source.
        clr.l FS_OFFSET
.chunk:
        move.l FS_LENGTH,d0
        sub.l FS_OFFSET,d0
        cmpi.l #512,d0
        bls.s .bounded
        move.l #512,d0
.bounded:
        move.l d0,FS_CHUNK
        move.l FS_OFFSET,d1
        lea FS_PATH,a0
        lea FS_VERIFY,a1
        bsr fs_load
        bne fs_return
        movea.l FS_SOURCE,a0
        adda.l FS_OFFSET,a0
        lea FS_VERIFY,a1
        move.l FS_CHUNK,d1
        subq.w #1,d1
.compare:
        cmpm.b (a0)+,(a1)+
        bne fs_verify_error
        dbf d1,.compare
        move.l FS_CHUNK,d0
        add.l d0,FS_OFFSET
        move.l FS_LENGTH,d0
        cmp.l FS_OFFSET,d0
        bne.s .chunk
        movea.l FS_SOURCE,a0
        move.l FS_LENGTH,d1
        bsr fs_crc32
        move.l d0,FS_RESULT_CRC
        bra fs_final

fs_delete:
        ; Preserve the full exact survivors in existing READBACK scratch.
        movea.l a4,a0
        lea 32(a0),a1
        lea EDITOR_DIRECTORY_BASE+4800,a2
.compact:
        cmpa.l a2,a1
        bhs.s .zero
        move.l (a1)+,(a0)+
        bra.s .compact
.zero:  moveq #7,d1
.clear_tail: clr.l (a0)+
        dbf d1,.clear_tail
        subq.w #1,FS_COUNT
        lea EDITOR_DIRECTORY_BASE,a0
        lea EDITOR_READBACK_BASE,a1
        move.w #1199,d1
.snapshot: move.l (a0)+,(a1)+
        dbf d1,.snapshot
        bsr fs_sort_crc
        move.l FS_CRC,FS_INITIAL_CRC
        bsr fs_cancel
        bne fs_return
        lea FS_TARGET,a0
        bsr fs_path
        lea FS_PATH,a0
        movea.l resload(pc),a2
        move.w #1,FS_ATTEMPTED
        bsr fs_audio_quiet
        jsr resload_DeleteFile(a2)
        tst.l d1
        bne fs_io
        tst.l d0
        beq fs_io
fs_final:
        bsr fs_directory
        bne fs_return
        move.l FS_CRC,d0
        cmp.l FS_INITIAL_CRC,d0
        bne fs_media
        bsr fs_identity
        bne fs_return
        lea FS_INITIAL_MARKER,a0
        lea FS_MARKER,a1
        moveq #15,d1
.marker_compare:
        cmpm.l (a0)+,(a1)+
        bne fs_media
        dbf d1,.marker_compare
        cmpi.w #4,FS_MODE
        bne.s .publish
        lea EDITOR_DIRECTORY_BASE,a0
        lea EDITOR_READBACK_BASE,a1
        move.w #1199,d1
.survivors:
        cmpm.l (a0)+,(a1)+
        bne fs_verify_error
        dbf d1,.survivors
.publish:
        bsr fs_cancel_late
        bne fs_return
        movea.l FS_CONTEXT,a0
        cmpi.w #1,FS_MODE
        beq.s .inspection
        move.l FS_LENGTH,STORAGE_READ_RESULT_BYTES(a0)
        move.l FS_RESULT_CRC,STORAGE_READ_RESULT_CRC(a0)
        lea STORAGE_READ_RESULT_ID(a0),a1
        lea FS_MARKER+16,a2
        moveq #3,d1
.result_id: move.l (a2)+,(a1)+
        dbf d1,.result_id
        bra.s .ready
.inspection:
        move.l #STORAGE_INSPECT_MAGIC,(a0)
        move.l #$00010050,4(a0)
        lea 8(a0),a1
        lea FS_MARKER+16,a2
        moveq #11,d1
.inspection_id: move.l (a2)+,(a1)+
        dbf d1,.inspection_id
        ; This is an enforced logical quota in510-byte units, not free HD.
        bsr fs_free_quota
        mulu #510,d0
        move.l d0,56(a0)
        move.w #150,d0
        sub.w FS_COUNT,d0
        move.w d0,60(a0)
        move.w FS_COUNT,62(a0)
        move.l FS_CRC,64(a0)
.ready:
        move.l #1,72(a0)
        moveq #0,d0
fs_return:
        ; A failed operation may have met a changed Custom directory.
        tst.w d0
        beq.s .checked
        lea whd_directory_checked(pc),a0
        sf (a0)
.checked:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
fs_invalid: moveq #10,d0
        bra fs_return
fs_media: moveq #11,d0
        bra fs_return
fs_verify_error: moveq #13,d0
        bra fs_return
fs_size: moveq #15,d0
        bra fs_return
fs_absent: moveq #3,d0
        bra fs_return
fs_quota_full: moveq #2,d0
        bra fs_return
fs_full: moveq #1,d0
        bra fs_return
fs_io:  moveq #5,d0
        bra fs_return

fs_cancel:
        tst.w FS_ATTEMPTED
        bne.s fs_cancel_allow
fs_cancel_late:
        movea.l FS_CONTEXT,a0
        moveq #14,d0
        tst.l 76(a0)
        bne.s fs_cancel_return
fs_cancel_allow: moveq #0,d0
fs_cancel_return: tst.w d0
        rts

; A write switches to the OS, which stops the game's interrupts while Paula
; keeps looping its current samples, and can take long on real hardware.
; Silence the four channels before each write; the native player rewrites
; every volume on its next tick. Reads, listings and module loads keep the
; music playing: their OS switches take a few milliseconds, and a reset would
; silence every channel until that tick.
fs_audio_quiet:
        move.w #0,$dff0a8
        move.w #0,$dff0b8
        move.w #0,$dff0c8
        move.w #0,$dff0d8
        rts

; Raw bounded API; errors map to a stable I/O status. No decompression call.
fs_load:
        movem.l d0-d1/a0-a1,-(sp)
        bsr fs_cancel
        beq.s .admitted
        lea 16(sp),sp
        rts
.admitted:
        movem.l (sp)+,d0-d1/a0-a1
        movea.l resload(pc),a2
        jsr resload_LoadFileOffset(a2)
        tst.l d1
        bne.s .error
        tst.l d0
        beq.s .error
        moveq #0,d0
        rts
.error: moveq #3,d0
        rts

; Rebuild a zero-padded, sorted4800-byte directory. ListFiles names are treated
; as untrusted bounded bytes even after API success. API returnD1 is mandatory.
fs_directory:
        bsr fs_cancel
        bne .return
        lea fs_names(pc),a0
        move.w #599,d1
.zero_names: clr.l (a0)+
        dbf d1,.zero_names
        lea fs_directory_name(pc),a0
        lea fs_names(pc),a1
        move.l #2400,d0
        movea.l resload(pc),a2
        jsr resload_ListFiles(a2)
        tst.l d1
        bne .media
        tst.l d0
        beq .media
        cmpi.l #150,d0
        bhi .media
        move.w d0,FS_COUNT
        lea EDITOR_DIRECTORY_BASE,a0
        move.w #1199,d1
.clear: clr.l (a0)+
        dbf d1,.clear
        lea fs_names(pc),a3
        lea EDITOR_DIRECTORY_BASE,a4
        move.w FS_COUNT,d6
        subq.w #1,d6
.record:
        bsr fs_cancel
        bne .return
        movea.l a4,a1
        moveq #14,d5
        tst.b (a3)
        beq .corrupt
.character:
        lea fs_names_end(pc),a0
        cmpa.l a0,a3
        bhs .corrupt
        move.b (a3)+,d0
        move.b d0,(a1)+
        beq.s .size
        bsr fs_valid_character
        bne .corrupt
        dbf d5,.character
        bra .corrupt
.size:
        movea.l a4,a0
        bsr fs_path
        lea FS_PATH,a0
        movea.l resload(pc),a2
        jsr resload_GetFileSize(a2)
        tst.l d0
        beq .corrupt
        cmpi.l #65535,d0
        bhi .corrupt
        move.l d0,28(a4)
        lea 32(a4),a4
        dbf d6,.record
        bsr fs_sort_crc
        bne.s .return
        lea fs_campaign_name(pc),a0
        bsr fs_find
        move.l a4,d0
        bne.s .media
        lea fs_marker_name(pc),a0
        bsr fs_find
        move.l a4,d0
        beq.s .media
        cmpi.l #64,28(a4)
        bne.s .media
        ; Require canonical marker spelling, avoiding a filesystem-dependent
        ; case-fold lookup for the identity anchor.
        cmpi.l #$43464544,(a4)
        bne.s .media
        cmpi.l #$49544F52,4(a4)
        bne.s .media
        moveq #0,d0
.return: tst.w d0
        rts
.media: moveq #11,d0
        bra.s .return
.corrupt: moveq #12,d0
        bra.s .return

fs_sort_crc:
        move.w FS_COUNT,d6
        subq.w #1,d6
        ble.s .crc
.outer:
        lea EDITOR_DIRECTORY_BASE,a4
        move.w d6,d5
        subq.w #1,d5
.inner:
        movea.l a4,a0
        lea 32(a4),a1
        bsr fs_compare
        beq.s .duplicate
        blo.s .next
        moveq #7,d1
        movea.l a4,a0
        lea 32(a4),a1
.swap:  move.l (a0),d0
        move.l (a1),(a0)+
        move.l d0,(a1)+
        dbf d1,.swap
.next:  lea 32(a4),a4
        dbf d5,.inner
        subq.w #1,d6
        bne.s .outer
.crc:   bsr fs_directory_fingerprint
        move.l d0,FS_CRC
        moveq #0,d0
        rts
.duplicate: moveq #12,d0
        rts

; Case-folded lexical compare, bounded because records were validated first.
fs_compare:
        moveq #15,d1
.loop:  move.b (a0)+,d0
        move.b (a1)+,d2
        ori.b #$20,d0
        ori.b #$20,d2
        cmp.b d2,d0
        bne.s .return
        cmpi.b #$20,d0
        beq.s .return
        dbf d1,.loop
.return: rts

; A0 padded name -> A4 record or zero. Preserve input name viaA3.
fs_find:
        movea.l a0,a3
        lea EDITOR_DIRECTORY_BASE,a4
        move.w FS_COUNT,d4
        subq.w #1,d4
.loop:  movea.l a3,a0
        movea.l a4,a1
        bsr fs_compare
        beq.s .return
        lea 32(a4),a4
        dbf d4,.loop
        suba.l a4,a4
.return: rts

fs_path:
        lea FS_PATH,a1
        move.l #$43757374,(a1)+
        move.w #$6F6D,(a1)+
        move.b #'/',(a1)+
        moveq #15,d1
.copy:  move.b (a0)+,(a1)+
        beq.s .return
        dbf d1,.copy
.return: rts

fs_identity:
        lea fs_marker_name(pc),a0
        bsr fs_path
        lea FS_PATH,a0
        lea FS_MARKER,a1
        moveq #64,d0
        moveq #0,d1
        bsr fs_load
        bne .return
        moveq #11,d0
        cmpi.l #$43464449,FS_MARKER
        bne .return
        cmpi.l #$00010010,FS_MARKER+4
        bne .return
        cmpi.l #48,FS_MARKER+8
        bne .return
        lea FS_MARKER+16,a0
        moveq #48,d1
        bsr fs_crc32
        cmp.l FS_MARKER+12,d0
        bne.s .media
        move.l FS_MARKER+16,d0
        or.l FS_MARKER+20,d0
        or.l FS_MARKER+24,d0
        or.l FS_MARKER+28,d0
        beq.s .media
        cmpi.w #1,FS_MODE
        beq.s .name
        lea FS_REQUEST+16,a0
        lea FS_MARKER+16,a1
        moveq #3,d1
.id:    cmpm.l (a0)+,(a1)+
        bne.s .media
        dbf d1,.id
.name:  lea FS_MARKER+32,a0
        moveq #31,d1
        moveq #0,d2
        moveq #0,d3
.char:  move.b (a0)+,d0
        tst.w d2
        bne.s .padding
        tst.b d0
        beq.s .nul
        cmpi.b #32,d0
        blo.s .media
        cmpi.b #126,d0
        bhi.s .media
        addq.w #1,d3
        bra.s .next
.nul:   moveq #1,d2
.padding: tst.b d0
        bne.s .media
.next:  dbf d1,.char
        tst.w d2
        beq.s .media
        tst.w d3
        beq.s .media
        moveq #0,d0
.return: tst.w d0
        rts
.media: moveq #11,d0
        bra.s .return

fs_valid_character:
        cmpi.b #'.',d0
        beq.s .ok
        cmpi.b #'-',d0
        beq.s .ok
        cmpi.b #'_',d0
        beq.s .ok
        cmpi.b #'0',d0
        blo.s .bad
        cmpi.b #'9',d0
        bls.s .ok
        ori.b #$20,d0
        cmpi.b #'a',d0
        blo.s .bad
        cmpi.b #'z',d0
        bhi.s .bad
.ok:    moveq #0,d0
        rts
.bad:   moveq #12,d0
        rts

fs_valid_target:
        moveq   #7,d1
        cmpi.l  #$2e636d69,8(a0)
        bne.s   .phase
        tst.b   12(a0)
        beq.s   .hex_start
.phase:
        moveq   #9,d1
        cmpi.l  #$2e6d6170,10(a0)
        beq.s   .phase_end
        cmpi.l  #$2e737074,10(a0)
        bne.s   .bad
.phase_end:
        tst.b   14(a0)
        bne.s   .bad
.hex_start:
        movea.l a0,a1
.hex:
        move.b  (a1)+,d0
        cmpi.b  #'0',d0
        blo.s   .bad
        cmpi.b  #'9',d0
        bls.s   .next
        cmpi.b  #'a',d0
        blo.s   .bad
        cmpi.b  #'f',d0
        bhi.s   .bad
.next:
        dbf     d1,.hex
        moveq   #0,d0
        rts
.bad:
        moveq   #STORAGE_READ_INVALID,d0
        rts

; Reflected IEEE CRC32 over a positive bounded byte count in D1, starting A0.
fs_crc32:
        moveq   #-1,d0
        bsr.s fs_crc32_part
        not.l d0
        rts
; One reflected CRC-32 table step: D0 = D0>>8 ^ table[(D0 ^ \1) & $FF],
; with the data byte in the low byte of \1. A1 = table. Uses D2.
CRC_STEP macro
        move.l d0,d2
        eor.b \1,d2
        lsl.w #2,d2
        andi.w #$3fc,d2
        lsr.l #8,d0
        move.l (a1,d2.w),d2
        eor.l d2,d0
        endm

; Byte-table CRC-32; the table is built on first use. D0=running CRC,
; A0/D1 source and nonzero length. Longword-aligned data is read four bytes
; at a time: one Chip RAM access instead of four. A0 ends after the data;
; clobbers D1-D3.
fs_crc32_part:
        movem.l d4/a1,-(sp)
        lea fs_crc_table(pc),a1
        tst.l 4(a1)
        bne.s .head
        moveq #0,d2
.entry:
        moveq #0,d3
        move.w d2,d3
        swap d2
        move.w #7,d2
.bit:
        lsr.l #1,d3
        bcc.s .next
        eori.l #$EDB88320,d3
.next:
        dbf d2,.bit
        swap d2
        move.l d3,(a1)+
        addq.w #1,d2
        cmpi.w #256,d2
        bne.s .entry
        lea fs_crc_table(pc),a1
.head:
        move.w a0,d2
        andi.w #3,d2
        beq.s .body
        bsr.s .byte
        bne.s .head
        bra.s .done
.body:
        move.l d1,d4
        lsr.l #2,d4
        beq.s .tail
.long:
        move.l (a0)+,d3
        rol.l #8,d3
        CRC_STEP d3
        rol.l #8,d3
        CRC_STEP d3
        rol.l #8,d3
        CRC_STEP d3
        rol.l #8,d3
        CRC_STEP d3
        subq.l #1,d4
        bne.s .long
        andi.l #3,d1
        beq.s .done
.tail:
        bsr.s .byte
        bne.s .tail
.done:
        movem.l (sp)+,d4/a1
        rts
; One byte at A0; Z set when D1 reaches zero.
.byte:
        move.b (a0)+,d3
        CRC_STEP d3
        subq.l #1,d1
        rts

; Exact shared catalog fingerprint: header32 + records4800 + zero tail1312.
; WORK320..831 is dead during listing/identity, so inspection keeps READBACK.
fs_directory_fingerprint:
        lea FS_VERIFY,a0
        moveq #127,d1
.clear: clr.l (a0)+
        dbf d1,.clear
        move.l #$63666469,FS_VERIFY
        move.w #$736b,FS_VERIFY+4
        move.w FS_COUNT,FS_VERIFY+26
        moveq #-1,d0
        lea FS_VERIFY,a0
        moveq #32,d1
        bsr fs_crc32_part
        lea EDITOR_DIRECTORY_BASE,a0
        move.l #4800,d1
        bsr fs_crc32_part
        clr.l FS_VERIFY
        clr.w FS_VERIFY+4
        clr.w FS_VERIFY+26
        moveq #1,d4
.zeros: lea FS_VERIFY,a0
        move.l #512,d1
        bsr fs_crc32_part
        dbf d4,.zeros
        lea FS_VERIFY,a0
        move.l #288,d1
        bsr fs_crc32_part
        not.l d0
        rts

; D0 remaining logical sectors, saturated at0. Preserve all other registers.
fs_free_quota:
        movem.l d1-d3/a1,-(sp)
        move.l #156*12,d0
        lea EDITOR_DIRECTORY_BASE,a1
        move.w FS_COUNT,d3
        subq.w #1,d3
.file:  move.l 28(a1),d1
        addi.l #509,d1
        divu #510,d1
        andi.l #$ffff,d1
        sub.l d1,d0
        bcs.s .zero
        lea 32(a1),a1
        dbf d3,.file
        bra.s .done
.zero:  moveq #0,d0
.done:  movem.l (sp)+,d1-d3/a1
        rts

fs_directory_name: dc.b "Custom",0
fs_marker_name: dc.b "CFEDITOR",0
fs_campaign_name: dc.b "CFSDISK",0
        even
fs_names: dcb.b 2400,0
fs_names_end:
        cnop 0,4
fs_crc_table: dcb.l 256,0
