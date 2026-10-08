<!-- Cannon Fodder In-Game Level Editor V1.0
Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
Licensed under the MIT License. See the LICENSE file for details. -->

# Verified Generation Cleanup

`cleanup.s` and `guarded_delete.s` are synchronous, include-only libraries in
the SAVE overlay. Include them after the SAVE, reader, encoder, payload
validator, writer and preflight code. `guarded_delete.s` includes the deletion
core `delete.s` (see [DELETE.md](DELETE.md)).

After a verified Save, cleanup removes older complete generations of the same
mission from the `Custom` directory. It never touches the new generation,
incomplete or invalid generations, other missions or unreferenced files.

## Entry Contracts

`cf_cleanup_entry` runs immediately after SAVE has published READY. It takes no
input registers and uses the fixed `SAVE_CONTEXT`. It requires READY = 1,
status 0, SAVE's guard flag, the target ID and generation equal to the resident
CFMD, and either mode 0 with no snapshot tag or authoring mode 2 with the exact
`SN` tag (status 10 otherwise). D0.w returns the cleanup status, which is also
stored in `SAVE_CLEANUP_STATUS`; D1-D7/A0-A6 and SP are preserved. It never
changes SAVE's status or READY, the committed generation, resident CFMD, MAP,
SPT or undo.

`cf_delete_guarded` removes one file:

| Register | Input |
|---|---|
| A0 | Even, addressable 16-byte NUL-padded canonical filename |

It preserves D1-D7/A0-A6 and SP and returns D0.w with Z set only on zero. It
requires the same SAVE READY, status, ID, generation and lifecycle conditions,
stopped gameplay, a zero SAVE source selector and interrupt priority below 6.
It refuses names that are not `hhhhhhhh.cmi`, `hhhhhhhhpp.map` or
`hhhhhhhhpp.spt` in lowercase hexadecimal, and any name starting with the
committed generation's eight-character prefix. A successful delete that sees
SAVE's CANCEL set returns 14. When a host delete was attempted, it clears the
game's cached directory count so native file operations reread the directory.

`cf_delete_attempted` and `cf_delete_verified` describe the last call. The
caller must have validated the complete obsolete generation before calling;
the helper does not infer that from a filename or READY alone.

Inside the helper, the identity check (`cf_delete_inspect`) qualifies the
directory with SAVE's cancellation, requires the `CFEDITOR` ID to equal
`SAVE_DISK_ID`, pins all 64 marker bytes on the first call and compares them on
every later call. Once a host delete has been attempted, cancellation is no
longer checked until that file has been verified.

## Selection and Validation

Each scan starts with a fresh preflight, restoring `SAVE_GENERATION` afterwards
so the committed generation never changes. The first pass records the record
count, which must be below 151; after every removed generation the count must
have decreased (status 12 otherwise). Within one pass the count and fingerprint
must stay unchanged (status 12).

Records are taken from the preflight catalog in order. A record is a candidate
when its case-folded name is a canonical `.cmi` name of 17..4,096 bytes. Its
manifest is read and parsed; a candidate with a different mission ID, or with
the committed generation, is skipped. The name is folded only in a private copy;
directory names are never rewritten.

The candidate is re-encoded into canonical form in the manifest slice. Every
phase is parsed from that canonical copy and its SPT and MAP are read with exact
length and CRC and structurally validated, including phases removed or reordered
in the new generation. Gameplay errors do not invalidate a draft. A candidate
whose manifest does not parse or whose payload fails structural validation is
skipped, as is one whose read returns 3 (absent), 13 (CRC) or 15 (size). Any
other read error, a failed re-encoding or an unparsable canonical copy stops
cleanup with that status.

## Removal

Nothing is deleted until every phase of the candidate has passed. Then the
manifest is removed first, followed by each phase's MAP and SPT, each through
`cf_delete_guarded`. An interruption therefore leaves only orphan payload files,
which an explicit RECOVER can remove; it never leaves a manifest whose files are
gone. After a removed generation the scan restarts from the first record with a
fresh preflight. The strictly decreasing record count bounds the loop by the
150-record limit.

Cleanup status zero means the scan completed, not that every old file was
removed. SAVE still returns zero with READY = 1 after a cleanup error; callers
show the cleanup warning and do not retry the committed save blindly. Private
SAVE word 124 counts verified removed files.

## Memory

| Owner | Extent |
|---|---|
| Preflight catalog / fresh catalog | READBACK 0..6,143 / 6,144..12,287 |
| Preflight state | READBACK 12,616..12,703 |
| Candidate CMI / parser scratch | READBACK 0..4,095 / 4,096..4,607 |
| One MAP or SPT read | READBACK from 0 |
| Delete: fresh / confirmed catalog | READBACK 0..6,143 / 6,144..12,287 |
| Delete masks and state | READBACK 12,288..12,939 |
| Guarded-delete state and pinned marker | READBACK 12,940..13,055 |
| File service / candidate name / CFMD candidate | WORK 0..863 / 864..879 / 1,032..1,287 |
| Canonical CMI / staged SPT | MANIFEST 0..3,583 / 3,584..4,095 |

These READBACK roles are sequential, never live at the same time. The candidate
name shares WORK 864.. with the encoder state and is copied back from the
reader request after canonicalization. Cleanup reuses SAVE private bytes
98..127 only after commitment, leaving SAVE's guard flag intact. The manifest
slice no longer holds the new manifest on return; use its file and the resident
CFMD as authority. No second authored MAP, undo or snapshot buffer, or extra
resident allocation is used. The combined SAVE image must fit its 16 KiB cap.
