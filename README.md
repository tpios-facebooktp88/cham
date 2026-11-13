# Cham AutoClicker

Standalone iOS automation tweak/dylib intended for TrollStore + TrollFools.

## Agreed scope
- Tap Mode: POINT, DOUBLE, HOLD, HUMAN, EXTREME, ULTRA and multi-point.
- Touch Recorder: record, save, replay, speed multiplier, loop, stop and clear.
- Smart OCR: Apple Vision OCR, EXACT / CONTAINS / STARTS WITH, keyword sequence, ROI, cooldown and scan interval.
- Floating overlay: draggable controls, mode selection, recorder controls, preferences, English and Arabic.

## Current status
- [x] Initial Theos scaffold
- [x] In-process floating handle and basic panel
- [x] Tap timing/point scheduler abstraction
- [x] OCR text matching primitives
- [ ] Real touch-event backend and device validation
- [ ] Touch Recorder capture/replay
- [ ] Vision capture loop, ROI and cooldown
- [ ] Full overlay controls, preferences and localization

Checked items are source-code milestones, not device-tested claims.

## Build
Requires Theos and an iOS SDK. Run make package in a configured Theos environment. No CI workflow is enabled.

## Compatibility
iOS touch synthesis is environment/version dependent. The scheduler is intentionally separated from the private touch-event backend. Synthetic touch support is not claimed until that backend is implemented and tested on the target device. The original Cham.dylib is not modified, linked, or required.
