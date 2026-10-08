; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        xdef cfmi_parse

; A0=file, D0.l=exact bytes, A1=13-byte basename, D1.w=selected phase,
; A2=512-byte output, A3=512-byte scratch. D0.w=status, D1.l=error offset.
; Preserve D2-D7/A0-A6. All four spans must be addressable and disjoint;
; file/output/scratch must be even. No output is changed before full validation.
;
; Candidate occupies scratch $000..$0FF, decoded token $100..$13F,
; scanner $140..$17F. The remaining $80 bytes are reserved and zeroed.
MP_TOKEN        equ $100
MP_INPUT        equ $140
MP_OUTPUT       equ $144
MP_SAVED_SP     equ $148
MP_FILE_BYTES   equ $14C
MP_SELECTED     equ $150
MP_PHASE        equ $152
MP_PHASES       equ $154
MP_STORE        equ $156
MP_TOKEN_BYTES  equ $158
MP_ROOT_MASK    equ $15A
MP_PHASE_MASK   equ $15C
MP_REF_MASK     equ $15E
MP_AGG_MASK     equ $160
MP_MIN          equ $162
MP_MAX          equ $164
MP_OBJ_MASK     equ $166
MP_OBJ_COUNT    equ $168
MP_REF_KIND     equ $16A

cfmi_parse:
        movem.l d2-d7/a0-a6,-(sp)
        move.l  d0,d5
        moveq   #0,d6
        move.w  d1,d6
        cmpi.l  #17,d5
        blo     .argument
        cmpi.l  #4096,d5
        bhi     .argument
        cmpi.w  #5,d6
        bhi     .argument
        move.l  a0,d2
        move.l  a2,d3
        move.l  a3,d4
        or.l    d3,d2
        or.l    d4,d2
        btst    #0,d2
        bne     .argument
        move.l  a0,d2
        add.l   d5,d2
        bcs     .argument
        addi.l  #CFMD_OUTPUT_BYTES,d3
        bcs     .argument
        addi.l  #CFMD_PARSE_BYTES,d4
        bcs     .argument
        move.l  a1,d7
        addi.l  #13,d7
        bcs     .argument
        cmp.l   a2,d2
        bls.s   .no_file_output
        cmp.l   a0,d3
        bhi     .argument
.no_file_output:
        cmp.l   a3,d2
        bls.s   .no_file_scratch
        cmp.l   a0,d4
        bhi     .argument
.no_file_scratch:
        cmp.l   a1,d2
        bls.s   .no_file_name
        cmp.l   a0,d7
        bhi     .argument
.no_file_name:
        cmp.l   a3,d3
        bls.s   .no_output_scratch
        cmp.l   a2,d4
        bhi     .argument
.no_output_scratch:
        cmp.l   a1,d3
        bls.s   .no_output_name
        cmp.l   a2,d7
        bhi     .argument
.no_output_name:
        cmp.l   a1,d4
        bls.s   .arguments_valid
        cmp.l   a3,d7
        bhi     .argument
.arguments_valid:
        movea.l a0,a5
        movea.l d2,a6
        movea.l a3,a4
        movea.l a3,a0
        moveq   #0,d0
        moveq   #127,d1
.clear_scratch:
        move.l  d0,(a0)+
        dbra    d1,.clear_scratch
        move.l  a5,MP_INPUT(a4)
        move.l  a2,MP_OUTPUT(a4)
        move.l  sp,MP_SAVED_SP(a4)
        move.l  d5,MP_FILE_BYTES(a4)
        move.w  d6,MP_SELECTED(a4)
        move.b  d6,CFMD_PHASE_INDEX(a4)
        move.w  d5,CFMD_MANIFEST_BYTES(a4)
        lea     CFMD_MANIFEST_NAME(a4),a0
        moveq   #12,d1
.copy_name:
        move.b  (a1)+,(a0)+
        dbra    d1,.copy_name
        lea     CFMD_MANIFEST_NAME(a4),a0
        moveq   #0,d3
        moveq   #7,d4
.generation:
        moveq   #0,d0
        move.b  (a0)+,d0
        cmpi.b  #'9',d0
        bls.s   .generation_digit
        cmpi.b  #'a',d0
        blo     .reference_error
        cmpi.b  #'f',d0
        bhi     .reference_error
.generation_digit:
        bsr     .hex_digit
        lsl.l   #4,d3
        or.l    d0,d3
        dbra    d4,.generation
        move.l  d3,CFMD_GENERATION(a4)
        cmpi.b  #'.',(a0)+
        bne     .reference_error
        cmpi.b  #'c',(a0)+
        bne     .reference_error
        cmpi.b  #'m',(a0)+
        bne     .reference_error
        cmpi.b  #'i',(a0)+
        bne     .reference_error
        tst.b   (a0)
        bne     .reference_error
        cmpi.l  #$43464D49,(a5)
        bne.s   .header_error
        cmpi.w  #1,4(a5)
        bne.s   .header_error
        cmpi.w  #16,6(a5)
        bne.s   .header_error
        move.l  MP_FILE_BYTES(a4),d0
        subi.l  #16,d0
        cmp.l   8(a5),d0
        bne.s   .header_error
        move.l  12(a5),CFMD_MANIFEST_CRC(a4)
        lea     16(a5),a0
        move.l  d0,d1
        bsr     read_crc32
        cmp.l   CFMD_MANIFEST_CRC(a4),d0
        bne.s   .crc_error
        adda.w  #16,a5
        bsr.s   .root
        bsr     .space
        cmpi.l  #-1,d0
        bne.s   .json_error
        move.l  #CFMD_MAGIC,(a4)
        move.w  #CFMD_ABI,4(a4)
        move.w  #CFMD_RECORD_BYTES,6(a4)
        movea.l MP_OUTPUT(a4),a1
        movea.l a4,a0
        moveq   #63,d1
.publish:
        move.l  (a0)+,(a1)+
        dbra    d1,.publish
        moveq   #0,d0
        moveq   #63,d1
.clear_output_reserve:
        move.l  d0,(a1)+
        dbra    d1,.clear_output_reserve
        moveq   #-1,d1
        bra.s   .clear_pointers
.argument:
        moveq   #CFMI_ERROR_ARGUMENT,d0
        moveq   #-1,d1
        bra.s   .return
.header_error:
        moveq   #CFMI_ERROR_HEADER,d0
        bra.s   .error
.crc_error:
        moveq   #CFMI_ERROR_CRC,d0
        bra.s   .error
.json_error:
        moveq   #CFMI_ERROR_JSON,d0
        bra.s   .error
.schema_error:
        moveq   #CFMI_ERROR_SCHEMA,d0
        bra.s   .error
.range_error:
        moveq   #CFMI_ERROR_RANGE,d0
        bra.s   .error
.reference_error:
        moveq   #CFMI_ERROR_REFERENCE,d0
        bra.s   .error
.phase_error:
        moveq   #CFMI_ERROR_PHASE,d0
.error:
        move.l  a5,d1
        sub.l   MP_INPUT(a4),d1
        movea.l MP_SAVED_SP(a4),sp
.clear_pointers:
        clr.l   MP_INPUT(a4)
        clr.l   MP_OUTPUT(a4)
        clr.l   MP_SAVED_SP(a4)
.return:
        movem.l (sp)+,d2-d7/a0-a6
        rts

; The schema fixes the call depth. No input-controlled recursive descent exists.
.root:
        moveq   #'{',d0
        bsr     .expect
.root_key:
        lea     .root_keys(pc),a0
        bsr     .key
        bset    d0,MP_ROOT_MASK+1(a4)
        bne.s   .schema_error
        move.w  d0,d7
        moveq   #':',d0
        bsr     .expect
        tst.w   d7
        beq.s   .root_schema
        cmpi.w  #1,d7
        beq.s   .root_id
        cmpi.w  #2,d7
        beq.s   .root_revision
        cmpi.w  #3,d7
        beq.s   .root_title
        cmpi.w  #4,d7
        beq.s   .root_recruits
        bsr.s   .phases
        bra.s   .root_next
.root_schema:
        bsr     .string
        lea     .schema(pc),a0
        bsr     .match_string
        bra.s   .root_next
.root_id:
        bsr     .hex_string
        move.l  d0,CFMD_ID(a4)
        bra.s   .root_next
.root_revision:
        bsr     .uint
        move.w  d0,CFMD_REVISION(a4)
        bra.s   .root_next
.root_title:
        bsr     .title
        lea     CFMD_TITLE(a4),a0
        bsr     .copy_title
        bra.s   .root_next
.root_recruits:
        bsr     .uint
        tst.w   d0
        beq     .range_error
        cmpi.w  #32767,d0
        bhi     .range_error
        move.w  d0,CFMD_RECRUITS(a4)
.root_next:
        moveq   #'}',d2
        bsr     .separator
        beq     .root_key
        cmpi.w  #$3F,MP_ROOT_MASK(a4)
        bne     .schema_error
        rts

.phases:
        moveq   #'[',d0
        bsr     .expect
        clr.w   MP_PHASE(a4)
.phase_next:
        cmpi.w  #6,MP_PHASE(a4)
        bhs     .range_error
        bsr.s   .phase
        addq.w  #1,MP_PHASE(a4)
        moveq   #']',d2
        bsr     .separator
        beq.s   .phase_next
        move.w  MP_PHASE(a4),d0
        move.w  d0,MP_PHASES(a4)
        move.b  d0,CFMD_PHASE_COUNT(a4)
        cmp.w   MP_SELECTED(a4),d0
        bls     .phase_error
        rts
.phase:
        clr.w   MP_PHASE_MASK(a4)
        clr.w   MP_STORE(a4)
        move.w  MP_PHASE(a4),d0
        cmp.w   MP_SELECTED(a4),d0
        bne.s   .phase_begin
        move.w  #-1,MP_STORE(a4)
.phase_begin:
        moveq   #'{',d0
        bsr     .expect
.phase_key:
        lea     .phase_keys(pc),a0
        bsr     .key
        moveq   #1,d2
        lsl.w   d0,d2
        move.w  MP_PHASE_MASK(a4),d3
        and.w   d2,d3
        bne     .schema_error
        or.w    d2,MP_PHASE_MASK(a4)
        move.w  d0,d7
        moveq   #':',d0
        bsr     .expect
        tst.w   d7
        beq     .phase_title
        cmpi.w  #2,d7
        bls     .phase_reference
        cmpi.w  #3,d7
        beq     .phase_objectives
        cmpi.w  #4,d7
        beq     .phase_aggression
        cmpi.w  #7,d7
        bls.s   .phase_numeric
        cmpi.w  #9,d7
        bls.s   .phase_boolean
        bsr     .space
        cmpi.b  #'n',d0
        beq.s   .countdown_null
        bsr     .string
        lea     .countdown(pc),a0
        bsr     .match_string
        tst.w   MP_STORE(a4)
        beq     .phase_after
        bset    #CFMD_COUNTDOWN_BIT,CFMD_FLAGS(a4)
        bra     .phase_after
.countdown_null:
        lea     .null(pc),a0
        bsr     .literal
        bra     .phase_after
.phase_numeric:
        bsr     .uint
        cmpi.w  #5,d7
        beq.s   .rank
        cmpi.w  #6,d7
        beq.s   .grenades
        cmpi.w  #1,d0
        bhi     .range_error
        lea     CFMD_ROCKETS(a4),a0
        bra.s   .phase_store_byte
.rank:
        cmpi.w  #7,d0
        bhi     .range_error
        lea     CFMD_RANK(a4),a0
        bra.s   .phase_store_byte
.grenades:
        cmpi.w  #2,d0
        bhi     .range_error
        cmpi.w  #1,d0
        beq     .range_error
        lea     CFMD_GRENADES(a4),a0
.phase_store_byte:
        tst.w   MP_STORE(a4)
        beq.s   .phase_after
        move.b  d0,(a0)
        bra.s   .phase_after
.phase_boolean:
        bsr     .boolean
        tst.w   MP_STORE(a4)
        beq.s   .phase_after
        tst.w   d0
        beq.s   .phase_after
        subi.w  #8,d7
        bset    d7,CFMD_FLAGS(a4)
        bra.s   .phase_after
.phase_title:
        bsr     .title
        tst.w   MP_STORE(a4)
        beq.s   .phase_after
        lea     CFMD_PHASE_TITLE(a4),a0
        bsr     .copy_title
        bra.s   .phase_after
.phase_reference:
        move.w  d7,d0
        subq.w  #1,d0
        bsr.s   .reference
        bra.s   .phase_after
.phase_objectives:
        bsr     .objectives
        bra.s   .phase_after
.phase_aggression:
        bsr     .aggression
.phase_after:
        moveq   #'}',d2
        bsr     .separator
        beq     .phase_key
        cmpi.w  #$7FF,MP_PHASE_MASK(a4)
        bne     .schema_error
        rts

.reference:
        move.w  d0,MP_REF_KIND(a4)
        clr.w   MP_REF_MASK(a4)
        moveq   #'{',d0
        bsr     .expect
.reference_key:
        lea     .ref_keys(pc),a0
        bsr     .key
        bset    d0,MP_REF_MASK+1(a4)
        bne     .schema_error
        move.w  d0,d7
        moveq   #':',d0
        bsr     .expect
        tst.w   d7
        beq.s   .reference_name
        cmpi.w  #1,d7
        beq.s   .reference_length
        bsr     .hex_string
        lea     CFMD_MAP_CRC(a4),a0
        tst.w   MP_REF_KIND(a4)
        beq.s   .reference_crc_store
        addq.l  #4,a0
.reference_crc_store:
        tst.w   MP_STORE(a4)
        beq     .reference_next
        move.l  d0,(a0)
        bra     .reference_next
.reference_length:
        bsr     .uint
        tst.w   d0
        beq     .range_error
        lea     CFMD_MAP_BYTES(a4),a0
        move.w  #15096,d1
        tst.w   MP_REF_KIND(a4)
        beq.s   .reference_bound
        addq.l  #2,a0
        move.w  #430,d1
.reference_bound:
        cmp.w   d1,d0
        bhi     .range_error
        tst.w   MP_STORE(a4)
        beq.s   .reference_next
        move.w  d0,(a0)
        bra.s   .reference_next
.reference_name:
        bsr     .string
        cmpi.w  #14,MP_TOKEN_BYTES(a4)
        bne     .reference_error
        lea     CFMD_MANIFEST_NAME(a4),a0
        lea     MP_TOKEN(a4),a1
        moveq   #7,d1
.reference_generation:
        cmpm.b  (a0)+,(a1)+
        bne     .reference_error
        dbra    d1,.reference_generation
        cmpi.b  #'0',(a1)+
        bne     .reference_error
        move.w  MP_PHASE(a4),d0
        addi.b  #'0',d0
        cmp.b   (a1)+,d0
        bne     .reference_error
        cmpi.b  #'.',(a1)+
        bne     .reference_error
        lea     .map_suffix(pc),a0
        tst.w   MP_REF_KIND(a4)
        beq.s   .reference_suffix
        lea     .spt_suffix(pc),a0
.reference_suffix:
        moveq   #3,d1
.reference_suffix_byte:
        cmpm.b  (a0)+,(a1)+
        bne     .reference_error
        dbra    d1,.reference_suffix_byte
        tst.w   MP_STORE(a4)
        beq.s   .reference_next
        lea     CFMD_MAP_NAME(a4),a0
        tst.w   MP_REF_KIND(a4)
        beq.s   .reference_copy
        adda.w  #16,a0
.reference_copy:
        lea     MP_TOKEN(a4),a1
        moveq   #14,d1
.reference_copy_byte:
        move.b  (a1)+,(a0)+
        dbra    d1,.reference_copy_byte
.reference_next:
        moveq   #'}',d2
        bsr     .separator
        beq     .reference_key
        cmpi.w  #7,MP_REF_MASK(a4)
        bne     .schema_error
        rts

.aggression:
        clr.w   MP_AGG_MASK(a4)
        moveq   #'{',d0
        bsr     .expect
.aggression_key:
        lea     .agg_keys(pc),a0
        bsr     .key
        bset    d0,MP_AGG_MASK+1(a4)
        bne     .schema_error
        move.w  d0,d7
        moveq   #':',d0
        bsr     .expect
        bsr     .uint
        cmpi.w  #20,d0
        bhi     .range_error
        tst.w   d7
        bne.s   .aggression_max
        move.w  d0,MP_MIN(a4)
        bra.s   .aggression_next
.aggression_max:
        move.w  d0,MP_MAX(a4)
.aggression_next:
        moveq   #'}',d2
        bsr     .separator
        beq.s   .aggression_key
        cmpi.w  #3,MP_AGG_MASK(a4)
        bne     .schema_error
        move.w  MP_MIN(a4),d0
        cmp.w   MP_MAX(a4),d0
        bhi     .range_error
        tst.w   MP_STORE(a4)
        beq.s   .aggression_done
        move.b  d0,CFMD_AGGRESSION_MIN(a4)
        move.b  MP_MAX+1(a4),CFMD_AGGRESSION_MAX(a4)
.aggression_done:
        rts
.objectives:
        clr.w   MP_OBJ_COUNT(a4)
        clr.w   MP_OBJ_MASK(a4)
        moveq   #'[',d0
        bsr     .expect
.objective:
        bsr     .uint
        tst.w   d0
        beq     .range_error
        cmpi.w  #8,d0
        bhi     .range_error
        move.w  d0,d1
        subq.w  #1,d1
        bset    d1,MP_OBJ_MASK+1(a4)
        bne     .schema_error
        move.w  MP_OBJ_COUNT(a4),d1
        cmpi.w  #8,d1
        bhs     .range_error
        tst.w   MP_STORE(a4)
        beq.s   .objective_count
        lea     CFMD_OBJECTIVES(a4),a0
        move.b  d0,(a0,d1.w)
.objective_count:
        addq.w  #1,MP_OBJ_COUNT(a4)
        moveq   #']',d2
        bsr     .separator
        beq.s   .objective
        tst.w   MP_STORE(a4)
        beq.s   .objectives_done
        move.b  MP_OBJ_COUNT+1(a4),CFMD_OBJECTIVE_COUNT(a4)
        move.b  MP_OBJ_MASK+1(a4),CFMD_OBJECTIVE_MASK(a4)
.objectives_done:
        rts

; All valid schema strings are printable ASCII; escaped controls and Unicode
; outside that domain are rejected even when the JSON spelling itself is legal.
.title:
        bsr     .string
        tst.w   MP_TOKEN_BYTES(a4)
        beq     .range_error
        rts
.copy_title:
        lea     MP_TOKEN(a4),a1
.copy_title_byte:
        move.b  (a1)+,d0
        beq.s   .copy_title_end
        move.b  d0,(a0)+
        bra.s   .copy_title_byte
.copy_title_end:
        move.b  #$FF,(a0)
        rts
.key:
        bsr     .string
        moveq   #0,d3
.key_candidate:
        tst.b   (a0)
        beq     .schema_error
        lea     MP_TOKEN(a4),a1
.key_compare:
        move.b  (a0)+,d0
        cmp.b   (a1)+,d0
        bne.s   .key_skip
        tst.b   d0
        bne.s   .key_compare
        move.w  d3,d0
        rts
.key_skip:
        tst.b   d0
        beq.s   .key_advance
.key_skip_byte:
        tst.b   (a0)+
        bne.s   .key_skip_byte
.key_advance:
        addq.w  #1,d3
        bra.s   .key_candidate
.match_string:
        lea     MP_TOKEN(a4),a1
.match_byte:
        move.b  (a0)+,d0
        cmp.b   (a1)+,d0
        bne     .schema_error
        tst.b   d0
        bne.s   .match_byte
        rts
.hex_string:
        bsr     .string
        cmpi.w  #8,MP_TOKEN_BYTES(a4)
        bne     .schema_error
        lea     MP_TOKEN(a4),a1
        moveq   #0,d3
        moveq   #7,d4
.hex_string_digit:
        moveq   #0,d0
        move.b  (a1)+,d0
        cmpi.b  #'F',d0
        bhi     .schema_error
        bsr.s   .hex_digit
        lsl.l   #4,d3
        or.l    d0,d3
        dbra    d4,.hex_string_digit
        move.l  d3,d0
        rts
.hex_digit:
        cmpi.b  #'0',d0
        blo     .json_error
        cmpi.b  #'9',d0
        bls.s   .hex_decimal
        cmpi.b  #'A',d0
        blo     .json_error
        cmpi.b  #'F',d0
        bls.s   .hex_upper
        cmpi.b  #'a',d0
        blo     .json_error
        cmpi.b  #'f',d0
        bhi     .json_error
        subi.w  #'a'-10,d0
        rts
.hex_upper:
        subi.w  #'A'-10,d0
        rts
.hex_decimal:
        subi.w  #'0',d0
        rts
.boolean:
        bsr     .space
        cmpi.b  #'t',d0
        beq.s   .true_value
        lea     .false(pc),a0
        bsr.s   .literal
        moveq   #0,d0
        rts
.true_value:
        lea     .true(pc),a0
        bsr.s   .literal
        moveq   #1,d0
        rts
.literal:
        bsr     .space
.literal_byte:
        move.b  (a0)+,d1
        beq.s   .literal_end
        bsr     .byte
        cmp.b   d1,d0
        bne     .json_error
        bra.s   .literal_byte
.literal_end:
        rts
.uint:
        bsr     .space
        cmpi.b  #'0',d0
        blo     .json_error
        cmpi.b  #'9',d0
        bhi     .json_error
        addq.l  #1,a5
        subi.w  #'0',d0
        move.w  d0,d1
        bne.s   .uint_more
        rts
.uint_more:
        cmpa.l  a6,a5
        bhs.s   .uint_done
        moveq   #0,d0
        move.b  (a5),d0
        cmpi.b  #'0',d0
        blo.s   .uint_done
        cmpi.b  #'9',d0
        bhi.s   .uint_done
        addq.l  #1,a5
        subi.w  #'0',d0
        cmpi.w  #6553,d1
        bhi     .range_error
        bne.s   .uint_append
        cmpi.w  #5,d0
        bhi     .range_error
.uint_append:
        mulu.w  #10,d1
        add.w   d0,d1
        bra.s   .uint_more
.uint_done:
        moveq   #0,d0
        move.w  d1,d0
        rts
.string:
        moveq   #'"',d0
        bsr     .expect
        lea     MP_TOKEN(a4),a1
        clr.w   MP_TOKEN_BYTES(a4)
.string_byte:
        bsr.s   .byte
        cmpi.b  #'"',d0
        beq.s   .string_end
        cmpi.b  #$5C,d0
        bne.s   .string_decoded
        bsr.s   .byte
        cmpi.b  #'"',d0
        beq.s   .string_decoded
        cmpi.b  #$5C,d0
        beq.s   .string_decoded
        cmpi.b  #'/',d0
        beq.s   .string_decoded
        cmpi.b  #'u',d0
        bne     .json_error
        moveq   #0,d3
        moveq   #3,d4
.unicode_digit:
        bsr.s   .byte
        bsr     .hex_digit
        lsl.w   #4,d3
        or.w    d0,d3
        dbra    d4,.unicode_digit
        move.w  d3,d0
.string_decoded:
        cmpi.w  #$20,d0
        blo     .json_error
        cmpi.w  #$7E,d0
        bhi     .json_error
        cmpi.w  #63,MP_TOKEN_BYTES(a4)
        bhs     .range_error
        move.b  d0,(a1)+
        addq.w  #1,MP_TOKEN_BYTES(a4)
        bra.s   .string_byte
.string_end:
        clr.b   (a1)
        rts
.byte:
        cmpa.l  a6,a5
        bhs     .json_error
        moveq   #0,d0
        move.b  (a5)+,d0
        rts
.space:
        cmpa.l  a6,a5
        bhs.s   .eof
        moveq   #0,d0
        move.b  (a5),d0
        cmpi.b  #$20,d0
        beq.s   .space_next
        cmpi.b  #9,d0
        beq.s   .space_next
        cmpi.b  #10,d0
        beq.s   .space_next
        cmpi.b  #13,d0
        bne.s   .space_done
.space_next:
        addq.l  #1,a5
        bra.s   .space
.eof:
        moveq   #-1,d0
.space_done:
        rts
.expect:
        move.w  d0,d2
        bsr.s   .space
        cmp.w   d2,d0
        bne     .json_error
        addq.l  #1,a5
        rts
.separator:
        bsr.s   .space
        cmp.w   d2,d0
        beq.s   .separator_end
        cmpi.b  #',',d0
        bne     .json_error
        addq.l  #1,a5
        moveq   #0,d0
        rts
.separator_end:
        addq.l  #1,a5
        moveq   #1,d0
        rts
.root_keys:
        dc.b "schema",0,"id",0,"revision",0,"title",0,"initial_recruits",0,"phases",0,0
.phase_keys:
        dc.b "title",0,"map",0,"spt",0,"objectives",0,"aggression",0
        dc.b "new_recruit_rank",0,"grenades_per_troop",0,"rockets_per_troop",0
        dc.b "enemy_grenades",0,"overview",0,"countdown",0,0
.ref_keys:
        dc.b "name",0,"length",0,"crc32",0,0
.agg_keys:
        dc.b "minimum",0,"maximum",0,0
.schema:
        dc.b "cannon-fodder-custom-mission-v1",0
.countdown:
        dc.b "original-final-map",0
.map_suffix:
        dc.b "map",0
.spt_suffix:
        dc.b "spt",0
.null:
        dc.b "null",0
.false:
        dc.b "false",0
.true:
        dc.b "true",0
        even
