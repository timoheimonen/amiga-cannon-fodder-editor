; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Private logical bits follow the same transaction as the phase map. Source
; indices are not identities: an independently untested copy may share a source.
phl_test_begin:
        move.l E7_CONTEXT,PHL_TEST_TAG
        move.b E7_TESTED,PHL_TEST_ORIGINAL
        clr.b PHL_TESTED
        cmpi.l #E7_TAG,PHL_TEST_TAG
        bne.s .return
        moveq #0,d0
        move.b PHL_TEST_ORIGINAL,d0
        cmpi.w #63,d0
        bhi.s .return
        moveq #0,d1
        move.b PHL_OWNER+AUR_PHASE_COUNT,d1
        moveq #1,d2
        lsl.w d1,d2
        subq.w #1,d2
        and.w d2,d0
        move.b d0,PHL_TESTED
.return:
        move.b PHL_TESTED,PHL_TEST_INITIAL
        rts
phl_test_check:
        move.l E7_CONTEXT,d1
        cmp.l PHL_TEST_TAG,d1
        bne.s .return
        move.b E7_TESTED,d1
        cmp.b PHL_TEST_ORIGINAL,d1
.return:
        rts
phl_private_changed:
        bsr phl_changed
        bne.s .return
        move.b PHL_TESTED,d1
        cmp.b PHL_TEST_INITIAL,d1
        beq.s .return
        moveq #1,d0
.return:
        tst.w d0
        rts

; Pure map API inputs; preserves D1-D7/A0-A6 like plm_apply. Only the private
; tested byte changes on successful operations. Canonical bits publish on Apply.
phl_map_apply:
        movem.l d1-d7,-(sp)
        move.l d0,d7
        bsr plm_apply
        tst.l d0
        bmi.s .return
        move.w d0,-(sp)
        moveq #0,d3
        move.b PHL_TESTED,d3
        cmpi.w #2,d7
        beq.s .copy
        move.l d3,d6
        lsr.w d1,d6
        andi.w #1,d6
        moveq #1,d5
        lsl.w d1,d5
        subq.w #1,d5
        move.w d3,d4
        and.w d5,d4
        not.w d5
        lsr.w #1,d3
        and.w d5,d3
        or.w d4,d3
        tst.w d7
        bne.s .store
        moveq #1,d5
        lsl.w d2,d5
        subq.w #1,d5
        move.w d3,d4
        and.w d5,d4
        not.w d5
        and.w d5,d3
        lsl.w #1,d3
        or.w d4,d3
        lsl.w d2,d6
        or.w d6,d3
        bra.s .store
.copy:
        moveq #0,d2
        move.b PHL_MAP+6,d2
        subq.w #1,d2
        bclr d2,d3
.store:
        move.b d3,PHL_TESTED
        move.w (sp)+,d0
.return:
        movem.l (sp)+,d1-d7
        tst.l d0
        rts
