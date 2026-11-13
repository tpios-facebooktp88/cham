# Cham AutoClicker — Checkpoint

Updated: 2026-11-13
Repository: `tpios-facebooktp88/cham`
Branch: `main` only

## Scope
POINT-only auto-clicker for TrollStore + TrollFools. No alternate tap modes, recorder, or OCR implementation is in scope.

## Confirmed baseline
- User previously confirmed that POINT tapping produces a real click on-device.
- Known-good touch backend: `Cham/CHMTouchBackend.m`, blob SHA `51fd6a2ad99d57a1f896b8c4c32dad0666a9fd29`.
- Keep the IOKit digitizer ABI, UIKit `sendEvent:` delivery, and DOWN/UP safety behavior unchanged.
- Original `Cham.dylib` remains untouched.

## Current implementation on main
- `CHMTapScheduler` contains only sequential POINT DOWN → press duration → UP → interval.
- Multiple POINT coordinates remain supported.
- `CHMOverlay` has the refreshed compact panel and saves coordinates, points, interval, press duration, handle position, panel position, and scale through `NSUserDefaults`.
- Unused OCR matcher files and legacy tap-mode code have been removed.
- Explicit `dispatch/dispatch.h` import added to the scheduler.

## Recent cleanup commits
- Scheduler dispatch import: `82ba1b84339a03e87ae6636add15e359fc1397dd`
- Remove completed REA workflow: `1a23ee31960d099d8a1e8638594286bbe6a11289`
- Remove REA runner: `fac61ad576f2d0f6e17615962122f29e8dfbb682`
- Remove REA report: `e27ef9a37d4efaf51f926bf933377bae25d6dd10`

## Validation
- Source was re-fetched from `main` after edits.
- The known-good touch backend was not modified.
- No build, GitHub Actions run, Codemagic build, or device test was started by the assistant.
- The POINT-only scheduler, persistence, and UI changes still require a successful user build and device test.
- If the build still fails, use the first actual compiler error from the build log; do not guess at further changes.

## Workflow rules
- Work on `main` only. Never create a branch.
- Inspect current source and repository status before every edit.
- Keep changes minimal and avoid new dependencies.
- Do not run builds or GitHub Actions without explicit user permission.
