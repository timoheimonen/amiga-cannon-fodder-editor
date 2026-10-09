<!--
Cannon Fodder In-Game Level Editor V1.1
Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
Licensed under the MIT License. See the LICENSE file for details.
-->

# Object palette

`cf_opal.mod` displays the 70 supported object roots in five categories: Player, Enemies, Buildings, Vehicles, and Items/terrain. It uses original static sprite parts from the current terrain. Spawn hole `$18` uses a visible H marker. Labels include the hexadecimal type ID; a question mark marks an uncertain descriptive name. Internal effects are omitted, and multi-part objects appear as one catalog item.

The page keeps the terrain palette for the preview's original sprites. The Slave's text service draws the category tabs and thirteen rows in colours chosen from that palette: colour 0 behind, the most contrasting colour as ink, and darker colours for the selected row and the hovered tab. The 48-line bar has Up, Down, the visible rows, Choose and Cancel in the UI palette, and the highlighted type in the terrain band.

Press O from a scrolling editor tool to open the palette. Click a tab or use Left/Right. Up/Down, the bar's Up and Down buttons, and the pointer at the bottom of its range (below the bar's buttons) scroll within the category. Moving the pointer over a row highlights and previews it. Clicking the row, Choose or Return selects its type and enters Object mode with no existing object selected. Escape, Cancel or the right button preserves the previous tool, type, object index, and camera.

The overlay fits the existing 16 KiB module slot. It checks the current authoring request and inspects the `Custom` directory before acquiring the display, validates text and preview bounds, and restores the saved graphics owner before publishing a by-value result. It does not edit the map, object records, metadata, or Undo history. The caller consumes the result once and restores the appropriate scrolling view.

Catalog data and source contain no original game graphics. Fonts, palettes, and sprite pixels are read from the user's loaded game assets.
