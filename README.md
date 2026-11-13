# Cham AutoClicker

Cham is a lightweight POINT-only iOS auto-clicker tweak for a jailbroken/TrollStore-style environment using TrollFools to load the tweak. It creates a floating control and sends touch DOWN/UP events at configured screen points.

> Scope is intentionally small: POINT tapping only. There is no OCR, recording, multi-mode tap engine, or alternate tap mode.

## What the tool does

- Displays a draggable floating **CHAM** handle and a compact control panel.
- Stores one or more POINT coordinates in the active app window's coordinate space.
- Runs the points in order, repeating from the first point after the last.
- Lets the user set the delay between taps and the duration of each touch.
- Allows marker dragging to reposition saved points.
- Saves settings locally with `NSUserDefaults`, so they survive closing/reopening the panel and relaunching the app.
- Stops when the host app becomes inactive and attempts to release any active touch.

## Controls

| Control | Meaning |
| --- | --- |
| **X / Y** | Window-local coordinate for the next point. |
| **ADD POINT** | Adds a point at the current X/Y values. |
| **Point marker** | Drag a numbered marker to move that saved point. |
| **CLEAR** | Removes all saved points. |
| **DELAY BETWEEN TAPS (SEC)** | Wait time after a touch is released before the next touch begins. For example, `0.5` means wait half a second. |
| **PRESS DURATION (MS)** | How long the finger remains DOWN before UP. It can be entered directly in the number field or adjusted with the slider. Range: `0.1–1000.0 ms`, displayed to 0.1 ms precision. |
| **START** | Starts the sequential POINT loop. If there are no saved points, the current X/Y coordinate is added automatically. |
| **STOP** | Stops the loop and attempts to send UP if a touch is still active. |
| **− / +** | Shrinks or enlarges the panel. |
| **×** | Closes the panel; it does not clear settings or stop the floating handle. |

### Timing example

With **PRESS DURATION = 60 ms** and **DELAY BETWEEN TAPS = 0.5 sec**:

1. Send touch DOWN.
2. Keep the touch down for 60 ms.
3. Send touch UP.
4. Wait 0.5 sec.
5. Start the next point.

So the approximate start-to-start period for one point is **0.56 sec**, excluding dispatch/OS scheduling overhead. The interval is therefore meaningful: it controls the pause *between* taps, not how long the finger is held down.

## Settings persistence

The settings dictionary is stored under `com.cham.autoclicker.settings.v1` in `NSUserDefaults`.

Persisted values:
- Current X/Y values and the ordered POINT list.
- Interval (seconds) and press duration (milliseconds).
- Floating handle position.
- Panel position and scale.

POINT coordinates are clamped to the current window bounds when restored or added. Panel and handle positions are saved as the user moves/resizes them.

## Architecture

| File | Responsibility |
| --- | --- |
| `Cham/Entry.xm` | Tweak entry point. Creates the overlay on the main queue after the host app starts. |
| `Cham/CHMOverlay.h/.m` | Floating handle, panel UI, coordinate markers, user input, settings persistence, and app-inactive stop handling. |
| `Cham/CHMTapScheduler.h/.m` | POINT sequence and timer: DOWN → press duration → UP → interval → next point. |
| `Cham/CHMTouchBackend.h/.m` | iOS touch event backend. Resolves IOKit HID symbols and dispatches the paired HID/UIKit touch events. |
| `Makefile` | Theos target, source list, architectures, and framework configuration. |
| `.github/workflows/build.yml` | Manually dispatched GitHub Actions build; compiles and uploads a versioned dylib artifact. |

### Touch lifecycle invariants

- A new DOWN is not sent while a previous touch remains active.
- UP uses the same retained `UITouch`, `UIWindow`, original target `UIView`, and context captured at DOWN. The original view may detach from the window during an app transition; this alone must not prevent the matching UP.
- UP must never be re-hit-tested against a replacement view. If the retained touch/window/view is missing or UP cannot be confirmed, the scheduler remains blocked from starting another DOWN.
- STOP and app-inactive handling attempt to release an active touch.
- The backend reports unavailable/error states rather than pretending a touch succeeded.

The HID/UIKit implementation uses private iOS APIs and dynamically resolved IOKit/BackBoard symbols. Compatibility depends on the target iOS version and runtime environment; a successful compile alone does not prove that touch injection works on-device.

### App-transition handling

Some apps replace or detach the view that received DOWN while transitioning between screens. Cham must still deliver UP through the original retained touch/window/view context; rejecting UP only because `originalView.window` is now `nil` can leave the contact active and stop the tap loop. The fix keeps the original target objects and removes only that invalid attachment check—it does not re-hit-test, synthesize a new target, or weaken the active-touch safety gate.

## Build

Requirements:
- macOS with Xcode command-line tools.
- Theos and an iOS SDK supported by the selected Theos setup.
- A signing/loading environment appropriate for the target device.

Build locally with Theos:

```sh
make clean all FINALPACKAGE=1
```

Or manually dispatch **Build Cham dylib** from the repository's GitHub Actions page. The workflow produces a versioned `Cham-XX.dylib` artifact. Do not trigger builds automatically; run only when intentionally requested.

## Validation status

- The user confirmed the tool runs smoothly in Lazada.
- After the detached-view UP fix, the user confirmed the tool also runs smoothly in Shopee, including continued taps rather than stopping after the first tap.
- The user confirmed a successful build after the scheduler compile fix; subsequent device testing validates actual touch behavior, not merely compilation.
- The original uploaded `Cham.dylib` is preserved unchanged and is not a build input.

## Project rules

- Work on `main` only; do not create branches.
- Inspect the current repository/source before every edit.
- Keep changes minimal and avoid unnecessary dependencies.
- Do not modify the verified touch backend ABI or DOWN/UP safety behavior without concrete test evidence.
- Do not run GitHub Actions or other builds without the user's explicit authorization.
