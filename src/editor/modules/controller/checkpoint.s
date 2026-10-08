; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; All public calls preserve D1-D7/A0-A6/SP; D0 is zero or a negative error.
; The caller owns validated CFMD/SPT and excludes ordinary hill/debrief code.
        xdef checkpoint_capture,checkpoint_retry,checkpoint_preflight
        xdef checkpoint_initial_preflight

CP_MODE                 equ 0
CP_SNAPSHOT_VALID       equ 20
CP_SNAPSHOT_TAG         equ SESSION_SNAPSHOT_TAG
CP_ROSTER               equ 96
CP_SCALARS              equ 192
CP_POLICY               equ 224
CP_VALID                equ 288
CP_HOF                  equ 320
CP_RANK_END             equ 350
CP_RANK_READ            equ 354
CP_NAME_END             equ 358
CP_COUNTS               equ 362
CP_MAP                  equ 366
CP_USED_END             equ 368
CP_POOL                 equ CP_SCALARS+6
CP_NAME_CURSOR          equ CP_SCALARS+26
CP_MAGIC                equ SESSION_CHECKPOINT_TAG
CP_ERROR_STATE          equ -1
CP_ERROR_LIST           equ -2
CP_ERROR_POLICY         equ -3
CP_ERROR_ROSTER         equ -4
CP_ERROR_CAPACITY       equ -5
CP_ERROR_SPT            equ -6

checkpoint_start:
; Validate a new session without touching the campaign or snapshot. The
; temporary empty roster lies beyond the bounded reader's working record.
checkpoint_initial_preflight:
        movem.l d1-d7/a0-a6,-(sp)
        moveq   #CP_ERROR_STATE,d0
        tst.w   native_gameplay_active
        bne.s   .return
        tst.w   session_custom_mode
        bne.s   .return
        tst.w   SESSION_SNAPSHOT_VALID
        bne.s   .return
        lea     EDITOR_SERIAL_WORK_BASE+STORAGE_READ_WORK_BYTES,a2
        movea.l a2,a0
        moveq   #23,d1
.empty:
        move.l  #-1,(a0)+
        dbra    d1,.empty
        move.w  EDITOR_METADATA_BASE+CFMD_RECRUITS,d4
        moveq   #0,d5
        moveq   #0,d2
        moveq   #0,d3
        bsr     cp_preflight
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w   d0
        rts

checkpoint_capture:
        movem.l d1-d7/a0-a6,-(sp)
        lea     EDITOR_SESSION_BASE,a5
        bsr     cp_guard
        bne     cp_return
        bsr     cp_live_bounds
        bne     cp_return
        lea     native_roster,a2
        move.w  native_recruits_remaining,d4
        bsr     cp_preflight
        bne     cp_return
        move.w  sr,-(sp)
        ori.w   #$0700,sr
        ; A rejected replacement retains the previous phase's retry checkpoint.
        clr.l   CP_VALID(a5)
        lea     native_roster,a0
        lea     CP_ROSTER(a5),a1
        moveq   #47,d0
        bsr     cp_copy_words
        lea     native_mission_number,a0
        lea     CP_SCALARS(a5),a1
        moveq   #5,d0
        bsr     cp_copy_words
        lea     native_campaign_scalars_b,a0
        moveq   #9,d0
        bsr     cp_copy_words
        lea     EDITOR_METADATA_BASE+CFMD_ID,a0
        lea     CP_POLICY(a5),a1
        moveq   #19,d0
        bsr     cp_copy_words
        moveq   #13,d0
.reserved:
        clr.l   (a1)+
        dbra    d0,.reserved
        lea     native_hall_of_fame,a0
        lea     CP_HOF(a5),a1
        moveq   #14,d0
        bsr     cp_copy_words
        move.l  native_dead_rank_end,(a1)+
        move.l  native_dead_rank_cursor,(a1)+
        move.l  native_dead_name_end,(a1)+
        move.l  native_death_kill_counts,(a1)+
        move.w  native_map_index,(a1)+
        move.l  #CP_MAGIC,CP_VALID(a5)
        move.w  (sp)+,sr
        moveq   #0,d0
        bra     cp_return

checkpoint_retry:
        movem.l d1-d7/a0-a6,-(sp)
        lea     EDITOR_SESSION_BASE,a5
        bsr     cp_guard
        bne     cp_return
        moveq   #CP_ERROR_STATE,d0
        cmpi.l  #CP_MAGIC,CP_VALID(a5)
        bne     cp_return
        bsr     cp_live_bounds
        bne     cp_return
        lea     CP_POLICY(a5),a0
        lea     EDITOR_METADATA_BASE+CFMD_ID,a1
        moveq   #19,d1
        moveq   #CP_ERROR_POLICY,d0
.policy:
        cmpm.w  (a0)+,(a1)+
        bne     cp_return
        dbra    d1,.policy
        movea.l CP_RANK_END(a5),a0
        movea.l CP_RANK_READ(a5),a1
        movea.l CP_NAME_END(a5),a2
        move.w  CP_NAME_CURSOR(a5),d5
        bsr     cp_bounds
        bne     cp_return
        ; Saved tails may contain this attempt's first append. Validate their
        ; addresses here, then recreate the terminators only during commit.
        lea     CP_ROSTER(a5),a2
        move.w  CP_POOL(a5),d4
        bsr     cp_preflight
        bne     cp_return
        move.w  sr,-(sp)
        ori.w   #$0700,sr
        lea     native_roster_tail,a0
        clr.l   (a0)+
        clr.l   (a0)+
        clr.l   (a0)+
        jsr     native_roster_init
        lea     CP_ROSTER(a5),a0
        lea     native_roster,a1
        moveq   #47,d0
        bsr     cp_copy_words
        lea     CP_SCALARS(a5),a0
        lea     native_mission_number,a1
        moveq   #5,d0
        bsr     cp_copy_words
        lea     native_campaign_scalars_b,a1
        moveq   #9,d0
        bsr     cp_copy_words
        lea     native_roster+4,a0
        lea     native_recruit_bindings,a1
        moveq   #7,d0
.bindings:
        move.w  #-1,(a0)
        move.w  #-1,(a1)+
        lea     12(a0),a0
        dbra    d0,.bindings
        clr.w   native_binding_backup_valid
        lea     CP_HOF(a5),a0
        lea     native_hall_of_fame,a1
        moveq   #14,d0
        bsr     cp_copy_words
        move.l  (a0)+,native_dead_rank_end
        move.l  (a0)+,native_dead_rank_cursor
        move.l  (a0)+,native_dead_name_end
        move.l  (a0)+,native_death_kill_counts
        move.w  (a0)+,native_map_index
        movea.l native_dead_rank_end,a0
        move.w  #-1,(a0)
        movea.l native_dead_name_end,a0
        move.w  #-1,(a0)
        move.w  (sp)+,sr
        moveq   #0,d0
        bra.s   cp_return

checkpoint_preflight:
        movem.l d1-d7/a0-a6,-(sp)
        lea     EDITOR_SESSION_BASE,a5
        bsr.s   cp_guard
        bne.s   cp_return
        bsr.s   cp_live_bounds
        bne.s   cp_return
        lea     native_roster,a2
        move.w  native_recruits_remaining,d4
        bsr     cp_preflight
cp_return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w   d0
        rts

cp_guard:
        moveq   #CP_ERROR_STATE,d0
        tst.w   CP_MODE(a5)
        beq.s   .return
        cmpi.w  #CP_SNAPSHOT_TAG,CP_SNAPSHOT_VALID(a5)
        bne.s   .return
        tst.w   native_gameplay_active
        bne.s   .return
        moveq   #0,d0
.return:
        tst.w   d0
        rts

cp_live_bounds:
        movea.l native_dead_rank_end,a0
        movea.l native_dead_rank_cursor,a1
        movea.l native_dead_name_end,a2
        move.w  native_next_recruit_name,d5
        bsr.s   cp_bounds
        bne.s   .return
        moveq   #CP_ERROR_LIST,d0
        cmpi.w  #-1,(a0)
        bne.s   .return
        cmpi.w  #-1,(a2)
        bne.s   .return
        moveq   #0,d0
.return:
        tst.w   d0
        rts

; Bounds include one final sentinel word after at most 360 entries. Return
; rank/name append counts in D3/D2 for the independent allocation preflight.
cp_bounds:
        move.l  a0,d0
        move.l  a1,d1
        or.l    d1,d0
        move.l  a2,d1
        or.l    d1,d0
        btst    #0,d0
        bne.s   .bad
        cmpa.l  #native_dead_ranks,a0
        blo.s   .bad
        cmpa.l  #native_dead_rank_limit,a0
        bhi.s   .bad
        cmpa.l  #native_dead_ranks,a1
        blo.s   .bad
        cmpa.l  a0,a1
        bhi.s   .bad
        cmpa.l  #native_dead_names,a2
        blo.s   .bad
        cmpa.l  #native_dead_name_limit,a2
        bhi.s   .bad
        cmpi.w  #360,d5
        bhi.s   .bad
        move.l  a0,d3
        subi.l  #native_dead_ranks,d3
        lsr.l   #1,d3
        move.l  a2,d2
        subi.l  #native_dead_names,d2
        lsr.l   #1,d2
        cmp.w   d5,d3
        bhi.s   .bad
        cmp.w   d5,d2
        bhi.s   .bad
        moveq   #0,d0
        rts
.bad:
        moveq   #CP_ERROR_LIST,d0
        rts

; A2 points at eight roster records, D4 pool, D5 next name, D2/D3 append counts.
; Demand follows native active-X semantics and only the first 30 placements.
cp_preflight:
        tst.w   d4
        bmi     .capacity
        moveq   #0,d6
        moveq   #7,d7
.roster:
        move.w  (a2),d0
        cmpi.w  #-1,d0
        beq.s   .next_roster
        cmpi.w  #360,d0
        bhs     .roster_bad
        cmp.w   d5,d0
        bhs     .roster_bad
        addq.w  #1,d6
.next_roster:
        lea     12(a2),a2
        dbra    d7,.roster
        moveq   #0,d1
        move.w  EDITOR_METADATA_BASE+CFMD_SPT_BYTES,d1
        cmpi.w  #10,d1
        blo     .spt
        cmpi.w  #430,d1
        bhi.s   .spt
        divu.w  #10,d1
        move.l  d1,d0
        swap    d0
        tst.w   d0
        bne.s   .spt
        cmpi.w  #30,d1
        bls.s   .count
        moveq   #30,d1
.count:
        subq.w  #1,d1
        moveq   #0,d7
        lea     EDITOR_SPT_BASE,a0
.placement:
        tst.w   8(a0)
        bne.s   .next_placement
        move.w  4(a0),d0
        addi.w  #16,d0
        bmi.s   .next_placement
        addq.w  #1,d7
.next_placement:
        lea     10(a0),a0
        dbra    d1,.placement
        cmpi.w  #8,d7
        bhi.s   .capacity
        move.w  d7,d0
        sub.w   d6,d0
        bmi.s   .no_new
        cmp.w   d4,d0
        bls.s   .allocate
        move.w  d4,d0
.allocate:
        move.w  d0,d4
        add.w   d6,d0
        bra.s   .assigned
.no_new:
        moveq   #0,d4
        move.w  d7,d0
.assigned:
        tst.w   d0
        beq.s   .capacity
        cmpi.w  #8,d0
        bhi.s   .capacity
        add.w   d0,d2
        add.w   d0,d3
        cmpi.w  #360,d2
        bhi.s   .capacity
        cmpi.w  #360,d3
        bhi.s   .capacity
        move.w  #360,d1
        sub.w   d5,d1
        cmp.w   d1,d4
        bhi.s   .capacity
        moveq   #0,d0
        rts
.spt:
        moveq   #CP_ERROR_SPT,d0
        rts
.roster_bad:
        moveq   #CP_ERROR_ROSTER,d0
        rts
.capacity:
        moveq   #CP_ERROR_CAPACITY,d0
        rts

cp_copy_words:
        move.w  (a0)+,(a1)+
        dbra    d0,cp_copy_words
        rts
checkpoint_end:
