; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Addresses independently checked in the supported FODDERC executable.
; The build verifies each patched instruction; the Slave rechecks its own sites.

main_base             equ $80000
hill_wait_call        equ $a58ac
disk_read_track       equ $8c1e2
disk_write_track      equ $8c0de
disk_write_protected  equ $8c790
disk_no_media         equ $8c788
disk_read_error       equ $8c7a8
disk_current_track    equ $8c3d6
disk_drive            equ $8c882
disk_scratch          equ $8c888
