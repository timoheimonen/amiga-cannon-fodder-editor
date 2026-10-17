; Cannon Fodder In-Game Level Editor V1.2.2
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Bounded selected-root toolbar names. Full variants belong to the palette.
object_name_offsets:
        dc.w .name0-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .name1-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .name2-object_name_offsets
        dc.w .name3-object_name_offsets
        dc.w .name4-object_name_offsets
        dc.w .name5-object_name_offsets
        dc.w .name2-object_name_offsets
        dc.w .name6-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .name7-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .name8-object_name_offsets
        dc.w .name7-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .name9-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .name10-object_name_offsets
        dc.w .name11-object_name_offsets
        dc.w .name12-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .name13-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .name13-object_name_offsets
        dc.w .name13-object_name_offsets
        dc.w .name13-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .name14-object_name_offsets
        dc.w .name14-object_name_offsets
        dc.w .name14-object_name_offsets
        dc.w .name14-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .name15-object_name_offsets
        dc.w .name16-object_name_offsets
        dc.w .name17-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .name18-object_name_offsets
        dc.w .name19-object_name_offsets
        dc.w .name19-object_name_offsets
        dc.w .name20-object_name_offsets
        dc.w .name20-object_name_offsets
        dc.w .name21-object_name_offsets
        dc.w .name22-object_name_offsets
        dc.w .name22-object_name_offsets
        dc.w .name23-object_name_offsets
        dc.w .name24-object_name_offsets
        dc.w .name19-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .name25-object_name_offsets
        dc.w .name26-object_name_offsets
        dc.w .name27-object_name_offsets
        dc.w .name27-object_name_offsets
        dc.w .name27-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .name28-object_name_offsets
        dc.w .name28-object_name_offsets
        dc.w .name29-object_name_offsets
        dc.w .name29-object_name_offsets
        dc.w .name29-object_name_offsets
        dc.w .name19-object_name_offsets
        dc.w .name30-object_name_offsets
        dc.w .name30-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .name7-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .name31-object_name_offsets
        dc.w .name32-object_name_offsets
        dc.w .name33-object_name_offsets
        dc.w .name34-object_name_offsets
        dc.w .name35-object_name_offsets
        dc.w .name36-object_name_offsets
        dc.w .name37-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .name38-object_name_offsets
        dc.w .name39-object_name_offsets
        dc.w .name7-object_name_offsets
        dc.w .unknown-object_name_offsets
        dc.w .name14-object_name_offsets
        dc.w .name14-object_name_offsets
        dc.w .name14-object_name_offsets
        dc.w .name30-object_name_offsets
        dc.w .name40-object_name_offsets
        dc.w .name13-object_name_offsets
        dc.w .name41-object_name_offsets
        dc.w .name41-object_name_offsets
        dc.w .name41-object_name_offsets
.unknown: dc.b "OBJECT",-1
.name0: dc.b "SOLDIER",-1
.name1: dc.b "ENEMY",-1
.name2: dc.b "BUSH",-1
.name3: dc.b "TREE",-1
.name4: dc.b "ROOF",-1
.name5: dc.b "SNOWMAN",-1
.name6: dc.b "WATERFALL",-1
.name7: dc.b "SPAWN",-1
.name8: dc.b "HOLE",-1
.name9: dc.b "BODY",-1
.name10: dc.b "ROCKET ENEMY",-1
.name11: dc.b "GRENADES",-1
.name12: dc.b "ROCKETS",-1
.name13: dc.b "HELI E",-1
.name14: dc.b "HELI P",-1
.name15: dc.b "MINE",-1
.name16: dc.b "TRIP WIRE",-1
.name17: dc.b "SPIKE TRAP",-1
.name18: dc.b "CAMPFIRE",-1
.name19: dc.b "CIVILIAN",-1
.name20: dc.b "JEEP P",-1
.name21: dc.b "TANK P",-1
.name22: dc.b "BIRD",-1
.name23: dc.b "SEAL/SHEEP",-1
.name24: dc.b "TANK E",-1
.name25: dc.b "HOSTAGE",-1
.name26: dc.b "RESCUE",-1
.name27: dc.b "CIV DOOR",-1
.name28: dc.b "TURRET P",-1
.name29: dc.b "JEEP E",-1
.name30: dc.b "TURRET E",-1
.name31: dc.b "CIV HOME",-1
.name32: dc.b "SEAL MINE",-1
.name33: dc.b "SPIDER MINE",-1
.name34: dc.b "RANK BONUS",-1
.name35: dc.b "HOMING BONUS",-1
.name36: dc.b "ARMOUR BONUS",-1
.name37: dc.b "LEADER BONUS",-1
.name38: dc.b "SQUAD BONUS",-1
.name39: dc.b "CALL PAD",-1
.name40: dc.b "LEADER",-1
.name41: dc.b "COMPUTER",-1
        even
