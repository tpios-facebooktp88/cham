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
