# Cham AutoClicker

A lightweight iOS POINT auto-clicker tweak for TrollStore + TrollFools.

## Current scope
- POINT tapping with one or more saved coordinates.
- Adjustable repeat interval and press duration.
- Draggable floating handle and compact control panel.
- Automatic persistence of coordinates, point list, interval, press duration, panel position/scale, and handle position.
- Safe DOWN/UP lifecycle handling.

## Status
- POINT touch delivery was previously confirmed by the user on-device.
- The known-good HID/UIKit backend is preserved unchanged.
- POINT-only scheduler, refreshed panel, and persistent settings are committed but still need a successful user build and device test.

## Build
The Theos build workflow is manual-only. Do not run it unless the user explicitly authorizes it. The user normally runs builds and device tests.

## Preservation
The original `Cham.dylib` is preserved unchanged and is not a build input.
