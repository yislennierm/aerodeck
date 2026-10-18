OLC navigation test fixtures

encoding.csv is the official Google Open Location Code test dataset.
encoding-float32.csv contains those coordinates rounded to binary32; expected
codes were independently produced by the official Python encoder. This checks
the actual numbers available on EdgeTX rather than demanding double-precision
coordinates from a float32 interpreter. Both contain 302 cases.

LICENSE applies to the upstream fixtures. See provenance.json for exact hashes
and primary-source URLs. No fixture or reference Python source ships to the SD.

Actual EdgeTX VM regression

native-check.lua is a development-only tool containing the 302 float32 fixture
cases plus eight boundary/known-position/navigation cases. It loads the real
navigation-utils.lua and runs eight cases per callback to bound native CPU use.
Copy it to an isolated simulator Tools path for verification; never include it
in the runtime SD archive. native-verification.json records a 310/310 PASS in
actual EdgeTX 3.0.0 TX16S WASM. This is separate from target 2.12.4 radio testing.

The native probe found that mixed float/integer equality truncates fractions:
0.5 == 0 evaluates true, while 0.5 == 0.0 evaluates false. Comparing a fractional
remainder against integer zero incorrectly reduced coordinates to whole degrees.
The utility therefore compares these fractional zero cases with 0.0. Stock
Lua 5.3 configured int4/float4 did not reproduce this VM behavior; its passing
numeric tests alone were insufficient. The corrected native tool retains
76Q4XRXV+33C for the original position and 76Q4XRXV+75G for the nearby current one.
