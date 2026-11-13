# REA Reverse-Engineering Baseline — Original Cham.dylib

Date: 2026-11-13  
Repository: `tpios-facebooktp88/cham`  
Branch: `main`  
Source binary: `Cham.dylib`

## Purpose and evidence rules

This document preserves the part of the REA/Ghidra research that has completed successfully. It is a baseline, not a completed reverse-engineering report. Keep three evidence classes separate:

- **Verified:** directly returned by a successful REA/Ghidra run or independently checked against the original file.
- **Lead:** a selector/string address that helps locate Objective-C metadata; it is not a code address or method implementation.
- **Open:** requires cross-references, method metadata resolution, decompilation, or runtime validation.

Do not edit or replace the original `Cham.dylib` during analysis. The workflow verifies its SHA-256 and creates a temporary arm64 slice for Ghidra.

## Successful run #2 — environment and inventory

- GitHub Actions run: [#2](https://github.com/tpios-facebooktp88/cham/actions/runs/43386452967)
- Commit analyzed: `c2c01839b632c9b1d38ac1fa01dd65c1c835cdaa`
- Result: **success**
- Artifact: `Cham-REA-Research-2` (temporary Actions artifact; expires 2026-11-27)
- Artifact SHA-256: `d4d8c545f46210b0a2853d24e81bd3b9f5478d64c5c1c3f393c1718c2a8e3276`

### Original binary integrity

- Original size: `472048` bytes
- Original SHA-256: `bfeeced4b8d57d8f384fbe539fa2c575b98405172d4f32655ce79bd4ef1c4fdd`
- Architecture: universal Mach-O (arm64 + arm64e)
- Analysis slice: arm64
- Thin slice size: `226288` bytes
- Thin slice SHA-256: `2fe3e601883f42ba5ff0975323fcaf6e042c6f5c17b1f5a9c53b637a978b414d`

The original binary's hash matched the expected hash before analysis. The temporary thin slice was created under the runner's temporary directory; the checked-in original was not modified.

### Toolchain verified

| Component | Observed version/status |
|---|---|
| REA CLI | 6.9.0 |
| Node.js | v24.22.1 |
| Java | OpenJDK 25.0.5 |
| Ghidra provider | Ghidra 12.2 |
| REA doctor | all required Ghidra checks passed |

The workflow installed the official Ghidra release and verified its SHA-256 before use.

### Inventory result

- Procedures/functions inventoried: **736**
- Segments: **33**
- Defined strings: **1,171**
- Ghidra auto-analysis completed before REA exposed the inventory.
- Inventory scope is the provider's discovered inventory. REA explicitly reports discovery coverage as unknown; these counts do not prove that every function or every packed/undefined string was discovered.

## Selector/string leads found

The following are **addresses of Objective-C selector strings in the arm64 analysis image**, not function entry points or IMP addresses.

| Feature lead | Selector string address |
|---|---:|
| Fake touch base selector | `0x297f3` |
| Fake touch with `preferSystem:` | `0x28baf` |
| Normal tap | `0x28e07` |
| Double tap | `0x28ae1` |
| Extreme burst | `0x28b08` |
| Ultra tap | `0x291ad` |
| Smart tap | `0x2a575` |

The fake-touch search also found the selector string `fakeTouchId:AtScreenPoint:inWindow:withTouchPhase:force:radius:` at `0x28ee1`.

These hits establish that the strings are present in the defined-string inventory. They do **not** establish method ownership, implementation address, call direction, argument semantics, or runtime behavior.

## Completed work

- [x] Confirmed the original binary's identity using SHA-256.
- [x] Resolved the universal-binary provider limitation by analyzing only a temporary arm64 slice.
- [x] Installed and checked the REA/Ghidra toolchain.
- [x] Completed Ghidra auto-analysis and retrieved the binary inventory.
- [x] Located the initial Tap/HID selector-string leads.
- [x] Saved the successful baseline artifact and recorded its identity above.

## Work that remains — do not mark complete yet

### Phase A — resolve Objective-C references (next run)

The latest workflow revision on `main` adds the following commands:

- `rea xrefs` for each of the seven selector-string addresses above.
- `rea trace` for the fake-touch selector and smart-tap selector.

This revision is committed as `75e51efe0f58133a5718f43f1df91c83678d95f5`, but **has not yet been run**. Its output is required before selecting any method implementation addresses.

### Phase B — method implementation and pseudocode

After Phase A returns references that can be tied to Objective-C method metadata:

1. Identify the owning class and exact method-list entry for each selector.
2. Resolve each method's IMP/code address from the metadata; do not treat the selector-string address as an IMP.
3. Run `rea function` on the resolved procedure and save the function dossier.
4. Run `rea decompile` on each resolved code address and preserve the pseudocode.
5. Follow incoming/outgoing references and build a call graph around the fake-touch/HID path.
6. Record confidence and unresolved branches for every conclusion.

### Phase C — feature coverage

After the shared touch primitive is understood, trace in this order:

1. Touch/HID construction and dispatch.
2. POINT / normal tap and DOUBLE.
3. HOLD and phase transitions.
4. HUMAN timing behavior.
5. EXTREME and ULTRA scheduling/burst behavior.
6. Multi-point / touch-ID behavior.
7. Touch Recorder capture, persistence, and replay.
8. OCR/Vision and overlay/preferences only after the core path is mapped.

### Phase D — runtime validation

Static pseudocode is not proof of successful touch delivery. Any device-level conclusion must be separately validated on the intended iOS version and reported as runtime evidence.

## Workflow and preservation policy

- Research workflow: `.github/workflows/rea-research.yml`
- It is manual-only (`workflow_dispatch`) and does not build the tweak.
- It verifies the original binary hash and analyzes a temporary arm64 slice.
- Research outputs are saved as Actions artifacts. The latest workflow revision extends the analysis with xrefs and traces.
- The successful baseline artifact is time-limited by GitHub Actions retention. This Markdown document is the durable repository record; retain/download the raw JSON artifact separately if the raw evidence is needed later.
- Do not run the separate Theos build workflow as part of REA research.
- Work on `main` only. Do not create branches.
- No source implementation changes are authorized by this research record.

## Acceptance criteria

A phase is complete only when its output has been retrieved, inspected, and recorded here. A successful workflow run alone does not mean the methods have been reconstructed. Do not mark Tap/HID reverse engineering complete until method IMPs, decompilation, and a defensible call graph are available.


## Successful run #3 — selector cross-references and trace

- GitHub Actions run: [#3](https://github.com/tpios-facebooktp88/cham/actions/runs/43387946159)
- Analyzed commit: `58ee892a312160944ce1cfe4f6cc17719fc9480d`
- Result: **success**; elapsed approximately 12 minutes 29 seconds.
- Artifact: `Cham-REA-Research-3`, 45,737 bytes, retained until 2027-02-11.
- Artifact SHA-256: `b231032b5bd84bca65efcc7a7929f25fe585707ab99aafcb63759615ee15c670`.
- Original-binary hash verification and Ghidra setup passed again. All stderr logs in this run were empty.

### New reference evidence

The REA trace resolved references from selector strings to containing Ghidra procedures. The following procedure entries were directly reported in the trace output:

| Procedure entry | Procedure name | Evidence / role |
|---|---|---|
| `0x9a5c` | `ACPT_8c93f1::fakeTouchId:AtScreenPoint:inWindow:withTouchPhase:` | Fake-touch screen-point wrapper |
| `0x9a74` | `ACPT_8c93f1::fakeTouchId:AtScreenPoint:inWindow:withTouchPhase:preferSystem:` | Fake-touch variant with preferSystem |
| `0x9a8c` | `ACPT_8c93f1::fakeTouchId:AtScreenPoint:inWindow:withTouchPhase:force:radius:` | Fake-touch variant with force/radius |
| `0xba18` | `ACPS_71d2c4::_normalTapAt:inWindow:duration:` | Normal tap implementation |
| `0xbdc4` | `ACPS_71d2c4::_doubleTapAt:inWindow:` | Double tap implementation |
| `0xcecc` | `ACPS_71d2c4::smartTapAtScreenPoint:` | Smart tap implementation |

These are Ghidra function/procedure entries reported by the containing-procedure evidence for references to the selector strings. They are substantially stronger than selector-string addresses. However, their method ownership and runtime semantics should still be checked against the decompiled body and Objective-C metadata before treating every label as a fully proven method implementation.

### Additional xref observations

- Selector string `0x297f3` (base fake-touch selector) had references from procedures including `0xba18` (normal tap), `0xbdc4` (double tap), and `0xcecc` (smart tap), plus several additional procedures at `0xbbec`, `0xbc90`, `0xbf34`, `0xc02c`, `0xc18c`, `0xc490`, `0xc628`, and `0xd028`.
- Selector string `0x28baf` (preferSystem variant) was referenced from `0xb608`, named `ACPS_71d2c4::_instantTapAt:inWindow:preferSystem:`.
- Selector string `0x28e07` (normal tap) had references from procedures `0xc444` and `0xc944`, in addition to metadata reference `0x30d40`.
- Selector string `0x28ae1` (double tap) had references from `0xc96c` and metadata reference `0x30d20`.
- Selector string `0x28b08` (extreme burst) had references from `0xc99c` and metadata reference `0x30d28`.
- Selector string `0x291ad` (ultra tap) had references from `0xc990` and metadata reference `0x30d50`.
- Smart tap selector string `0x2a575` was referenced from `0x104b0`, contained in procedure `0x1044c` (`FUN_0001044c`); the trace also identifies `0xcecc` as the smartTap method symbol/procedure.
- Both trace outputs reported `truncated: false` and no residual unknowns in their normalized result. This does not guarantee global reference completeness; REA explicitly limits each query to the matched start addresses and reports that empty/truncated-false output alone is not proof of complete coverage.

### Next phase prepared

The research workflow has now been updated on `main` at commit `05d14158e9aaf5a7484a046fe19b8e6fdbbf8245`. The next manual run adds REA function dossiers and pseudocode decompilation for these six key procedure entries:

- `0x9a5c`, `0x9a74`, `0x9a8c` — fake-touch wrappers
- `0xba18` — normal tap
- `0xbdc4` — double tap
- `0xcecc` — smart tap

This next run has **not yet been dispatched**. It will produce one function dossier and one decompilation JSON per address. Do not start Theos/Codemagic build workflows during this analysis.


## Workflow optimization — one persistent REA session

- Research runner: `scripts/rea-research-batch.mjs`
- Workflow: `.github/workflows/rea-research.yml`
- Runner commit: `0bdf4172bc30fb36e1cc27b93dc7430e1703ebc5`
- Workflow commit: `0220e6d11ab9f19f3079866914b5e34a2b36eefc`
- Branch: `main`
- Status: committed; **not yet executed or runtime-validated**.

The earlier workflow used separate one-shot REA CLI invocations for inventory, searches, xrefs, traces, function dossiers and decompilation. REA documents that each CLI invocation is a separate process. The revised runner starts one REA MCP stdio server, opens the temporary arm64 slice once, waits for the Ghidra-backed overview, and submits all six known procedure entries to one `batch_decompile` call in the same persistent session.

The new batch targets are `0x9a5c`, `0x9a74`, `0x9a8c`, `0xba18`, `0xbdc4`, and `0xcecc`. The previous run #3 xrefs and traces remain the source for selecting these addresses; they are no longer recomputed in this focused follow-up. The batch output, tool catalog, overview and environment report are uploaded together as one Actions artifact.

This reduces repeated provider startup/auto-analysis. It does not guarantee a specific wall-clock duration; Ghidra's first import and auto-analysis still occur once, and the batch decompilation itself may take time. The original `Cham.dylib` remains hash-verified and untouched. No Theos or Codemagic build is part of this workflow.


## REA run #4 — persistent MCP batch decompilation

- Run ID: `43390728802` (run #4), job ID `131769704896`
- Commit analyzed: `7000ee5ed9b20950327585bf0a419446167b502f`
- Result: success; elapsed about 1m48s (08:07:16Z–08:09:04Z)
- Artifact: `Cham-REA-Research-4`, ID `14020935714`, 953,308 bytes, SHA-256 `7f307e7052b4196ca684694a54f0ff7073350b14ef4d1d0d6df1ecc30249bc7a`, expires 2027-02-11.
- All 11 workflow steps succeeded, including original-binary hash verification, Ghidra readiness, REA analysis and artifact upload.
- Original universal binary was not modified. The analyzed arm64 slice hash matches the prior verified slice: `2fe3e601883f42ba5ff0975323fcaf6e042c6f5c17b1f5a9c53b637a978b414d`.
- Binary overview: 736 procedures, 1,171 defined strings, 33 segments; discovery coverage remains unknown.
- Batch decompile: 6/6 succeeded for `0x9a5c`, `0x9a74`, `0x9a8c`, `0xba18`, `0xbdc4`, `0xcecc`.
- The batch was submitted through one persistent REA MCP stdio connection. The MCP catalog was saved in the artifact for reproducibility.
- Timing improvement: prior run #3 took about 12m29s; run #4 took about 1m48s. This is one observed run, not a guaranteed duration for future or deeper analysis.

### Touch primitive — confirmed static observations

**Core procedure: `0x9a8c` — `fakeTouchId:AtScreenPoint:inWindow:withTouchPhase:force:radius:`**

Ghidra pseudocode shows this routine:
1. Resolves a touch identifier, allocating/looking up an available point ID when needed.
2. Converts the supplied point from the given window and checks it against the window bounds; an out-of-bounds point returns a negative result.
3. Stores/reuses `UITouch` objects in a static `NSMutableDictionary` keyed by point ID.
4. Updates touch state through helper `FUN_0000a464`.
5. Obtains `UIApplication.sharedApplication` and probes private selectors dynamically using `NSSelectorFromString` and `respondsToSelector:`, including `_touchesEvent`, `_clearTouches`, `_setHidEvent_`, `_setHIDEvent_`, `_setTimestamp_`, and `_addTouch:forDelayedDelivery:`.
6. Creates/obtains a HID event through `FUN_0000a9d8`, attaches it to the touch/application event where the selectors are available, assigns a system-uptime timestamp, and releases the event with `CFRelease`.
7. Iterates the tracked touches and adds them for delayed delivery, then calls `UIApplication.sendEvent:`.
8. Removes touch objects for terminal phases (phase values 3/4 in the decompiler's observed branch) or updates a retained touch; finally performs `hitTest:withEvent:`.
9. Uses `FUN_0000a28c` as an alternate/system-touch path. The exact behavior of that helper is not yet decompiled.

These observations establish use of UIKit `UITouch` plus dynamically resolved private UIApplication selectors and an HID-event helper. They do **not** yet establish the complete HID event structure, the exact meaning of every phase value, runtime acceptance by iOS, or which branch is taken on a particular device/OS version.

**Wrappers**
- `0x9a5c`: delegates to the core routine with fixed force `0.5` and radius `0.04`.
- `0x9a74`: also delegates with `0.5` and `0.04`; its decompiled `preferSystem` parameter is not visibly consumed in this wrapper. Verify the Objective-C ABI/selector and callers before concluding the flag is ignored globally.

**Tap modes**
- `0xba18` normal tap: enables the touch subsystem, injects phase 0 through the core fake-touch routine, then schedules delayed blocks. Duration is clamped to at least 0.0001 seconds. When state `DAT_00031c30 == 2`, an additional callback is scheduled at 30% of the duration; the final callback is scheduled at the full duration.
- `0xbdc4` double tap: begins with phase 0, reads a configured delay `DAT_00031ad8` (minimum 0.0001), obtains another timing value through `FUN_00008238` (minimum 0.0005 and capped by the observed `fmin` constant), then schedules `FUN_0000bf34`. The exact phase sequence is in the callback and remains to be decompiled.
- `0xcecc` smart tap: runs only when the busy flag `DAT_00031be1` is clear, `FUN_00005f30()` succeeds, and `targetApplicationWindow` returns a window. It sets the busy flag, enables the touch subsystem, sends phase 0, then schedules `FUN_0000d028` after `DAT_00031ad8` (minimum 0.0001). Failure resets the touch subsystem and busy flag.

### Next focused batch

Decompile the helper/callback procedures in one REA MCP batch, using addresses grounded by the current pseudocode and earlier trace:
`0x0a28c`, `0x0a464`, `0x0a9d8`, `0xbbec`, `0xbc90`, `0xbf34`, `0xd028`, plus `0x09698`, `0x093b8`, `0x08238`, `0x05f30` if confirmed as procedure entries by REA's resolver. Focus first on touch phase transitions, HID event construction, and release/cleanup callbacks. Do not infer runtime behavior without device testing.


## Next batch prepared — Touch/HID helpers and completion callbacks

- Script update commit: `7001975b5c74b9821a3657ae6af33e9026a43243`
- Branch: `main`
- The persistent MCP runner now submits these 11 candidate procedure entries in one `batch_decompile` request:
  - `0xa28c` — alternate/system-touch path called by the core fake-touch routine.
  - `0xa464` — touch-state update helper.
  - `0xa9d8` — HID-event construction/creation helper.
  - `0xbbec`, `0xbc90` — normal-tap delayed callbacks.
  - `0xbf34` — double-tap delayed callback.
  - `0xd028` — smart-tap delayed callback.
  - `0x9698`, `0x93b8` — core routine's touch/window-related helper calls.
  - `0x8238` — timing helper used by double tap.
  - `0x5f30` — smart-tap eligibility helper.
- These are candidate addresses inferred from direct call targets in the successful run #4 pseudocode. REA must resolve each address as a procedure; unresolved/non-entry addresses will be recorded as such rather than assumed to be functions.
- This batch has been prepared but not yet run. It continues to use one persistent REA MCP session and does not alter the original binary or build the tweak.


## Final consolidated research run — only one more Actions execution

The user requested that the remaining research be consolidated and that Actions be run only one more time. The workflow and runner are now prepared for that single final pass.

- Runner commit: `944f4128b06fc8c4d5a7f49508cc2a7d466ca0f1`
- Workflow comment update: `fe80c58df9e13d719c403a45f9299d66477ad750`
- Branch: `main`
- This is **one manual GitHub Actions workflow run**, not one run per feature.
- The runner opens the arm64 image once in one persistent REA MCP/Ghidra session.
- It performs one discovery pass for: `record`, `replay`, `OCR`, `Vision`, `HUMAN`, `EXTREME`, `ULTRA`, `HOLD`, `multiTouch`, `fakeTouch`, `normalTap`, `doubleTap`, and `smartTap`.
- For every feature query, it saves the trace and collects matched procedure entries plus procedures containing references to matched strings.
- It combines those dynamically discovered procedures with the known Touch/HID helpers, Tap entry points and callbacks, then submits **one** `batch_decompile` request (maximum 160 procedure addresses).
- Expected artifact includes every individual feature trace, one consolidated decompile result, the tool catalog, binary overview, environment and a summary of discovered/decompiled targets.
- The batch is prepared but **has not been run yet**. The user must manually click Run workflow once.
- After this run, do not request another Actions execution for routine follow-up. Analyze the saved artifact and record any gaps as limitations. Only ask for another run if the final artifact is corrupt or the workflow itself fails, and explain why first.

Scope of this final static pass: Touch/HID, known Tap modes and callbacks, Recorder/Replay string-reference discovery, and OCR/Vision string-reference discovery. A successful static pass does not establish device runtime behavior; runtime validation remains a separate evidence class and is not part of this Actions run.


## REA run #5 — final consolidated static research pass

- GitHub Actions run: [#5](https://github.com/tpios-facebooktp88/cham/actions/runs/43392892934)
- Run ID: `43392892934`; job ID: `131776810201`
- Analyzed commit: `6bce0a9e53c0534dd5d9a2d11e11b2db1c895e47`
- Result: **success**; all 15 job steps succeeded.
- Artifact: `Cham-REA-Research-5`, ID `14020929507`, 1,099,999 bytes; SHA-256 `b3bc3c2b89252217b260a42549284c0634d95fa619643667a463aa7b52d8083f`; expires 2027-02-11.
- The artifact was downloaded and inspected. It contains the binary overview, environment, 13 feature trace JSON files, the consolidated decompilation result, REA tool catalog and final summary.
- Original `Cham.dylib`: 472,048 bytes; SHA-256 again matched `bfeeced4b8d57d8f384fbe539fa2c575b98405172d4f32655ce79bd4ef1c4fdd`.
- Temporary arm64 analysis slice: 226,288 bytes; SHA-256 `2fe3e601883f42ba5ff0975323fcaf6e042c6f5c17b1f5a9c53b637a978b414d`.
- Toolchain: REA 6.9.0, Node v24.22.1, Temurin OpenJDK 25.0.5, Ghidra 12.2.
- One persistent REA MCP/Ghidra session was used. Thirteen feature traces completed, followed by one consolidated `batch_decompile` request for 73 procedure entries. Result: **73 succeeded, 0 failed**.
- This was static research only; no Theos, Codemagic or device build/runtime test was performed.

### Feature discovery coverage

| Query | Matched strings/procedures | References | New procedures collected | Notes |
|---|---:|---:|---:|---|
| `record` | 46 | 107 | 21 | Recorder UI/action handlers found |
| `replay` | 2 | 2 | 0 | Only help/description strings in this trace |
| `OCR` | 67 | 131 | 15 | Smart OCR settings, panel and ROI handlers |
| `Vision` | 1 | 1 | 1 | Vision framework path referenced by `0xec04` |
| `HUMAN` | 1 | 1 | 0 | Label string only |
| `EXTREME` | 3 | 5 | 2 | Method `0xb8b0` resolved |
| `ULTRA` | 3 | 5 | 1 | Method `0xb810` resolved |
| `HOLD` | 8 | 11 | 1 | Hold duration setting handler `0x15bd0` |
| `multiTouch` | 0 | 0 | 0 | No literal match for this query |
| `fakeTouch` | 8 | 50 | 3 | Touch wrappers and selector references |
| `normalTap` | 2 | 7 | 1 | Method `0xba18` resolved |
| `doubleTap` | 2 | 5 | 0 | Method `0xbdc4` already known |
| `smartTap` | 2 | 5 | 0 | Method `0xcecc` already known |

All trace queries reported `truncated: false` and no residual unknowns in their normalized query results. This means the individual REA query outputs were not marked truncated; it does **not** prove global binary coverage. References whose source addresses were not inside a Ghidra procedure remain unresolved by those traces.

### Touch/HID — new helper findings

**`0xa9d8` — HID event construction helper**

- Initializes its dynamic API bindings once through `dispatch_once`.
- If the required HID API binding is unavailable, returns no event.
- Uses `mach_absolute_time()` and the default CF allocator.
- Calls dynamically resolved function pointers to create two related HID objects; applies additional event fields/attributes through other resolved function pointers, then links the objects.
- Applies minimum force/radius-like numeric values of 0.01 where applicable; branches on the supplied phase-like parameter and sets different event type values (observed constants `0x24` / `0x27`).
- The pseudocode does not expose the resolved symbol names or establish the semantic meaning of every numeric HID field. Do not infer undocumented constant meanings from the values alone.

**`0xa28c` — alternate/system HID delivery helper**

- Calls `0xa9d8` to construct the event.
- Optionally obtains a context identifier from the touch and calls a dynamically resolved function with the event/context.
- Checks whether UIApplication responds to private selector `_enqueueHIDEvent:`; if supported, invokes it.
- Also uses a dynamically resolved enqueue/delivery function and releases the event.
- Returns success only when the associated function pointer/context is available. This is a separate path from the main `sendEvent:` flow described under run #4.

**`0xa464` — UITouch state population**

- Hit-tests the supplied point in the target window; falls back to the root view/controller view when no hit view is found.
- Dynamically checks and sets private UITouch properties/selectors for window, view, gesture view, tap count, phase, timestamp, location in window, first-touch-for-view and tap status.
- Uses system uptime for the timestamp.
- This confirms the touch object is populated with view/window/phase/location metadata before delivery; it does not prove every private setter exists or behaves identically on every iOS version.

### Tap modes and scheduling

**`0xc75c` — `ACPS_71d2c4::performTap`**

The decompiled switch dispatches seven numeric modes:

- Case 0: normal tap using the configured base duration.
- Case 1: normal tap using `DAT_00031ae0`; the UI's `holdChanged:` handler stores the Hold slider value in this global and persists it. This links the Hold duration control to this path.
- Case 2: randomized tap path. It offsets X and Y independently by an integer in the range -5 through +5 and scales the base duration by a factor from 0.80 through 1.20. The visible `HUMAN` label is present in the binary, but this trace does not directly prove the UI enum-to-case mapping; therefore, do not label case 2 as HUMAN with full certainty.
- Case 3: double tap.
- Case 4: sequence of configured points.
- Case 5: ULTRA.
- Case 6: EXTREME burst.

Before dispatch, it checks enabled/busy state, stop state, eligibility and target window, then marks the tap operation busy and records a media-time timestamp. The mode-to-label mapping should still be checked against UI enum construction before implementation.

**Sequence — `0xc444` / `0xc2b0`**

- Copies the configured point sequence.
- If empty, falls back to a normal tap at the default tap screen point.
- Otherwise schedules each point on the main queue with `dispatch_after`.
- The per-point interval is bounded by the configured duration plus 0.0001 seconds and the value returned by `0x8238`.
- Callback `0xc490` performs each scheduled point; its full behavior is in the artifact pseudocode.

**ULTRA — `0xb810`**

- Enables the touch subsystem, gets the next configured point, performs an instant touch using the fake-touch `preferSystem:` path, and calls the fast-batch completion helper.
- This method body performs one instant tap per invocation; any repeated cadence is controlled by its caller/scheduler, not a loop in this method.

**EXTREME — `0xb8b0`**

- Enables the touch subsystem and selects a burst count using the timing value from `0x8238`: 1, 2, 3 or 4 depending on observed timing thresholds (0.003, 0.008 and 0.02 seconds).
- Caps the burst by the remaining configured tap count when a limit exists.
- Repeatedly obtains the next tap point and calls the instant-tap path while eligibility, enabled state and tap-count conditions remain satisfied.
- Calls the fast-batch completion helper with the prior count.

**Completion callbacks**

- `0xbbec` adds independent random X/Y offsets from -1.0 to +1.0 points to the intermediate touch position and sends phase value 1.
- `0xbc90` sends terminal phase value 3, disables the touch subsystem, clears the busy state, updates count/state and stops when the configured count is reached.
- `0xbf34` sends a terminal phase, then schedules `0xc02c` after a stored delay.
- `0xc02c` sends a new begin phase (value 0); on success schedules `0xc18c`. The callback chain continues the double-tap sequence and releases state on failure/completion.
- `0xd028` sends terminal phase value 3, increments the count, disables the touch subsystem, clears busy state and updates the UI state.
- Phase numbers above are the literal values passed by the decompiled code. Their UIKit enum interpretation is consistent with the observed flow but should be runtime-validated on target iOS.

### Recorder — what is established and what remains open

The binary contains a dedicated Recorder panel and handlers:

- Persistent setting keys include `recorderSpeed`, `recorderLoops`, and `recorderEventFile`; the named file is `acp_recording.bin`.
- UI strings describe recording touches/swipes and replaying them.
- Decompiled handlers include record, stop, play, clear, speed, loop, floating stop button and panel open/close.
- `recorderRecordFromMenu` calls internal routines at `0xe0c0` and `0x119d8`, then hides the main menu and shows a floating stop button.
- `recorderStopFromMenu` calls `0x11854` and `0x11b4c`, hides the floating stop button and reopens the Recorder panel.
- `recorderPlayFromMenu` calls `0xe0c0` and `0x124b4`.
- `recorderClearFromMenu` calls `0x12b04`.
- Speed is clamped to the observed range 0.25–100.0 and persisted.
- Loop control uses 0 for no repeat, finite positive values, and 51 as a special sentinel value in the handler. Its exact user-facing meaning should be confirmed in the playback core.

**Important limitation:** the internal Recorder core routines above were identified as direct calls but were not included in the 73-address decompile batch. The artifact therefore proves the UI wiring, setting names, file name and call targets, but does not yet establish the binary event schema, how touches are captured, exact persistence/write behavior, replay timing/scaling, loop termination or cleanup. Do not implement the Recorder from UI strings alone.

### OCR/Vision — what is established and what remains open

- Smart OCR settings include `smartOCRText`, `smartOCRInterval`, `smartOCRCooldown`, `smartOCRMatchMode`, and ROI preferences `smartOCRROIX/Y/W/H` plus `smartOCRROIEnabled`.
- Decompiled methods cover Smart OCR panel construction/open/close, text and match-mode controls, cooldown control, enable toggle, ROI preference save/load/reset, ROI editor display/hide, overlay update and drag/pan handlers.
- The Vision framework path `/System/Library/Frameworks/Vision.framework/Vision` is referenced by `0xec04`, whose decompiled body calls `dlopen` on that path.
- The default ROI reset routine constructs a centered rectangle with 60% of screen width and 30% of screen height. ROI editing enforces a minimum observed width/height of 40 points.
- The OCR trace did not resolve a decompiled Vision request/recognition/matching engine. The 73-function batch includes extensive OCR UI/ROI code, not proof of the full OCR processing pipeline, text matching algorithm, scan interval execution or result-to-touch dispatch.

### Final assessment and next engineering gate

- **Touch/HID construction and dispatch:** strong static evidence for the UITouch + HID event paths; no device runtime proof.
- **POINT / DOUBLE / Hold-duration path / sequence / ULTRA / EXTREME:** entry points and major scheduling logic decompiled; HUMAN label-to-case mapping remains unproven.
- **Recorder:** UI and settings are understood at a high level; capture/storage/replay core remains open.
- **OCR:** Smart OCR controls and ROI management are understood; recognition and matching core remains open.
- **Multi-touch:** no literal `multiTouch` match in the final trace. The fake-touch APIs accept a touch identifier and maintain a dictionary of touch objects, but this alone does not prove the complete multi-point feature behavior.
- **Runtime validation:** not performed. Static decompilation cannot prove successful injection, HID acceptance, touch delivery, Recorder fidelity or Vision behavior on iOS 16.

This is the final planned Actions run. Use the downloaded `Cham-REA-Research-5` artifact and this report for further static review and implementation planning; do not schedule additional Actions runs for ordinary follow-up. If an engineering decision depends on one of the explicitly open core routines, first assess whether it can be answered from the existing artifact/repository before requesting any new execution.
