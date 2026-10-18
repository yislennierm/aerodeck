ARM-TOOLBAR-20261018 icon addition
ARM INFO uses gpp_bad.png: native 30x30 RGB on 480x272 and native 50x50 RGB
on 800x480. Both are direct rsvg-convert exports of the existing approved
masters/gpp_bad.svg, flattened on white without raster resizing. Black/grey
coverage is tinted by the existing Bitmap.toMask renderer. Apache-2.0 notices,
originals, and masters remain unchanged. Existing speed.png and speed-18.png
exports are retained; all prior PNG bytes are unchanged.
Native 30px SHA256: 798ff1c279b654aaac9ac96a064d5cc1804333b6064dd52c5cc7d1abbf4d7c39
Native 50px SHA256: 7c80859891103b54a8f1416df4ceb6524ac5ce083bca06557368b0aa32dbdb83

REPLACEMENT-RC1-20261017 display variants
TX16S 480x272 keeps the original native30px navigation and18px detail masks.
The800x480 subfolder contains native50px navigation and30px detail exports
from the same vector masters; the display adapter selects these paths directly.
No full-panel artwork is required. Prior export details and notices follow.

AERODECK Material Symbols Outlined icon masks
Current local FLIGHT-FLAT-20261016 adds home-18.png for local-home distance; existing masks, including home.png, retain their hashes.
Google Material Symbols Outlined; Apache-2.0. Full license: LICENSE.txt.

Navigation uses native30x30RGB PNGs; context tabs and footer use native18x18RGB PNGs.
Black draws, white becomes transparent through Bitmap.toMask; grey supplies edge coverage.
Approved navigation30px masks are copied byte-for-byte from the proposal.
Context18px masks are exported directly using rsvg-convert -w18 -h18 from the30px masters, then flattened RGB on white. No on-radio scaling is required.

Modification notice: Original Google path geometry is retained. Edited masters use a30x30canvas with a centered viewBox fitted to26px maximum ink extent, plus an opaque white background.18px variants are derived raster exports of these edited masters. Modified for AERODECK,2026-10-16.

Existing home.png remains unchanged (30x30RGB); its original/modification notice and source are retained below.
Source: https://github.com/google/material-design-icons/blob/master/symbols/web/home/materialsymbolsoutlined/home_24px.svg
Modified:30x30canvas; viewBox fitted to26px ink height; opaque white background.
Editable home master: assets/icons/home-outlined-30.svg.

New runtime files:
speed.png: 30x30RGB; SHA256 dde260c9abcbb85db55a13ba28d87fa678d8d4a6d6779b866a9029f28d16ad39
table_chart.png: 30x30RGB; SHA256 cb156605dabf0196f54490fdc9e47f69afcc815339d9e5562243b59058891d6a
my_location.png: 30x30RGB; SHA256 8efe6881630adefaa140e1eb82e5b57d5550b2f2ce7208a085373d8a0927d509
head_mounted_device.png: 30x30RGB; SHA256 e2547a125a635ff6a0b348f7cf6c9896a87643c44c19cd1f43f0fb9a5ce52c52
tune.png: 30x30RGB; SHA256 b308525580147d5818270bb343f0797a8604775ebf80e74471fa53eb4d2a856a
build.png: 30x30RGB; SHA256 fef1db514c1916d6f291d331acb2906120f15cf4625b47b315cc670937ffb418
speed-18.png: 18x18RGB; SHA256 2d9204e15b8a4cf7a2acd7eee0f596f62f8c702031126b6e1b4208e4a7a27934
route-18.png: 18x18RGB; SHA256 ac863cf7053acc6ae3222844a19dfae62c5a2b34010a0a472b277c9fbd5e1f4a
battery_full-18.png: 18x18RGB; SHA256 45eb2683003373196581e4f5546d3e4e60aaf9ebcde6c1095ccb986f503f4cac
sensors-18.png: 18x18RGB; SHA256 50f49afa97efcdb61f86d80ca3da4bf4139e33af0a8c1f16272042ff9ef9224c
table_chart-18.png: 18x18RGB; SHA256 1b2e723554e138d74ef10f9f552e92056401063cba52f8a5f53e964936c27eb4
sports_esports-18.png: 18x18RGB; SHA256 27c24e1897c478a4887ef19a30cf77d0cf5bf83d21dfe907e85374236fda7f71
my_location-18.png: 18x18RGB; SHA256 1471edbf48d82a38110b8385fb965e31d74970418b9bf8b0ac71760a8d0b1428
cell_tower-18.png: 18x18RGB; SHA256 218d4ffac7721968ae2606ce114ea245c6c9fd7f02d899dba9de4ea69b6f969c
gpp_bad-18.png: 18x18RGB; SHA256 720cb481e696303e236000cde8720ca8145b755215ee1134c7cf714b81a14c16
head_mounted_device-18.png: 18x18RGB; SHA256 0203282602b0c7dabb4f18bbff36e185b7a9e2bb36dc9fc26f4b628e5e6b8161
bug_report-18.png: 18x18RGB; SHA256 13f83f4bfdccca792eddf2c5bb64c215cf8c2305cbda3fbb92107c5bc4c04c0d

satellite_alt-18.png: 18x18RGB; SHA256 16241dea34276792cf3445539f4cb27530a10bb5ee935742162853643a2727ed
Footer mapping: satellite_alt-18.png (icon ID14) + satellite count; existing battery_full-18.png + pack voltage.

Source URLs for the14 additional symbols:
battery_full: https://raw.githubusercontent.com/google/material-design-icons/master/symbols/web/battery_full/materialsymbolsoutlined/battery_full_24px.svg
bug_report: https://raw.githubusercontent.com/google/material-design-icons/master/symbols/web/bug_report/materialsymbolsoutlined/bug_report_24px.svg
build: https://raw.githubusercontent.com/google/material-design-icons/master/symbols/web/build/materialsymbolsoutlined/build_24px.svg
cell_tower: https://raw.githubusercontent.com/google/material-design-icons/master/symbols/web/cell_tower/materialsymbolsoutlined/cell_tower_24px.svg
gpp_bad: https://raw.githubusercontent.com/google/material-design-icons/master/symbols/web/gpp_bad/materialsymbolsoutlined/gpp_bad_24px.svg
head_mounted_device: https://raw.githubusercontent.com/google/material-design-icons/master/symbols/web/head_mounted_device/materialsymbolsoutlined/head_mounted_device_24px.svg
my_location: https://raw.githubusercontent.com/google/material-design-icons/master/symbols/web/my_location/materialsymbolsoutlined/my_location_24px.svg
route: https://raw.githubusercontent.com/google/material-design-icons/master/symbols/web/route/materialsymbolsoutlined/route_24px.svg
sensors: https://raw.githubusercontent.com/google/material-design-icons/master/symbols/web/sensors/materialsymbolsoutlined/sensors_24px.svg
speed: https://raw.githubusercontent.com/google/material-design-icons/master/symbols/web/speed/materialsymbolsoutlined/speed_24px.svg
sports_esports: https://raw.githubusercontent.com/google/material-design-icons/master/symbols/web/sports_esports/materialsymbolsoutlined/sports_esports_24px.svg
table_chart: https://raw.githubusercontent.com/google/material-design-icons/master/symbols/web/table_chart/materialsymbolsoutlined/table_chart_24px.svg
tune: https://raw.githubusercontent.com/google/material-design-icons/master/symbols/web/tune/materialsymbolsoutlined/tune_24px.svg

satellite_alt: https://raw.githubusercontent.com/google/material-design-icons/master/symbols/web/satellite_alt/materialsymbolsoutlined/satellite_alt_24px.svg

Editable originals and masters, per-file hashes, mapping and license:
assets/icons/material/{originals,masters,sources.json,mapping.json,assets.json,LICENSE.txt}
Originals are preserved unedited. All originals correspond to mapped runtime icons.
Replacing an icon requires its stated native dimensions and RGB format; exit/reopen AERODECK to reload caches.

home-18.png: 18x18RGB; SHA256 9ac516212f71704bb8a6b9364f976e1d3a14b0ef8a16492b23b8ebf50e8d9ac0
Flight local-home distance uses this native18px export from the existing licensed
Home master: assets/icons/home-outlined-30.svg. Its Google source/modification
notice remains above. Existing30px home.png is byte-identical. No runtime scaling.

GPS-SIMPLE-20261018: aircraft position is a native white dot with a dark halo.
The former neutral/directional quad PNGs are no longer shipped or loaded.
Editable original artwork remains under assets/icons for historical reference.
Home uses the existing Material home mask; no runtime aircraft bitmap is needed.

Startup branding:
branding/aerodeck-logo-120.png is the approved original AERODECK AD monogram,
generated with the built-in image tool and exported at120x120 RGBA. It is not
a Google Material icon or an alpha-mask asset. Source master and prompt are
in assets/branding/aerodeck-v2/. startup-screen.lua draws it as a native bitmap.
