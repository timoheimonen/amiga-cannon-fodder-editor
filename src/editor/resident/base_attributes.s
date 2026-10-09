; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

        include "layout.i"
        include "session.i"
        include "fodders.i"
        section .text,code
        xdef editor_base_attributes,editor_base_attributes_end
        xdef editor_base_bht_loaded,editor_base_bht_canonical

; In-place replacement of the native base SWP/HIT/BHT loader. SWP and HIT
; keep their retry-until-success contract; absent BHT still becomes all zero.
; The native caller consumes the tables, not returned flags. Preserve A3,
; which holds each required destination while the filename helper changes A2.
editor_base_attributes:
        move.l a3,-(sp)
        lea editor_base_attributes+(native_extension_swp-native_base_attributes)(pc),a1
        lea native_base_swp,a3
        bsr.s base_attributes_required
        lea editor_base_attributes+(native_extension_hit-native_base_attributes)(pc),a1
        lea native_base_hit,a3
        bsr.s base_attributes_required
        movea.l native_terrain_name_pointer,a0
        lea editor_base_attributes+(native_extension_bht-native_base_attributes)(pc),a1
        bsr.w editor_base_attributes+(native_resource_build_name-native_base_attributes)
        lea native_resource_name,a0
        lea native_base_bht,a1
        moveq #8,d0
        moveq #-1,d1
        bsr.w editor_base_attributes+(sensi_disk_command-native_base_attributes)
editor_base_bht_loaded:
        tst.w d0
        bne.s base_attributes_clear_bht
        tst.w session_custom_mode
        beq.s base_attributes_done
        ; Admitted custom terrain pairs have a unique lowercase base prefix.
        ; The name builder normalizes case before the successful BHT read.
        cmpi.l #$64657362,native_resource_name
        bne.s base_attributes_done
        ; Custom Desert uses the Disk 2 mask. Disk 3 adds twelve bits in tile
        ; 62; clear only those bits, leaving every other loaded bit unchanged.
        andi.l #$C793BBFF,native_base_bht+$1F0
        andi.b #$8F,native_base_bht+$1F6
editor_base_bht_canonical:
base_attributes_done:
        movea.l (sp)+,a3
        rts
base_attributes_clear_bht:
        move.w #959,d0
        lea native_base_bht,a1
        clr.w d1
base_attributes_clear:
        move.w d1,(a1)+
        dbf d0,base_attributes_clear
        bra.s base_attributes_done
base_attributes_required:
        movea.l native_terrain_name_pointer,a0
        bsr.w editor_base_attributes+(native_resource_build_name-native_base_attributes)
        lea native_resource_name,a0
        movea.l a3,a1
        moveq #-1,d1
        bra.w editor_base_attributes+(native_resource_raw-native_base_attributes)
        dcb.b native_base_attributes_end-native_base_attributes-(*-editor_base_attributes),0
editor_base_attributes_end:
