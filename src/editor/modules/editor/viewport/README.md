<!-- Cannon Fodder In-Game Level Editor V1.0
Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
Licensed under the MIT License. See the LICENSE file for details. -->

# Reversible Sprite Preview

`preview.s` draws a logical item containing up to eight sprite parts without
running object behavior. It saves every part's background before drawing any
part, so overlapping parts can be removed without leaving marks.

## Calling Contract

Include `fodders.i` before `preview.s`. Set A4 to an even-aligned, zero-initialized
`PV_STATE_SIZE` allocation. The current state size is 3,216 bytes, including the
3,072-byte background save area. Keep this state and all referenced sprite
descriptors alive until `preview_restore` has returned.

| Routine | Inputs | Result |
|---|---|---|
| `preview_set_item` | A0: part records; D0.w: count | D0.l: 0 accepted, -1 rejected |
| `preview_update` | D0.w/D1.w: world anchor X/Y | Draws when the anchor or camera changes |
| `preview_restore` | A4: state | Restores the saved pixels; safe when nothing is drawn |

The routines preserve registers except documented results. Condition codes are
not preserved. Each eight-byte part is a long descriptor pointer followed by
signed word X/Y offsets. Descriptors use the native 16-byte layout: source and
mask pointers, width in words including the guard word, row count, source plane
stride, and signed byte anchor offsets.

`preview_set_item` removes the old item before validating its replacement.
Zero parts, more than eight parts, empty frames, or an excessive save budget
leave no active preview. The required worst-case save bytes are:

```text
sum(part_rows * (4 + 4 * (part_source_bytes_per_row + 1)))
```

The caller must validate the offered catalog against this budget. A rejected
item must not silently disappear from the catalog.

## Buffers And Masks

The destination is one native four-plane display buffer: 256 rows of 40 bytes
per plane, plus a 40-byte guard row, giving a `$2828` plane stride. The logical
viewport is 304 by 192 pixels. Camera and ring coordinates use the integer words
of the native 16.16 globals. The ring is linear; crossing its right edge advances
to the next row, and crossing its end wraps to byte zero.

Set `pv_mask_row` to at least 1,536 even-aligned bytes of caller-owned Chip RAM
for the generated masks. Source graphics, installed masks and the destination
must also be in Chip RAM. Select native four-plane mode (`native_fifth_plane`
zero). The routine waits for its blits and preserves the ring guard rows. It is
not reentrant; no interrupt routine may concurrently use its state or blitter.

Set `pv_native_masks` nonzero only while the matching gameplay mask table remains
installed. Fully visible columns then reuse those masks. Clipped columns build
their own packed masks in the caller's scratch. Installing a font table replaces
the shared mask bank: remove the preview first, draw the text, reinstall the
gameplay table, and then redraw the preview.

A nonzero `pv_pad` stamps the parts permanently: nothing is saved, and the
parts are clipped to the rectangle in `pv_clip_left`..`pv_clip_bottom` instead
of the whole viewport. The map view uses it to draw placed objects.

## Frame Order

1. Call `preview_restore` before changing any covered background pixels.
2. Repaint changed tiles, scroll edges or placed objects.
3. Call `preview_update` with the new world anchor.

Call `preview_restore` on cancellation, before committing a placement, when the
pointer enters the toolbar, and before releasing the display or module state.
An unchanged anchor and camera produce no display writes. The caller owns static
terrain rendering, copper publication, fixed UI pixels and native resource
restoration. A double-buffered caller needs a separate preview state per buffer.

Clipping may touch hidden pixels immediately outside the visible byte columns;
those pixels are saved and restored as well. Do not place unrelated content in
the ring's hidden right margin. Use a separate fixed bitmap for a toolbar.
