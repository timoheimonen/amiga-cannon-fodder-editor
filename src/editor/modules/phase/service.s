; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Private candidate lifetime is BEGIN until CANCEL or successful COMMIT.
; No source pointer, new AUR field or installed overlay identity is introduced.
PHM_TITLE       equ EDITOR_SERIAL_WORK_BASE+384
PHM_ORIGINAL    equ EDITOR_SERIAL_WORK_BASE+448
PHM_DRAFT       equ EDITOR_SERIAL_WORK_BASE+832
PHM_OWNER       equ EDITOR_SERIAL_WORK_BASE+1088
PHM_BASE        equ EDITOR_UI_BASE
PHM_MAGIC       equ PHM_BASE
PHM_FIELD       equ PHM_BASE+4
PHM_OBJECTIVE   equ PHM_BASE+6
PHM_TITLE_KIND  equ PHM_BASE+8
PHM_READY       equ PHM_BASE+10
PHM_TAG         equ $50484D31
PHM_ERROR_STATE equ -120
PHM_ERROR_VALUE equ -121
PHM_ERROR_STALE equ -122
PHM_ERROR_EMPTY equ -123
PHM_FIELD_COUNT equ 12

        section .text,code
        xdef phm_start,phm_end,phm_begin,phm_set,phm_toggle_objective
        xdef phm_title_begin,phm_title_event,phm_cancel,phm_commit
        xdef phm_before_commit,phm_after_commit,phm_validate_record
        xdef phd_open,phd_step
phm_start:

; No display or disk calls. Require released authoring operations, a valid
; AUR owner and exclusive scratch. Preserve D1-D7/A0-A6/SP/SR control.
; Success copies all metadata384 and AUR128; canonical state is unchanged.
; This is service admission only. An installed wrapper must additionally check
; its exact page/identity and Custom directory authority before invoking BEGIN.
phm_begin:
        movem.l d1-d7/a0-a6,-(sp)
        clr.l PHM_MAGIC
        bsr phm_admit
        bne phm_return
        lea EDITOR_METADATA_BASE,a0
        bsr phm_validate_record
        bne phm_return
        lea EDITOR_METADATA_BASE,a0
        lea PHM_ORIGINAL,a1
        lea PHM_DRAFT,a2
        moveq #63,d1
.copy:
        move.l (a0),d2
        move.l d2,(a1)+
        move.l d2,(a2)+
        addq.l #4,a0
        dbf d1,.copy
        moveq #31,d1
.display_titles:
        move.l (a0)+,(a1)+
        dbf d1,.display_titles
        lea AUR_BASE,a0
        lea PHM_OWNER,a1
        moveq #31,d1
.owner:
        move.l (a0)+,(a1)+
        dbf d1,.owner
        clr.w PHM_FIELD
        move.w #1,PHM_OBJECTIVE
        clr.l PHM_TITLE_KIND
        move.l #PHM_TAG,PHM_MAGIC
        moveq #0,d0
        bra phm_return

; D0.l=field, D1.l=absolute value. Fields 2 recruits,4/5 aggression min/max,
; 6 rank,7 grenades,8 rockets,9 enemy grenades,10 overview,11 countdown.
; Refused writes leave every candidate byte intact. Titles and objective
; arrays have separate APIs. Full longword inputs are checked.
phm_set:
        movem.l d1-d7/a0-a6,-(sp)
        move.l d0,d6
        bsr phm_editable
        bne phm_return
        moveq #PHM_ERROR_VALUE,d0
        cmpi.l #2,d6
        beq .recruits
        cmpi.l #4,d6
        blo phm_return
        cmpi.l #11,d6
        bhi phm_return
        cmpi.l #6,d6
        blo.s .aggression
        beq.s .rank
        cmpi.l #7,d6
        beq.s .grenades
        cmpi.l #1,d1
        bhi phm_return
        cmpi.l #8,d6
        beq.s .rockets
        subi.w #9,d6
        lea PHM_DRAFT+CFMD_FLAGS,a0
        tst.l d1
        beq.s .clear_flag
        bset d6,(a0)
        bra .ok
.clear_flag:
        bclr d6,(a0)
        bra.s .ok
.rockets:
        move.b d1,PHM_DRAFT+CFMD_ROCKETS
        bra.s .ok
.grenades:
        tst.l d1
        beq.s .grenade_store
        cmpi.l #2,d1
        bne phm_return
.grenade_store:
        move.b d1,PHM_DRAFT+CFMD_GRENADES
        bra.s .ok
.rank:
        cmpi.l #7,d1
        bhi phm_return
        move.b d1,PHM_DRAFT+CFMD_RANK
        bra.s .ok
.aggression:
        cmpi.l #20,d1
        bhi phm_return
        cmpi.l #4,d6
        bne.s .maximum
        cmp.b PHM_DRAFT+CFMD_AGGRESSION_MAX,d1
        bhi phm_return
        move.b d1,PHM_DRAFT+CFMD_AGGRESSION_MIN
        bra.s .ok
.maximum:
        cmp.b PHM_DRAFT+CFMD_AGGRESSION_MIN,d1
        blo phm_return
        move.b d1,PHM_DRAFT+CFMD_AGGRESSION_MAX
        bra.s .ok
.recruits:
        tst.l d1
        beq phm_return
        cmpi.l #32767,d1
        bhi phm_return
        move.w d1,PHM_DRAFT+CFMD_RECRUITS
.ok:
        moveq #0,d0
        bra phm_return

; D0.l=objective ID1..8. Existing order is preserved; new IDs append.
; Refuse removal of the final objective; gameplay-invalid sets remain drafts.
phm_toggle_objective:
        movem.l d1-d7/a0-a6,-(sp)
        move.l d0,d6
        bsr phm_editable
        bne phm_return
        moveq #PHM_ERROR_VALUE,d0
        subq.l #1,d6
        cmpi.l #7,d6
        bhi phm_return
        moveq #0,d1
        move.b PHM_DRAFT+CFMD_OBJECTIVE_COUNT,d1
        lea PHM_DRAFT+CFMD_OBJECTIVES,a0
        btst d6,PHM_DRAFT+CFMD_OBJECTIVE_MASK
        bne.s .remove
        move.w d6,d2
        addq.b #1,d2
        move.b d2,(a0,d1.w)
        addq.b #1,PHM_DRAFT+CFMD_OBJECTIVE_COUNT
        bset d6,PHM_DRAFT+CFMD_OBJECTIVE_MASK
        bra.s .ok
.remove:
        moveq #PHM_ERROR_EMPTY,d0
        cmpi.w #1,d1
        beq phm_return
        move.w d6,d2
        addq.b #1,d2
        moveq #0,d3
.find:
        cmp.b (a0,d3.w),d2
        beq.s .shift
        addq.w #1,d3
        cmp.w d1,d3
        blo.s .find
        moveq #PHM_ERROR_STATE,d0
        bra phm_return
.shift:
        addq.w #1,d3
        cmp.w d1,d3
        bhs.s .tail
        move.b (a0,d3.w),-1(a0,d3.w)
        bra.s .shift
.tail:
        clr.b -1(a0,d1.w)
        subq.b #1,PHM_DRAFT+CFMD_OBJECTIVE_COUNT
        bclr d6,PHM_DRAFT+CFMD_OBJECTIVE_MASK
.ok:
        moveq #0,d0
        bra phm_return

; D0.l=0 mission title or1 phase title. Picker owns UI96..255 and a private
; NUL source at WORK384..447. Existing unsupported glyphs produce an empty
; proposal as MENU does; they are never silently rewritten in the candidate.
phm_title_begin:
        movem.l d1-d7/a0-a6,-(sp)
        move.l d0,d6
        bsr phm_editable
        bne phm_return
        moveq #PHM_ERROR_VALUE,d0
        cmpi.l #1,d6
        bhi phm_return
        lea PHM_DRAFT+CFMD_TITLE,a0
        tst.w d6
        beq.s .copy_start
        lea PHM_DRAFT+CFMD_PHASE_TITLE,a0
.copy_start:
        lea PHM_TITLE,a1
        moveq #63,d1
.copy:
        move.b (a0)+,d2
        cmpi.b #$FF,d2
        beq.s .end
        move.b d2,(a1)+
        dbf d1,.copy
        moveq #PHM_ERROR_STATE,d0
        bra phm_return
.end:
        clr.b (a1)
        bsr.s phm_picker_begin
        beq.s .ready
        clr.b PHM_TITLE
        bsr.s phm_picker_begin
        bne phm_return
.ready:
        addq.w #1,d6
        move.w d6,PHM_TITLE_KIND
        bra phm_return
phm_picker_begin:
        lea PHM_TITLE,a0
        moveq #63,d0
        move.w #TITLE_HILL_WIDTH,d1
        move.w #320,d2
        bra text_picker_begin

; D0.w=the established picker event. Accepted title changes only PHM_DRAFT.
; D0=1 accepted,2 cancelled,0 editing; negative refusal. Parent dialog owns
; compact picker rendering, input and display restoration.
phm_title_event:
        movem.l d1-d7/a0-a6,-(sp)
        move.w d0,d6
        bsr phm_active
        bne phm_return
        moveq #PHM_ERROR_STATE,d0
        tst.w PHM_READY
        bne phm_return
        move.w PHM_TITLE_KIND,d1
        subq.w #1,d1
        cmpi.w #1,d1
        bhi phm_return
        move.w d6,d0
        bsr text_picker_event
        cmpi.w #2,d0
        beq.s .closed
        cmpi.w #1,d0
        bne phm_return
        lea PHM_DRAFT+CFMD_TITLE,a1
        cmpi.w #1,PHM_TITLE_KIND
        beq.s .clear_start
        lea PHM_DRAFT+CFMD_PHASE_TITLE,a1
.clear_start:
        movea.l a1,a2
        moveq #15,d1
.clear:
        clr.l (a2)+
        dbf d1,.clear
        lea PHM_TITLE,a0
.copy:
        move.b (a0)+,d1
        beq.s .terminate
        move.b d1,(a1)+
        bra.s .copy
.terminate:
        move.b #$FF,(a1)
.closed:
        clr.w PHM_TITLE_KIND
        bra phm_return

; Cancel only invalidates this component's transient authority.
phm_cancel:
        clr.l PHM_MAGIC
        clr.l PHM_TITLE_KIND
        clr.l picker_magic
        moveq #2,d0
        rts

; Called only after the caller restores its display and requalifies the directory.
; APPLY input is required. Validate the owner again and reject any stale
; metadata384 or AUR128 snapshot. Commit only the 146 editable bytes, mark DIRTY
; for a real edit, and consume this private receipt exactly once.
; D0=1 changed,0 unchanged; error leaves every canonical byte unchanged.
phm_commit:
        movem.l d1-d7/a0-a6,-(sp)
        bsr phm_active
        bne phm_return
        moveq #PHM_ERROR_STATE,d0
        cmpi.w #1,PHM_READY
        bne phm_return
        tst.w PHM_TITLE_KIND
        bne phm_return
        bsr phm_admit
        bne phm_return
        moveq #PHM_ERROR_STALE,d0
        lea AUR_BASE,a0
        lea PHM_OWNER,a1
        moveq #31,d1
.owner:
        cmpm.l (a0)+,(a1)+
        bne phm_return
        dbf d1,.owner
        lea EDITOR_METADATA_BASE,a0
        lea PHM_ORIGINAL,a1
        moveq #95,d1
.source:
        cmpm.l (a0)+,(a1)+
        bne phm_return
        dbf d1,.source
        lea PHM_DRAFT,a0
        bsr phm_validate_record
        bne phm_return
        lea phm_edit_spans(pc),a3
        moveq #3,d3
        moveq #0,d7
.span:
        lea PHM_DRAFT,a0
        lea PHM_ORIGINAL,a1
        move.w (a3)+,d1
        adda.w d1,a0
        adda.w d1,a1
        move.w (a3)+,d2
.compare:
        cmpm.b (a0)+,(a1)+
        beq.s .same
        bset #0,d7
        cmpi.w #3,d3
        beq.s .mission_changed
        tst.w d3
        bne.s .same
        cmpa.l #PHM_DRAFT+CFMD_PHASE_TITLE,a0
        bhi.s .same
.mission_changed:
        bset #1,d7
.same:
        dbf d2,.compare
        dbf d3,.span
        tst.w d7
        beq.s phm_unchanged
phm_before_commit:
        move.w sr,-(sp)
        ori.w #$0700,sr
        lea phm_edit_spans(pc),a3
        moveq #3,d3
.copy_span:
        lea PHM_DRAFT,a0
        lea EDITOR_METADATA_BASE,a1
        move.w (a3)+,d1
        adda.w d1,a0
        adda.w d1,a1
        move.w (a3)+,d2
.copy:
        move.b (a0)+,(a1)+
        dbf d2,.copy
        dbf d3,.copy_span
        btst #1,d7
        beq.s .phase_changed
        clr.b E7_TESTED
        bra.s .mark_dirty
.phase_changed:
        bsr aur_mark_edited
.mark_dirty:
        ori.w #AUR_DIRTY,AUR_BASE+AUR_FLAGS
        moveq #1,d7
        move.w (sp)+,sr
phm_unchanged:
phm_after_commit:
        clr.l PHM_MAGIC
        clr.w PHM_READY
        move.w d7,d0
phm_return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
phm_edit_spans:
        dc.w CFMD_RECRUITS,1
        dc.w CFMD_OBJECTIVE_COUNT,7
        dc.w CFMD_OBJECTIVES,7
        dc.w CFMD_TITLE,127

phm_editable:
        bsr.s phm_active
        bne.s .return
        moveq #PHM_ERROR_STATE,d0
        tst.l PHM_TITLE_KIND
        bne.s .return
        moveq #0,d0
.return:
        tst.w d0
        rts
phm_active:
        moveq #PHM_ERROR_STATE,d0
        cmpi.l #PHM_TAG,PHM_MAGIC
        bne.s .return
        moveq #0,d0
.return:
        tst.w d0
        rts

; Both BEGIN and COMMIT require these session fields. They live outside the
; AUR snapshot, so a newly published result must be refused independently.
phm_admit:
        bsr aur_validate
        bne.s .return
        moveq #PHM_ERROR_STATE,d0
        ; A caller may share an aur_validate variant that admits recovery.
        ; Metadata edits always require the complete retained asset state.
        tst.w AUR_BASE+AUR_ASSET_STATE
        bne.s .return
        btst #2,AUR_BASE+AUR_FLAGS+1
        bne.s .return
        tst.w AUR_BASE+AUR_EXIT_REQUEST
        bne.s .return
        tst.w AUR_BASE+AUR_TRANSPORT_STATUS
        bne.s .return
        tst.l AUR_BASE+AUR_TRANSPORT_ID
        bne.s .return
        tst.l EDITOR_SESSION_BASE+REQ_RESULT_ID
        bne.s .return
        tst.w EDITOR_SESSION_BASE+REQ_LAST_RESULT
        bne.s .return
        moveq #0,d0
.return:
        tst.w d0
        rts

; A0=read-only CFMD256. Validate the edited data's structural schema.
; Imported display-unsupported ASCII survives; title edits enforce both fonts.
; Preserves D1-D7/A0-A6. No scratch or canonical writes.
phm_validate_record:
        movem.l d1-d7/a0-a6,-(sp)
        moveq #PHM_ERROR_VALUE,d0
        cmpi.l #CFMD_MAGIC,(a0)
        bne .return
        cmpi.l #$00010100,4(a0)
        bne.s .return
        move.w CFMD_RECRUITS(a0),d1
        beq.s .return
        bmi.s .return
        cmpi.b #20,CFMD_AGGRESSION_MAX(a0)
        bhi.s .return
        move.b CFMD_AGGRESSION_MIN(a0),d1
        cmp.b CFMD_AGGRESSION_MAX(a0),d1
        bhi.s .return
        cmpi.b #7,CFMD_RANK(a0)
        bhi.s .return
        move.b CFMD_GRENADES(a0),d1
        beq.s .rockets
        cmpi.b #2,d1
        bne.s .return
.rockets:
        cmpi.b #1,CFMD_ROCKETS(a0)
        bhi.s .return
        cmpi.b #7,CFMD_FLAGS(a0)
        bhi.s .return
        moveq #0,d1
        move.b CFMD_OBJECTIVE_COUNT(a0),d1
        beq.s .return
        cmpi.w #8,d1
        bhi.s .return
        lea CFMD_OBJECTIVES(a0),a1
        moveq #0,d2
        moveq #0,d3
.objective:
        moveq #0,d4
        move.b (a1)+,d4
        subq.w #1,d4
        cmpi.w #7,d4
        bhi.s .return
        bset d4,d2
        bne.s .return
        addq.w #1,d3
        cmp.w d1,d3
        blo.s .objective
        cmp.b CFMD_OBJECTIVE_MASK(a0),d2
        bne.s .return
        lea CFMD_TITLE(a0),a1
        bsr.s .title
        bne.s .return
        lea CFMD_PHASE_TITLE(a0),a1
        bsr.s .title
.return:
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
.title:
        moveq #PHM_ERROR_VALUE,d0
        moveq #0,d1
.character:
        move.b (a1)+,d2
        cmpi.b #$FF,d2
        beq.s .end
        cmpi.b #32,d2
        blo.s .title_return
        cmpi.b #126,d2
        bhi.s .title_return
        addq.w #1,d1
        cmpi.w #64,d1
        blo.s .character
        bra.s .title_return
.end:
        tst.w d1
        beq.s .title_return
        moveq #0,d0
.title_return:
        tst.w d0
        rts

        include "../phase/dialog.s"
phm_end:
        ifgt phm_end-phm_start-EDITOR_SERIALIZER_BYTES
        fail "Private metadata service exceeds 16 KiB code partition"
        endif
        ifgt PHM_OWNER+AUR_BYTES-EDITOR_SERIAL_WORK_BASE-1216
        fail "Private metadata state overlaps modal tail"
        endif
