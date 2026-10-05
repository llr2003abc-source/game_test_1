# Phase 9.1 Drag UX implementation plan and ledger

Spec: C:/Users/疯狂/.codex/attachments/c9aece75-478a-4e1e-8fbc-4c5d7fb76c09/貼上的文字.txt (63 sections).

Scope: UI scripts/new UI-only helpers and tests. Protect all Gameplay/Grid/Transaction/resources/scenes/project settings and addons/godot_ai313 SHA256. No commit/push/tag. Current clean HEAD5876f36.

Ruling: explicit complete spec authorizes inline execution; no additional design approval. Use current Editor checkout, preserving all uncommitted changes, no Git integration. Cost if revised: reversible local edits only.
Ruling: floor maps ghost top-left to raw cell; normalized grab coordinates map to the rotated rectangle. Raw valid always wins; only invalid raw searches8neighbors with inclusive16px Euclidean distance. Stable row-major ties. Cost: exact-edge misalignment may choose adjacent legal raw cell instead of snapping, as requested.
Ruling: preserve explicit-cell UI transaction helpers for existing Phase9 tests; native mouse drop uses one displayed candidate. No changes to old assertions/results. Cost: direct callers must distinguish cell-based APIs from pointer resolver.
Ruling: DragSurface handles pointer just outside a grid; target detection scans12grid/6slot rectangles only, snap searches one local3x3 neighborhood. No full-placement global search.

Shared interfaces: context holds original Item/source/rotation/normalized grab; resolver reads only can_place and compatibility; UI reads candidate to draw and passes it to unchanged transactions. Ghost/placement overlay ignore pointer; Native drag-end cancels visuals/data context. Transaction-caused UI refresh deferred until drag end.

Review Focus:
1. Pointer offset, negative floor and rotation cannot change real placement before commit.
2. Native preview and drop commit identical candidate; special targets override placement and correctly reject incompatible/full ammo targets.
3. Snap bounded16px/3x3, nearest stable, cannot cross individual Rig grids or ignore rotated size/occupancy.
4. Ghost and overlay ignore input; ESC/Tab/data refresh leaves no ghost, invalid source dim or stale candidate.
5. All1747 old expectations unchanged; Gameplay72 protected hashes and addon313 unchanged; final Editor warnings checked in addition to CLI parsers.

- [x] 1. Baseline1747 and root-cause/source/hash audit.
- [x] 2. RED pure context/resolver tests; implement UI-only context and resolver; GREEN.
- [x] 3. RED ghost/footprint/native tests; UI integration, source dim, preview/commit/cancel; GREEN.
- [x] 4. Full1747 regression/new suites/parsers/hashes; MCP actual native grabs/rotation/snap/special targets.
- [x] 5. One fresh read-only review, important fixes RED->GREEN, final verification/report.

Evidence directory: %TEMP%/codex-fps-phase9_1-audit. Before edits: existing GridView casts mouse cell directly; begin_drag only item/rotation; preview root anchored at pointer with no offset. MCP4.7.2 Test_1 connected, main stopped.

Task 1: complete — baseline18 legacy suites1449 +14 Phase9 suites298 =1747 PASS,0 failures/errors/warnings. Task 2: complete — missing-helper RED2; context/resolver GREEN70. Task 3: complete — missing-visual RED2; native visual/transaction GREEN68, includes real click capture, ghost offsets,16/17px bounds, gap parent drops and rotated commit. Godot4 Transform2D multiplication repaired during integration; no production suppression.

Task 4: complete — unchanged legacy1449 +Phase9 298 =1747; new70+68=138; total1885/1885,0 failures/errors/warnings. CLI --check-only80 scripts (48 production +32 test),0 issues. Protected72 and addon313 hashes unchanged. Main MCP actual clicks top/middle/bottom committed cell0,0 with offsets24,12/24,48/24,75; native8/16snap true,17false; nativeR weapon5x2→2x5→5x2 unchanged source, ESC cleanup; native LOAD17→30 loose60→47, native STACK27+20→47. Native diagnostic eval compilation/unguarded ended-drag probe errors were in ephemeral MCP expressions only, fixed automation and relaunched; current clean Main run10 logs0 warnings/errors.
Final review: one fresh read-only reviewer gpt-6-astra/high; no Critical/Minor/Declined items; P2 external inventory changes retained stale preview/ghost. Final: fixed external change notification — real native target occupancy/source ownership/ammo count tests RED75/4fail ->GREEN75/0fail. UI-only committing-drag notification scope keeps own drop deferred to native end, external changes cancel and refresh. New145,total1892; full suite rerunning. No re-review required; all old expectations unchanged. Preserve ledger/audit because user prohibits commits and history cannot archive implementation evidence.
Task 5: complete — final fix full suite1449+298+70+75=1892/1892 PASS,0 failures/errors/warnings. Final --check-only80/80. Main MCP final native3 grabs PASS; external transaction active-drag cancellation PASS preserving source and external result. Relaunched default Main run12: live, UI closed, mouse captured, player alive, no drag, originalRig0/1 restored; game output0errors/warnings, editor since_cursor12 no new entries. Final313addon/72protected unchanged; no commit/push/tag. Full30-point report docs/phase9_1_drag_ux_report.md.
