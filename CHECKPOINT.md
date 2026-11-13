# Cham AutoClicker — Engineering Checkpoint

Updated: 2026-11-13
Repository: `tpios-facebooktp88/cham`
Active branch: `main` only

## Product intent

A small POINT-only iOS auto-clicker tweak. The user wants the simplest useful tool: a floating handle, a compact control panel, saved screen points, adjustable tap timing, and reliable touch release. Do not reintroduce alternate tap modes, OCR, recording, or speculative features.

## User-confirmed behavior and status

- User reports the latest build after fixing the scheduler compile error succeeded.
- User reports the floating tool opens and saved settings persist.
- User previously confirmed that POINT touch delivery generated a real click on-device.
- The user observed a thin purple horizontal bar at the top of the panel; removed in commit `1c38ee2239fd021b4e68981cb53d289b6edad75a`.
- The user requested precise numeric entry for press duration because slider-only adjustment was too coarse. A numeric millisecond field was added beside/below the slider in the same commit.
- The latest UI/documentation edits have not yet been rebuilt or visually verified on-device.

## UI and control design

- Floating **CHAM** handle: draggable, opens/closes the panel, position persisted.
- Panel: dark compact surface, draggable by its title, scalable with − / +, closable with ×. No separate purple top accent bar.
- X/Y fields: window-local point coordinates.
- POINT markers: numbered, draggable; multiple points execute in configured order and repeat.
- ADD POINT: saves the current X/Y as a point.
- CLEAR: removes all points.
- DELAY BETWEEN TAPS (SEC): pause after UP before the next DOWN. Example: 0.5 means half a second.
- PRESS DURATION (MS): DOWN-to-UP hold duration. Slider plus editable numeric field; 0.1–1000.0 ms, 0.1 ms display/input precision.
- START: starts the point loop; if no point exists, adds the current X/Y automatically.
- STOP: stops scheduling and attempts UP if a touch is still active.
- Status line reports ready/running/stopped/error states.

### Timing model

For each point:
1. Send DOWN.
2. Wait `pressDuration` milliseconds.
3. Send UP.
4. Wait `interval` seconds.
5. Advance to the next point (wrap to first point).

Example: 60 ms press duration + 0.5 s interval gives approximately 0.56 s from one DOWN to the next, excluding OS/dispatch overhead. Interval is a post-release delay; it is not the press duration.

## Persistence

NSUserDefaults key: `com.cham.autoclicker.settings.v1`.

Persisted:
- Current X/Y and ordered POINT list.
- Interval and press duration.
- Floating handle position.
- Panel position and scale.

Settings are saved during edits and layout changes and restored when the overlay is recreated. Keep the settings schema backward-compatible unless there is a clear reason to migrate it.

## Source architecture

- `Cham/Entry.xm`: Logos tweak constructor; creates the singleton overlay on the main queue after a short startup delay.
- `Cham/CHMOverlay.h/.m`: floating handle, panel, numeric fields/slider, point markers, persistence, and app-inactive stop behavior.
- `Cham/CHMTapScheduler.h/.m`: sequential POINT scheduler using dispatch-source timers.
- `Cham/CHMTouchBackend.h/.m`: HID/UIKit touch event generation and active-touch context.
- `Makefile`: Theos build target, architectures, source list, and linked frameworks.
- `.github/workflows/build.yml`: manual-only GitHub Actions build; uploads a versioned dylib artifact.
- `README.md`: user-facing design, controls, timing model, architecture, build instructions, and validation notes.

## Verified touch backend — preserve

- Known-good backend file: `Cham/CHMTouchBackend.m`.
- Blob SHA: `51fd6a2ad99d57a1f896b8c4c32dad0666a9fd29`.
- Original uploaded `Cham.dylib` remains untouched and is not a build input.
- Preserve the IOKit digitizer function-pointer ABI, event metadata, UIKit `sendEvent:` path, same-window/view DOWN→UP pairing, and failure blocking.
- Never claim success when the backend cannot confirm dispatch.
- Do not modify this backend without concrete device evidence and explicit need.

## Recent relevant commits

- `11a42068fdb2a08070ffffacfed260e44c986173`: fix NSValue CGPoint read in scheduler using `getValue:`.
- `633a5161f51af632807c3e08b5dd803d344d39a7`: record compile fix and validation state.
- `1c38ee2239fd021b4e68981cb53d289b6edad75a`: remove purple top accent; clarify interval label; add numeric press-duration entry.
- `8ee595e3bf52f221f5b4d25661b832e772bd1577`: explicitly import math declarations for slider rounding.
- `ab76e29f726f8a2ab11c09a1c9c59ee9af993d76`: expand README with controls, timing, architecture, build, and project rules.

## REA research cleanup

The completed REA workflow, runner script, and research report were removed from the repository. Existing uploaded Actions artifacts were intentionally retained at the user's request. Do not recreate or rerun the REA workflow unless the user asks.

## Validation discipline

- The compile error from Actions run `43418856210` was `NSValue *` missing `CGPointValue` at `CHMTapScheduler.m:105`; fixed with `getValue:`.
- User subsequently confirmed that the build succeeded.
- The current panel refinements and documentation commits were re-fetched from `main`, but have not been built or device-tested yet.
- A successful build does not by itself verify tap timing, touch injection, or visual layout; distinguish compile status from on-device behavior.

## Mandatory workflow rules

- Work on `main` only. Never create branches.
- Before every edit, inspect current repository state and the exact source being changed.
- After edits, re-fetch the changed files and verify the resulting contents.
- Keep diffs small; no unnecessary dependencies or speculative abstractions.
- Do not run GitHub Actions, Codemagic, or Theos builds without explicit user permission.
- Keep the original binary and verified touch backend unchanged.
