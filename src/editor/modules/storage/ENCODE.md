<!-- Cannon Fodder In-Game Level Editor V1.1
Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
Licensed under the MIT License. See the LICENSE file for details. -->

# Canonical CFMI Encoding

`encode.s` provides three position-independent 68000 subroutines that encode a
CFMI version-1 manifest from one CFMD phase record at a time. Include it in the
caller's code section. It includes `metadata.i` only when its definitions are
not already present. It has no fixed load address, heap, disk I/O, callbacks,
engine calls, user interface, or mutable storage inside its code image.

The output uses compact JSON with sorted object keys and authored array order.
The 16-byte big-endian CFMI envelope contains version 1, header size 16, exact
JSON body length, and CRC-32/ISO-HDLC of that body. ID and checksum strings use
uppercase hexadecimal; generation-relative filenames use lowercase hexadecimal.

## Calling Convention

| Entry | Inputs |
|---|---|
| `cf_encode_begin` | A0=CFMD256 root record; A1=destination; D0.l=destination capacity 17..3584; A2=128-byte state |
| `cf_encode_phase` | A0=CFMD256 phase record; A2=the same state |
| `cf_encode_finish` | A2=the same state |

All entries return status in D0.w and preserve D1-D7/A0-A6 and SP. CCR is
unspecified; SR control bits are preserved. The routines neither disable nor
require disabled interrupts. Call begin once, append exactly the declared
number of phases in target index order, then call finish once.

| Status | Symbol | Meaning |
|---:|---|---|
| 0 | | Call succeeded |
| -1 | `CFE_ERROR_ARGUMENT` | Invalid begin capacity, alignment, address wrap or span overlap |
| -2 | `CFE_ERROR_CAPACITY` | Destination cannot hold the complete encoding |
| -3 | `CFE_ERROR_RECORD` | Invalid CFMD header, title, scalar, policy or objective data |
| -4 | `CFE_ERROR_SEQUENCE` | Invalid state, wrong phase index, incomplete phase sequence or call after finish |

Begin checks nonzero/even pointers, non-wrapping source256/destination-capacity/
state128 spans, and their mutual disjointness before modifying memory. The caller
must also provide addressable spans outside live code, stack and other owners.
Later phase calls require a readable, even, disjoint caller-owned 256-byte source;
they do not repeat arbitrary-pointer validation. A fixed staging candidate is
the intended binding. State is trusted private scratch and may not be modified
by other code between calls. None of these pointers comes from manifest data.

Use ordinary word-padded memory for byte fields on a 68000. Capacity can be odd;
the encoder writes only its declared bytes. The caller owns any adjacent bus
word byte lane and must not map it onto a device or invalid memory.

## Root and Phase Data

Begin checks the CFMD magic, ABI 1 and 256-byte record size. It retains root mission
ID, new generation, revision, initial recruits, total phase count and mission
title. Phase count must be 1..6; recruits 1..32767; title 1..63 printable ASCII
characters followed by `$FF`. Revision and both 32-bit identifiers use their
complete unsigned field ranges.

Each phase supplies its title, ordered objective IDs and matching presence mask,
aggression bounds, rank, grenade/rocket inventory, policy flags, and referenced
MAP/SPT lengths and CRCs. All schema ranges are checked before that phase starts
emission. Objective IDs must be distinct 1..8, and count 1..8. MAP length must be
1..15096 and SPT length1..430. Flags permit only enemy grenades, overview, and
the original-final-map countdown. This does not validate the referenced payloads.

The phase's total count must equal the root count; its index must be the next
target index, beginning with 0. Root fields in subsequent phase records are
ignored. Manifest/MAP/SPT filename slots and old manifest length/CRC fields are
also ignored: output reference names are always derived from the root's new
generation, target phase index and `.map`/`.spt` extension.

When a source phase is moved to a different target index, stage its projection
and replace its count/index in that private copy before append. Keep any source-
to-target mapping independently for subsequent payload copying. The encoder
never edits a source record or retains a source pointer.

Only quote and backslash are escaped in printable ASCII titles. Raw title bits
are preserved; no case conversion, font projection or display substitution is
performed. Objective order is preserved rather than reconstructed from its mask.

## State and Publication

`CFE_STATE_BYTES` is 128. State contains three transient output pointers, root
scalars, a copied 64-byte root title, counters and status. It holds no per-phase
array and no module/source pointer. Reserve it from begin through finish and
discard it before evicting the caller; it is not a persistent serialized record.
The caller can reparse a source manifest into one candidate between append calls.

After successful finish, these state fields are available:

| Offset | Symbol | Result |
|---:|---|---|
| 32 | `CFE_BYTES` | Exact complete CFMI file length, longword |
| 36 | `CFE_CRC` | JSON body CRC-32, longword |

Other state fields are private. The destination may be independently retained
after finish; it contains no native pointers. Encoding uses bounded call depth.
The deepest internal stack path is 80 bytes including the caller's JSR return
address. Budget interrupt handlers, the caller's frame and any surrounding
services separately; 80 is not a combined I/O/IRQ stack allowance.

Invalid begin arguments leave both existing output and state unchanged. Once
begin accepts its pointer spans, it clears state and destination magic. A later
failure is sticky and leaves the new transaction unpublished, though a bounded
partial body may remain. Begin again to restart. Finish rejects missing phases,
calculates the body CRC, writes the header, and writes CFMI magic last. A repeated
finish returns -4 without altering the previous successful result.

Always check status and the successful finish result, not just an old magic or
size. Publication is a memory-buffer convention, not an atomic interrupt-visible
write or filesystem commit. Keep consumers disabled until the caller publishes
its own ready state. No failure promises that the destination body is unchanged.

## Capacity

`CFE_MAX_BYTES` is 3584. Every canonical manifest admitted by the current schema
fits within 3146 bytes, including the envelope. The bound is attainable:

- Seven 63-character titles each take at most 128 JSON bytes including quotes.
  Quote and backslash are the only two-byte encodings among printable ASCII.
- Revision 65535, recruits 32767, MAP length 15096, SPT length 430 and aggression 20
  maximize their decimal widths. Other numeric fields use one digit.
- Eight objective IDs maximize each objective array. `false` is longer than
  `true`, and `"original-final-map"` is longer than `null`.
- Names, IDs, CRC strings, schema spelling and object keys have fixed widths.

The maximum root with an empty phase array is 251 bytes; each maximum phase is 479.
With six phases and five separators, the exact file bound is
`16 + 251 + 6*479 + 5 = 3146`. The remaining 438 destination bytes are unused.
This does not lower the parser's 4096-byte accepted-input limit: whitespace and
alternate escape spellings can make an equivalent input larger than canonical
output. A 4096-byte owner can therefore dedicate 3584 bytes to new output and keep
its last 512 bytes separately owned, without either owner overlapping.

Schema-valid encoding does not establish payload existence, CRC truth, payload
structure, gameplay validity, available quota, directory identity, readback
integrity or commit success. Those checks remain the transaction caller's work.
