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
- [x] Touch backend adapter contract with explicit unavailable state
- [ ] Verified iOS touch-event provider and device validation
- [ ] Touch Recorder capture/replay
- [ ] Vision capture loop, ROI and cooldown
- [ ] Full overlay controls, preferences and localization

Checked items are source-code milestones, not device-tested claims.

## Build
Requires Theos and an iOS SDK. Run make package in a configured Theos environment. No CI workflow is enabled.

## Compatibility
iOS touch synthesis is environment/version dependent. The scheduler emits correctly timed down/up phases through a backend adapter, including a real hold duration and two distinct taps for DOUBLE. The low-level iOS provider is intentionally fail-closed until its API and ABI are verified against the reference binary and target iOS version. No synthetic touch success is claimed. The original Cham.dylib is not modified, linked, or required.
