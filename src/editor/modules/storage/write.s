; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

CF_WRITE_CANCEL equ EDITOR_IO_BASE+444
        xdef cf_write_entry,cf_write_after_native
        xdef cf_write_return,cf_write_end
; A0=name16,A1=immutable source,D1=length. Shared SAVE retains manifest-last
; ordering; this primitive creates only a new canonical generation filename.
; Fixed reader context is restored exactly after its bounded service call.
cf_write_entry:
        movem.l d1-d7/a0-a6,-(sp)
        moveq #STORAGE_READ_INVALID,d0
        tst.w native_gameplay_active
        bne cf_write_return
        move.w sr,d2
        andi.w #$0700,d2
        cmpi.w #$0600,d2
        bhs cf_write_return
        cmpi.l #SAVE_MAGIC,SAVE_CONTEXT
        bne cf_write_return
        cmpi.w #SAVE_ABI,SAVE_CONTEXT+4
        bne cf_write_return
        cmpi.w #SAVE_CONTEXT_BYTES,SAVE_CONTEXT+6
        bne cf_write_return
        tst.l d1
        beq cf_write_return
        cmpi.l #EDITOR_READBACK_BYTES,d1
        bhi.s cf_write_return
        lea -80(sp),sp
        movea.l a0,a3
        movea.l a1,a4
        move.l d1,d4
        lea EDITOR_IO_BASE+64,a0
        movea.l sp,a1
        moveq #19,d1
.save:  move.l (a0)+,(a1)+
        dbf d1,.save
        lea EDITOR_IO_BASE+64,a1
        moveq #3,d1
.name:  move.l (a3)+,(a1)+
        dbf d1,.name
        lea SAVE_CONTEXT+SAVE_DISK_ID,a0
        moveq #3,d1
.id:    move.l (a0)+,(a1)+
        dbf d1,.id
        move.l d4,(a1)+
        move.l #EDITOR_READBACK_BYTES,(a1)+
        moveq #8,d1
.clear: clr.l (a1)+
        dbf d1,.clear
        move.l CF_WRITE_CANCEL,EDITOR_IO_BASE+64+STORAGE_READ_CANCEL
        lea EDITOR_IO_BASE+64,a0
        movea.l a4,a1
        moveq #3,d0
        jsr EDITOR_BACKEND_ENTRY
cf_write_after_native:
        move.l d0,d7
        movea.l sp,a0
        lea EDITOR_IO_BASE+64,a1
        moveq #19,d1
.restore: move.l (a0)+,(a1)+
        dbf d1,.restore
        lea 80(sp),sp
        move.l d7,d0
cf_write_return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
cf_write_end:
