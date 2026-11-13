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

Latest source-code commit (checkpoint-only commit follows): `8326a808df25e835f72f2a61814359e167619aa2`.

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
- Follow-up source audit found that the reimplementation still rejected a window without `_contextId`, even though BackBoardServices had become optional. The original path only applies BackBoard digitizer metadata when the function and a nonzero context are available. The backend now requires an active window, but obtains context ID opportunistically and calls the metadata function only when both are available.
- Source change commit: `951b894170d230b3b0ec12115e3bc679a5009c46`.
- UITouch lifecycle correction: the backend now retains `activeTouch` for the DOWN phase and clears its strong reference after dispatching UP. A new tap therefore creates a fresh `UITouch` instead of reusing the previous completed tap's object. If UP preparation fails before dispatch, the prior active touch remains available for diagnosis/recovery.
- Source change commit: `6273e204073a3e2b6e53064bdb92c9906d2a61d5`.
- Scheduler release-failure correction: `stop` now clears `touchIsDown` only when the backend confirms UP; otherwise it retains the blocked state and reports an error. `start` retries stop and refuses to begin a new DOWN while a previous touch remains unconfirmed. The UP-failure path no longer clears the state before stop attempts release.
- Source change commit: `8326a808df25e835f72f2a61814359e167619aa2`.
- Dispatch-path audit: original binary and current source both conditionally enqueue through UIApplication first, then call HID event-system dispatch with the same parent event. Kept both calls and their order; no source change. Original binary also releases the created finger and parent events after dispatch, matching the current success-path release sequence. The precise ownership/retain contract of `IOHIDEventAppendEvent` and delivery behavior still cannot be proven from static call-site inspection alone; retain this as a runtime/API validation item.

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
4. Determine whether calling both UIApplication `_enqueueHIDEvent:` and HID client dispatch duplicates delivery; do not assume both are required. **Audit result (2026-11-13):** the original binary's touch path conditionally invokes UIApplication `_enqueueHIDEvent:` when the selector is supported, then invokes `IOHIDEventSystemClientDispatchEvent` on the same parent event. The current source preserves this order. No source change made; removing either call would diverge from the original without device evidence.
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


## Consolidated backend research plan (2026-11-13)

Purpose: complete one coherent audit of the existing Tap/HID backend before further implementation. This is a research plan and status record, not a claim of device validation. No source code or build configuration is changed by this plan.

### Research workstreams and priority

| Priority | Workstream | Questions to close | Evidence required |
|---|---|---|---|
| P0 | Touch lifecycle and failure recovery | What happens on DOWN success / UP failure, STOP, rapid START-STOP, deactivation, backgrounding, scene disconnect, and backend loss? Can any path leave a contact logically down? | Scheduler/backend state trace, lifecycle notification flow, device test |
| P0 | Coordinate and window correctness | Are saved points window-local, screen-logical, or fixed-screen coordinates? Does orientation, safe area, scene/window selection, display scale, or external display alter the mapping? | Original method call-site trace, UIKit coordinate-space rules, device tests in portrait/landscape |
| P0 | UIKit bridge lifecycle | Is Stationary the correct UITouch phase for both HID DOWN and UP? How are the shared UIEvent and UITouch retained, cleared, and reused by UIKit on iOS 16? | Full original call-site comparison; runtime diagnostics on iOS 16 |
| P1 | HID ABI and event ownership | Verify exact function signatures, parameter widths/order, append semantics, and CF ownership for parent/finger events on every success/error branch. | Original arm64/arm64e disassembly, SDK/header evidence where public, runtime memory diagnostics |
| P1 | Dispatch semantics | Confirm the original conditional UIApplication enqueue followed by HID-client dispatch; establish whether target apps receive one event, not zero or duplicate. | Original call-site comparison and target-app event-delivery test |
| P1 | Scheduler semantics | Confirm POINT/DOUBLE/HOLD timing, repeat boundaries, interval floors, single-finger sequential multi-point behavior, and behavior when configuration changes while running. | State-machine review and deterministic test matrix |
| P2 | Diagnostics and readiness | Add bounded, actionable diagnostics only after the failure states are defined; distinguish API-loaded, dispatch-called, and app-received. | Log review and device test |
| P2 | Scope handoff | Only after Tap Mode is stable, begin Recorder, then Vision OCR, then remaining overlay/preferences. | Acceptance checklist per feature |

### Initial research progress

**Verified from current repository source on `main`:**
- The backend requires the main thread, selects a key window, stores points as `CGPoint`, and uses the same point for `window hitTest:`, UITouch location, and HID event coordinates.
- The overlay creates and moves points in `hostWindow.bounds` coordinates. It does not currently convert those points to the screen's fixed coordinate space.
- The original wrapper name includes `AtScreenPoint`, while Apple's UIKit documentation distinguishes window and screen coordinate spaces and notes that orientation affects those coordinate spaces. Coordinate equivalence is therefore not yet proven; do not change coordinate math until the original conversion path is fully traced.
- The backend currently has no scene/app deactivation or background observer. Apple's lifecycle guidance says apps should quiet work and invalidate timers on deactivation/background; scene notifications are available. A pending DOWN must be treated as a safety-critical stop/release case.
- Scheduler state is serial and single-finger. The original method accepts an explicit touch ID; current code pins finger index to 1. Multi-point currently means sequential taps at several locations, not simultaneous multi-touch.
- On an UP failure, scheduler state is retained and START is blocked. If STOP's release attempt also fails, there is no autonomous retry path; state remains blocked until another explicit start/stop attempt or object teardown.
- The original binary and current source both conditionally call UIApplication `_enqueueHIDEvent:` and then HID-client dispatch on the same parent event. The current order is preserved pending device-level delivery testing.
- The current source releases the created finger and parent events after dispatch and releases already-created events on checked pre-dispatch error branches. Append ownership semantics and UIKit's internal retention behavior remain unproven from source alone.
- `Entry.xm` only schedules overlay attachment after launch; it does not register lifecycle observers.

**Verified from original binary / prior static analysis:**
- Original file SHA-256: `bfeeced4b8d57d8f384fbe539fa2c575b98405172d4f32655ce79bd4ef1c4fdd`.
- Original Objective-C wrapper accepts an explicit touch ID, screen point, window, phase, force, and radius.
- Original normal tap path uses phase 0 for initial contact and phase 1 for completion; current DOWN=0 / UP=1 mapping is consistent.
- Original dispatch path conditionally uses UIApplication enqueue, then HID-client dispatch; both calls should remain until device evidence justifies a change.

### Research order and exit gates

1. Finish original-binary tracing for coordinate conversion, UIKit phase values, touch-ID use, append/release order, and lifecycle-related selectors.
2. Map all scheduler states and every failure/stop/deallocation path. Define a safe state invariant: no new DOWN while an earlier contact is unconfirmed UP.
3. Specify foreground/inactive/background/scene-disconnect behavior and how a release attempt is made while the owning window/context is still valid.
4. Specify coordinate contracts at the UI boundary and HID boundary; validate portrait, landscape, safe-area offsets, and display scale.
5. Prepare an iOS 16 device matrix: single tap, double tap, hold, each interval mode, multiple sequential points, stop during DOWN, rapid start/stop, app interruption, app switch/background, orientation change, window loss, and backend-unavailable cases.
6. Only then make the smallest code changes, one focused commit per concern. User performs all builds; no Actions/Codemagic/Theos build without explicit authorization.
7. Do not call Tap Mode complete until the user confirms reproducible app-level event delivery on device.

### External platform references
- Apple UIKit coordinate spaces: window and screen coordinate spaces change with interface orientation; explicit conversion APIs are provided. https://developer.apple.com/documentation/uikit/uicoordinatespace
- Apple UIKit background preparation: apps should quiet work and invalidate active timers on deactivation, and clean up when entering background. https://developer.apple.com/documentation/uikit/preparing-your-ui-to-run-in-the-background
- Apple scene lifecycle: each scene has its own lifecycle; scene background notifications are available. https://developer.apple.com/documentation/uikit/managing-your-app-s-life-cycle

### Current research status
- Repository/source inventory: complete.
- Original binary identity/hash rechecked: complete.
- Dual-dispatch order comparison: complete.
- Lifecycle/background gap identified: complete as a source finding; behavior still needs device validation.
- Coordinate contract: open.
- Full UIKit phase/retention semantics: open.
- Exact IOHID append ownership and runtime event receipt: open.
- No source-code edits, build, Actions run, or device test performed in this research pass.


### Deep-dive findings added after the consolidated plan

**Scheduler state-machine review (current source, no edits):**
- STOP during HOLD is synchronous: it cancels the pending main-queue timer and immediately attempts UP at the remembered point. This is the correct basic order, but depends on the backend still finding a valid window and successfully constructing/dispatching the release.
- On a normal UP failure in `advance`, the scheduler reports the error and calls `stop`, which makes one additional immediate UP attempt. If that also fails, `touchIsDown` remains true and a future START first retries STOP, then blocks if still unconfirmed. This is a bounded retry policy driven by user actions, not an autonomous retry loop.
- The backend's return value only means its synchronous preparation and void dispatch calls were reached. Neither `IOHIDEventSystemClientDispatchEvent` nor UIApplication `_enqueueHIDEvent:` returns a delivery result; therefore `touchIsDown = NO` after a returned YES is only "dispatch path invoked", not proof the target app processed UP.
- Important teardown limitation: scheduler `dealloc` calls `stop`, but if UP fails and the scheduler is then destroyed, its `touchIsDown` flag is lost. The backend currently retains the active `UITouch` only while the backend itself survives. No durable recovery mechanism exists. Avoid deallocating the scheduler while a touch is unconfirmed.
- Important target-consistency gap: DOWN uses the current key window and a hit-tested view. UP calls the same path again, selecting the then-current key window and hit-testing again, then reassigns the existing `UITouch` to that window/view. If key-window ownership changes between DOWN and UP, the release may be associated with a different window/view than the original DOWN. Recommended design: capture the owning window, hit-tested view, scene/context and coordinate at DOWN; use that same contact context for UP, and fail closed if it has become invalid. Do not silently substitute another key window.
- STOP UI status currently writes "Stopped" immediately after the scheduler call. The scheduler error handler dispatches its label update asynchronously, so a failed UP can briefly be displayed as Stopped before the error appears. This is a UI truthfulness issue to correct when implementing diagnostics.
- DOUBLE is two sequential DOWN/UP pairs separated by `doubleTapGap`; `repeatCount=0` means indefinite cycles. HOLD is implemented as one DOWN held for `holdDuration`, then UP; it is not a separate HID phase.
- The interval helper has a 10 ms minimum even though the UI's interval field can parse values below that. EXTREME caps to 30 ms and ULTRA to 10 ms; these modes change timing only and do not create a distinct touch mechanism.
- Multi-point means serial points with one fixed finger index (1), not simultaneous contacts. The unused `tapsAtCurrentPoint` property is scheduler bookkeeping, not a multi-touch implementation.

**Original binary coordinate/lifecycle evidence (static inspection):**
- The original binary contains Objective-C selector references for `convertPoint:fromWindow:` and `convertPoint:toWindow:`, as well as methods named `addTargetAtScreenPoint:`, `moveTargetAtIndex:toScreenPoint:save:`, and `fakeTouchId:AtScreenPoint:inWindow:withTouchPhase:...`. This is evidence that the original code has explicit window/screen coordinate conversion machinery somewhere in its target/overlay path.
- This string/selector evidence does **not** yet establish the exact conversion direction, the exact point passed into the HID event versus UITouch, or whether conversion occurs before the fakeTouch method. The source's current direct use of the same `CGPoint` for HID coordinates and `_setLocationInWindow:` is therefore not proven equivalent to the original. Keep coordinate conversion as a P0 open item until the relevant original method call sites are fully traced.
- Original binary contains UIApplication lifecycle notification strings for will-resign-active, did-enter-background, and did-become-active. This indicates lifecycle handling exists in the reference binary, but does not by itself prove which callback stops the scheduler or releases an active touch.
- Current backend UP path still selects a fresh key window and hit-tests again. It does not preserve the original DOWN window/view/context. This is a concrete source-level lifecycle/ownership gap, independent of whether the private HID API accepts the event.

**Platform documentation cross-check:**
- Apple's `UICoordinateSpace` documentation explicitly says window and screen coordinate spaces track interface orientation; persistent fixed-screen points should be converted to `UIScreen.fixedCoordinateSpace`. This confirms that coordinate-space contracts must be explicit, not inferred from matching CGPoint types: https://developer.apple.com/documentation/uikit/uicoordinatespace
- Apple's `UIScene.willDeactivateNotification` is posted before a scene stops responding to user events, including temporary interruptions and transition to background; Apple recommends pausing ongoing work and disabling timers there: https://developer.apple.com/documentation/uikit/uiscene/willdeactivatenotification
- `UIScene.didEnterBackgroundNotification` is later and intended for background cleanup; it is too late to be the sole point at which an active touch is released: https://developer.apple.com/documentation/uikit/uiscene/didenterbackgroundnotification
- `UIScene.didDisconnectNotification` means the scene is being removed and is a final cleanup point, not a reliable opportunity to initiate a fresh touch sequence: https://developer.apple.com/documentation/uikit/uiscene/diddisconnectnotification

**Revised implementation recommendations (not yet implemented):**
1. Add a scene-scoped observer for `UIScene.willDeactivateNotification` (and a defensive app-level resign-active observer if required for non-scene lifecycle). Filter notifications to the scene owning the overlay. Stop the scheduler synchronously on the main thread while the scene/window is still available; record whether release was confirmed. Do not auto-resume taps on foreground.
2. Capture the exact DOWN contact context (window, view, scene/context ID, and coordinate contract) and reuse it for UP. If it is no longer valid, report a release-unconfirmed state and block new DOWN; do not redirect UP to a different key window.
3. Define a single coordinate contract. Likely UI point storage remains in overlay/window-local coordinates; convert explicitly to the exact coordinate space expected by HID, while UITouch receives window-local coordinates. Verify this against the original binary call sites before coding.
4. Keep failed-UP state alive and visible. Do not let scheduler teardown erase an unconfirmed contact state. Any retry must be bounded and explicit; no infinite retry loop.
5. Make UI status reflect "Stop requested / release unconfirmed" until a successful release dispatch path is invoked; still label that as dispatch attempted, not app receipt.
6. Before Recorder, test iOS 16 in portrait/landscape, key-window changes, interruptions, background transition, stop-during-HOLD, repeated STOP, rapid START/STOP, and simulated backend failures.

### Research status after deep dive
- Scheduler normal/STOP/HOLD/double/interval semantics: source review complete.
- UP failure and bounded retry behavior: source review complete; teardown and window reassignment gaps identified.
- Original binary coordinate conversion: selector evidence found; exact call-site direction remains open.
- Original binary lifecycle handling: notification evidence found; exact behavior remains open.
- iOS lifecycle timing and coordinate-space guidance: checked against current Apple documentation.
- No source-code edits, build, Actions run, or device test performed in this pass.


## Implementation update — 2026-11-13

The first P0 source changes following the audit are now committed to `main`. These are source-only changes; no build, injection, or device test was run.

### Changes made

- `CHMTouchBackend` now retains the exact DOWN target window and view, plus the window context ID and point, until the matching UP dispatch path completes.
- UP no longer calls the key-window selector or hit-tests again. It uses the captured window/view/context/point. If the original window/view is no longer valid, the backend refuses to redirect UP to a different target and retains the active-touch state for diagnosis/retry.
- A second DOWN is rejected while the backend still retains an active UITouch.
- `CHMTapScheduler.hasUnconfirmedTouch` exposes whether the scheduler still considers a release unconfirmed.
- `CHMOverlay` observes `UISceneWillDeactivateNotification` for its owning scene. For a non-scene window, it falls back to `UIApplicationWillResignActiveNotification`. The observer runs on the main queue and requests scheduler STOP before the scene/app deactivation proceeds; the observer token is removed during overlay deallocation.
- STOP status now distinguishes a retained/unconfirmed release from a completed UP dispatch path. It explicitly says delivery remains unverified.

### Source-level checks performed

- Confirmed active window and view are strongly retained for the contact lifetime.
- Confirmed UP uses the captured window, view, context ID, and point.
- Confirmed key-window lookup and hit-testing occur only on DOWN.
- Confirmed scene-scoped deactivation observer, app fallback observer, and observer cleanup.
- Confirmed the GitHub Actions workflow remains manual-only (`workflow_dispatch`).

### Remaining open items

- Coordinate-space contract is unchanged and remains open. The UI points are currently window-local; HID coordinates still receive the same numeric point. Do not change conversion math until original call-site tracing/device evidence closes this.
- UIKit `UITouchPhaseStationary` semantics and private API behavior still require iOS 16 device validation.
- If the captured window or view is detached before UP, release is deliberately not redirected. The scheduler remains blocked and reports release unconfirmed; recovery behavior must be validated on device.
- No build, GitHub Actions, Codemagic, Theos compile, or artifact generation was run. The user performs builds.



## Build-error source audit — 2026-11-13

- User reported a build failure after the lifecycle/source milestone and asked that the fix and workflow be recorded.
- Static review found an Objective-C dot-syntax error in `Cham/CHMOverlay.m`: the scheduler declares `@property (nonatomic, readonly, getter=isRunning) BOOL running`, so property access must use `.running`. Calling `.isRunning` is not a declared property and can fail compilation.
- Replaced both `self.scheduler.isRunning` expressions with `self.scheduler.running`.
- Searched the current source for other `.isRunning` dot-property accesses; none remain in the reviewed source files.
- Build was not run. This source correction is not a claim that the full project now compiles; the user's next build result remains the acceptance check.
- **Build-failure workflow:** when the user reports a build error, first fetch latest `main`, inspect the exact source and build configuration, locate the earliest concrete compiler error, make the smallest correction, record it here, and leave all build execution to the user unless explicitly authorized.


## Follow-up build-error source audit — 2026-11-13

The previous `.isRunning` correction was not the only Objective-C dot-syntax issue. A second source pass found three more invalid property-name accesses and one class-method dot expression:

- `CHMOverlay.m`: `candidate.isKeyWindow` changed to `candidate.keyWindow`. UIKit declares the property as `keyWindow` with getter `isKeyWindow`.
- `CHMTouchBackend.m`: `window.isKeyWindow` changed to `window.keyWindow` for the same reason.
- `CHMTapScheduler.m`: `self.backend.isAvailable` changed to `self.backend.available`. The declared property is `available` with getter `isAvailable`.
- `CHMTouchBackend.m`: `NSThread.isMainThread` changed to the explicit class-method call `[NSThread isMainThread]`.

These are source-level compile-risk corrections found by scanning every current Objective-C/Objective-C++ source file for dot expressions beginning with `is`. The code was not compiled. The user still performs the build; if it fails again, the earliest compiler diagnostic is needed to distinguish any remaining SDK/toolchain issue from source errors.

## Build failure #10 — exact compiler diagnostic and fix — 2026-11-13

- Inspected GitHub Actions run #10 for commit `554630c71bee9f3cfee6a87e4fc42c462c2a8f58` directly; job `Build Cham.dylib` failed during compilation of `Cham/CHMOverlay.m`.
- Exact first compiler error: `Cham/CHMOverlay.m:47:46: error: unused parameter 'note' [-Werror,-Wunused-parameter]`.
- Cause: the notification observer block accepted `NSNotification *note` but never read it. The project enables `-Wextra`, and Theos/Clang treats this warning as an error in the build environment.
- Minimal fix: added `(void)note;` at the start of the observer block. No behavior change; notification timing and observer logic are unchanged.
- The failure was retrieved from the existing user-triggered Actions run; no new build or workflow run was started by the assistant.
- Source fix commit: `08365142c2500ee73f5dd97a27d93e058ab0cb89`.
- Build has not been rerun. The user remains responsible for the next build; do not mark compilation successful until a subsequent run succeeds.


## START tap routing fix — 2026-11-13

- User confirmed injection and overlay display work, but pressing START produced no visible target-app action.
- Source inspection found a concrete hit-testing defect: the default tap point is the window center, while Cham's panel is placed over the central screen area. The backend only hid a point marker during hit-testing; it did not exclude Cham's own handle or panel. Thus the synthetic UITouch could be associated with Cham's overlay view rather than the underlying app content.
- Marked the Cham handle and panel with the existing overlay tag (`0x43484D`). Point markers already use that tag.
- During DOWN hit-testing, the backend now temporarily hides all tagged direct subviews of the host window, resolves the underlying app view, then restores each overlay's visibility. The rest of the HID dispatch path and scheduler timing are unchanged.
- This is a source-level routing correction. It has not been compiled or device-validated; user must rebuild and test START on a clear target-app control. If it still does nothing, next investigation is the unresolved window-local versus HID screen-coordinate contract and runtime HID dispatch diagnostics.
- Source commits: overlay `8b8b2e0ebf633022188ea9554d940d2109ceb8f7`; backend `8314410603b225f241746c59c8a71279efbb30ac`.


## Post-REA source alignment audit — 2026-11-13

Compared the current `main` source against the final REA/Ghidra baseline. This is a static source review only; no source code or binary was changed in this audit.

### Tap Mode alignment

| Mode / capability | Current source behavior | REA evidence | Assessment |
|---|---|---|---|
| POINT | One DOWN/UP pair per configured point | Normal tap path uses phase 0 then completion phase | Basic path represented; runtime unverified |
| DOUBLE | Two sequential tap pairs with configurable gap | Double-tap callback chain starts a second touch after a delay | Broadly aligned; exact timing still unverified |
| HOLD | One DOWN held for the configured duration, then UP | Hold setting feeds a separate duration path | Broadly aligned; runtime unverified |
| HUMAN | Randomizes the interval by 0.8–1.2 | A numeric mode case randomizes X/Y by -5…+5 and duration by 0.80–1.20; visible HUMAN label-to-case mapping is not proven | Not equivalent; do not claim complete |
| EXTREME | Caps the interval at 30 ms | Reference selects a burst of 1–4 instant taps using timing thresholds | Not equivalent |
| ULTRA | Caps the interval at 10 ms | Reference invokes an instant-tap path; repeat cadence is controlled by its caller | Not equivalent |
| Multiple points | Sequential taps using one fixed finger index | Reference has a configured-point sequence path; explicit touch IDs exist, but full simultaneous multi-touch is not established | Sequential multi-point only; simultaneous multi-touch not implemented |

### Other feature gaps

- Recorder: current repository has no capture, event serialization, persistence, or replay implementation. REA identified UI handlers and call targets, but the recorder core was not decompiled in the final batch. Do not invent the recording file format from the `acp_recording.bin` string.
- Smart OCR: current repository has text matching primitives only. Vision image capture, recognition requests, scan scheduling, cooldown execution, ROI-to-image conversion, and result dispatch are not implemented.
- Touch backend: source contains the HID/UIKit bridge and preserves the DOWN target context for UP. This remains unbuilt and unvalidated on an iOS 16 device.
- Coordinate contract: current overlay points are window-local and the same numeric point is passed to HID coordinates. Original-binary selector evidence shows explicit window/screen conversion exists somewhere, but its exact call path is unresolved. Do not change coordinate conversion by guesswork.
- Lifecycle: the overlay stops on scene deactivation; if release cannot be dispatched, the state remains blocked. This is a source safeguard, not proof of successful OS-level release.

### Recommended implementation order

1. Close the Tap Mode mapping gap from the already-saved REA artifact before changing mode behavior. In particular, prove the UI enum/selector mapping for HUMAN, EXTREME and ULTRA.
2. Resolve the coordinate conversion path from existing binary evidence before changing HID coordinates.
3. Keep the current DOWN/UP safety invariant: never send a new DOWN while the prior contact remains unconfirmed.
4. Only then implement the smallest mode-specific scheduler changes, without touching the original binary.
5. Recorder and OCR remain separate phases; implement neither from UI strings alone. First establish their internal data/recognition paths from evidence already available.
6. User performs all builds and device tests. Do not run Actions, Theos, or Codemagic without explicit permission.

### Acceptance status

- Static source alignment audit: complete.
- Tap Mode feature parity: incomplete.
- Recorder: not implemented.
- Vision OCR engine: not implemented.
- iOS 16 device validation: outstanding.
- Original `Cham.dylib`: preserved unchanged.


## Touch terminal-phase correction — 2026-11-13

A focused source correction was made from the saved REA run #5 pseudocode. No new REA/Actions run or build was performed.

### Evidence from the existing artifact

- `0x9a8c` passes the supplied phase value into UITouch's private `setPhase:` selector.
- The same routine removes the stored UITouch from its dictionary for phase values 3 and 4; other phases retain/update the touch.
- `0xba18` begins a normal tap with phase 0. Its completion callback `0xbc90` sends phase 3.
- `0xa9d8` maps phase values 0, 3 and 4 to HID event mask `0x27`; phase values 1 and 2 map to `0x24`.

### Source changes on main

- `CHMTouchPhaseUp` is now explicitly value 3, matching UITouch Ended.
- The backend sets `UITouchPhaseBegan` for DOWN and `UITouchPhaseEnded` for UP instead of setting Stationary for both.
- The DOWN/ENDED HID event uses mask `0x27`, consistent with the reference helper.
- `_setLocationInWindow:resetPrevious:` now resets previous location on DOWN and preserves it on UP.

Commits:
- Header enum: `c2fa36dc473545bb9e5e3e5637f706b1b0eff351`
- Backend release phase: `70d2f943c0418e8bc6eafce79ff5760c036ac8b0`

### Validation boundary

- Source changes are committed and verified in GitHub.
- No build or device test was run. User must compile and test a tap on a clear target-app control.
- A successful dispatch call still does not prove that iOS delivered the touch to the target app.
- The backend currently supports only DOWN and terminal UP; the reference's optional intermediate HUMAN move phase (1) is not yet implemented.


## HID constructor ABI and coordinate correction — 2026-11-13

User reported that the injected tweak and overlay still did not produce a target-app touch. Re-opened the saved final REA #5 pseudocode and compared the exact dynamic function-pointer call argument order with `CHMTouchBackend.m`.

### Confirmed mismatches

- REA `0xa9d8` calls the digitizer constructor with the five scalar values first (`x, y, z, force, twist`), followed by allocator, mach timestamp, transducer/index/identity, event mask, button mask, and range/touch flags. The previous source typedef and call used allocator/time/metadata first. The ABI argument order did not match the recovered call site.
- REA calls the finger constructor in the same scalar-first order, followed by allocator/time, finger index/identity, event mask, range/touch flags, and options. The previous source also used a different order.
- REA `0xa28c` invokes the BackBoard digitizer metadata function as `(0, 0, event, windowContextID, 0, 0, 0)`. The previous source passed `(event, contextID, 0, 0, NULL, 0, 0)`, which did not match the recovered call order.
- The overlay stores points in host-window coordinates. The original fake-touch path explicitly converts between screen and window coordinate spaces. The previous source sent the same window-local point to both HID and UITouch.

### Source correction on main

- Corrected both dynamic constructor function-pointer typedefs and their call argument order to match the saved REA pseudocode.
- Corrected the BackBoard metadata function signature and call order.
- Converted the stored window-local point to screen coordinates for HID event creation; UIKit `UITouch` continues to receive the window-local point.
- Set digitizer range/touch flags to 1 on DOWN and 0 on terminal UP, matching the recovered phase-derived boolean for phases 0 and 3.
- Kept the recovered event mask `0x27`, sender ID, parent/finger field IDs, force and radius values, event append, UIApplication enqueue, and event-system-client dispatch.

Source commit: `b1e93c314cd70407a30488b5514e4f9d2d25835b`.

### Static verification

Re-fetched the committed source from GitHub and verified all eight expected ABI, metadata, coordinate, and phase-flag patterns. No build, Actions run, injection, or device test was performed.

### Remaining validation

- The exact ABI order is supported by the saved decompiled call site, but must still be validated by compiling and testing on the target iOS 16 environment.
- `IOHIDEventSystemClientDispatchEvent` and UIApplication's private enqueue method do not provide an application-level delivery acknowledgement. A successful return from the local backend is not proof that the target app received the touch.
- If the corrected build still does not touch, the next required evidence is the in-app diagnostic output for each stage: symbol resolution, parent event creation, finger event creation, window-to-screen coordinates, context ID/BKS metadata availability, UIKit enqueue selector availability, and dispatch invocation. Do not add another HID API blindly.


## UIKit event delivery correction — 2026-11-13

- Re-fetched the current `main` implementation and compared it with the saved REA baseline for `fakeTouchId:AtScreenPoint:inWindow:withTouchPhase:force:radius:`.
- The backend already created/populated `UITouch` and `UIEvent`, attached the HID event, cleared/added the touch, and invoked the alternate HID enqueue/dispatch calls, but it did not invoke `UIApplication.sendEvent:`.
- The REA baseline explicitly records that the original UIKit path iterates tracked touches, adds them to the event, and calls `UIApplication.sendEvent:`. Added the missing `[application sendEvent:touchEvent]` immediately after `_addTouch:forDelayedDelivery:`.
- No timing code, mode behavior, original `Cham.dylib`, or Makefile framework list was changed. The Makefile currently links UIKit and Foundation; IOKit symbols are dynamically resolved with `dlopen/dlsym`, so adding `-framework IOKit` is not required by this implementation.
- This is an evidence-based source correction, not proof of OS-level touch delivery. The coexistence/branch relationship between the UIKit send path and alternate HID dispatch path still needs iOS 16 device validation. No build, Actions run, or injection test was performed.


## IOKit HID constructor ABI correction — 2026-11-13

- Re-fetched the current `main` source before editing. The two dynamically resolved constructor typedefs/calls in `Cham/CHMTouchBackend.m` did not match the exported IOKit function signatures: the source passed coordinate/pressure scalars before allocator, timestamp and digitizer metadata.
- Corrected `IOHIDEventCreateDigitizerEvent` to the 15-argument ABI: allocator, timestamp, transducer type, index, identity, event mask, button mask, x/y/z, tip pressure, barrel pressure, range, touch, options.
- Corrected `IOHIDEventCreateDigitizerFingerEvent` to the 13-argument ABI: allocator, timestamp, index, identity, event mask, x/y/z, tip pressure, twist, range, touch, options.
- Kept the existing intended values (parent transducer type 3; finger index/identity 1; event mask 0x27; existing coordinates, force, range/touch flags). No scheduler timing, overlay, framework list, or original `Cham.dylib` changes.
- ABI signatures cross-checked against the public IOKit header and WebKit's iOS HID event generator. Static source correction only; no build or iOS 16 runtime test was run. This does not yet prove event delivery.

## Device milestone: POINT click confirmed — 2026-11-13

<badge>DEVICE TEST PASSED</badge>

The user built the latest `main` and confirmed that the synthetic POINT touch now produces a real click on the target device. This is the first confirmed app-level touch-delivery milestone; the earlier source-only checks did not establish this.

### Changes present in the working build

1. **Corrected the IOKit digitizer constructor ABI** — commit `398054e930f13b5e8922deca849e2f292f09757f`.
   - `IOHIDEventCreateDigitizerEvent` now uses the correct 15-argument signature and order: allocator, timestamp, digitizer metadata, coordinates/pressure, range/touch, options.
   - `IOHIDEventCreateDigitizerFingerEvent` now uses the correct 13-argument signature and order: allocator, timestamp, finger metadata, coordinates/pressure, range/touch, options.
   - Updated both function-pointer typedefs and both constructor calls. The previous argument order was wrong, so the dynamically resolved functions were being called with an ABI mismatch. This was the critical correction immediately preceding the successful device test.

2. **Added explicit UIKit event delivery** — commit `9ea555e700861d35f6fb8af7d30862614665ec04`.
   - After populating the `UITouch` and `UIEvent`, the backend now calls `[application sendEvent:touchEvent]`.
   - This was already present in the successful build. The device test confirms the combined implementation works; it does not independently prove whether this call or the ABI correction alone was sufficient.

### Confirmed scope

- Confirmed by user: POINT mode can click on the target device.
- The successful build includes both the UIKit `sendEvent:` delivery addition and the corrected IOKit constructor ABI.
- No claim yet for DOUBLE, HOLD, HUMAN, EXTREME, ULTRA, multi-point, recorder, or OCR.
- No timing values were changed in this fix.
- Original `Cham.dylib` remains untouched.
- No GitHub Actions, Codemagic, or assistant-run build was used for this milestone; the user built and tested.

### Next validation

Use this commit as the known-good touch-delivery baseline. Keep the backend constructor ABI and UIKit `sendEvent:` path unchanged while validating the remaining Tap modes. If a later change breaks POINT, compare against this exact milestone first.

## POINT-only cleanup, persistent settings, and UI refresh — 2026-11-13

### User-approved scope

The user confirmed that only POINT mode is currently needed. Other Tap modes and unfinished feature scaffolding should be removed rather than maintained speculatively. Preserve the already device-confirmed POINT touch backend and let the user run builds/tests.

### Changes committed on `main`

- Simplified `CHMTapScheduler` to a POINT-only cycle: configured point sequence, DOWN, press duration, UP, then interval. Removed mode enum/selection, DOUBLE/HOLD/HUMAN/EXTREME/ULTRA branches, double-tap gap, random timing, and unused repeat-count/cycle state.
- Kept multiple configured POINT coordinates. This is still POINT mode; no alternate tap modes remain.
- Reworked `CHMOverlay.m` into a compact dark panel with a blue-violet accent, clearer coordinate fields, interval, press-duration slider, point controls, and prominent START/STOP controls.
- Added automatic persistence with `NSUserDefaults`: coordinate fields, point list, interval, press duration, floating handle position, panel position, and panel scale are saved as settings change and restored when the tweak attaches / panel reopens.
- Removed the unused OCR text-matcher source files and removed them from `Makefile`. OCR was only a standalone matching primitive, not a complete Vision OCR workflow.
- Updated README to describe the actual POINT-only scope and distinguish the previous device-tested touch baseline from the new source changes awaiting user build/test.
- Did not change `CHMTouchBackend`, IOKit constructor ABI, UIKit `sendEvent:` delivery, DOWN/UP safety handling, or the original `Cham.dylib`.

### Source commits

- Scheduler header: `95da3549707e27853a87f339c9419ef1978ad1c0`
- Scheduler implementation: `ab06cf968ae8fa2c506064f5608919ce57efd108`
- Overlay redesign and persistence: `1d5385225a6052dba47610a0abb3aaa34efce9f3`
- Preserve existing defaults before the panel is first opened: `276e0d3e5b58b397c46f2f94365b3a884d2e7392`
- Remove unused UIKit scheduler import: `4f0b7e125b1fcc7bdaf15a44ba297ca83679450d`
- Adjust press-duration value label spacing: `04873c5bc090116bce4ba14002e8b96b93119ca7`
- Preserve pre-panel settings defaults: `276e0d3e5b58b397c46f2f94365b3a884d2e7392`
- Makefile OCR removal: `b4b79feda2936067bb1d5324fd007b68a63f7d74`
- README scope update: `5d0e831e89192deeb3bf02f255e3eab8b59704c9`
- Delete unused OCR matcher header: `958535503f6b5d11ee00fe7a90ec12db061b8f17`
- Delete unused OCR matcher implementation: `05f5c662b2136345f118f81633219acd95da09bf`

### Validation boundary

- Changes were committed directly to `main`; no branch was created.
- No build, GitHub Actions, Codemagic, Theos compile, or device test was run.
- Static source review still needs a final pass for references to removed OCR/mode symbols and persistence paths.
- User must build this revision and test: POINT click, STOP/release, saved coordinates and point list after closing/reopening the panel, and settings after terminating/relaunching the app.
- Do not mark the refreshed UI/persistence as device-verified until the user confirms it.
- The previous confirmed working touch baseline remains `398054e`; if POINT stops working, compare the backend against that exact baseline before changing touch logic.

### Final static verification after cleanup

- Re-fetched the updated source from `main`.
- Confirmed no legacy mode enum/branch names remain in the active scheduler, overlay, or touch backend source.
- Confirmed the mode picker and OCR source references are absent; both OCR matcher files are deleted and the Makefile no longer compiles them.
- Confirmed the settings store covers point coordinates/list, interval, press duration, floating-handle position, panel position, and panel scale.
- Confirmed balanced Objective-C delimiters in the rewritten scheduler header/implementation and overlay source.
- Confirmed `Cham/CHMTouchBackend.m` is byte-for-byte represented by the same Git blob SHA as the known-good touch backend (`51fd6a2ad99d57a1f896b8c4c32dad0666a9fd29`); the IOKit constructor and UIKit `sendEvent:` path remain present.
- These are static checks only, not a compiler result. Build and relaunch persistence remain pending user validation.
