; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

TPL_OWNER_FRAME equ EDITOR_UI_BASE+20
TPL_SOURCE_DIRECTORY equ EDITOR_UI_BASE+24
TPL_SOURCE_QUALIFIED equ EDITOR_UI_BASE+28
TPL_SNAPSHOT_BYTES equ 512

; Stack-local immutable metadata384+AUR128 for this synchronous module call.
; UI20..31 is disjoint from picker0..19, saved colors32..87 and text160..223.
template_snapshot:
        movea.l TPL_OWNER_FRAME+PCREL(pc),a1
        lea EDITOR_METADATA_BASE+PCREL(pc),a0
        moveq #95,d0
.metadata:
        move.l (a0)+,(a1)+
        dbf d0,.metadata
        lea AUR_BASE+PCREL(pc),a0
        moveq #31,d0
.author:
        move.l (a0)+,(a1)+
        dbf d0,.author
        clr.l TPL_SOURCE_DIRECTORY
        clr.w TPL_SOURCE_QUALIFIED
        rts

template_snapshot_check:
        movea.l TPL_OWNER_FRAME+PCREL(pc),a0
        lea EDITOR_METADATA_BASE+PCREL(pc),a1
        moveq #95,d1
.metadata:
        cmpm.l (a0)+,(a1)+
        bne.s .stale
        dbf d1,.metadata
        lea AUR_BASE+PCREL(pc),a1
        moveq #31,d1
.author:
        cmpm.l (a0)+,(a1)+
        bne.s .stale
        dbf d1,.author
        moveq #0,d0
        rts
.stale:
        moveq #AUR_ERROR_OWNER,d0
        rts

template_append_admit:
        cmpi.w #AUR_CONTINUE_PHASE_TEMPLATE,AUR_BASE+AUR_PAGE_CANDIDATE
        bne.s .same
        moveq #AUR_ERROR_SOURCE,d0
        btst #0,AUR_BASE+AUR_FLAGS+1+PCREL(pc)
        beq.s .return
        cmpi.b #6,AUR_BASE+AUR_PHASE_COUNT
        bhs.s .return
        lea AUR_BASE+AUR_PHASE_MAP+PCREL(pc),a0
        moveq #0,d1
        move.b AUR_BASE+AUR_SELECTED+PCREL(pc),d1
        cmpi.b #$FF,0(a0,d1.w)
        beq.s .return
.same:
        moveq #0,d0
.return:
        tst.w d0
        rts

; Reread the captured source from the freshly inspected Custom directory. The complete
; CFMI envelope and recomputed body CRC pin the previously qualified body, whose
; ID/revision/schema belong to the captured AUR. No parser scratch is retained.
template_source_pin:
        cmpi.w #AUR_CONTINUE_PHASE_TEMPLATE,AUR_BASE+AUR_PAGE_CANDIDATE
        bne .same
        movea.l TPL_OWNER_FRAME+PCREL(pc),a2
        lea 384(a2),a2
        move.l AUR_SOURCE_BYTES(a2),d0
        cmpi.l #17,d0
        blo .bad
        cmpi.l #4096,d0
        bhi .bad
        ; Custom files are read through the qualified Custom directory reader;
        ; the original template reader reads only the standard game disks.
        lea AUR_SOURCE_NAME(a2),a0
        lea STORAGE_CONTEXT+PCREL(pc),a1
        moveq #3,d1
.name:
        move.l (a0)+,(a1)+
        dbf d1,.name
        lea AUR_DISK_ID(a2),a0
        moveq #3,d1
.identity:
        move.l (a0)+,(a1)+
        dbf d1,.identity
        move.l d0,(a1)+
        move.l #4096,(a1)+
        clr.l (a1)+
        clr.l (a1)+
        clr.l STORAGE_CONTEXT+STORAGE_READ_CANCEL
        lea STORAGE_CONTEXT+PCREL(pc),a0
        bsr storage_read_entry
        tst.w d0
        bne.s .bad
        move.l AUR_SOURCE_BYTES(a2),d0
        lea EDITOR_READBACK_BASE+PCREL(pc),a0
        cmpi.l #$43464D49,(a0)+
        bne.s .bad
        cmpi.l #$00010010,(a0)+
        bne.s .bad
        subi.l #16,d0
        cmp.l (a0)+,d0
        bne.s .bad
        move.l AUR_SOURCE_CRC(a2),d2
        cmp.l (a0)+,d2
        bne.s .bad
        move.l d0,d1
        bsr read_crc32
        cmp.l AUR_SOURCE_CRC(a2),d0
        bne.s .bad
        move.l read_directory_crc+PCREL(pc),TPL_SOURCE_DIRECTORY
        move.w #1,TPL_SOURCE_QUALIFIED
.same:
        moveq #0,d0
.return:
        tst.l d0
        rts
.bad:
        moveq #AUR_ERROR_SOURCE,d0
        rts

; The prospective phase keeps the mission fields and a newly selected FF slot.
; Called only after the Custom directory and the full original owner were rechecked.
template_append_metadata:
        movea.l TPL_OWNER_FRAME+PCREL(pc),a0
        lea TPL_STAGE_METADATA+PCREL(pc),a1
        bsr.s phase_preserve_mission
        move.b AUR_BASE+AUR_PHASE_COUNT+PCREL(pc),d0
        move.b d0,TPL_STAGE_METADATA+CFMD_PHASE_INDEX
        addq.b #1,d0
        move.b d0,TPL_STAGE_METADATA+CFMD_PHASE_COUNT
        rts

template_append_publish:
        moveq #0,d0
        move.b AUR_BASE+AUR_PHASE_COUNT+PCREL(pc),d0
        lea AUR_BASE+AUR_PHASE_MAP+PCREL(pc),a0
        move.b #$FF,0(a0,d0.w)
        move.b d0,AUR_BASE+AUR_SELECTED
        bclr d0,E7_TESTED
        addq.b #1,AUR_BASE+AUR_PHASE_COUNT
        ori.w #AUR_DIRTY,AUR_BASE+AUR_FLAGS
        clr.l AUR_BASE+AUR_UNDO_NEXT
        clr.l AUR_BASE+AUR_CAMERA_X
        clr.w AUR_BASE+AUR_TOOL
        clr.w AUR_BASE+AUR_TILE
        move.w #-1,AUR_BASE+AUR_OBJECT_INDEX
        clr.l STORAGE_READY
        moveq #3,d7
        bra template_finish
        include "../phase_list/mission.s"
