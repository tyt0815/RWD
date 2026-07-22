# Task 3 Report: Core TempoMap

## Status

Completed. Added the public `Core.TempoMap` boundary for single-BPM beat/seconds conversion without changing stage storage or editor UI.

## RED

Command:

```powershell
& 'C:\Program Files\LOVE\lovec.exe' . --test
```

Result: exit code 1. All four new `TempoMap` tests failed as expected because `require("core").TempoMap` was nil.

## GREEN

Command:

```powershell
& 'C:\Program Files\LOVE\lovec.exe' . --test
```

Result: exit code 0, `PASS: 108 tests`.

## Implementation

- Added `TempoMap.new(bpm)` with positive finite BPM validation.
- Added exact single-BPM conversions for non-negative finite beat and seconds values.
- Added `getBpm()` and exported the module only from `core/init.lua`.
- Added tests for exact and fractional conversion, invalid BPM, and invalid positions.

## Changed Files

- `core/TempoMap.lua`
- `core/init.lua`
- `tests/TempoMapTest.lua`
- `tests/TestRunner.lua`

## Self-Review

- `git diff --check` produced no output.
- Verified no stage schema, editor UI, or storage files changed.
- API is limited to the requested single-BPM boundary; no BPM-change event behavior was added.

## Concerns

None. PowerShell emitted an unrelated oh-my-posh profile cache permission warning before test execution; LÖVE test results were unaffected.
