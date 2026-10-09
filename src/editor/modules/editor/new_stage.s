; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        section .text,code
        xdef new_draft_stage,new_draft_stage_end

; Build a blank mission in scratch without changing the current draft.
; D0.l=family 0..5, D1.l=width >=19, D2.l=height >=15; at most 7500 cells.
; Return D0.l=0 or -1. Preserve every other register and SR control bits.
; Invalid arguments leave every staging byte intact. Valid output owns MAP's
; exact encoded length, all 430 SPT bytes and all 384 metadata bytes below.
; The caller must release modal/readback and disk scratch before entry, and
; validate its session and Custom directory before publishing this candidate. No I/O or commit.
NEW_STAGE_MAP      equ EDITOR_READBACK_BASE
NEW_STAGE_SPT      equ EDITOR_SERIAL_WORK_BASE+400
NEW_STAGE_METADATA equ EDITOR_SERIAL_WORK_BASE+832
new_draft_stage:
        movem.l d1-d7/a0-a6,-(sp)
        cmpi.l #5,d0
        bhi .reject
        cmpi.l #19,d1
        blo .reject
        cmpi.l #500,d1
        bhi .reject
        cmpi.l #15,d2
        blo .reject
        cmpi.l #394,d2
        bhi .reject
        move.w d0,d7
        move.w d1,d4
        move.w d2,d5
        move.w d4,d6
        mulu d5,d6
        cmpi.l #7500,d6
        bhi .reject
        lea NEW_STAGE_METADATA,a0
        move.w  #EDITOR_METADATA_BYTES/4-1,d1
.metadata:
        clr.l   (a0)+
        dbf     d1,.metadata
        lea NEW_STAGE_SPT,a0
        move.w  #EDITOR_SPT_BYTES/2-1,d1
.spt:
        clr.w   (a0)+
        dbf     d1,.spt
        lea     NEW_STAGE_MAP,a0
        move.w  d6,d1
        addi.w  #47,d1
.map:
        clr.w   (a0)+
        dbf     d1,.map
        lea     .resources(pc),a0
        move.w d7,d1
        lsl.w   #5,d1
        adda.w  d1,a0
        lea     NEW_STAGE_MAP,a1
        moveq   #7,d1
.names:
        move.l  (a0)+,(a1)+
        dbf     d1,.names
        move.l  #$63666564,NEW_STAGE_MAP+80
        move.w  d4,NEW_STAGE_MAP+84
        move.w  d5,NEW_STAGE_MAP+86
        move.w  d4,d1
        lsr.w   #1,d1
        lsl.w   #4,d1
        subq.w  #8,d1
        move.w  d1,NEW_STAGE_SPT+4
        move.w  d5,d1
        lsr.w   #1,d1
        lsl.w   #4,d1
        addq.w  #8,d1
        move.w  d1,NEW_STAGE_SPT+6

        lea NEW_STAGE_METADATA,a2
        move.l  #CFMD_MAGIC,(a2)
        move.l  #$00010100,4(a2)
        move.w  #15,CFMD_RECRUITS(a2)
        move.b  #1,CFMD_PHASE_COUNT(a2)
        move.b  #1,CFMD_OBJECTIVE_COUNT(a2)
        move.b  #1,CFMD_OBJECTIVE_MASK(a2)
        move.b  #1,CFMD_OBJECTIVES(a2)
        move.b  #1<<CFMD_OVERVIEW_BIT,CFMD_FLAGS(a2)
        add.w   d6,d6
        addi.w  #96,d6
        move.w  d6,CFMD_MAP_BYTES(a2)
        move.w  #10,CFMD_SPT_BYTES(a2)
        lea     .mission_title(pc),a0
        lea     CFMD_TITLE(a2),a1
        bsr.s   .title
        lea     .phase_title(pc),a0
        lea     CFMD_PHASE_TITLE(a2),a1
        bsr.s   .title
        lea     NEW_STAGE_MAP,a0
        moveq   #0,d1
        move.w  d6,d1
        bsr     read_crc32
        move.l  d0,CFMD_MAP_CRC(a2)
        lea NEW_STAGE_SPT,a0
        moveq   #10,d1
        bsr     read_crc32
        move.l  d0,CFMD_SPT_CRC(a2)
        moveq #0,d0
        bra.s .return
.reject:
        moveq #-1,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
.title:
        move.b  (a0)+,(a1)+
        cmpi.b  #$FF,-1(a1)
        bne.s   .title
        rts
        even
.resources:
        dc.b "junbase.blk",0,0,0,0,0
        dc.b "junsub0.blk",0,0,0,0,0
        dc.b "junbase.blk",0,0,0,0,0
        dc.b "junsub1.blk",0,0,0,0,0
        dc.b "icebase.blk",0,0,0,0,0
        dc.b "icesub0.blk",0,0,0,0,0
        dc.b "desbase.blk",0,0,0,0,0
        dc.b "dessub0.blk",0,0,0,0,0
        dc.b "morbase.blk",0,0,0,0,0
        dc.b "morsub0.blk",0,0,0,0,0
        dc.b "intbase.blk",0,0,0,0,0
        dc.b "intsub0.blk",0,0,0,0,0
.mission_title:
        dc.b "NEW MISSION",$FF
.phase_title:
        dc.b "PHASE 1",$FF
        even

new_draft_stage_end:
        ifgt NEW_STAGE_METADATA+EDITOR_METADATA_BYTES-EDITOR_SERIAL_WORK_BASE-EDITOR_SERIAL_WORK_BYTES
        fail "New metadata stage exceeds serializer work"
        endif
        ifgt NEW_STAGE_SPT+EDITOR_SPT_BYTES-NEW_STAGE_METADATA
        fail "New SPT and metadata stages overlap"
        endif
        iflt EDITOR_READBACK_BYTES-15096
        fail "New MAP stage is too small"
        endif
