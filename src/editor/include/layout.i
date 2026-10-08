; Cannon Fodder In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; Editor partitions above the FODDERC image in the Slave's BaseMem.
; Exclusive ends; fixed budgets, not claims of native memory ownership.
EDITOR_RESIDENT_BASE         equ $0ADA00
EDITOR_RESIDENT_BYTES        equ $00253A
EDITOR_GATE_BYTES            equ $000E80
EDITOR_SNAPSHOT_BASE         equ $0AE880
EDITOR_SNAPSHOT_BYTES        equ $000E68
EDITOR_SESSION_BASE          equ $0AF6E8
EDITOR_SESSION_BYTES         equ $000180
EDITOR_METADATA_BASE         equ $0AF868
EDITOR_METADATA_BYTES        equ $000180
EDITOR_IO_BASE               equ $0AF9E8
EDITOR_IO_BYTES              equ $000200
EDITOR_UI_BASE               equ $0AFBE8
EDITOR_UI_BYTES              equ $000100
EDITOR_SPT_BASE              equ $0AFCE8
EDITOR_SPT_BYTES             equ $0001AE
; Unused, zero at start.
EDITOR_SPARE_BASE            equ $0AFE96
EDITOR_SPARE_BYTES           equ $0000A2
EDITOR_GUARD_BASE            equ $0AFF38
EDITOR_GUARD_BYTES           equ $000002
EDITOR_RESIDENT_END          equ $0AFF3A
EDITOR_DIRECTORY_BASE        equ $0AFF3A
EDITOR_DIRECTORY_BYTES       equ $0012C0
EDITOR_DIRECTORY_RECORDS     equ $000096

; Editor mode: module code, undo, workspace, guards.
EDITOR_MODULE_BASE           equ $0B11FA
EDITOR_MODULE_BYTES          equ $008000
EDITOR_UNDO_BASE             equ $0B91FA
EDITOR_UNDO_BYTES            equ $001000
EDITOR_WORK_BASE             equ $0BA1FA
EDITOR_WORK_BYTES            equ $001000
EDITOR_MODULE_GUARD_BASE     equ $0BB1FA
EDITOR_MODULE_GUARD_BYTES    equ $0000A0
EDITOR_MODULE_END            equ $0BB29A
EDITOR_BANK_BYTES            equ $00A0A0

; Serialization mode replaces only the module code and workspace partitions.
EDITOR_SERIALIZER_BASE       equ $0B11FA
EDITOR_SERIALIZER_BYTES      equ $004000
EDITOR_READBACK_BASE         equ $0B51FA
EDITOR_READBACK_BYTES        equ $003AF8
EDITOR_SERIAL_WORK_BASE      equ $0B8CF2
EDITOR_SERIAL_WORK_BYTES     equ $000508
EDITOR_MANIFEST_BASE         equ $0BA1FA
EDITOR_MANIFEST_BYTES        equ $001000

; The cold-boot marker occupies the final longword of the bootstrap payload.
EDITOR_BOOT_MARKER_OFFSET    equ $000020
EDITOR_BOOT_MARKER_VALUE     equ $43465031
