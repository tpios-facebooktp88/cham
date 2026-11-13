# Cham AutoClicker

Standalone iOS automation tweak/dylib intended for TrollStore + TrollFools.

## Agreed scope
- Tap Mode: POINT, DOUBLE, HOLD, HUMAN, EXTREME, ULTRA and multi-point.
- Touch Recorder: record, save, replay, speed multiplier, loop, stop and clear.
- Smart OCR: Apple Vision OCR, EXACT / CONTAINS / STARTS WITH, keyword sequence, ROI, cooldown and scan interval.
- Floating overlay: draggable controls, mode selection, recorder controls, preferences, English and Arabic.

## Current status
- [x] Initial Theos scaffold
- [x] Draggable floating handle and initial Tap Mode menu controls (source only)
- [x] Tap timing/point scheduler abstraction
- [x] OCR text matching primitives
- [x] Primary HID event provider source implementation (IOHID + BackBoardServices)
- [x] UIApplication `_enqueueHIDEvent:` path
- [x] UITouch and UIEvent state bridge source implementation
- [ ] Device validation on iOS 16 (event delivery, DOWN/UP lifecycle and stop-time release)
- [ ] Touch Recorder capture/replay
- [ ] Vision capture loop, ROI and cooldown
- [ ] Full overlay controls, preferences and localization

Checked items are source-code milestones, not device-tested claims. The HID and UIKit touch bridge source has not been built or validated on a device.

## Build
GitHub Actions runs only when manually dispatched from the Actions tab. It compiles the Theos tweak and uploads only `Cham.dylib` as the `Cham-dylib-*` artifact. It does not run on pushes, create a `.deb` package, install the tweak, or test it on a device.

## Compatibility
The current provider dynamically resolves the HID and BackBoardServices entry points, constructs a parent Digitizer event and a finger event, applies the active window context ID, and dispatches through the HID event-system client. The provider also queues the event through UIApplication's `_enqueueHIDEvent:` selector. The provider also updates the shared UITouch/UIEvent state using the private UIKit selectors found in the reference binary. The scheduler's phase contract is DOWN = 0 and UP = 1. API availability and a dispatch call do not prove that iOS accepted or delivered the touch; device validation is still required. The original Cham.dylib is not modified, linked, or required.
