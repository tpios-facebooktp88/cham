# Cham AutoClicker

A lightweight iOS POINT auto-clicker tweak for TrollStore + TrollFools.

## Project checkpoint
- Current implementation, device-tested milestones, and remaining work: [CHECKPOINT.md](CHECKPOINT.md).
- Static reverse-engineering baseline and evidence boundaries: [docs/REA-RESEARCH-BASELINE-2026-11-13.md](docs/REA-RESEARCH-BASELINE-2026-11-13.md).

## Scope
- POINT tapping with one or more saved coordinates.
- Adjustable repeat interval and press duration.
- Draggable floating handle and compact control panel.
- Automatic persistence of coordinates, point markers, interval, press duration, panel position/scale, and handle position across panel close/reopen and app relaunch.
- Safe DOWN/UP lifecycle handling; a new DOWN is blocked while a previous release remains unconfirmed.

## Current status
- [x] POINT touch path confirmed by the user on a device (2026-11-13).
- [x] IOKit digitizer constructor ABI corrected.
- [x] UIKit `UIApplication sendEvent:` path included in the confirmed working build.
- [x] POINT-only scheduler and simplified overlay source.
- [x] Persistent settings via `NSUserDefaults`.
- [x] Compact dark UI refresh.
- [ ] User build and device validation of the cleanup/UI/persistence changes.

## Build
GitHub Actions is manual-only. Do not start a workflow or build unless the user explicitly authorizes it. The user normally runs the build and device test.

## Compatibility and safety
The original `Cham.dylib` is preserved and is not modified, linked, or required. The known-good touch backend is intentionally kept separate from UI and scheduler cleanup. A successful local dispatch call is not treated as proof of delivery; device confirmation is the acceptance test.
