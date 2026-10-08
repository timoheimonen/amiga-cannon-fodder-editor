<!-- Cannon Fodder In-Game Level Editor V1.0
Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
Licensed under the MIT License. See the LICENSE file for details. -->

# Dialogs

Shared sources for modules that show dialogs through the WHDLoad Slave's dialog
service (backend operation 7, constants in `include/dialog.i`). They are
included by a module, not built on their own.

A dialog is a full-width panel band with a title strip, text and bevelled
buttons in the small font and the fixed UI palette. Above and below the band
the authoring map stays visible with a darkened palette while the canvas still
holds the ring the view last published; otherwise those rows are black. The
service saves the native copper list and the chip memory it borrows from the
second display buffer, and restores both on close.

## Routines

| File | Routine | Contract |
|---|---|---|
| `dialog.s` | `dialog_open` | A0: descriptor, D2.l: mask of disabled buttons. D0.l: 0 open, 10 refused |
| | `dialog_poll` | One frame of input. D0.l: -1 nothing chosen, otherwise the chosen code |
| | `dialog_close` | Restores the display exactly as `dialog_open` found it |
| | `dialog_draw` | A0: UI command list drawn into the open panel |
| | `dialog_set` | D2.w: button index, D3.w: state, A0: new label or 0; redraws the button |
| | `dialog_release` | Waits until both mouse buttons are up and drops pending input |
| `standard.s` | `dialog_standard_open` | D7.w: dialog kind, D6.w: signed status; opens the matching standard dialog |
| | `dialog_copy` | A1: source, A0: destination; copies at most 63 characters and leaves A0 on the NUL |
| | `dialog_number` | D0.w: unsigned value written in decimal at A0, which ends on the NUL |
| | `dialog_field` | A1: string, D1/D2: X/Y, D3: width, D4: colour role, D5: alignment; clears the field's eight rows and redraws it |

All routines preserve every register except D0 (`dialog_copy` also moves A0).
A caller polls once per frame after `wait_frame`, closes the dialog, then
calls `dialog_release`. A dialog that takes typed text reads `native_last_key`
before polling and clears the keys it consumes; Return and Esc are left to the
service. The service's `DIALOG_SET` function changes one button's state or
label while the dialog is open (selected terrain, steppers at their limits).

## Descriptor

A descriptor is word aligned; its addresses are absolute because modules link
at a fixed base. Layout offsets are in `include/dialog.i`:

| Field | Meaning |
|---|---|
| Top, height | Screen rows of the band, top 8 or more, ending at row 224 or above |
| Title role, title | Colour role of the title strip and the title string |
| Body | UI command list drawn below the title, or zero |
| Default | Button index chosen by Return, or -1 |
| Cancel | Code returned by Esc and the right button, or -1 |
| Buttons | Up to 32 entries: X, Y, width, height, code, state, label |

Buttons are hit-tested with the rectangles they are drawn with. A left press
chooses a button; the button under the pointer is highlighted and the default
button is framed. `DIALOG_REPEAT` in a button's state word makes it repeat its
code while held, after 12 frames and then every 4. `DIALOG_ROW` draws the
button as a flat list row with a left-aligned label; the selected row has
state `UI_ACTIVE`.

## Standard Dialogs

`standard.s` holds the editor menu, Unsaved changes (with and without Don't
save), Large change, Terrain graphics missing and the messages for marker,
object and Save refusals, with a generic Editor error that shows the status.
The including module defines `EXIT_TEXT` (64 bytes), `EXIT_NUMBER` (32 bytes)
and `EXIT_LIST` (32 bytes) in its scratch for the menu's status text, numbers
and redrawn fields. With `DIALOG_LARGE_ONLY` set only the Large change
confirmation is assembled.

## Shared Dialogs

| File | Dialog |
|---|---|
| `new_mission.s` | New mission: six terrain buttons, width and height steppers, Create and Cancel (with `NEW_DIALOG_WITH_TEMPLATE` also Template...); with `NEW_DIALOG_PHASE` titled for a blank phase. The includer defines the words `NEW_DIALOG_FAMILY`, `_WIDTH` and `_HEIGHT` |
| `template_list.s` | The original missions and their phases, eight at a time, and the game-disk prompt |
| `page.s` | The `edtr_modal` of a page overlay whose modal is one dialog; the includer provides `open_owner`, `page_open` and `page_step` |
