# Cham AutoClicker — Technical Checkpoint

Date: 2026-11-13  
Branch: `main`  
Repository: `tpios-facebooktp88/cham`

## Purpose

Preserve the reverse-engineering notes supplied for the original `Cham.dylib` and use them as a design reference for rebuilding Cham AutoClicker as a standalone iOS 16 Theos dylib for TrollStore + TrollFools.

This checkpoint records research claims separately from facts verified in the current repository. It is not proof that private APIs work on a target device.

## Project constraints

- Work on `main` only. Do not create branches.
- Preserve the original `Cham.dylib`; do not patch, overwrite, or link it into the new project.
- Keep changes minimal and avoid unnecessary dependencies.
- Do not run GitHub Actions, Codemagic, Theos builds, or generate build artifacts unless the user explicitly authorizes it. The user performs builds.
- Keep GitHub Actions manual-only (`workflow_dispatch`); never add push-triggered builds.
- Target iOS 16 and TrollStore + TrollFools.
- Do not implement stealth, anti-detection, or anti-bot evasion. Do not claim synthetic input is undetectable.

## Reference research supplied by the user

### Touch/HID symbols reported in the original binary

- `IOHIDEventSystemClientCreate`
- `IOHIDEventCreateDigitizerFingerEvent`
- `BKSHIDEventSetDigitizerInfo`
- `IOHIDEventSetFloatValue`
- `IOHIDEventSetIntegerValue`
- `IOHIDEventSetSenderID`
- `IOHIDEventAppendEvent`
- `IOHIDEventSystemClientDispatchEvent`

The supplied research also describes a wrapper named:

`fakeTouchId:AtScreenPoint:inWindow:withTouchPhase:force:radius:`

Treat symbol names and wrapper behavior as research leads. Verify exact symbol availability, function signatures, argument semantics, ownership, event masks, coordinate space, and phase transitions before relying on them.

### Feature groups described by the reference

1. **Tap Mode**
   - POINT, DOUBLE, HOLD, HUMAN, EXTREME, ULTRA.
   - Multiple saved points and configurable timing.
2. **Touch Recorder**
   - Record gestures, save/load recordings, replay with timing and speed multiplier, loop, stop, clear, and floating stop control.
   - The supplied notes mention an `acp_recording.bin` file and `recorderLoops`; neither format nor key is independently verified.
3. **Smart OCR**
   - Apple Vision text recognition.
   - EXACT, CONTAINS, STARTS WITH matching.
   - Ordered keyword sequences (examples supplied: START, CLAIM, OK, CONTINUE, SKIP).
   - ROI, cooldown, scan interval, and READY/SCANNING/RESET states.
4. **Floating overlay**
   - Draggable controls, mode selection, recorder controls, OCR/ROI editor, preferences, English/Arabic localization, and target-app configuration.
5. **Preferences / injection targeting**
   - Supplied notes cite `/var/mobile/Library/Preferences/com.darwiniq.autoclicker.plist`, notification `com.darwiniq.autoclicker/prefsChanged`, and keys such as `allowAllApps`.
   - These identifiers and semantics are unverified and must not be copied blindly.
   - Supplied target bundle IDs: `com.darwiniq.autotouchclick.app`, `com.boundlessdrop.jawaker`. Treat as reference-only, not defaults.

### Limitations reported by the research

- OpenGL/Metal rendering may introduce coordinate offsets.
- OCR capture may fail or return black frames when screen capture is restricted (`UIScreen.isCaptured`).
- Private API signatures and availability can change across iOS versions.
- Highly regular automation timing can be rejected by some apps; do not add evasion logic.

## Current repository facts checked on 2026-11-13

Latest `main` commit: `54c2f0cd1b1208945c1f42bb2ce9965969e0a68e`.

Current source tree includes:
- `Cham/CHMOverlay.h`, `Cham/CHMOverlay.m`
- `Cham/CHMTapScheduler.h`, `Cham/CHMTapScheduler.m`
- `Cham/CHMTouchBackend.h`, `Cham/CHMTouchBackend.m`
- `Cham/CHMOCRMatcher.h`, `Cham/CHMOCRMatcher.m`
- `Cham/Entry.xm`
- `Makefile`, `control`, `.github/workflows/build.yml`, `README.md`

Current source milestones (not device-validated):
- Tap Mode overlay has draggable panel, zoom controls, mode selector, X/Y inputs, interval, duration slider, numbered draggable point markers, and START/STOP controls.
- Scheduler currently emits only DOWN and UP phases, handles one active finger, and schedules point cycles.
- Backend dynamically resolves IOKit and BackBoardServices functions, creates digitizer/finger events, updates UIKit touch/event state, and dispatches through both UIApplication `_enqueueHIDEvent:` when available and `IOHIDEventSystemClientDispatchEvent`.
- Backend currently requires the main thread, finds the key window, uses a single fixed finger index, and retains one `activeTouch` property.
- Marker hit-testing exclusion is implemented by temporarily hiding the marker root while hit-testing.
- OCR matching primitives exist, but the full Vision capture/scan loop is not implemented.
- Touch Recorder capture, persistence, and replay are not implemented.
- Full overlay preferences, target-app filtering, and localization are not implemented.
- README explicitly says device validation is still outstanding.

## Original binary cross-check completed on 2026-11-13

Original file examined directly from the Project upload:
- SHA-256: `bfeeced4b8d57d8f384fbe539fa2c575b98405172d4f32655ce79bd4ef1c4fdd`
- Size: 472,048 bytes.
- Universal Mach-O: arm64 + arm64e; `cryptid=0`.
- The binary contains the expected IOKit and BackBoardServices symbol strings and private UIKit selectors.

Verified from Objective-C metadata and arm64 call-site disassembly:
- Original method encoding for `fakeTouchId:AtScreenPoint:inWindow:withTouchPhase:force:radius:` is `q72@0:8q16{CGPoint=dd}24@40q48d56d64`. It carries a touch identifier, CGPoint, window, phase, force, and radius.
- The binary resolves `IOHIDEventCreateDigitizerEvent`, `IOHIDEventCreateDigitizerFingerEvent`, `IOHIDEventAppendEvent`, `IOHIDEventSetSenderID`, `IOHIDEventSetIntegerValue`, `IOHIDEventSetFloatValue`, `IOHIDEventSystemClientCreate`, `IOHIDEventSystemClientDispatchEvent`, and `BKSHIDEventSetDigitizerInfo`.
- IOKit is attempted from both public-framework and private-framework paths; BackBoardServices is loaded from its private-framework path.
- Call sites confirm sender ID `0xDEFACEDBEEFFECE5`; integer field IDs `0xB002F`, `0xB0039`, `0xB003A`, `0xB003B`; and finger float field IDs `0xB0030`, `0xB0031`.
- The original constructs a parent digitizer event and a finger event, appends the finger event, conditionally applies BackBoard digitizer metadata when the API and nonzero window context are available, then uses the UIApplication enqueue path when supported and the HID event-system dispatch path.
- The original helper's branch selects event mask `0x27` for phase value 0, `0x24` for phase values 1–2, and `0x27` for values 3–4. The original normal-tap scheduler call site invokes phase 0 for the initial touch and phase 1 in the delayed completion, confirming that the current DOWN=0 / UP=1 mapping matches the original tap path.

Correction made from this comparison:
- The first reimplementation incorrectly treated BackBoardServices and `BKSHIDEventSetDigitizerInfo` as mandatory. The original loader continues when BackBoardServices cannot be opened; the metadata call is conditional on the function and a valid context ID. `CHMTouchBackend.m` now keeps both optional.
- Source change commits: `7f49737224f309134d45ea7bf3177060733ef2b4` (optional symbol) and `02c2c98f82dc036a6deee9d45b382224908548ba` (optional framework).

Still requiring audit:
- Full UITouch/UIEvent phase and reuse lifecycle, including cleanup after UP and stop.
- Exact event ownership/release behavior for every failure branch.
- The original multi-touch identifier behavior versus the current scheduler's deliberate single-finger index. The original Objective-C method encoding confirms an explicit touch-ID parameter; current reimplementation pins the ID to 1.
- Whether all UIKit bridge selectors are required on every supported iOS 16 target.
- Device-level receipt of events. Binary similarity and a void dispatch call are not proof of successful app-level delivery.

## Audit items before extending touch dispatch

1. Compare the original binary's actual call sites and signatures with the declarations in `CHMTouchBackend.m`; do not infer ABI from symbol names alone.
2. Verify event ownership and release behavior for parent and finger events.
3. Trace DOWN/UP state and ensure stop/deallocation cannot leave a touch active.
4. Determine whether calling both UIApplication `_enqueueHIDEvent:` and HID client dispatch duplicates delivery; do not assume both are required.
5. Verify coordinate conversion and window/context selection.
6. Keep the current single-finger limitation explicit until multi-touch is designed and tested.
7. Validate only on the user's test device and report dispatch success separately from confirmed app-level touch delivery.

## Implementation sequence

1. **Backend audit and stability:** finish source/binary comparison, document verified signatures, fix lifecycle/ownership issues, and add bounded diagnostic logging.
2. **Tap Mode validation:** test each supported mode and multi-point UI behavior on iOS 16; do not mark it complete based only on a successful dylib build.
3. **Touch Recorder:** implement capture, a documented compact recording format, persistence, replay timing/speed, loops, and reliable stop.
4. **Smart OCR:** implement Vision frame acquisition, ROI normalization, matching modes, ordered sequence state, cooldown, and scan interval.
5. **Overlay/preferences:** integrate the completed controls, target-app allowlist/preferences, localization, and persistence.
6. **Release verification:** user builds manually; verify the resulting versioned dylib and device behavior before marking features complete.

## Acceptance rules

- A source milestone is not a successful build.
- A successful build is not proof of injection.
- Successful injection is not proof that an app received the intended touch.
- Only mark a feature device-tested after the user reports a reproducible test result.
- Keep original-binary observations, current-source facts, and device-test results clearly separated.
