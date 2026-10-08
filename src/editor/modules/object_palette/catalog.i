; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Selected roots only; each complete companion bundle is one row.
pal_catalog:
        dc.w $00,.name0-pal_catalog
        dc.w $48,.name1-pal_catalog
        dc.w $05,.name2-pal_catalog
        dc.w $24,.name3-pal_catalog
        dc.w $6a,.name4-pal_catalog
        dc.w $0f,.name5-pal_catalog
        dc.w $14,.name6-pal_catalog
        dc.w $18,.name7-pal_catalog
        dc.w $19,.name8-pal_catalog
        dc.w $49,.name9-pal_catalog
        dc.w $4a,.name10-pal_catalog
        dc.w $4b,.name11-pal_catalog
        dc.w $4c,.name12-pal_catalog
        dc.w $58,.name13-pal_catalog
        dc.w $5a,.name14-pal_catalog
        dc.w $63,.name15-pal_catalog
        dc.w $64,.name16-pal_catalog
        dc.w $6c,.name17-pal_catalog
        dc.w $6d,.name18-pal_catalog
        dc.w $6e,.name19-pal_catalog
        dc.w $28,.name20-pal_catalog
        dc.w $2a,.name21-pal_catalog
        dc.w $2b,.name22-pal_catalog
        dc.w $2c,.name23-pal_catalog
        dc.w $31,.name24-pal_catalog
        dc.w $32,.name25-pal_catalog
        dc.w $33,.name26-pal_catalog
        dc.w $34,.name27-pal_catalog
        dc.w $3f,.name28-pal_catalog
        dc.w $40,.name29-pal_catalog
        dc.w $41,.name30-pal_catalog
        dc.w $45,.name31-pal_catalog
        dc.w $4e,.name32-pal_catalog
        dc.w $4f,.name33-pal_catalog
        dc.w $50,.name34-pal_catalog
        dc.w $51,.name35-pal_catalog
        dc.w $52,.name36-pal_catalog
        dc.w $54,.name37-pal_catalog
        dc.w $55,.name38-pal_catalog
        dc.w $66,.name39-pal_catalog
        dc.w $67,.name40-pal_catalog
        dc.w $68,.name41-pal_catalog
        dc.w $69,.name42-pal_catalog
        dc.w $6b,.name43-pal_catalog
        dc.w $0d,.name44-pal_catalog
        dc.w $0e,.name45-pal_catalog
        dc.w $10,.name46-pal_catalog
        dc.w $11,.name47-pal_catalog
        dc.w $12,.name48-pal_catalog
        dc.w $1b,.name49-pal_catalog
        dc.w $25,.name50-pal_catalog
        dc.w $26,.name51-pal_catalog
        dc.w $36,.name52-pal_catalog
        dc.w $37,.name53-pal_catalog
        dc.w $38,.name54-pal_catalog
        dc.w $3c,.name55-pal_catalog
        dc.w $3d,.name56-pal_catalog
        dc.w $3e,.name57-pal_catalog
        dc.w $42,.name58-pal_catalog
        dc.w $43,.name59-pal_catalog
        dc.w $44,.name60-pal_catalog
        dc.w $46,.name61-pal_catalog
        dc.w $53,.name62-pal_catalog
        dc.w $5b,.name63-pal_catalog
        dc.w $5c,.name64-pal_catalog
        dc.w $5d,.name65-pal_catalog
        dc.w $5e,.name66-pal_catalog
        dc.w $5f,.name67-pal_catalog
        dc.w $60,.name68-pal_catalog
        dc.w $62,.name69-pal_catalog
.name0: dc.b "00 SOLDIER",-1
.name1: dc.b "48 HOSTAGE",-1
.name2: dc.b "05 ENEMY",-1
.name3: dc.b "24 ENEMY?",-1
.name4: dc.b "6A LEADER",-1
.name5: dc.b "0F ROOF?",-1
.name6: dc.b "14 SPAWN DOOR",-1
.name7: dc.b "18 SPAWN HOLE",-1
.name8: dc.b "19 SPAWN DOOR2",-1
.name9: dc.b "49 RESCUE TENT",-1
.name10: dc.b "4A CIVIL DOOR",-1
.name11: dc.b "4B CIVIL DOOR2",-1
.name12: dc.b "4C CIV SPEAR DOOR",-1
.name13: dc.b "58 SPAWN DOOR3",-1
.name14: dc.b "5A RESCUE DOOR?",-1
.name15: dc.b "63 HELI CALL PAD",-1
.name16: dc.b "64 REINF DOOR",-1
.name17: dc.b "6C COMPUTER70?",-1
.name18: dc.b "6D COMPUTER105?",-1
.name19: dc.b "6E COMPUTER175?",-1
.name20: dc.b "28 E HELI GRENADE",-1
.name21: dc.b "2A E HELI UNARMED",-1
.name22: dc.b "2B E HELI MISSILE",-1
.name23: dc.b "2C E HELI HOMING",-1
.name24: dc.b "31 P HELI GRENADE",-1
.name25: dc.b "32 P HELI UNARMED",-1
.name26: dc.b "33 P HELI MISSILE",-1
.name27: dc.b "34 P HELI HOMING",-1
.name28: dc.b "3F P CAR UNARMED?",-1
.name29: dc.b "40 P CAR GUN?",-1
.name30: dc.b "41 P TANK",-1
.name31: dc.b "45 E TANK",-1
.name32: dc.b "4E P TURRET 0",-1
.name33: dc.b "4F P TURRET 1",-1
.name34: dc.b "50 E CAR UNARMED?",-1
.name35: dc.b "51 E CAR GUN?",-1
.name36: dc.b "52 E VEHICLE10?",-1
.name37: dc.b "54 E TURRET 0",-1
.name38: dc.b "55 E TURRET 1",-1
.name39: dc.b "66 CALL HELI5",-1
.name40: dc.b "67 CALL HELI7",-1
.name41: dc.b "68 CALL HELI8",-1
.name42: dc.b "69 E TURRET 9",-1
.name43: dc.b "6B E HELI HOMING2",-1
.name44: dc.b "0D SHRUB?",-1
.name45: dc.b "0E TREE?",-1
.name46: dc.b "10 SNOWMAN?",-1
.name47: dc.b "11 SHRUB2?",-1
.name48: dc.b "12 WATERFALL?",-1
.name49: dc.b "1B DEAD SOLDIER?",-1
.name50: dc.b "25 GRENADES",-1
.name51: dc.b "26 ROCKETS",-1
.name52: dc.b "36 MINE?",-1
.name53: dc.b "37 MINE2?",-1
.name54: dc.b "38 SPIKE?",-1
.name55: dc.b "3C BOILING POT?",-1
.name56: dc.b "3D CIVILIAN?",-1
.name57: dc.b "3E CIVILIAN2?",-1
.name58: dc.b "42 BIRD LEFT",-1
.name59: dc.b "43 BIRD RIGHT",-1
.name60: dc.b "44 SEAL?",-1
.name61: dc.b "46 CIVIL SPEAR?",-1
.name62: dc.b "53 CIVIL HIDDEN?",-1
.name63: dc.b "5B SEAL MINE?",-1
.name64: dc.b "5C SPIDER MINE?",-1
.name65: dc.b "5D RANK 15",-1
.name66: dc.b "5E ROCKET BONUS?",-1
.name67: dc.b "5F ARMOUR BONUS?",-1
.name68: dc.b "60 LEADER BONUS",-1
.name69: dc.b "62 SQUAD BONUS",-1
        even
pal_category_ranges:
        dc.w 0,2
        dc.w 2,3
        dc.w 5,15
        dc.w 20,24
        dc.w 44,26
pal_category_labels:
        dc.w 0,96,.player-pal_category_labels
        dc.w 96,96,.enemies-pal_category_labels
        dc.w 192,112,.buildings-pal_category_labels
        dc.w 0,128,.vehicles-pal_category_labels
        dc.w 128,176,.items-pal_category_labels
.player: dc.b "PLAYER",-1
.enemies: dc.b "ENEMIES",-1
.buildings: dc.b "BUILDINGS",-1
.vehicles: dc.b "VEHICLES",-1
.items: dc.b "ITEMS/TERRAIN",-1
        even
