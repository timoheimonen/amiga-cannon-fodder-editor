; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        xdef cf_encode_begin,cf_encode_phase,cf_encode_finish

CFE_STATE_BYTES equ 128
CFE_MAX_BYTES equ 3584
CFE_ERROR_ARGUMENT equ -1
CFE_ERROR_CAPACITY equ -2
CFE_ERROR_RECORD equ -3
CFE_ERROR_SEQUENCE equ -4
CFE_BASE equ 0
CFE_END equ 4
CFE_CURSOR equ 8
CFE_STATUS equ 12
CFE_COUNT equ 14
CFE_NEXT equ 16
CFE_REV equ 18
CFE_ID equ 20
CFE_GEN equ 24
CFE_RECRUITS equ 28
CFE_DONE equ 30
CFE_BYTES equ 32
CFE_CRC equ 36
CFE_TITLE equ 48
CFE_MAGIC equ 112

; Begin: A0=CFMD256 root, A1=destination, D0.l=capacity17..3584,
; A2=128-byte state. All three spans even, nonzero and disjoint.
; Phase: A0=CFMD256 phase, A2=state. Finish: A2=state.
; D0.w=0/-1 argument/-2 capacity/-3 record/-4 sequence.
; D1-D7/A0-A6/SP preserved. Begin argument failures leave output unchanged.
; After a successful begin, no CFMI is published until successful finish.
; Phase source remains a readable, even, disjoint 256-byte caller-owned span.
; State is private trusted scratch: do not modify or evict during a transaction.
cf_encode_begin:
        movem.l d1-d7/a0-a6,-(sp)
        cmpi.l #17,d0
        blo cfe_argument
        cmpi.l #CFE_MAX_BYTES,d0
        bhi cfe_argument
        move.l a0,d1
        beq cfe_argument
        move.l a1,d2
        beq cfe_argument
        move.l a2,d3
        beq cfe_argument
        or.l d2,d1
        or.l d3,d1
        btst #0,d1
        bne cfe_argument
        move.l a0,d1
        addi.l #256,d1
        bcs cfe_argument
        add.l d0,d2
        bcs cfe_argument
        addi.l #CFE_STATE_BYTES,d3
        bcs cfe_argument
        cmpa.l d2,a0
        bhs.s cfe_pair2
        cmpa.l d1,a1
        blo cfe_argument
cfe_pair2:
        cmpa.l d3,a0
        bhs.s cfe_pair3
        cmpa.l d1,a2
        blo cfe_argument
cfe_pair3:
        cmpa.l d3,a1
        bhs.s cfe_args_ok
        cmpa.l d2,a2
        blo cfe_argument
cfe_args_ok:
        movea.l a0,a5
        movea.l a2,a6
        movea.l a2,a3
        moveq #31,d1
cfe_clear:
        clr.l (a3)+
        dbra d1,cfe_clear
        move.l a1,CFE_BASE(a6)
        move.l d2,CFE_END(a6)
        move.l #$454E4331,CFE_MAGIC(a6)
        clr.l (a1)
        lea 16(a1),a4
        move.l a4,CFE_CURSOR(a6)
        bsr cfe_record
        bne cfe_bad_record
        moveq #0,d0
        move.b CFMD_PHASE_COUNT(a5),d0
        beq cfe_bad_record
        cmpi.w #6,d0
        bhi cfe_bad_record
        move.w d0,CFE_COUNT(a6)
        move.w CFMD_RECRUITS(a5),d0
        ble cfe_bad_record
        move.w d0,CFE_RECRUITS(a6)
        move.w CFMD_REVISION(a5),CFE_REV(a6)
        move.l CFMD_ID(a5),CFE_ID(a6)
        move.l CFMD_GENERATION(a5),CFE_GEN(a6)
        lea CFMD_TITLE(a5),a0
        bsr cfe_title_valid
        bne cfe_bad_record
        lea CFMD_TITLE(a5),a0
        lea CFE_TITLE(a6),a1
        moveq #15,d1
cfe_copy_title:
        move.l (a0)+,(a1)+
        dbra d1,cfe_copy_title
        lea cfe_root_id(pc),a0
        bsr cfe_literal
        move.l CFE_ID(a6),d0
        moveq #0,d1
        bsr cfe_hex8
        lea cfe_root_recruits(pc),a0
        bsr cfe_literal
        move.w CFE_RECRUITS(a6),d0
        bsr cfe_number
        lea cfe_root_phases(pc),a0
        bsr cfe_literal
        bra cfe_complete_call

cf_encode_phase:
        movem.l d1-d7/a0-a6,-(sp)
        movea.l a0,a5
        movea.l a2,a6
        bsr cfe_state
        bne cfe_return
        bsr cfe_record
        bne cfe_bad_record
        moveq #0,d0
        move.b CFMD_PHASE_COUNT(a5),d0
        cmp.w CFE_COUNT(a6),d0
        bne cfe_bad_record
        moveq #0,d0
        move.b CFMD_PHASE_INDEX(a5),d0
        cmp.w CFE_NEXT(a6),d0
        bne cfe_sequence
        cmp.w CFE_COUNT(a6),d0
        bhs cfe_sequence
        lea CFMD_PHASE_TITLE(a5),a0
        bsr cfe_title_valid
        bne cfe_bad_record
        move.w CFMD_MAP_BYTES(a5),d0
        beq cfe_bad_record
        cmpi.w #15096,d0
        bhi cfe_bad_record
        move.w CFMD_SPT_BYTES(a5),d0
        beq cfe_bad_record
        cmpi.w #430,d0
        bhi cfe_bad_record
        cmpi.b #20,CFMD_AGGRESSION_MAX(a5)
        bhi cfe_bad_record
        move.b CFMD_AGGRESSION_MIN(a5),d0
        cmp.b CFMD_AGGRESSION_MAX(a5),d0
        bhi cfe_bad_record
        cmpi.b #7,CFMD_RANK(a5)
        bhi cfe_bad_record
        move.b CFMD_GRENADES(a5),d0
        beq.s cfe_grenades_ok
        cmpi.b #2,d0
        bne cfe_bad_record
cfe_grenades_ok:
        cmpi.b #1,CFMD_ROCKETS(a5)
        bhi cfe_bad_record
        cmpi.b #7,CFMD_FLAGS(a5)
        bhi cfe_bad_record
        moveq #0,d6
        move.b CFMD_OBJECTIVE_COUNT(a5),d6
        beq cfe_bad_record
        cmpi.w #8,d6
        bhi cfe_bad_record
        subq.w #1,d6
        moveq #0,d2
        lea CFMD_OBJECTIVES(a5),a0
cfe_object_check:
        moveq #0,d1
        move.b (a0)+,d1
        beq cfe_bad_record
        cmpi.w #8,d1
        bhi cfe_bad_record
        subq.w #1,d1
        bset d1,d2
        bne cfe_bad_record
        dbra d6,cfe_object_check
        cmp.b CFMD_OBJECTIVE_MASK(a5),d2
        bne cfe_bad_record
        tst.w CFE_NEXT(a6)
        beq.s cfe_first
        moveq #44,d0
        bsr cfe_put
cfe_first:
        lea cfe_phase_aggression(pc),a0
        bsr cfe_literal
        moveq #0,d0
        move.b CFMD_AGGRESSION_MAX(a5),d0
        bsr cfe_number
        lea cfe_minimum(pc),a0
        bsr cfe_literal
        moveq #0,d0
        move.b CFMD_AGGRESSION_MIN(a5),d0
        bsr cfe_number
        lea cfe_countdown(pc),a0
        bsr cfe_literal
        lea cfe_null(pc),a0
        btst #2,CFMD_FLAGS(a5)
        beq.s cfe_countdown_emit
        lea cfe_final_map(pc),a0
cfe_countdown_emit:
        bsr cfe_literal
        lea cfe_enemy(pc),a0
        bsr cfe_literal
        moveq #0,d0
        btst #0,CFMD_FLAGS(a5)
        sne d0
        bsr cfe_boolean
        lea cfe_grenades(pc),a0
        bsr cfe_literal
        moveq #0,d0
        move.b CFMD_GRENADES(a5),d0
        bsr cfe_number
        lea cfe_map(pc),a0
        bsr cfe_literal
        move.l CFMD_MAP_CRC(a5),d0
        move.w CFMD_MAP_BYTES(a5),d6
        lea cfe_map_suffix(pc),a3
        bsr cfe_reference
        lea cfe_rank(pc),a0
        bsr cfe_literal
        moveq #0,d0
        move.b CFMD_RANK(a5),d0
        bsr cfe_number
        lea cfe_objectives(pc),a0
        bsr cfe_literal
        moveq #0,d7
        move.b CFMD_OBJECTIVE_COUNT(a5),d7
        subq.w #1,d7
        moveq #0,d6
cfe_objective_emit:
        moveq #0,d0
        move.b CFMD_OBJECTIVES(a5,d6.w),d0
        bsr cfe_number
        cmp.w d6,d7
        beq.s cfe_objects_done
        moveq #44,d0
        bsr cfe_put
        addq.w #1,d6
        bra.s cfe_objective_emit
cfe_objects_done:
        lea cfe_overview(pc),a0
        bsr cfe_literal
        moveq #0,d0
        btst #1,CFMD_FLAGS(a5)
        sne d0
        bsr cfe_boolean
        lea cfe_rockets(pc),a0
        bsr cfe_literal
        moveq #0,d0
        move.b CFMD_ROCKETS(a5),d0
        bsr cfe_number
        lea cfe_spt(pc),a0
        bsr cfe_literal
        move.l CFMD_SPT_CRC(a5),d0
        move.w CFMD_SPT_BYTES(a5),d6
        lea cfe_spt_suffix(pc),a3
        bsr cfe_reference
        lea cfe_title(pc),a0
        bsr cfe_literal
        lea CFMD_PHASE_TITLE(a5),a0
        bsr cfe_quoted
        moveq #125,d0
        bsr cfe_put
        addq.w #1,CFE_NEXT(a6)
        bra cfe_complete_call

cf_encode_finish:
        movem.l d1-d7/a0-a6,-(sp)
        movea.l a2,a6
        bsr cfe_state
        bne cfe_return
        move.w CFE_NEXT(a6),d0
        cmp.w CFE_COUNT(a6),d0
        bne cfe_sequence
        lea cfe_revision(pc),a0
        bsr cfe_literal
        move.w CFE_REV(a6),d0
        bsr cfe_number
        lea cfe_schema(pc),a0
        bsr cfe_literal
        lea CFE_TITLE(a6),a0
        bsr cfe_quoted
        moveq #125,d0
        bsr cfe_put
        move.l a4,CFE_CURSOR(a6)
        tst.w CFE_STATUS(a6)
        bne cfe_complete_call
        movea.l CFE_BASE(a6),a0
        move.l a4,d2
        sub.l a0,d2
        move.l d2,CFE_BYTES(a6)
        subi.l #16,d2
        move.l d2,8(a0)
        move.l #$00010010,4(a0)
        lea 16(a0),a0
        move.l d2,d1
        bsr read_crc32
        move.l d0,CFE_CRC(a6)
        movea.l CFE_BASE(a6),a0
        move.l d0,12(a0)
        move.l #$43464D49,(a0)
        move.w #1,CFE_DONE(a6)
        bra.s cfe_complete_call

cfe_record:
        cmpi.l #CFMD_MAGIC,(a5)
        bne.s cfe_record_return
        cmpi.l #$00010100,4(a5)
cfe_record_return:
        rts
cfe_title_valid:
        moveq #0,d1
cfe_title_check:
        move.b (a0)+,d0
        cmpi.b #$ff,d0
        beq.s cfe_title_end
        cmpi.b #32,d0
        blo.s cfe_title_bad
        cmpi.b #126,d0
        bhi.s cfe_title_bad
        addq.w #1,d1
        cmpi.w #63,d1
        bls.s cfe_title_check
cfe_title_bad:
        moveq #CFE_ERROR_RECORD,d0
        rts
cfe_title_end:
        tst.w d1
        beq.s cfe_title_bad
        moveq #0,d0
        rts
cfe_state:
        move.l a6,d0
        beq.s cfe_state_bad
        btst #0,d0
        bne.s cfe_state_bad
        cmpi.l #$454E4331,CFE_MAGIC(a6)
        bne.s cfe_state_bad
        tst.w CFE_DONE(a6)
        bne.s cfe_state_bad
        movea.l CFE_CURSOR(a6),a4
        move.w CFE_STATUS(a6),d0
        rts
cfe_state_bad:
        moveq #CFE_ERROR_SEQUENCE,d0
        rts
cfe_argument:
        moveq #CFE_ERROR_ARGUMENT,d0
        bra.s cfe_return
cfe_bad_record:
        move.w #CFE_ERROR_RECORD,CFE_STATUS(a6)
        bra.s cfe_complete_call
cfe_sequence:
        move.w #CFE_ERROR_SEQUENCE,CFE_STATUS(a6)
cfe_complete_call:
        move.l a4,CFE_CURSOR(a6)
        move.w CFE_STATUS(a6),d0
cfe_return:
        movem.l (sp)+,d1-d7/a0-a6
        rts

cfe_put:
        cmpa.l CFE_END(a6),a4
        bhs.s cfe_full
        move.b d0,(a4)+
        rts
cfe_full:
        move.w #CFE_ERROR_CAPACITY,CFE_STATUS(a6)
        rts
cfe_literal:
        move.b (a0)+,d0
        beq.s cfe_literal_end
        bsr.s cfe_put
        bra.s cfe_literal
cfe_literal_end:
        rts
cfe_quoted:
        moveq #34,d0
        bsr.s cfe_put
cfe_quote_loop:
        move.b (a0)+,d0
        cmpi.b #$ff,d0
        beq.s cfe_quote_end
        cmpi.b #34,d0
        beq.s cfe_escape
        cmpi.b #92,d0
        bne.s cfe_quote_byte
cfe_escape:
        move.b d0,d1
        moveq #92,d0
        bsr.s cfe_put
        move.b d1,d0
cfe_quote_byte:
        bsr.s cfe_put
        bra.s cfe_quote_loop
cfe_quote_end:
        moveq #34,d0
        bra.s cfe_put
cfe_boolean:
        lea cfe_false(pc),a0
        tst.b d0
        beq.s cfe_boolean_emit
        lea cfe_true(pc),a0
cfe_boolean_emit:
        bra.s cfe_literal
cfe_number:
        andi.l #$ffff,d0
        moveq #0,d2
cfe_divide:
        divu.w #10,d0
        move.l d0,d1
        swap d1
        addi.w #48,d1
        move.w d1,-(sp)
        addq.w #1,d2
        andi.l #$ffff,d0
        bne.s cfe_divide
cfe_digits:
        move.w (sp)+,d0
        bsr.s cfe_put
        subq.w #1,d2
        bne.s cfe_digits
        rts
cfe_hex8:
        move.l d0,d2
        moveq #7,d3
cfe_hex_loop:
        rol.l #4,d2
        move.l d2,d0
        andi.w #15,d0
        cmpi.w #10,d0
        blo.s cfe_decimal_hex
        addi.w #55,d0
        tst.b d1
        beq.s cfe_hex_emit
        addi.w #32,d0
        bra.s cfe_hex_emit
cfe_decimal_hex:
        addi.w #48,d0
cfe_hex_emit:
        bsr cfe_put
        dbra d3,cfe_hex_loop
        rts
cfe_reference:
        moveq #0,d1
        bsr.s cfe_hex8
        lea cfe_ref_length(pc),a0
        bsr cfe_literal
        move.w d6,d0
        bsr.s cfe_number
        lea cfe_ref_name(pc),a0
        bsr cfe_literal
        move.l CFE_GEN(a6),d0
        moveq #1,d1
        bsr.s cfe_hex8
        moveq #48,d0
        bsr cfe_put
        move.w CFE_NEXT(a6),d0
        addi.w #48,d0
        bsr cfe_put
        movea.l a3,a0
        bra cfe_literal
cfe_root_id: dc.b '{"id":"',0
cfe_root_recruits: dc.b '","initial_recruits":',0
cfe_root_phases: dc.b ',"phases":[',0
cfe_phase_aggression: dc.b '{"aggression":{"maximum":',0
cfe_minimum: dc.b ',"minimum":',0
cfe_countdown: dc.b '},"countdown":',0
cfe_null: dc.b 'null',0
cfe_final_map: dc.b '"original-final-map"',0
cfe_enemy: dc.b ',"enemy_grenades":',0
cfe_grenades: dc.b ',"grenades_per_troop":',0
cfe_map: dc.b ',"map":{"crc32":"',0
cfe_ref_length: dc.b '","length":',0
cfe_ref_name: dc.b ',"name":"',0
cfe_map_suffix: dc.b '.map"}',0
cfe_spt_suffix: dc.b '.spt"}',0
cfe_rank: dc.b ',"new_recruit_rank":',0
cfe_objectives: dc.b ',"objectives":[',0
cfe_overview: dc.b '],"overview":',0
cfe_rockets: dc.b ',"rockets_per_troop":',0
cfe_spt: dc.b ',"spt":{"crc32":"',0
cfe_title: dc.b ',"title":',0
cfe_revision: dc.b '],"revision":',0
cfe_schema: dc.b ',"schema":"cannon-fodder-custom-mission-v1","title":',0
cfe_true: dc.b 'true',0
cfe_false: dc.b 'false',0
        even
