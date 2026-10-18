# Editable artwork

`icons/` contains the approved SVG masters, provenance and rendered-mask records. `branding/aerodeck-v2/` contains the approved AD monogram and its source/export information. Installable bitmaps live under `sdcard/SCRIPTS/TOOLS/AERODECK/icons/`.

To produce the native800×480 icon masks from the existing masters, use `python3 tools/export_display_icons.py` from the repository root. This optional artwork task requires `rsvg-convert` and Pillow; it is separate from the portable Lua checks and packaging.

Some retained provenance records name their original pre-cleanup `development/` paths. The files moved without changing those historical records. Use the current asset folders above for editing; `archive/index.json` maps archived experiments and prior branding.

The README header embeds the approved120×120 PNG without changing its pixels. It is documentation artwork and is not installed on the radio.
