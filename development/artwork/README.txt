AERODECK flat attitude surround — original code-native artwork

attitude-cover.svg is the152x152 corner-mask master. Export152px then flatten RGB: black corners draw, white aperture becomes transparent through Bitmap.toMask. Cache the conversion once. Draw with native p.black so EdgeTX RGB565 colors match the surrounding surface exactly.

attitude-flat.svg is the152x152 transparent RGBA rim/ticks/index master. Its corners and circular center have alpha0. Export at native152px using rsvg-convert; do not flatten or add a background. Draw after the tinted corner mask.

The split avoids native EdgeTX ARGB4444 quantization changing #050c13 into a visible square. The global palette remains unchanged. Geometry: center76,76; aperture r68; inner border r68.5; outer rim r74. Border#395464, ticks#8ca4b3, top index#a4e37d. Both assets place at164,64 for global center240,140 at100% native scale. Existing HUD, moving marker and aircraft overlay remain unchanged. No texture, metallic gradient or screw decorations.

See attitude-flat.json for exact roles, geometry and hashes.
