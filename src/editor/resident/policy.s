; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Custom policy reads only the validated persistent metadata record. A zero
; session mode follows the displaced native instructions and destinations.
        xdef    policy_rank
        xdef    policy_ammunition
        xdef    policy_aggression
        xdef    policy_objectives
        xdef    policy_enemy_grenades
        xdef    policy_overview
        xdef    policy_countdown
        xdef    policy_countdown_failure
        xdef    policy_countdown_setup
        xdef    policy_title_measure
        xdef    policy_title_draw
        xdef    policy_title_heading

; JMP replaces the six-byte MOVE.W at $89FE8, after native MOVEQ #0,D0.
policy_rank:
        bsr     editor_test_custom_mode
        beq.s   .native
        move.b     editor_resident_start+(EDITOR_METADATA_BASE+CFMD_RANK-EDITOR_RESIDENT_BASE)(pc),d0
        jmp     native_rank_store
.native:
        move.w  native_mission_number,d0
        jmp     native_rank_resume

; JSR target replacement at $861D0. Native tail preserves its normal return.
policy_ammunition:
        bsr     editor_test_custom_mode
        beq.s   .native
        move.w  native_assigned_count,d1
        moveq   #0,d0
        move.b     editor_resident_start+(EDITOR_METADATA_BASE+CFMD_GRENADES-EDITOR_RESIDENT_BASE)(pc),d0
        mulu.w  d1,d0
        move.w  d0,native_grenades
        ; Validated demand <=8 and factor <=2 leave the upper bytes zero.
        move.b     editor_resident_start+(EDITOR_METADATA_BASE+CFMD_ROCKETS-EDITOR_RESIDENT_BASE)(pc),d0
        mulu.w  d1,d0
        move.w  d0,native_rockets
        rts
.native:
        jmp     native_ammo

; JSR target replacement at $861D6; retain native distribution over enemies.
policy_aggression:
        bsr     editor_test_custom_mode
        beq.s   .native
        moveq   #0,d1
        moveq   #0,d2
        move.b     editor_resident_start+(EDITOR_METADATA_BASE+CFMD_AGGRESSION_MIN-EDITOR_RESIDENT_BASE)(pc),d1
        move.b     editor_resident_start+(EDITOR_METADATA_BASE+CFMD_AGGRESSION_MAX-EDITOR_RESIDENT_BASE)(pc),d2
        jmp     native_aggression_apply
.native:
        jmp     native_aggression

; Both JSR sites $861DC and briefing $A7F28 must target this same adapter.
; CFMD's eight-byte authored list has no ninth sentinel. Initialize the eight
; native objective words directly from its validated mask, never scan past it.
policy_objectives:
        bsr     editor_test_custom_mode
        beq.s   .native
        movem.l d1-d2,-(sp)
        lea     native_objective_flags,a0
        moveq   #0,d0
        move.b     editor_resident_start+(EDITOR_METADATA_BASE+CFMD_OBJECTIVE_MASK-EDITOR_RESIDENT_BASE)(pc),d0
        moveq   #7,d1
.word:
        lsr.b   #1,d0
        subx.w  d2,d2
        move.w  d2,(a0)+
        dbra    d1,.word
        movem.l (sp)+,d1-d2
        rts
.native:
        jmp     native_objectives

; Eight-byte CMP hooks use JMP plus one NOP. Native mode replays the CMP and
; resumes at its original conditional branch, including the original CCR.
policy_enemy_grenades:
        bsr     editor_test_custom_mode
        beq.s   .native
        btst    #CFMD_ENEMY_GRENADES_BIT,editor_resident_start+(EDITOR_METADATA_BASE+CFMD_FLAGS-EDITOR_RESIDENT_BASE)(pc)
        beq.s   .disabled
        jmp     native_grenade_random
.disabled:
        jmp     native_grenade_skip
.native:
        cmpi.w  #4,native_map_index
        jmp     native_grenade_branch

policy_overview:
        bsr     editor_test_custom_mode
        beq.s   .native
        btst    #CFMD_OVERVIEW_BIT,editor_resident_start+(EDITOR_METADATA_BASE+CFMD_FLAGS-EDITOR_RESIDENT_BASE)(pc)
        rts
.native:
policy_native_final_map:
        cmpi.w  #71,native_map_index
        rts

; JSR plus NOP replaces each eight-byte CMP. Overview retains its native
; BEQ-to-disabled; countdown/failure share this BNE-to-disabled gate. No
; register is clobbered. TST/BTST/EORI preserve X, as does the native CMP.
policy_countdown:
policy_countdown_failure:
        bsr     editor_test_custom_mode
        beq.s   .native
        btst    #CFMD_COUNTDOWN_BIT,editor_resident_start+(EDITOR_METADATA_BASE+CFMD_FLAGS-EDITOR_RESIDENT_BASE)(pc)
        eori.b  #4,ccr
        rts
.native:
        bra.s   policy_native_final_map

; JSR target replacement at $8620C. Disabled policy has no live countdown;
; enabled policy retains native 100/40 setup, including its immediate first tick.
policy_countdown_setup:
        bsr     editor_test_custom_mode
        beq.s   .native
        clr.w   native_countdown_delay
        btst    #CFMD_COUNTDOWN_BIT,editor_resident_start+(EDITOR_METADATA_BASE+CFMD_FLAGS-EDITOR_RESIDENT_BASE)(pc)
        bne.s   .native
        clr.l   native_countdown_subtick
        rts
.native:
        jmp     native_countdown_setup

; Controller must measure both titles with the native font table before play;
; the CFMD string byte bound alone does not establish safe centered rendering.
; $A81C6 MOVEA (4) plus LEA (6). The continuation's MOVE.W #$140,D2
; overwrites NZVC before use; TST leaves the preceding ASL's X unchanged.
policy_title_measure:
        bsr     editor_test_custom_mode
        beq.s   .native
        bsr.s   policy_title_pointer
        bra.s   .resume
.native:
        movea.l (a0,d0.w),a0
.resume:
        lea     editor_resident_start+(native_briefing_font-EDITOR_RESIDENT_BASE)(pc),a2
        bra     editor_resident_start+(native_title_measure-EDITOR_RESIDENT_BASE)

; $A8200 MOVEA (4) plus MOVE.W #1,D0 (4). The replayed MOVE supplies CCR.
policy_title_draw:
        bsr     editor_test_custom_mode
        beq.s   .native
        bsr.s   policy_title_pointer
        bra.s   .resume
.native:
        movea.l (a0,d0.w),a0
.resume:
        move.w  #1,d0
        bra     editor_resident_start+(native_title_draw-EDITOR_RESIDENT_BASE)

policy_title_pointer:
        lea     editor_resident_start+(EDITOR_METADATA_BASE+CFMD_RECORD_BYTES-EDITOR_RESIDENT_BASE)(pc),a0
        cmpi.w  #$14,native_title_y
        beq.s   .return
        lea     editor_resident_start+(EDITOR_METADATA_BASE+CFMD_RECORD_BYTES+64-EDITOR_RESIDENT_BASE)(pc),a0
.return:
        rts

; The phase screen uses the projected mission title in its native top heading.
; A2 is already font 1, D3 is zero, and the centering routine preserves A0/A2/D3.
; Native mode replays both displaced instructions without changing their inputs.
policy_title_heading:
        bsr     editor_test_custom_mode
        beq.s   .draw
        lea     editor_resident_start+(EDITOR_METADATA_BASE+CFMD_RECORD_BYTES-EDITOR_RESIDENT_BASE)(pc),a0
        move.w  #320,d2
        bsr     editor_resident_start+(native_measure_text-EDITOR_RESIDENT_BASE)
        move.w  #1,d0
.draw:
        bsr     editor_resident_start+(native_draw_text-EDITOR_RESIDENT_BASE)
        lea     editor_resident_start+(native_mission_title_table-EDITOR_RESIDENT_BASE)(pc),a0
        bra     editor_resident_start+(native_title_heading_resume-EDITOR_RESIDENT_BASE)
