; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Bounded raw transport shared by modules, disk markers and campaign staging.
; Modules cannot request another load while their return address is in the
; replaceable bank. The dispatcher preserves D1-D7/A0-A6 and returns D0 status.
        xdef    editor_module_dispatch
        xdef    editor_custom_module_dispatch
        xdef    editor_module_return
        xdef    editor_module_active
        xdef    editor_module_marker
        xdef    editor_module_runs
        xdef    editor_load_preflight
        xdef    editor_load_copy_sector
        xdef    editor_load_read_track
        xdef    editor_load_publish
        xdef    editor_marker_gate
        xdef    editor_marker_call
        xdef    editor_snapshot_call

RAW_MODE                    equ MODULE_IO_HEADER
RAW_MARKER                  equ MODULE_IO_HEADER+2
editor_module_marker        equ EDITOR_SESSION_BASE+MODULE_CONTEXT_MARKER
editor_module_runs          equ EDITOR_SESSION_BASE+MODULE_CONTEXT_RUNS

editor_module_dispatch:
        moveq   #0,d0
        bra.s   editor_module_policy
; Runtime overlays use the same Custom directory module transport. Their first
; entry operation must separately qualify CFDI identity before UI or state changes.
editor_custom_module_dispatch:
        moveq   #12,d0
editor_module_policy:
        clr.l   editor_module_active
        cmpi.l  #EDITOR_MODULE_BASE,(sp)
        blo.s   .caller_ok
        cmpi.l  #EDITOR_MODULE_END,(sp)
        blo     editor_load_bad_caller
.caller_ok:
        movem.l d1-d7/a0-a6,-(sp)
        bsr     editor_raw_begin
        move.b  d0,RAW_MARKER(a5)
        clr.w   RAW_MODE(a5)
        move.l  d1,MODULE_IO_ID(a5)
        move.l  d2,MODULE_IO_CAPACITY(a5)
        lea     editor_resident_start+(EDITOR_MODULE_BASE-EDITOR_RESIDENT_BASE)(pc),a2
        cmpi.l  #EDITOR_MODULE_BYTES,d2
        beq.s   editor_load_name
        cmpi.l  #EDITOR_SERIALIZER_BYTES,d2
        bne     editor_load_bad_capacity
        bra.s   editor_load_name

; Disk-marker reads use the bounded one-byte transport. Other asset
; destinations retain the native loader.
editor_marker_gate:
        cmpa.l  #campaign_marker_destination,a1
        bne.s   .native
        bsr.s   editor_marker_call
        bne.s   .return
        moveq   #1,d1
        movea.l a1,a0
        sub.l   d0,d0
.return:
        rts
.native:
        move.l  a0,sensi_lookup_name
        jmp     sensi_load_file_continue
editor_marker_call:
        movem.l d1-d7/a0-a6,-(sp)
        moveq   #1,d3
        moveq   #1,d2
        lea     editor_resident_start+(EDITOR_IO_BASE+RAW_MARKER-EDITOR_RESIDENT_BASE)(pc),a2
        bra.s   editor_exact_begin
editor_snapshot_call:
        movem.l d1-d7/a0-a6,-(sp)
        moveq   #2,d3
        move.l  #CAMPAIGN_BYTES,d2
        lea     editor_resident_start+(EDITOR_SNAPSHOT_BASE-EDITOR_RESIDENT_BASE)(pc),a2
editor_exact_begin:
        bsr     editor_raw_begin
        move.w  d3,RAW_MODE(a5)
        move.l  d2,MODULE_IO_CAPACITY(a5)
        bsr     editor_test_custom_mode
        beq.s   editor_load_name
        cmpi.w  #1,d3
        bne     editor_load_media_changed
        cmpa.l  #campaign_marker_name,a0
        beq     editor_load_media_changed
editor_load_name:
        lea     MODULE_IO_NAME(a5),a1
        moveq   #14,d7
.copy:
        move.b  (a0)+,d0
        beq.s   .end
        cmpi.b  #' ',d0
        blo     editor_load_bad_name
        cmpi.b  #'~',d0
        bhi     editor_load_bad_name
        tst.w   RAW_MODE(a5)
        bne.s   .accepted
        ; Preserve the module ABI's narrower filename alphabet.
        cmpi.b  #'0',d0
        blo.s   .punctuation
        cmpi.b  #'9',d0
        bls.s   .accepted
        cmpi.b  #'A',d0
        blo.s   .punctuation
        cmpi.b  #'Z',d0
        bls.s   .accepted
        cmpi.b  #'a',d0
        blo.s   .punctuation
        cmpi.b  #'z',d0
        bls.s   .accepted
.punctuation:
        cmpi.b  #'_',d0
        beq.s   .accepted
        cmpi.b  #'.',d0
        beq.s   .accepted
        cmpi.b  #'-',d0
        bne     editor_load_bad_name
.accepted:
        move.b  d0,(a1)+
        dbra    d7,.copy
        bra     editor_load_bad_name
.end:
        cmpi.w  #14,d7
        beq     editor_load_bad_name
        ; Pad the entire fixed filename ABI before handing it to the Slave.
        addq.w  #1,d7
.pad_name:
        clr.b   (a1)+
        dbra    d7,.pad_name
        tst.w   RAW_MODE(a5)
        bne.s   .disk_file
        movea.l a5,a0
        moveq   #5,d0
        bsr     editor_backend_call
        bne     editor_load_done
        bra     editor_module_validate
.disk_file:
        bsr     editor_raw_directory
        bne     editor_load_done
        lea     32(a4),a4
        suba.l  a3,a3
.find:
        subq.l  #1,d6
        bmi.s   .found
        lea     MODULE_IO_NAME(a5),a0
        movea.l a4,a1
        moveq   #14,d2
.compare:
        move.b  (a0)+,d0
        move.b  (a1)+,d1
        or.b    d0,d1
        beq.s   .match
        move.b  -1(a1),d1
        ori.b   #$20,d0
        ori.b   #$20,d1
        cmp.b   d0,d1
        bne.s   .next
        dbra    d2,.compare
        bra.s   .next
.match:
        move.l  a3,d0
        bne     editor_load_bad_chain
        movea.l a4,a3
.next:
        lea     32(a4),a4
        bra.s   .find
.found:
        move.l  a3,d0
        beq     editor_load_absent
        movea.l a3,a4
        tst.b   21(a4)
        bne     editor_load_compressed
        move.l  28(a4),d0
        tst.w   RAW_MODE(a5)
        beq.s   .module_size
        cmp.l   MODULE_IO_CAPACITY(a5),d0
        bne     editor_load_bad_size
        bra.s   .size_ok
.module_size:
        cmpi.l  #MODULE_HEADER_BYTES+2,d0
        blo     editor_load_bad_size
        cmp.l   MODULE_IO_CAPACITY(a5),d0
        bhi     editor_load_bad_size
        btst    #0,d0
        bne     editor_load_bad_size
.size_ok:
        move.l  d0,MODULE_IO_SIZE(a5)
        move.l  d0,d6
        moveq   #0,d4
        moveq   #0,d5
        move.b  26(a4),d4
        move.b  27(a4),d5
editor_load_preflight:
        bsr     editor_load_sector
        bne     editor_load_done
editor_load_copy_sector:
        bsr     editor_raw_epoch
        bne     editor_load_done
        move.l  d6,d0
        cmpi.w  #510,d0
        bls.s   .count
        move.w  #510,d0
.count:
        sub.l   d0,d6
        move.b  510(a4),d4
        move.b  511(a4),d5
        subq.w  #1,d0
.byte:
        move.b  (a4)+,(a2)+
        dbra    d0,.byte
        tst.l   d6
        beq.s   .terminal
        bsr     editor_load_sector
        bne.s   editor_load_done
        bra.s   editor_load_copy_sector
.terminal:
        or.w    d5,d4
        bne     editor_load_bad_chain
        bsr     editor_raw_epoch
        bne.s   editor_load_done
        tst.w   RAW_MODE(a5)
        beq.s   editor_module_validate
        cmpi.w  #1,RAW_MODE(a5)
        bne.s   editor_load_success
        moveq   #0,d1
        move.b  MODULE_IO_NAME(a5),d0
        ori.b   #$20,d0
        cmpi.b  #'c',d0
        beq.s   .marker_value
        moveq   #$0c,d1
.marker_value:
        cmp.b   RAW_MARKER(a5),d1
        bne.s   editor_load_bad_header
        move.b  d1,campaign_marker_destination
        bra.s   editor_load_success

editor_module_validate:
        lea     editor_resident_start+(EDITOR_MODULE_BASE-EDITOR_RESIDENT_BASE)(pc),a4
        bsr     editor_load_check_header
        bne.s   editor_load_done
        move.l  MODULE_IO_PAYLOAD_CRC(a5),d0
        cmp.l     editor_resident_start+(EDITOR_MODULE_BASE+MODULE_CRC_OFFSET-EDITOR_RESIDENT_BASE)(pc),d0
        bne.s   editor_load_bad_crc
editor_load_publish:
        move.l  MODULE_IO_ID(a5),editor_module_active-editor_resident_start+EDITOR_RESIDENT_BASE-EDITOR_IO_BASE(a5)
        move.l     editor_resident_start+(EDITOR_MODULE_BASE+MODULE_ENTRY_OFFSET-EDITOR_RESIDENT_BASE)(pc),d0
        addi.l  #EDITOR_MODULE_BASE,d0
        movea.l d0,a1
        lea     editor_resident_start+(EDITOR_SESSION_BASE-EDITOR_RESIDENT_BASE)(pc),a0
        moveq   #MODULE_ABI,d0
        clr.w   REQ_ACTION(a0)
        jsr     (a1)
editor_module_return:
        lea     editor_resident_start+(EDITOR_IO_BASE-EDITOR_RESIDENT_BASE)(pc),a5
        clr.l   editor_module_active-editor_resident_start+EDITOR_RESIDENT_BASE-EDITOR_IO_BASE(a5)
        bra.s   editor_load_done
editor_load_success:
        moveq   #0,d0
editor_load_done:
        move.w  d0,-(sp)
        move.w  MODULE_IO_KEEP_DRIVE(a5),d1
        moveq   #36,d0
        jsr     sensi_disk_command
        move.w  (sp)+,d0
        movem.l (sp)+,d1-d7/a0-a6
        tst.w   d0
        rts
editor_load_bad_name:
        moveq   #-1,d0
        bra.s   editor_load_done
editor_load_bad_capacity:
        moveq   #-2,d0
        bra.s   editor_load_done
editor_load_compressed:
        moveq   #-3,d0
        bra.s   editor_load_done
editor_load_bad_size:
        moveq   #-4,d0
        bra.s   editor_load_done
editor_load_bad_header:
        moveq   #-5,d0
        bra.s   editor_load_done
editor_load_bad_crc:
        moveq   #-6,d0
        bra.s   editor_load_done
editor_load_bad_caller:
        moveq   #-8,d0
        rts
editor_load_absent:
        moveq   #3,d0
        bra.s   editor_load_done
editor_load_media_changed:
        moveq   #4,d0
        bra.s   editor_load_done
editor_load_bad_chain:
        moveq   #-9,d0
        bra.s   editor_load_done

editor_raw_begin:
        lea     editor_resident_start+(EDITOR_IO_BASE-EDITOR_RESIDENT_BASE)(pc),a5
        move.w  sensi_keep_drive_selected,MODULE_IO_KEEP_DRIVE(a5)
        move.w  #1,sensi_keep_drive_selected
        clr.b   MODULE_IO_SECTORS(a5)
        rts
editor_raw_directory:
        tst.w   editor_campaign_modal-editor_resident_start+EDITOR_RESIDENT_BASE-EDITOR_IO_BASE(a5)
        beq.s   .fresh
        bsr     editor_raw_epoch
        bne.s   .return
.fresh:
        moveq   #-1,d7
        moveq   #2,d4
        bsr     editor_load_read_track
        bne.s   .return
        movea.l sensi_track_scratch_pointer,a4
        lea     20(a4),a4
        move.l  24(a4),d6
        cmpi.l  #150,d6
        bhi.s   .bad
        tst.w   RAW_MODE(a5)
        bne.s   .exact
        tst.b   RAW_MARKER(a5)
        beq.s   .valid
        bra.s   .native
.exact:
        cmpi.w  #2,RAW_MODE(a5)
        beq.s   .native
        move.b  MODULE_IO_NAME(a5),d0
        ori.b   #$20,d0
        cmpi.b  #'c',d0
        bne.s   .valid
.native:
        cmpi.b  #12,MODULE_IO_SECTORS(a5)
        bne.s   .bad
        cmpi.l  #$63666469,(a4)
        bne.s   .bad
        cmpi.w  #$736b,4(a4)
        bne.s   .bad
.valid:
        moveq   #0,d0
.return:
        rts
.bad:
        moveq   #-9,d0
        rts

; D4/D5: captured track/sector; A2: trusted bounded copy destination.
editor_load_sector:
        moveq   #-9,d0
        cmpi.w  #3,d4
        blo.s   .return
        cmpi.w  #160,d4
        bhs.s   .return
        cmp.b   MODULE_IO_SECTORS(a5),d5
        bhs.s   .return
        cmpi.b  #12,MODULE_IO_SECTORS(a5)
        bne.s   .latch
        cmpi.w  #81,d4
        beq.s   .return
.latch:
        bsr.s   editor_raw_epoch
        bne.s   .return
        cmp.w   d4,d7
        beq.s   .address
        bsr.s   editor_load_read_track
        bne.s   .return
.address:
        move.w  d5,d0
        mulu.w  #512,d0
        movea.l sensi_track_scratch_pointer,a4
        lea     20(a4,d0.l),a4
        moveq   #0,d0
.return:
        tst.w   d0
        rts
editor_raw_epoch:
        ; Disk.N resources are immutable. Custom file identity is established
        ; by its separate bounded Slave transport before CFMO.
        moveq   #0,d0
.return:
        tst.w   d0
        rts
editor_load_read_track:
        movem.l d4-d7/a2-a5,-(sp)
        movea.l sensi_track_scratch_pointer,a0
        clr.l   SENSI_TRACK_MAGIC_OFFSET(a0)
        move.w  d4,d2
        moveq   #1,d1
        lea     MODULE_IO_READ_BYTE(a5),a1
        moveq   #44,d0
        jsr     sensi_disk_command
        movem.l (sp)+,d4-d7/a2-a5
        tst.w   d0
        bne.s   .return
        moveq   #11,d1
        movea.l sensi_track_scratch_pointer,a0
        cmpi.l  #SENSI_NATIVE_MAGIC,SENSI_TRACK_MAGIC_OFFSET(a0)
        bne.s   .format
        moveq   #12,d1
.format:
        tst.b   MODULE_IO_SECTORS(a5)
        beq.s   .first
        cmp.b   MODULE_IO_SECTORS(a5),d1
        bne.s   .bad
.first:
        move.b  d1,MODULE_IO_SECTORS(a5)
        move.w  d4,d7
        moveq   #0,d0
.return:
        tst.w   d0
        rts
.bad:
        moveq   #-9,d0
        rts
editor_load_check_header:
        moveq   #-5,d0
        cmpi.l  #MODULE_MAGIC,(a4)
        bne.s   .return
        cmpi.w  #MODULE_ABI,4(a4)
        bne.s   .return
        cmpi.w  #MODULE_HEADER_BYTES,6(a4)
        bne.s   .return
        move.l  MODULE_ID_OFFSET(a4),d1
        cmp.l   MODULE_IO_ID(a5),d1
        bne.s   .return
        cmpi.l  #EDITOR_MODULE_BASE,MODULE_BASE_OFFSET(a4)
        bne.s   .return
        move.l  MODULE_SIZE_OFFSET(a4),d1
        cmp.l   MODULE_IO_SIZE(a5),d1
        bne.s   .return
        move.l  MODULE_ENTRY_OFFSET(a4),d2
        cmpi.l  #MODULE_HEADER_BYTES,d2
        blo.s   .return
        cmp.l   d1,d2
        bhs.s   .return
        btst    #0,d2
        bne.s   .return
        tst.l   MODULE_FLAGS_OFFSET(a4)
        bne.s   .return
        moveq   #0,d0
.return:
        tst.w   d0
        rts
editor_module_active:
        dc.l    0
