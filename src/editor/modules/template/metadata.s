; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        xdef template_lookup,template_metadata
; D0.w=zero-based mission, D1.w=zero-based phase. Return D0=map number 1..72
; and D1=mission phase count, or D0=-1. Preserve D2-D7/A0-A6.
template_lookup:
        movem.l d2-d6/a0,-(sp)
        cmpi.w #24,d0
        bhs.s .bad
        lea native_phase_count_table,a0
        moveq #0,d2
        moveq #0,d3
        moveq #0,d4
        moveq #0,d5
.loop:
        move.w (a0)+,d6
        beq.s .bad
        cmpi.w #6,d6
        bhi.s .bad
        cmp.w d0,d3
        bne.s .next
        move.w d2,d4
        move.w d6,d5
.next:
        add.w d6,d2
        addq.w #1,d3
        cmpi.w #24,d3
        blo.s .loop
        cmpi.w #72,d2
        bne.s .bad
        cmp.w d5,d1
        bhs.s .bad
        move.w d4,d0
        add.w d1,d0
        addq.w #1,d0
        move.w d5,d1
        bra.s .return
.bad:
        moveq #-1,d0
.return:
        movem.l (sp)+,d2-d6/a0
        tst.w d0
        rts

; D0.w/D1.w mission/phase; A0=384-byte metadata destination owned by caller.
; Produce a one-phase, unsaved custom policy from immutable original tables.
; Return D0=0 or -1; preserve all other registers. Failure may stage partial
; metadata. Payload lengths/CRCs are installed by the import caller afterward.
template_metadata:
        movem.l d1-d7/a0-a6,-(sp)
        move.w d0,d4
        bsr.s template_lookup
        bmi .bad
        move.w d0,d6
        subq.w #1,d6
        movea.l a0,a2
        moveq #95,d0
.clear:
        clr.l (a0)+
        dbf d0,.clear
        move.l #CFMD_MAGIC,(a2)
        move.l #$00010100,4(a2)
        move.w #15,CFMD_RECRUITS(a2)
        move.b #1,CFMD_PHASE_COUNT(a2)
        moveq #0,d0
        move.w d4,d0
        divu #3,d0
        move.b d0,CFMD_RANK(a2)
        move.b #1<<CFMD_OVERVIEW_BIT,CFMD_FLAGS(a2)
        cmpi.w #5,d6
        blo.s .ammunition_done
        move.b #2,CFMD_GRENADES(a2)
        bset #CFMD_ENEMY_GRENADES_BIT,CFMD_FLAGS(a2)
        cmpi.w #10,d6
        blo.s .ammunition_done
        move.b #1,CFMD_ROCKETS(a2)
.ammunition_done:
        cmpi.w #71,d6
        bne.s .aggression
        bclr #CFMD_OVERVIEW_BIT,CFMD_FLAGS(a2)
        bset #CFMD_COUNTDOWN_BIT,CFMD_FLAGS(a2)
.aggression:
        move.w d6,d5
        lsl.w #2,d5
        lea native_aggression_table,a0
        move.w (a0,d5.w),d0
        move.w 2(a0,d5.w),d1
        cmp.w d1,d0
        bhi .bad
        cmpi.w #20,d1
        bhi .bad
        move.b d0,CFMD_AGGRESSION_MIN(a2)
        move.b d1,CFMD_AGGRESSION_MAX(a2)
        lea native_objective_table,a0
        movea.l (a0,d5.w),a0
        lea CFMD_OBJECTIVES(a2),a1
        moveq #0,d2
        moveq #0,d3
.objective:
        cmpa.l #native_objective_lists_start,a0
        blo.s .bad
        cmpa.l #native_objective_lists_end,a0
        bhs.s .bad
        moveq #0,d0
        move.b (a0)+,d0
        cmpi.b #$FF,d0
        beq.s .objectives_done
        subq.w #1,d0
        cmpi.w #7,d0
        bhi.s .bad
        bset d0,d3
        bne.s .bad
        addq.w #1,d0
        cmpi.w #8,d2
        bhs.s .bad
        move.b d0,(a1)+
        addq.w #1,d2
        bra.s .objective
.objectives_done:
        tst.w d2
        beq.s .bad
        move.b d2,CFMD_OBJECTIVE_COUNT(a2)
        move.b d3,CFMD_OBJECTIVE_MASK(a2)
        lsl.w #2,d4
        lea native_mission_title_table,a0
        movea.l (a0,d4.w),a0
        lea CFMD_TITLE(a2),a1
        move.l #native_mission_titles_start,d2
        move.l #native_mission_titles_end,d3
        bsr.s .title
        bne.s .bad
        lea native_phase_title_table,a0
        movea.l (a0,d5.w),a0
        lea CFMD_PHASE_TITLE(a2),a1
        move.l #native_phase_titles_start,d2
        move.l #native_phase_titles_end,d3
        bsr.s .title
        bra.s .return
.bad:
        moveq #-1,d0
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
.title:
        moveq #63,d1
.char:
        cmpa.l d2,a0
        blo.s .bad_title
        cmpa.l d3,a0
        bhs.s .bad_title
        move.b (a0)+,d0
        move.b d0,(a1)+
        cmpi.b #$FF,d0
        beq.s .title_done
        cmpi.b #32,d0
        blo.s .bad_title
        cmpi.b #126,d0
        bhi.s .bad_title
        dbf d1,.char
.bad_title:
        moveq #-1,d0
        rts
.title_done:
        moveq #0,d0
        rts
