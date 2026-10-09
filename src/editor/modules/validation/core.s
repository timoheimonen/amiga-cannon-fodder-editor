; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Direct strict payload API: A0 MAP/D0 bytes, A1 SPT/D1 bytes, A2 CFMD256.
; MAP is canonical or READBACK; SPT is canonical or VD_STAGE_SPT; CFMD is
; canonical or VD_METADATA. Caller initializes VD_SKIP/BASE/CAPACITY. These
; fixed owners cannot alias writable rows/context or executable module bytes.
; Core validates all input lengths and spans against OUTPUT32/SCRATCH128.
; Returns structural D0, preserves D1-D7/A0-A6/SP. No persistent publication.
vald_scan:
        movem.l d1-d7/a0-a6,-(sp)
        move.l d0,d6
        moveq #-1,d0
        cmpa.l #map_file_buffer,a0
        beq.s .map_owner
        cmpa.l #EDITOR_READBACK_BASE,a0
        bne.s .bad
.map_owner:
        cmpa.l #EDITOR_SPT_BASE,a1
        beq.s .spt_owner
        cmpa.l #VD_STAGE_SPT,a1
        bne.s .bad
.spt_owner:
        cmpa.l #EDITOR_METADATA_BASE,a2
        beq.s .metadata_owner
        cmpa.l #VD_METADATA,a2
        bne.s .bad
.metadata_owner:
        tst.w VD_RESERVED
        bne.s .bad
        move.w VD_CAPACITY,d2
        beq.s .bad
        cmpi.w #VD_MAX_ROWS,d2
        bhi.s .bad
        cmpi.l #$FFFF0000,VD_BASE
        bhi.s .bad
        move.l VD_BASE,VD_TOTAL
        clr.w VD_WRITTEN
        clr.l VD_ERRORS
        clr.l VD_REVIEWS
        lea VD_ROWS,a3
        moveq #47,d2
.clear:
        clr.l (a3)+
        dbra d2,.clear
        lea VD_OUTPUT,a3
        lea VD_SCRATCH,a4
        move.l d6,d0
        bsr cf_payload_validate
.bad:
        move.w d0,VD_STATUS
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts

; Direct current-phase normalization. Reads only canonical metadata/MAP/SPT,
; writes only private clone/context/output/scratch. Source CFMD CRCs may be stale.
; VD_SKIP/BASE/CAPACITY are as for vald_scan; D0=status, all other regs preserved.
vald_current:
        movem.l d1-d7/a0-a6,-(sp)
        moveq #-2,d0
        lea EDITOR_METADATA_BASE,a2
        cmpi.l #CFMD_MAGIC,(a2)
        bne.s .return
        cmpi.l #$00010100,4(a2)
        bne.s .return
        moveq #0,d6
        moveq #0,d7
        move.w CFMD_MAP_BYTES(a2),d6
        move.w CFMD_SPT_BYTES(a2),d7
        moveq #-3,d0
        cmpi.w #96,d6
        blo.s .return
        cmpi.w #15096,d6
        bhi.s .return
        cmpi.w #10,d7
        blo.s .return
        cmpi.w #430,d7
        bhi.s .return
        lea VD_METADATA,a1
        movea.l a2,a0
        moveq #63,d0
.copy:
        move.l (a0)+,(a1)+
        dbra d0,.copy
        lea map_file_buffer,a0
        move.l d6,d1
        bsr read_crc32
        move.l d0,VD_METADATA+CFMD_MAP_CRC
        lea EDITOR_SPT_BASE,a0
        move.l d7,d1
        bsr read_crc32
        move.l d0,VD_METADATA+CFMD_SPT_CRC
        lea map_file_buffer,a0
        lea EDITOR_SPT_BASE,a1
        lea VD_METADATA,a2
        move.l d6,d0
        move.l d7,d1
        bsr vald_scan
.return:
        move.w d0,VD_STATUS
        movem.l (sp)+,d1-d7/a0-a6
        tst.w d0
        rts
