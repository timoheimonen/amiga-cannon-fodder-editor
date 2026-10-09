; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

MODULE_MAGIC                equ $43464D4F
MODULE_ABI                  equ $0002
MODULE_HEADER_BYTES         equ $0020
MODULE_ID_OFFSET            equ $0008
MODULE_BASE_OFFSET          equ $000C
MODULE_SIZE_OFFSET          equ $0010
MODULE_ENTRY_OFFSET         equ $0014
MODULE_CRC_OFFSET           equ $0018
MODULE_FLAGS_OFFSET         equ $001C
MODULE_CONTEXT_MARKER       equ $0040
MODULE_CONTEXT_RUNS         equ $0044

; The load transaction uses 64 bytes of the resident I/O scratch allocation.
MODULE_IO_NAME              equ $0000
MODULE_IO_ID                equ $0010
MODULE_IO_CAPACITY          equ $0014
MODULE_IO_SIZE              equ $0018
MODULE_IO_KEEP_DRIVE        equ $001C
MODULE_IO_SECTORS           equ $001E
MODULE_IO_READ_BYTE         equ $001F
MODULE_IO_HEADER            equ $0020
; The WHDLoad transport publishes the CRC-32 of the loaded module payload here.
MODULE_IO_PAYLOAD_CRC       equ $0028
