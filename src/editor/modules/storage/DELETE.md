<!-- Cannon Fodder In-Game Level Editor V1.0
Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
Licensed under the MIT License. See the LICENSE file for details. -->

# Custom File Deletion

`delete.s` removes canonical mission files from the `Custom` directory through
the Slave's file service (operation 4), one verified file at a time. It is an
include-only core with two callers:

- `guarded_delete.s` in the SAVE overlay removes one named file during
  generation cleanup (see [CLEANUP.md](CLEANUP.md)).
- The browser and live file-management views define `CF_DELETE_RECORD_SET` and
  remove a confirmed set of directory records selected by bit masks.

The including code must define `CF_DELETE_GUARDED`; assembly fails otherwise.
`delete_names.s` supplies the shared name checks.

## Caller Contract

The includer provides:

| Symbol | Purpose |
|---|---|
| `CF_DELETE_WORK_BASE` | 652 bytes of private state |
| `CF_TRACK_COPY` | 6,144-byte confirmed directory snapshot; default `EDITOR_READBACK_BASE + 6144` |
| `cf_delete_inspect` | Qualify the directory, check the disk ID and pin or compare the 64-byte marker |
| `cf_delete_check` | Ownership and cancellation check |
| `cf_delete_marker` | Pinned 64-byte `CFEDITOR` record |
| `cf_delete_attempted`, `cf_delete_verified` | Result words |

Record-set builds additionally use the BDQ1 request and masks from
`browser_delete.i`.

`delete_entry` takes A0 pointing to the caller's request. A single-target
request starts with the 16-byte NUL-padded target name, which must be
`hhhhhhhh.cmi`, `hhhhhhhhpp.map` or `hhhhhhhhpp.spt` in lowercase hexadecimal
(status 10 otherwise). D0.w returns the status; all other data and address
registers are preserved. The call is synchronous and non-reentrant; keep the
module loaded and its buffers exclusively owned until it returns.

| Status | Meaning |
|---:|---|
| 0 | Every selected file removed and verified |
| 3 | Single target not present |
| 10 | Invalid target, mask set or ownership |
| 11 | Directory or identity differs from the confirmed snapshot |
| 12 | More than one record matches a single target |
| 13 | The file service did not publish READY |
| 14 | Cancelled |

File-service statuses, such as 5 for a failed host delete, are returned
unchanged.

## Procedure

1. Clear the done and selected masks.
2. Qualify the directory and read its normalized catalog with
   `storage_read_track` into READBACK 0..6,143. The record count must be 1..150.
3. Single target: copy that catalog to `CF_TRACK_COPY`. Record set: require it to
   equal the confirmed snapshot already held in `CF_TRACK_COPY`, the BDQ1 live
   count to match, the selected bits to lie below the count and outside the
   protected mask, and their number to equal the BDQ1 file count.
4. Select the records. A single target matches by ASCII case-folded name and
   must match exactly once. Every record-set selection, folded to lowercase,
   must be a canonical mission filename.
5. Delete in two passes: all selected `.cmi` manifests first, then the remaining
   payload files. Before each file the core checks cancellation, requalifies the
   directory and requires the survivors to equal the confirmed snapshot minus
   the files already removed. It then sets ATTEMPTED and calls the file service
   with the lowercase name and the pinned disk ID.
6. After each removal it requalifies and checks the survivors again. Record-set
   builds publish the verified removal count in `BDQ_REMOVED` after every file.
7. When all files are removed it sets VERIFIED and checks cancellation once more.

The survivor check compares the record count and every remaining 32-byte record
in order, and requires the unused tail of the 150-record cache to be zero. The
file service itself verifies that its listing after the delete equals the
expected directory and that every surviving record is unchanged.

Each service call saves the 80-byte reader request at `EDITOR_IO_BASE + 64` on
the stack and restores it afterwards; the request it builds has a zero CANCEL
field, so a started removal is always completed and verified.

## Cancellation and Interruption

Cancellation is honoured before each file and after the last one, never during
a host delete. A cancellation after a verified removal returns 14 with ATTEMPTED
set; callers must treat the directory as changed.

Deleting manifests first means an interrupted operation leaves only orphan
payload files, never a visible manifest whose files have been removed. The
browser's RECOVER view lists such orphans.

## Memory

| Region | Use |
|---|---|
| READBACK 0..6,143 | Fresh catalog snapshot |
| `CF_TRACK_COPY`, 6,144 bytes | Confirmed catalog; record indices and names stay stable while the directory shrinks |
| `CF_DELETE_WORK_BASE` + 0..19 | Done mask, one bit per record |
| `CF_DELETE_WORK_BASE` + 20..39 | Selected mask |
| `CF_DELETE_WORK_BASE` + 40..41 | Removed count |
| `CF_DELETE_WORK_BASE` + 640..651 | Request pointer and record count |

Mask bit `i` is bit `i & 7` of byte `i >> 3`. The source asserts that
`CF_TRACK_COPY` ends inside READBACK.
