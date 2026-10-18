# Version policy

`VERSION.json` is authoritative. AERODECK uses **YYYY.M.PATCH**, following [Betaflight’s calendar versioning model](https://betaflight.com/blog/2025/09/01/Calendar%20Versioning%20Change).

The year and unpadded month identify the product release series. The patch starts at zero and increases for maintenance releases. Development builds use `-alpha`, feature-freeze builds may use `-beta`, and candidates use `-rc1`, `-rc2`, and so on. A validated final release drops the suffix. AERODECK release dates and numbers are independent of the connected Betaflight firmware.

After changing the version:

```sh
python3 tools/set_version.py
python3 tools/set_version.py --check
```

The Tool and widget receive the same literal at development time; the radio does not read a version file or load an extra module at runtime.

Keep the README independent of individual versions. Releases list available builds and their status. Update operating instructions when behaviour changes. A Git tag preserves the matching source and manual. Keep old reports, packages and release tags unchanged; create a new candidate or patch rather than relabel a published build.

Hardware deployment authority belongs to the equipment records. Publishing a version does not install or validate a radio.
