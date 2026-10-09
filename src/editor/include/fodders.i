; Cannon Fodder In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.

; The reference Fairlight FODDERC executable at $80000 in the Slave's 1 MiB
; BaseMem. Every value is the verified FODDERC binding of the native entry.
; Names keep their historical FODDERS prefix; addresses quoted in comments are
; FODDERC addresses.
FODDERS_BASE                 equ $080000
FODDERS_IMAGE_BYTES          equ $02CA14
FODDERS_INIT                 equ $085D92
FODDERS_PROBE_COMPLETE       equ $085DAC
FODDERS_FAIRLIGHT_FIX         equ $08BC82
FODDERS_DISK_COMMAND         equ $08B3E8
FODDERS_RECRUITMENT_LOOP     equ $0A5896
FLOAD_HANDOFF                equ $073C92

; Native recruitment wait/click entries and frame synchronization bindings.
; Hook sites are checked against whole-instruction reference byte sequences.
FODDERS_RECRUITMENT_WAIT     equ $0A58AC
FODDERS_RECRUITMENT_CLICK    equ $0A58F8
FODDERS_FRAME_WAIT           equ $08649A
FODDERS_LOAD_FLAG            equ $08289E

; Canonical native entry names for initialization, disk commands and input.
; These aliases refer to the same reference image entries above.
main_entry                  equ $080000
main_initialise             equ $085DAC
main_hardware_setup         equ $085DAC
sensi_disk_command          equ $08B3E8
wait_frame                  equ $08649A
recruitment_handle_click    equ $0A58F8

; The native directory count is patched to the allocated record capacity.
; D3 is a record count for sensi_cache_directory, not a byte count.
main_directory_limit        equ $085E3C
main_directory_limit_next   equ $085E40

; Native command 24 writes these fields at $8BCE6/$8BCF6.
; Command 8 expands a nonzero legacy marker; modules must have a zero marker.
sensi_file_rle_marker       equ $08C7C4
sensi_file_stored_bytes     equ $08C7C6

; Native initializer $8B44A supplies the scratch pointer used by track reads.
sensi_track_scratch_pointer equ $08C888
; Command 36 and motor-off $8C5C0; disk-change input at $8C544.
sensi_keep_drive_selected   equ $08C7EA

; Checked track read: hook, continuation and the native track decoder.
sensi_checked_read_hook     equ $08C20C
sensi_checked_read_next     equ $08C212
sensi_current_track         equ $08C3D6
sensi_decode_native_track   equ $08C6A4
SENSI_NATIVE_MAGIC          equ $534F5336
SENSI_TRACK_MAGIC_OFFSET    equ $000008
SENSI_TRACK_CHECKSUM_OFFSET equ $00000C
SENSI_TRACK_NUMBER_OFFSET   equ $000012

; Audio initialization and level 1 interrupt entry share this enable flag.
fodders_audio_enabled       equ $0A3C5E
fodders_audio_init_enable   equ $0A3E14
fodders_audio_init_next     equ $0A3E1C
fodders_audio_init_return   equ $0A3F12
fodders_audio_init_end      equ $0A3F18
; Front-end song selection and start; the results screen selects song 0 at
; $A8BC8 and starts it at $A8BD0 after every mission.
fodders_music_song          equ $0A3C56
fodders_music_start         equ $0A3C60

; Camera/ring globals used by the native
; four-plane masked blitter register contract at $A378C.
camera_world_x              equ $0814AE
camera_world_y              equ $0814B2
display_ring_x              equ $0814A6
display_ring_y              equ $0814AA
display_draw_buffer         equ $081492
blit_masked_sprite_planes   equ $0A378C

; Native MAP buffer: 96-byte header plus at most 15,000 cell bytes.
map_file_buffer             equ $0F9D5C

; Native campaign modal and the six disk-marker
; callers. Snapshot size is the exact native campaign load payload.
campaign_payload             equ $080626
campaign_marker_destination  equ $082888
campaign_directory_pointer   equ $0828D2
campaign_directory_count     equ $0828DE
campaign_loaded              equ $0829E6
campaign_marker_name         equ $0AAA30
campaign_gate_continue       equ $0A9E5C
campaign_retry               equ $0A9E6E
campaign_list_continue       equ $0A9EF6
campaign_cleanup             equ $0AACCE
campaign_restore_display     equ $0AABF0
campaign_cleanup_hook        equ $0AA00C
campaign_modal_return        equ $0AA014
sensi_load_file_continue     equ $08BD9A
sensi_lookup_name            equ $08C7B8
CAMPAIGN_BYTES               equ $0728

; Mission metadata bindings consumed by native
; rank, ammunition, aggression, objective, countdown and title consumers.
native_mission_number        equ $080632
native_map_index             equ $080626
native_rank_resume           equ $089FEE
native_rank_store            equ $089FF4
native_ammo                  equ $09E0B4
native_grenades              equ $081F4C
native_rockets               equ $081F52
native_assigned_count        equ $080D4C
native_aggression            equ $09E0EC
native_aggression_apply      equ $09E102
native_objectives            equ $0A4C4E
native_objective_flags       equ $082A08
native_grenade_branch        equ $0962AA
native_grenade_random        equ $0962AC
native_grenade_skip          equ $0962C4
native_overview_branch       equ $08845C
native_countdown_branch      equ $0884E6
native_failure_branch        equ $098382
native_ammunition_next       equ $0861D6
native_aggression_next       equ $0861DC
native_objectives_next       equ $0861E2
native_briefing_objectives_next equ $0A7F2E
native_countdown_setup_next  equ $086212
native_countdown_setup       equ $0884CC
native_countdown_subtick     equ $082A74
native_countdown_delay       equ $082A78
native_title_y               equ $0815A0
native_briefing_font         equ $0A9C86
native_title_measure         equ $0A81D0
native_title_draw            equ $0A8208
native_mission_title_table   equ $0A83E8
native_title_heading_resume  equ $0A81A4
; Immutable Template source tables in the original mission metadata.
native_phase_count_table     equ $0A4C1E
native_phase_title_table     equ $0A8448
native_aggression_table      equ $0A4F70
native_objective_table       equ $0A4D8E
native_mission_titles_start  equ $0A8223
native_mission_titles_end    equ $0A83E7
native_phase_titles_start    equ $0A8568
native_phase_titles_end      equ $0A89F8
native_objective_lists_start equ $0A4EAE
native_objective_lists_end   equ $0A4F6F

; Native MAP/SPT loader,
; gameplay return and post-hill instruction boundaries.
native_map_filename          equ $087096
native_map_name              equ $086DE4
native_map_full_resume       equ $086E2C
native_map_full_loaded       equ $086E3A
native_map_reload_resume     equ $086DFA
native_spt_resume            equ $08A546
native_enemy_count           equ $081F5E
native_rescue_count          equ $081F60
native_entity_pool           equ $0FDB2C
native_spt_construct         equ $08A5A0
native_outcome_nonzero       equ $08624C
native_outcome_zero          equ $08623E
native_play_guard            equ $08279C
native_no_squad              equ $081DCA
native_objective_success     equ $081DCC
native_abort_or_failure      equ $081DD2
native_gameplay_active       equ $080610
native_campaign_dialog       equ $0A9E56
native_after_dialog          equ $085FE4
native_phase_reset           equ $085F0C
native_resource_list_load    equ $086B24
native_briefing_palette_resources equ $086BC6 ; final font.pl8 record and sentinel
native_recruitment_pending   equ $080654
native_binding_backup_valid  equ $08063E
native_terrain_marker        equ $08000E
native_base_asset_cache      equ $0800E0
native_sub_asset_cache       equ $0800F0

; Whole-instruction hook sites for the bounded campaign and phase adapters.
; Reference main disassembly establishes the whole-instruction boundaries.
campaign_gate_hook                equ $0A9E56
campaign_list_hook                equ $0A9E90
campaign_load_hook                equ $0A9FFE
sensi_load_file_hook              equ $08BD94
policy_rank_hook                  equ $089FE8
policy_ammunition_hook            equ $0861D0
policy_aggression_hook            equ $0861D6
policy_objectives_hook            equ $0861DC
policy_briefing_objectives_hook   equ $0A7F28
policy_enemy_grenades_hook        equ $0962A2
policy_overview_hook              equ $088454
policy_countdown_hook             equ $0884DE
policy_countdown_failure_hook     equ $09837A
policy_countdown_setup_hook       equ $08620C
policy_title_measure_hook         equ $0A81C6
policy_title_draw_hook            equ $0A8200
policy_title_heading_hook         equ $0A819A
session_map_full_hook             equ $086E22
session_map_reload_hook           equ $086DF0
session_spt_hook                  equ $08A53C
session_outcome_hook              equ $086236
session_after_hill_hook           equ $085FDE

; Native recruitment, font, input and stopped-phase display consumers.
sensi_selected_drive             equ $08C882
native_font_masks                equ $0A3832
native_hill_font_table           equ $08D3F6
native_hill_animation_table      equ $090F10
native_hill_widths               equ $0A9D46
native_measure_text              equ $0A997A
native_draw_text                 equ $0A9A06
; D0.w selector, D1.w frame, D2.w X, D3.w top Y: a masked item into the draw buffer.
native_draw_sprite               equ $0A2464
native_mask_mode                 equ $08156A
display_visible_buffer           equ $081496
native_text_x_width              equ $0828A2
native_text_y_height             equ $0828A6
native_left_down                 equ $081476
native_left_pressed              equ $081484
; Native sampled/latched right mouse button.
native_right_down                equ $081478
native_right_pressed             equ $081486
native_last_key                  equ $0814E8
; Native key consumer at $8A366 reads this event before translation.
native_raw_key                   equ $0814E4
; The previous translated event; a repeat of it is not reported again.
native_key_previous              equ $0814E6
; The keyboard interrupt's store of the held raw code (0 on its release).
keyboard_store_hook              equ $08A346
keyboard_store_next              equ $08A34C
; Tail of the per-field key translation: compare with the previous event,
; then publish it or clear native_last_key (30 bytes up to its table).
keyboard_event_hook              equ $08A37E
keyboard_event_end               equ $08A39C
native_mouse_x                   equ $08CABA
native_mouse_y                   equ $08CABC
; Field counter, advanced by the game's level-1 handler every field.
native_field_counter             equ $080618
native_save_flag                 equ $0828A0
native_click_continue            equ $0A58FE
amiga_dmacon_read                equ $DFF002
native_descriptor_table          equ $081FEA
native_display_offsets           equ $08149A
native_cursor_offsets            equ $081E12
native_cursor_active             equ $081FDE
native_publish_display           equ $086624
; A0 buffer, clears 41120 bytes; D0/A0 changed.
native_clear_display_buffer      equ $0A35DC
; Native copper-list words borrowed by modal displays.
native_copper_depth              equ $0031FE
native_copper_odd_modulo          equ $00320A
native_copper_wrap_wait          equ $003254
native_copper_color0             equ $003136
native_copper_color6             equ $00314E
native_hill_cache                equ $0D13AA
native_hill_font_pixels          equ $03294A
; Rendering mask walk: 117 descriptors $8D45E..$8DBAD, sum 2*width*height.
native_hill_mask_bytes           equ $1CC2
native_mask_workspace           equ $04C3EA
native_hill_body                 equ $0A627A
native_hill_body_end             equ $0A633A
native_controller_body           equ $0A9E96
native_browser_request           equ $0A62B0
native_editor_prompt_title       equ $0A62C8
native_editor_prompt_options     equ $0A62DB
native_editor_hill_font          equ $0A62EA
; blit_masked_sprite_planes tests this flag before its plane count;
; native departure $A76F8 sets it and $A7850 clears it.
native_fifth_plane               equ $081E08
; Two unused final mask guard bytes
; sample adjacent source RAM during native gameplay-mask regeneration.
native_mask_discarded_guard      equ $057716

; Native campaign reconstruction at $85F0C/$85FD8 and the
; dead-list aging/render calls at $A57A6.
session_before_hill_hook          equ $085FD8
session_hill_history_hook         equ $0A57A6
native_hill_enter                 equ $0A56B0
native_dead_list_age              equ $0A635E
native_hall_of_fame_draw          equ $0A63BA
native_hill_history_next          equ $0A57AE

; Error-only frame waits used by raw and ILBM asset loader retry loops.
native_resource_raw_wait_hook     equ $087624
native_resource_ilbm_wait_hook    equ $087684
native_resource_raw_wait_next     equ $08762A
native_resource_ilbm_wait_next    equ $08768A
native_resource_retry_delay       equ $0826FE
; Base terrain loader and buffers used by native resource selection.
; The only caller at $86E9C ignores returned condition codes.
native_base_attributes           equ $08A404
native_base_attributes_end       equ $08A4A0
native_terrain_name_pointer      equ $08178A
native_resource_name             equ $0816E8
native_resource_raw              equ $0875F8
; Native resource retry ABI: raw/ILBM loader entries.
native_resource_ilbm             equ $08765C
native_resource_retry_body       equ $08767A
; Immutable native disk captions.
native_insert_disk_text          equ $0AAE6A
native_disk2_suffix              equ $0AAEA2
native_disk3_suffix              equ $0AAEB8
native_resource_toggle           equ $0876BC
; End of the delay toggle.
native_resource_loaders_end      equ $0876DA
native_resource_arguments        equ $0826F2
native_resource_status           equ $080620
native_resource_drive            equ $08061C
native_ilbm_load                 equ $08B12A
native_resource_build_name       equ $08A66C
native_extension_hit             equ $08A658
native_extension_bht             equ $08A65C
native_extension_swp             equ $08A660
native_base_swp                  equ $0F8A9A
native_base_bht                  equ $0F8DBC
native_base_hit                  equ $0F9A3C
native_frame_flag                 equ $08060E

; Paired recruitment bitmap,
; native text modes and the six hardware-sidebar sprite pointer pairs.
display_buffer_pair_a             equ $08148A
display_buffer_pair_b             equ $08148E
display_buffer_selector           equ $080616
native_text_space_substitute      equ $0821A6
native_text_alternate             equ $0821AE
native_sidebar_copper             equ $0031C4
native_sidebar_pointer_high       equ $0031C6

; Native roster initialization
; $89E48, allocation $89FC8, death appends $96CC0 and HOF update $96DF6.
native_frame_domain               equ $08060E
native_phase_number               equ $080634
native_recruits_remaining         equ $080638
native_recruit_bindings           equ $080640
native_campaign_scalars_b         equ $080650
native_phases_remaining           equ $080658
native_phase_count                equ $08065A
native_next_recruit_name           equ $08065E
native_roster                     equ $080664
native_roster_tail                equ $0806C4
native_dead_ranks                 equ $08073C
native_dead_rank_limit            equ $080A0C
native_dead_rank_end              equ $080A0E
native_dead_rank_cursor           equ $080A12
native_dead_names                 equ $080A16
native_dead_name_limit            equ $080CE6
native_dead_name_end              equ $080CE8
native_hall_of_fame               equ $080CF8
native_death_kill_counts           equ $080D1C
native_roster_init                equ $089E48
native_score_init                 equ $096DE2

; Native directory cache count, read by the guarded delete.
sensi_directory_cached_count     equ $08C7F0

; EDTR bindings into native rendering, assets and camera state.
editor_tile_blit              equ $0AB76A
editor_game_sprites           equ $08DCDA
editor_hill_font_frames       equ $08D66E
editor_base_palette          equ $0800A0
editor_hill_palette          equ $080174
editor_native_palette        equ $080010
editor_fade_state            equ $0817C0
editor_pointer_update        equ $09C67E
editor_copper_list           equ $003134
editor_copper_tail           equ $003248
editor_copper_scroll         equ $003202
editor_copper_fetch          equ $00321E
editor_copper_planes         equ $003222
editor_tile_data             equ $03FBEA
editor_map_width             equ $0F9DB0
editor_map_height            equ $0F9DB2
editor_map_grid              equ $0F9DBC

; Native campaign OK/$FF string, referenced in place without embedding game bytes.
native_authoring_ok equ $0AA232

; TILE palette binding: 400 contiguous native HIT words.
editor_hit_table             equ $0F9A3C

; Terrain metadata (400 contiguous slots).
editor_swp_table             equ $0F8A9A
editor_bht_table             equ $0F8DBC

; Commodore Hardware Reference Manual, custom-register summary and blitter DMA.
amiga_bltcon0 equ $DFF040
amiga_bltcon1 equ $DFF042
amiga_bltafwm equ $DFF044
amiga_bltcpt equ $DFF048
amiga_bltapt equ $DFF050
amiga_bltdpt equ $DFF054
amiga_bltsize equ $DFF058
amiga_bltcmod equ $DFF060
amiga_bltamod equ $DFF064
amiga_bltdmod equ $DFF066

; The Slave patches the backend veneer jump before Main entry.
EDITOR_BACKEND_ENTRY         equ $0ADA24
