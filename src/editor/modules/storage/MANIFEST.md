<!-- Cannon Fodder In-Game Level Editor V1.1
Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
Licensed under the MIT License. See the LICENSE file for details. -->

# CFMI Manifest Parser

`manifest.s` exports the position-independent 68000 subroutine `cfmi_parse`.
It validates a complete CFMI version-1 envelope and its schema, then produces
one owned, pointer-free selected-phase record. It performs no disk I/O, payload
validation, campaign mutation, module loading or user-interface work.

## Calling Convention

| Register | Input |
|---|---|
| A0 | Even address of the complete CFMI file |
| D0.l | Exact file length, 17 through 4,096 bytes |
| A1 | Basename: eight lowercase hexadecimal digits, `.cmi`, then NUL; 13 bytes |
| D1.w | Selected zero-based phase index, 0 through 5 |
| A2 | Even address of a writable 512-byte output span |
| A3 | Even address of a writable 512-byte parser-scratch span |

The four spans must be addressable and mutually disjoint. The routine checks
alignment, length, index, address wrap and span overlap before clearing scratch.
The caller must additionally keep the writable spans outside the executing code,
active stack and other live owners. On a 68000, byte reads still use aligned bus
words; allocate ordinary word-padded buffers, including a 16-byte basename slot.
An odd basename address is supported when its surrounding bus words are valid.

D0.w returns zero on success or a negative status below. D1.l returns the parser
cursor's byte offset from A0 on a format error; it is `$FFFFFFFF` on success or
an argument error. The cursor can point just after a consumed invalid token or
at end-of-file; it is not necessarily the token's first byte. D2-D7 and A0-A6
are preserved, and A7 is balanced. CCR is unspecified.

| Status | Meaning |
|---|---|
| -1 | Invalid pointer-span, alignment, file-length or phase-index argument |
| -2 | Invalid CFMI magic, version, header size or exact body length |
| -3 | Body CRC-32 mismatch |
| -4 | Invalid JSON spelling, delimiter, escape or character |
| -5 | Unknown, missing or duplicate key; invalid schema value |
| -6 | Scalar, string, array or policy range violation |
| -7 | Invalid manifest basename or generation-relative payload filename |
| -8 | Selected phase does not exist in an otherwise parsed phase array |

Error classes are diagnostic categories, not a promise about which violation
wins when an input contains several errors. Every error leaves all 512 output
bytes unchanged. Scratch may change after argument validation. Its temporary
input, output and stack pointers are cleared before return.

## Record Layout

`metadata.i` defines all offsets. Words and longwords are big-endian. The first
256 bytes form the `CFMD` record; the remaining 256 output bytes are zeroed on
success. Reserved bytes inside the record are also zero.

| Offset | Bytes | Contents |
|---|---:|---|
| `$00` | 4 | Magic `CFMD` |
| `$04` | 2 | Record ABI, 1 |
| `$06` | 2 | Record size, 256 |
| `$08` | 4 | Mission ID decoded from eight uppercase hexadecimal digits |
| `$0C` | 4 | Generation decoded from the manifest basename |
| `$10` | 2 | Revision, 0 through 65,535 |
| `$12` | 2 | Initial recruits, 1 through 32,767 |
| `$14` | 1 | Total phase count, 1 through 6 |
| `$15` | 1 | Selected phase index |
| `$16` | 1 | Objective count, 1 through 8 |
| `$17` | 1 | Objective presence mask; bit 0 represents ID 1 |
| `$18` | 1 | Minimum aggression |
| `$19` | 1 | Maximum aggression |
| `$1A` | 1 | New-recruit rank, 0 through 7 |
| `$1B` | 1 | Grenades per troop, 0 or 2 |
| `$1C` | 1 | Rockets per troop, 0 or 1 |
| `$1D` | 1 | Policy flags: bit 0 enemy grenades, bit 1 overview, bit 2 original-final-map countdown |
| `$1E` | 2 | Complete manifest file length |
| `$20` | 4 | Manifest body CRC-32 |
| `$24` | 2 | Referenced MAP length, 1 through 15,096 |
| `$26` | 2 | Referenced SPT length, 1 through 430 |
| `$28` | 4 | Referenced MAP CRC-32 |
| `$2C` | 4 | Referenced SPT CRC-32 |
| `$30` | 8 | Objective IDs in authored order, unused bytes zero |
| `$38` | 16 | Manifest basename, NUL-terminated and zero-padded |
| `$48` | 16 | Selected MAP basename, NUL-terminated and zero-padded |
| `$58` | 16 | Selected SPT basename, NUL-terminated and zero-padded |
| `$68` | 64 | Mission title, native `$FF` terminator followed by zero padding |
| `$A8` | 64 | Selected phase title, same representation |
| `$E8` | 24 | Reserved, zero |
| `$100` | 256 | Output expansion reserve, zero |

There are no pointer fields. Titles contain 1 through 63 printable ASCII
characters before their native terminator. Filename slots include their NUL
terminator. The objective mask does not replace authored objective ordering.
No policy is inherited from existing campaign memory.

## Parsing And Storage

The parser verifies the 16-byte CFMI header and CRC-32/ISO-HDLC of exactly the
declared body. It accepts object keys in any order and normal JSON string
escapes when their decoded characters satisfy the schema. Escaped known keys
are recognized, and duplicate keys are rejected after decoding. Only JSON's
space, tab, carriage-return and line-feed bytes are insignificant whitespace.

Every phase is validated, including phases other than the selected one. Root,
phase, file-reference and aggression objects require exactly their known keys.
The parser rejects unknown/missing keys, duplicate objectives, invalid containers,
trailing data, non-ASCII values, negative numbers including `-0`, fractions,
exponents, numeric constants and booleans in integer fields. Decimal overflow is
checked before multiplication. Generation, zero-based phase index and lowercase
extension must match each payload reference exactly.

The implementation uses schema-fixed subroutine calls rather than an input-driven
recursive JSON tree. Only root, phase-array, phase-object and its bounded nested
reference/aggression/objective containers are accepted. It allocates no heap and
stores no catalog or array of phase records.

| Scratch offset | Bytes | Use |
|---|---:|---|
| `$000..$0FF` | 256 | Selected-record candidate |
| `$100..$13F` | 64 | Decoded token and terminator |
| `$140..$17F` | 64 | Scanner pointers, sizes, masks, phase counters and temporary scalar state |
| `$180..$1FF` | 128 | Reserved, zero |

All 512 scratch bytes are cleared after argument validation. Decoded-token size,
not JSON spelling length, is bounded: a 63-character title written entirely with
six-byte Unicode escapes is accepted. Unselected phases reuse scalar masks and
counters; only the selected phase's data enters the candidate. Root data and
selected-phase data occupy separate fields, so arbitrary root key order works.

The deepest stack write is 88 bytes below the caller's SP, including its `JSR`
return address, register saves and parser calls. Reserve at least 128 bytes in
addition to the caller's own needs. A packaged module must count its header,
wrapper, other routines and read-only tables against its code-capacity limit.

## Ownership And Publication

Success means **schema valid**, not playable or payload verified. The output
lengths and CRCs are declarations until the corresponding raw files have been
read and checked. A successful parse does not establish MAP/SPT structure,
resource compatibility, objective feasibility or available troops.

Use a staging output while validation is incomplete. Only after every referenced
phase payload has passed validation and the directory identity is unchanged
should a controller copy the selected record into permanent metadata storage.
A controller can reparse the bounded manifest for each selected phase instead of
retaining module-owned offsets or pointers. The successful output copy is not an atomic
interrupt-visible publication; consumers must remain disabled until the caller
finishes installation and publishes its own ready state.

The caller may overwrite or evict the input, scratch and parser after copying the
record into an independently owned span. Native title/filename consumers must
derive addresses from that owned span, never from the original JSON or module.
The parser does not implement the controller, its identity check, or its
campaign restoration protocol.
