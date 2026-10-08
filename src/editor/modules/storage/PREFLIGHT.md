<!-- Cannon Fodder In-Game Level Editor V1.0
Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
Licensed under the MIT License. See the LICENSE file for details. -->

# Read-Only Save Preflight

`preflight.s` qualifies the `Custom` directory for a Save, captures a stable
catalog and chooses an unused generation token. It writes no files, does not
validate mission gameplay and does not reserve capacity for a later operation.

## Interface

Include the shared layout, metadata, module, native-address, storage-reader and
save definitions before this source, and link `read.s` with it. The file has no
module header or fixed origin.

Call `cf_preflight_entry` with `A0 = SAVE_CONTEXT`. Any other A0 returns status
10 without reading the request or writing the result. The caller must:

- own stopped editor mode with native gameplay inactive and interrupt priority
  below 6;
- validate its complete SVR1 request separately; this helper reads only the
  disk ID, the generation hint and the live cancellation word;
- own READBACK, serializer WORK 0..863, the directory cache, the native track
  scratch and the reader request at `EDITOR_IO_BASE + 64` for the whole call.

D0.w returns zero on success or the storage-reader statuses: 10 invalid call,
11 wrong or changed directory or identity, 12 corrupt listing, 14 cancelled,
and the file service's read statuses. D1-D7, A0-A6 and SP are preserved; the
condition codes test the returned status.

The request is unchanged except `SAVE_GENERATION`, which receives the chosen
unsigned 32-bit token on success. `SAVE_CANCEL` is copied into the reader request
before each inspection and checked between steps.

`SAVE_PREFLIGHT_RESULT` is a separate 32-byte record, cleared on entry:

| Offset | Field | Meaning |
|---|---|---|
| 0 | `SAVE_FREE_RECORDS` | Free directory records, word |
| 2 | `SAVE_FREE_SECTORS` | Remaining quota in 510-byte units, word |
| 4 | `SAVE_LIVE_RECORDS` | Directory records, word |
| 6 | `SAVE_PREFLIGHT_STATUS` | Returned status, word |
| 8 | `SAVE_DIRECTORY_CRC` | Directory fingerprint |
| 12 | `SAVE_PREFLIGHT_READY` | Longword 1 only after successful publication |
| 16..31 | Reserved | Zero |

On failure the capacity, fingerprint and READY stay zero and the generation is
unchanged. Always test D0 before consuming results.

## Procedure

1. Check the SVR1 header (magic, ABI 1, 128 bytes), stopped gameplay, interrupt
   priority and a nonzero disk ID (status 10).
2. Inspect the directory; the `CFEDITOR` ID must equal `SAVE_DISK_ID` (status 11).
   Record the fingerprint, record count, remaining quota units and all 64 marker
   bytes.
3. Read the normalized catalog with `storage_read_track` and require its CRC-32
   to equal the fingerprint (status 11). Keep it as the qualified catalog.
4. Choose the generation token.
5. Read the catalog again and require byte equality with the qualified copy.
   Inspect again and require the same fingerprint, disk ID and marker bytes
   (status 11).
6. Check cancellation (status 14), then publish the result and the generation.

See [READ.md](READ.md) for the listing rules, the marker format, the
fingerprint and the quota.

## Generation Token

Starting at `SAVE_GENERATION`, the token is formatted as eight lowercase
hexadecimal digits. If the case-folded first eight characters of any directory
record equal it, the token is incremented and the scan restarts. This skips
every existing prefix, including incomplete generations and noncanonical
suffixes. Unsigned wraparound is allowed. At most 150 records can exclude 150
candidates, so at most 151 attempts are needed. A token names files; it is not a
mission ID.

## Memory

| READBACK offset | Bytes | Owner |
|---:|---:|---|
| 0 | 6,144 | Qualified catalog (`CF_PREFLIGHT_DIRECTORY`) |
| 6,144 | 6,144 | Fresh catalog for comparison |
| 12,616 | 88 | Fingerprint, marker copy, count, generation, token and quota |

The service uses WORK 0..863. The CFMD candidate, the authored MAP, the resident
SPT/CFMD, undo and the manifest slice are preserved. `EDITOR_IO_BASE + 64..143`
is the private inspector request; the SVR1 request and the preflight result do
not overlap it.

On success `CF_PREFLIGHT_DIRECTORY` still holds the qualified catalog. The
record count is the longword at offset 24 and the 32-byte records begin at
offset 32. A caller may then copy up to 150 records to READBACK
10,240..15,039 before reusing the start of READBACK for manifest reads.

A successful preflight is not a reservation. The Save transaction runs the
preflight again before writing and every file operation requalifies the
directory itself.
