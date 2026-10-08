; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Key service (backend operations 9-11, see ui.i). The game turns the held
; key into an event once per field, and the event lasts one field: the next
; field clears it, or the key's release replaces it. A press whose release
; arrives before the next field (a key that was delayed while WHDLoad ran
; the OS comes with its release) gives no event at all, and an editor loop
; that runs past a field boundary misses an event that lasted one field.
; While an editor module runs outside gameplay, the service reports such a
; press and keeps every event until a module reads and clears it.

; Keyboard interrupt: D1.b = the raw code just stored, 0 on a release.
key_store:
        tst.b d1
        beq.s .out
        move.l a1,-(sp)
        lea key_pressed(pc),a1
        move.b d1,(a1)
        movea.l (sp)+,a1
.out:
        rts

; Per-field translation outside the editor: the game's own rule.
key_event:
        lea key_pressed(pc),a0
        clr.b (a0)
        cmp.w native_key_previous,d1
        beq.s .same
        move.w d1,native_key_previous
        move.w d1,native_last_key
        rts
.same:
        clr.w native_last_key
        rts

; Per-field translation under the editor. A0 = the game's key table. The
; game's field work runs in a level 1 interrupt, so a press can reach the
; keyboard interrupt after the game read the held key and before this
; service: it would then count as a lost press now and as a new held key in
; the next field. The held key is read again together with the pending
; press, with the keyboard interrupt masked.
key_hold:
        move.l a1,-(sp)
        lea key_pressed(pc),a1
        move.w sr,-(sp)
        ori.w #$0700,sr
        move.w native_raw_key,d1
        moveq #0,d0
        move.b (a1),d0
        clr.b (a1)
        move.w (sp)+,sr
        movea.l (sp)+,a1
        tst.w d1
        bne.s .held
        ; No key is held: the next press of the same key is a new event. One
        ; may have been pressed and released since the last field.
        clr.w native_key_previous
        tst.w d0
        beq.s .keep
        bsr.s key_translate
        move.w d1,native_last_key
        rts
.held:
        move.w d1,d0
        bsr.s key_translate
        cmp.w native_key_previous,d1
        beq.s .keep
        move.w d1,native_key_previous
        move.w d1,native_last_key
.keep:
        rts

; D0.w = a raw key code -> D1.w = its event, as the game translates it.
key_translate:
        moveq #0,d1
        move.b 0(a0,d0.w),d1
        cmpi.w #$3f,d1
        bne.s .out
        move.w d0,d1
        ori.w #$80,d1
.out:
        rts

key_pressed:        dc.b 0
        even
