; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        xdef cf_payload_validate

; A0=raw MAP, D0.l=MAP bytes, A1=raw SPT, D1.l=SPT bytes,
; A2=validated CFMD256, A3=CFVR32 output, A4=128-byte scratch.
; D0.w=structural status. Preserve D2-D7/A0-A6 and SP; D1/CCR unspecified.
; Every span must be addressable, even, disjoint and outside code/caller stack.
; Structural failure never writes output. Success publishes even with gameplay
; errors, and always sets PLAYTEST review. No raw input or CFMD is modified.
; With PAYLOAD_STRUCTURAL_ONLY defined, the gameplay checks are left out: the
; structural and CRC refusals are unchanged, but success publishes no CFVR
; output. Overlays that never read CFVR select it to save space.
;
; Scratch: candidate32, companion membership43, seven counters, flags2,
; pixel bounds8, input lengths8, reserved28. No pointers persist in scratch.
PV_COMPANIONS   equ 32
PV_TROOPS       equ 75
PV_ENEMIES      equ 76
PV_BUILDINGS    equ 77
PV_COMPUTERS    equ 78
PV_RESCUE       equ 79
PV_TENTS        equ 80
PV_HOMES        equ 81
PV_OBJECTIVES   equ 82
PV_FLAGS        equ 83
PV_PIXEL_WIDTH  equ 84
PV_PIXEL_HEIGHT equ 88
PV_MAP_BYTES    equ 92
PV_SPT_BYTES    equ 96

; With PAYLOAD_DIAGNOSTICS defined, every finding is also reported with its
; location class to vald_emit (bit 15 review, bits 8-9: 0 mission, 1 cell,
; 2 object, 3 marker), which preserves all registers and flags.
PAYLOAD_FINDING macro
        ifd PAYLOAD_DIAGNOSTICS
        bsr vald_emit
        dc.w \1
        endif
        endm

cf_payload_validate:
        movem.l d2-d7/a0-a6,-(sp)
        tst.l   d0
        beq     .argument
        cmpi.l  #15096,d0
        bhi     .argument
        tst.l   d1
        beq     .argument
        cmpi.l  #430,d1
        bhi     .argument
        ; Temporary stack intervals make all ten overlap checks symmetric.
        lea     -40(sp),sp
        move.l  a0,0(sp)
        move.l  d0,4(sp)
        move.l  a1,8(sp)
        move.l  d1,12(sp)
        move.l  a2,16(sp)
        move.l  #256,20(sp)
        move.l  a3,24(sp)
        move.l  #32,28(sp)
        move.l  a4,32(sp)
        move.l  #128,36(sp)
        movea.l sp,a5
        moveq   #4,d7
.intervals:
        move.l  (a5),d2
        beq     .bad_intervals
        btst    #0,d2
        bne     .bad_intervals
        add.l   4(a5),d2
        bcs     .bad_intervals
        move.l  d2,4(a5)
        addq.l  #8,a5
        dbra    d7,.intervals
        movea.l sp,a5
        moveq   #3,d7
.outer_interval:
        lea     8(a5),a6
        move.w  d7,d6
.inner_interval:
        move.l  4(a5),d2
        cmp.l   (a6),d2
        bls.s   .disjoint
        move.l  4(a6),d2
        cmp.l   (a5),d2
        bhi     .bad_intervals
.disjoint:
        addq.l  #8,a6
        dbra    d6,.inner_interval
        addq.l  #8,a5
        dbra    d7,.outer_interval
        lea     40(sp),sp
        movea.l a0,a5
        movea.l a1,a6
        movea.l a4,a0
        moveq   #31,d2
.clear:
        clr.l   (a0)+
        dbra    d2,.clear
        move.l  d0,PV_MAP_BYTES(a4)
        move.l  d1,PV_SPT_BYTES(a4)
        cmpi.l  #CFMD_MAGIC,(a2)
        bne     .metadata
        cmpi.l  #$00010100,4(a2)
        bne     .metadata
        moveq   #0,d2
        move.b  CFMD_PHASE_COUNT(a2),d2
        beq     .metadata
        cmpi.b  #6,d2
        bhi     .metadata
        cmp.b   CFMD_PHASE_INDEX(a2),d2
        bls     .metadata
        move.b  CFMD_OBJECTIVE_MASK(a2),PV_OBJECTIVES(a4)
        beq     .metadata
        move.b  CFMD_FLAGS(a2),d2
        move.b  d2,PV_FLAGS(a4)
        andi.b  #$F8,d2
        bne     .metadata
        cmp.w   CFMD_MAP_BYTES(a2),d0
        bne     .length
        cmp.w   CFMD_SPT_BYTES(a2),d1
        bne     .length
        movea.l a5,a0
        move.l  d0,d1
        bsr     read_crc32
        cmp.l   CFMD_MAP_CRC(a2),d0
        bne     .crc
        movea.l a6,a0
        move.l  PV_SPT_BYTES(a4),d1
        bsr     read_crc32
        cmp.l   CFMD_SPT_CRC(a2),d0
        bne     .crc
        cmpi.l  #96,PV_MAP_BYTES(a4)
        blo     .map
        cmpi.l  #$63666564,80(a5)
        bne     .map
        moveq   #0,d2
        moveq   #0,d3
        move.w  84(a5),d2
        beq     .map
        move.w  86(a5),d3
        beq     .map
        move.w  d2,CFVR_WIDTH(a4)
        move.w  d3,CFVR_HEIGHT(a4)
        mulu.w  d3,d2
        cmpi.l  #7500,d2
        bhi     .map
        move.w  d2,d7
        add.l   d2,d2
        addi.l  #96,d2
        cmp.l   PV_MAP_BYTES(a4),d2
        bne     .map
        lea     .resource_pairs(pc),a0
        moveq   #0,d3
.pair:
        move.l  (a0),d0
        cmp.l   (a5),d0
        bne.s   .next_pair
        move.l  4(a5),d0
        clr.b   d0
        cmp.l   4(a0),d0
        bne.s   .next_pair
        move.l  8(a0),d0
        cmp.l   16(a5),d0
        bne.s   .next_pair
        move.l  20(a5),d0
        clr.b   d0
        cmp.l   12(a0),d0
        bne.s   .next_pair
        lea     7(a5),a1
        bsr     .resource_end
        bne.s   .next_pair
        lea     23(a5),a1
        bsr     .resource_end
        beq.s   .pair_found
.next_pair:
        lea     16(a0),a0
        addq.w  #1,d3
        cmpi.w  #6,d3
        blo.s   .pair
        bra     .resource
.pair_found:
        move.b  d3,CFVR_RESOURCE_PAIR(a4)
        move.l  PV_SPT_BYTES(a4),d0
        divu.w  #10,d0
        move.l  d0,d1
        swap    d1
        tst.w   d1
        bne     .spt
        move.w  d0,d6
        move.w  d6,CFVR_OBJECTS(a4)
        movea.l a6,a0
        move.w  d6,d0
        subq.w  #1,d0
.type_check:
        cmpi.w  #$6E,8(a0)
        bhi     .spt
        lea     10(a0),a0
        dbra    d0,.type_check
        ifd PAYLOAD_STRUCTURAL_ONLY
        moveq   #0,d0
        bra.s   .return
        else
        moveq   #0,d4
        moveq   #0,d5
        bset    #CFVR_R_PLAYTEST,d5
        PAYLOAD_FINDING CFVR_R_PLAYTEST|$8000
        moveq   #0,d0
        move.w  CFVR_WIDTH(a4),d0
        lsl.l   #4,d0
        move.l  d0,PV_PIXEL_WIDTH(a4)
        moveq   #0,d0
        move.w  CFVR_HEIGHT(a4),d0
        lsl.l   #4,d0
        move.l  d0,PV_PIXEL_HEIGHT(a4)
        cmpi.w  #19,CFVR_WIDTH(a4)
        blo.s   .small_grid
        cmpi.w  #15,CFVR_HEIGHT(a4)
        bhs.s   .cells
.small_grid:
        bset    #CFVR_E_GRID_FLOOR,d4
        PAYLOAD_FINDING CFVR_E_GRID_FLOOR|$0000
.cells:
        lea     96(a5),a0
        subq.w  #1,d7
.cell:
        move.w  (a0)+,d0
        move.w  d0,d1
        andi.w  #$1FF,d1
        cmpi.w  #399,d1
        blo.s   .cell_reserved
        beq.s   .tile399
        bset    #CFVR_E_TILE_RANGE,d4
        PAYLOAD_FINDING CFVR_E_TILE_RANGE|$0100
        bra.s   .cell_reserved
.tile399:
        bset    #CFVR_R_TILE_399,d5
        PAYLOAD_FINDING CFVR_R_TILE_399|$8100
.cell_reserved:
        move.w  d0,d1
        andi.w  #$1E00,d1
        beq.s   .cell_marker
        bset    #CFVR_R_RESERVED_CELL,d5
        PAYLOAD_FINDING CFVR_R_RESERVED_CELL|$8100
.cell_marker:
        lsr.w   #8,d0
        lsr.w   #5,d0
        beq.s   .cell_next
        addq.w  #1,CFVR_MARKERS(a4)
        cmpi.w  #5,d0
        blo.s   .marker_los
        bset    #CFVR_R_MARKER_CLASS,d5
        PAYLOAD_FINDING CFVR_R_MARKER_CLASS|$8100
.marker_los:
        cmpi.w  #4,d0
        beq.s   .cell_next
        bset    #CFVR_R_MARKER_LOS,d5
        PAYLOAD_FINDING CFVR_R_MARKER_LOS|$8100
.cell_next:
        dbra    d7,.cell
        cmpi.w  #10,CFVR_MARKERS(a4)
        bls.s   .owners
        bset    #CFVR_E_MARKER_CAPACITY,d4
        PAYLOAD_FINDING CFVR_E_MARKER_CAPACITY|$0300
.owners:
        movea.l a6,a0
        moveq   #0,d7
.owner:
        move.w  8(a0),d0
        lea     .recipes(pc),a1
        moveq   #0,d1
        move.b  (a1,d0.w),d1
        beq       .owner_next
        lsl.w   #2,d1
        lea     .suffixes(pc),a1
        adda.w  d1,a1
        moveq   #0,d2
        move.b  (a1)+,d2
        move.w  d7,d3
        addq.w  #1,d3
        add.w   d2,d3
        cmpi.w  #43,d3
        bls.s   .owner_primary
        bset    #CFVR_E_BUNDLE_RENDER,d4
        PAYLOAD_FINDING CFVR_E_BUNDLE_RENDER|$0200
.owner_primary:
        cmpi.w  #$3C,d0
        beq.s   .owner_suffix
        cmpi.w  #30,d3
        bls.s   .owner_suffix
        bset    #CFVR_E_BUNDLE_PRIMARY,d4
        PAYLOAD_FINDING CFVR_E_BUNDLE_PRIMARY|$0200
.owner_suffix:
        cmp.w   d6,d3
        bhi.s   .bad_suffix
        movem.l a0/d2,-(sp)
.suffix_compare:
        lea     10(a0),a0
        moveq   #0,d1
        move.b  (a1)+,d1
        cmp.w   8(a0),d1
        bne.s   .suffix_mismatch
        subq.w  #1,d2
        bne.s   .suffix_compare
        movem.l (sp)+,a0/d2
        move.w  4(a0),d1
        addi.w  #16,d1
        bmi.s   .owner_next
        move.w  d7,d1
        addq.w  #1,d1
.authorize:
        move.b  #1,PV_COMPANIONS(a4,d1.w)
        addq.w  #1,d1
        subq.w  #1,d2
        bne.s   .authorize
        bra.s   .owner_next
.suffix_mismatch:
        movem.l (sp)+,a0/d2
.bad_suffix:
        bset    #CFVR_E_COMPANION_SUFFIX,d4
        PAYLOAD_FINDING CFVR_E_COMPANION_SUFFIX|$0200
.owner_next:
        lea     10(a0),a0
        addq.w  #1,d7
        cmp.w   d6,d7
        blo     .owner
        movea.l a6,a0
        moveq   #0,d7
.object:
        move.w  8(a0),d0
        lea     .type_flags(pc),a1
        moveq   #0,d3
        move.b  (a1,d0.w),d3
        move.w  4(a0),d1
        move.w  d1,d2
        addi.w  #16,d2
        cmpi.w  #$FFFF,d2
        bne.s   .object_disabled
        bset    #CFVR_E_RUNTIME_SENTINEL,d4
        PAYLOAD_FINDING CFVR_E_RUNTIME_SENTINEL|$0200
        bra.s   .object_activity
.object_disabled:
        cmpi.w  #$8000,d1
        bne.s   .object_range
        cmpi.w  #4,d0
        beq.s   .membership
        cmpi.w  #$29,d0
        bne.s   .unowned
.membership:
        tst.b   PV_COMPANIONS(a4,d7.w)
        bne.s   .object_activity
.unowned:
        bset    #CFVR_E_DISABLED_UNOWNED,d4
        PAYLOAD_FINDING CFVR_E_DISABLED_UNOWNED|$0200
        bra.s   .object_activity
.object_range:
        cmpi.w  #$7FEF,d1
        bls.s   .object_activity
        bset    #CFVR_E_TRANSFORMED_X,d4
        PAYLOAD_FINDING CFVR_E_TRANSFORMED_X|$0200
.object_activity:
        tst.w   d2
        bpl.s   .active_object
        btst    #1,d3
        beq     .object_next
        bset    #CFVR_E_DISABLED_COUNTED,d4
        PAYLOAD_FINDING CFVR_E_DISABLED_COUNTED|$0200
        bra     .object_next
.active_object:
        tst.w   6(a0)
        bpl.s   .anchor
        bset    #CFVR_E_NEGATIVE_Y,d4
        PAYLOAD_FINDING CFVR_E_NEGATIVE_Y|$0200
        bra.s   .primary
.anchor:
        moveq   #0,d2
        move.w  d1,d2
        cmp.l   PV_PIXEL_WIDTH(a4),d2
        bhs.s   .off_map
        move.w  6(a0),d2
        cmp.l   PV_PIXEL_HEIGHT(a4),d2
        blo.s   .primary
.off_map:
        bset    #CFVR_R_OFF_MAP,d5
        PAYLOAD_FINDING CFVR_R_OFF_MAP|$8200
.primary:
        btst    #0,d3
        beq.s   .count_types
        cmpi.w  #30,d7
        blo.s   .count_types
        bset    #CFVR_E_PRIMARY_SLOT,d4
        PAYLOAD_FINDING CFVR_E_PRIMARY_SLOT|$0200
.count_types:
        tst.w   d0
        bne.s   .enemy
        addq.b  #1,PV_TROOPS(a4)
        cmpi.w  #30,d7
        bhs.s   .enemy
        addq.w  #1,CFVR_TROOP_DEMAND(a4)
.enemy:
        btst    #2,d3
        beq.s   .building
        addq.b  #1,PV_ENEMIES(a4)
.building:
        btst    #3,d3
        beq.s   .computer
        addq.b  #1,PV_BUILDINGS(a4)
.computer:
        btst    #4,d3
        beq.s   .rescue
        addq.b  #1,PV_COMPUTERS(a4)
.rescue:
        btst    #5,d3
        beq.s   .tent
        addq.b  #1,PV_RESCUE(a4)
.tent:
        btst    #6,d3
        beq.s   .home
        addq.b  #1,PV_TENTS(a4)
.home:
        btst    #7,d3
        beq.s   .object_next
        addq.b  #1,PV_HOMES(a4)
.object_next:
        lea     10(a0),a0
        addq.w  #1,d7
        cmp.w   d6,d7
        blo     .object
        tst.w   CFVR_TROOP_DEMAND(a4)
        bne.s   .troop_capacity
        bset    #CFVR_E_NO_TROOP,d4
        PAYLOAD_FINDING CFVR_E_NO_TROOP|$0000
.troop_capacity:
        cmpi.b  #8,PV_TROOPS(a4)
        bls.s   .objectives
        bset    #CFVR_E_TROOP_CAPACITY,d4
        PAYLOAD_FINDING CFVR_E_TROOP_CAPACITY|$0000
.objectives:
        move.b  PV_OBJECTIVES(a4),d0
        move.b  d0,d1
        andi.b  #$97,d1
        bne.s   .label_dependencies
        bset    #CFVR_E_NO_POSITIVE,d4
        PAYLOAD_FINDING CFVR_E_NO_POSITIVE|$0000
.label_dependencies:
        move.b  d0,d1
        andi.b  #$60,d1
        beq.s   .enemy_gate
        move.b  d0,d1
        andi.b  #3,d1
        cmpi.b  #3,d1
        beq.s   .enemy_gate
        bset    #CFVR_E_LABEL_DEPENDENCIES,d4
        PAYLOAD_FINDING CFVR_E_LABEL_DEPENDENCIES|$0000
.enemy_gate:
        btst    #0,d0
        beq.s   .building_gate
        tst.b   PV_ENEMIES(a4)
        bne.s   .building_gate
        bset    #CFVR_R_EMPTY_ENEMY,d5
        PAYLOAD_FINDING CFVR_R_EMPTY_ENEMY|$8000
.building_gate:
        btst    #1,d0
        beq.s   .factory_gate
        tst.b   PV_BUILDINGS(a4)
        bne.s   .factory_gate
        bset    #CFVR_R_EMPTY_BUILDING,d5
        PAYLOAD_FINDING CFVR_R_EMPTY_BUILDING|$8000
.factory_gate:
        btst    #5,d0
        beq.s   .computer_gate
        bset    #CFVR_R_FACTORY,d5
        PAYLOAD_FINDING CFVR_R_FACTORY|$8000
.computer_gate:
        btst    #6,d0
        beq.s   .rescue_gate
        tst.b   PV_COMPUTERS(a4)
        bne.s   .rescue_gate
        bset    #CFVR_E_MISSING_COMPUTER,d4
        PAYLOAD_FINDING CFVR_E_MISSING_COMPUTER|$0000
.rescue_gate:
        andi.b  #$14,d0
        beq.s   .home_gate
        tst.b   PV_RESCUE(a4)
        bne.s   .tent_gate
        bset    #CFVR_E_MISSING_RESCUE,d4
        PAYLOAD_FINDING CFVR_E_MISSING_RESCUE|$0000
.tent_gate:
        tst.b   PV_TENTS(a4)
        bne.s   .multiple_tents
        bset    #CFVR_E_MISSING_TENT,d4
        PAYLOAD_FINDING CFVR_E_MISSING_TENT|$0000
.multiple_tents:
        cmpi.b  #1,PV_TENTS(a4)
        bls.s   .home_gate
        bset    #CFVR_R_MULTIPLE_TENTS,d5
        PAYLOAD_FINDING CFVR_R_MULTIPLE_TENTS|$8000
.home_gate:
        btst    #7,PV_OBJECTIVES(a4)
        beq.s   .countdown
        bset    #CFVR_R_CIVILIAN_HOME,d5
        PAYLOAD_FINDING CFVR_R_CIVILIAN_HOME|$8000
        tst.b   PV_HOMES(a4)
        bne.s   .countdown
        bset    #CFVR_E_MISSING_HOME,d4
        PAYLOAD_FINDING CFVR_E_MISSING_HOME|$0000
.countdown:
        move.b  PV_FLAGS(a4),d0
        andi.b  #6,d0
        cmpi.b  #6,d0
        bne.s   .publish
        bset    #CFVR_E_COUNTDOWN_OVERVIEW,d4
        PAYLOAD_FINDING CFVR_E_COUNTDOWN_OVERVIEW|$0000
.publish:
        move.l  #CFVR_MAGIC,(a4)
        move.l  #$00010020,4(a4)
        move.l  d4,CFVR_ERRORS(a4)
        move.l  d5,CFVR_REVIEWS(a4)
        move.b  CFMD_PHASE_INDEX(a2),CFVR_PHASE(a4)
        movea.l a4,a0
        moveq   #7,d1
.copy:
        move.l  (a0)+,(a3)+
        dbra    d1,.copy
        moveq   #0,d0
        bra.s   .return
        endif
.bad_intervals:
        lea     40(sp),sp
.argument:
        moveq   #CFVR_ERROR_ARGUMENT,d0
        bra.s   .return
.metadata:
        moveq   #CFVR_ERROR_METADATA,d0
        bra.s   .return
.length:
        moveq   #CFVR_ERROR_LENGTH,d0
        bra.s   .return
.crc:
        moveq   #CFVR_ERROR_CRC,d0
        bra.s   .return
.map:
        moveq   #CFVR_ERROR_MAP,d0
        bra.s   .return
.resource:
        moveq   #CFVR_ERROR_RESOURCE,d0
        bra.s   .return
.spt:
        moveq   #CFVR_ERROR_SPT,d0
.return:
        movem.l (sp)+,d2-d7/a0-a6
        rts

; A1 points to byte seven of an even filename slot. The native resource helper
; accepts the stem alone or a .blk filename; no authored bytes are rewritten.
.resource_end:
        tst.b   (a1)
        beq.s   .resource_return
        cmpi.b  #'.',(a1)
        bne.s   .resource_return
        cmpi.l  #$626C6B00,1(a1)
.resource_return:
        rts
.resource_pairs:
        dc.b "junbase",0,"junsub0",0
        dc.b "junbase",0,"junsub1",0
        dc.b "icebase",0,"icesub0",0
        dc.b "desbase",0,"dessub0",0
        dc.b "morbase",0,"morsub0",0
        dc.b "intbase",0,"intsub0",0
        ifnd PAYLOAD_STRUCTURAL_ONLY
.suffixes:
        dc.b 0,0,0,0, 1,4,0,0, 2,4,4,0
        dc.b 3,4,4,$29, 2,4,$29,0, 1,$29,0,0
; Type flags: primary,counted,enemy,building,computer,rescue,tent,home.
.type_flags:
        dc.b $03,$00,$00,$00,$00,$07,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        dc.b $00,$00,$00,$00,$08,$00,$00,$00,$00,$08,$00,$00,$00,$00,$00,$00
        dc.b $00,$00,$00,$00,$07,$00,$00,$00,$05,$00,$05,$05,$05,$00,$00,$00
        dc.b $00,$01,$01,$01,$01,$00,$00,$00,$00,$00,$00,$00,$00,$01,$01,$01
        dc.b $01,$01,$00,$00,$00,$05,$01,$00,$23,$40,$00,$00,$00,$00,$01,$01
        dc.b $05,$05,$05,$01,$05,$05,$00,$00,$08,$00,$80,$00,$00,$00,$00,$00
        dc.b $00,$00,$00,$01,$08,$01,$01,$01,$01,$05,$23,$01,$18,$18,$18
; Recipe zero is no suffix; other values index the four-byte table.
.recipes:
        dc.b 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        dc.b 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        dc.b 0,0,0,0,0,0,0,0,3,0,3,3,3,0,0,0
        dc.b 0,2,2,2,2,0,0,0,0,0,0,0,1,0,0,1
        dc.b 1,1,0,0,0,4,0,0,0,0,0,0,0,0,0,0
        dc.b 4,4,4,0,5,5,0,0,0,0,0,0,0,0,0,0
        dc.b 0,0,0,0,0,2,2,2,2,5,5,3,0,0,0
        endif
        even
