# Phase10.1 implementation plan and ledger

Goal: two equivalent long-gun slots, bounded placement previews, readonly pickup capacity and Hold-F vicinity management in existing UI.
Spec: C:/Users/疯狂/.codex/attachments/ffacbe81-41d1-4e17-b65a-2c9b21ce1400/貼上的文字.txt (A-AS), fully specified authorized implementation. Base0cf3d60 clean, editor4.7.2 Test_1 stopped. No commit/push/tag, no addon changes. Audit %TEMP%/codex-fps-phase10_1-audit.
Use writing-plans/executing-plans inline and TDD. Existing editor workspace retained as authorized; no isolated Editor copy. One final fresh read-only review required by executing-plans; fixes RED->GREEN and full suite, no re-review.

- [x] Baseline2168 and hash audit.
- [x] Task1: long-gun common fallback/data/UI names, roundtrip and input-switch tests RED->GREEN.
- [x] Task2: candidate/render bounds, 8/16/17 edges and Ghost tests RED->GREEN; old UX regression.
- [x] Task3: readonly PickupPreviewResult and explicit world grid/equipment/stack transactions RED->GREEN; auto Secure remains excluded, manual Secure allowed.
- [x] Task4: RefCounted InteractionInputResolver tap/hold/cancel tests RED->GREEN, Interactor .35 threshold and capacity/hold prompt.
- [x] Task5: Vicinity query (actor distance3m + World blockers), virtual first-fit layout, shared existing inventory UI/ghost/snap/transfers, event/interval refresh and deletion safety; tests RED->GREEN.
- [x] Task6: Main MCP full-inventory workflow and switch/bounds/hold checks, full2168+new, parsers/hashes/output, fresh review,35-point final report.

Interfaces: pickup plan -> readonly preview -> prompt; F resolver identity token -> Interactor revalidation -> UI.open_vicinity; world query -> virtual placements (no InventoryGrid ownership) -> shared UI drag candidate -> explicit WORLD transaction or inventory WORLD drop; refresh cancels external stale drags but defers own commit updates.
Pre-flight: explicit Secure is a separate manual entry, auto policy untouched. WORLD source UI drop cannot call ordinary move/equip or load_ammo because those reject WORLD; route through validated explicit methods. Nearby is NOT registered InventoryGrid. Preview still updates metadata while hiding invalid placement to preserve existing UX tests. Released input fixtures must change, not the pickup result expectations. New Weapon1 Slot2 compatibility means old bag-fallback fixtures must occupy both long-gun slots.
Ruling: implement the user's complete supplied design directly in the existing editor workspace, without additional approval/commits — all operations authorized and reversible; cost is local changes must be reverted if withdrawn.
Ruling: keep explicit allowed_equipment_slots restrictions, unify long-gun category fallback and set actual Weapon1 [0,1] — preserves authored restrictions and legacy custom fixtures; cost is other deliberately restricted definitions remain restricted until updated.
Ruling: preserve original2168 assertion counts and behaviors except input setup/placement fixtures explicitly superseded by new F release/Slot2 policy; document every old test edit — cost is baseline coverage compares equivalent scenarios rather than obsolete input semantics.

Review Focus:
1. WORLD identity and source scope/range/occlusion revalidation on drag commit; manual Secure vs automatic exclusion; partial merges and failure atomicity.
2. Hold target changes/deletion/ownership/UI/ESC/reload cancellation; no release pickup after hold/cancel; threshold boundary and echo.
3. Nearby display references never become registered inventory ownership, dynamic refresh/deletion while dragging and scroll coordinates.
4. Current Active Slot runtime binding after equipment move/drop/switch, chamber/magazine/mode preserved.
5. Preview footprint containment for every grid size/rotation/edge, legal snap vs hidden invalid, current candidate commit consistency and old UX tests.
Baseline2168 confirmed:1449+298+70+75+276 all0issues. Task1 RED slot2 rejection reproduced; common category fallback true and actualWeapon1 allowed[0,1], UI labels updated. Explicit authored restricted fixture remains valid.
Task1 GREEN15 rendered actual1/2 key with buffered input flush/time advance; Task2 RED31->GREEN99 plus original UX75; no clipping symptom fix, invalid placement hidden and renderer bounds enforced. Task3 RED missing3->GREEN17 readonly partial/lock/Secure/manual merge. Task4 pure resolver test RED missing1; production independent resolver/Interactor and readonly Chinese capacity prompt added.
Task4 GREEN26 pure +43 actual Interactor: threshold/tap/hold/echo and all eight real cancellation states. Task5 GREEN34 query/layout +30 native UI: partial WORLD merge/load, manual Secure, lock/deletion/duplicate protection, movement refresh and real scrolling. Native bounds102 passed. Old fixture edits: player_interaction press+release; pickup_placement_policy/world_runtime_persistence/world_loot_gameplay occupy both long-gun slots before bag/full assertions. Player interaction now rendered because headless cannot capture mouse. All107 scripts check-only0issues.
Task6 verification pre-review: original2168+374 new=2542,49runs,0issues; original legacy long-running3 initially hit artificial1200frame harness cutoff, rerun6000 completed to2542, no production errors. All107 parsers clean. Addon313unchanged and27protected weapon/combat/movement/acoustic scripts unchanged (PlayerInteractor intentionally edited). Main MCP verified full bag/hold/no-pick/highlight/two native inventory-world drops outside collider/one visual/native originalmag17 back tobag/exact displayed cell.
Final review: one fresh gpt-6-astra high read-only reviewer; two Important/P2, no Critical/Minor, Declined to judge empty. Both accepted. Safety test clean RED15/8fail -> GREEN15/0fail/0issues: wall-blocked Nearby drop rejected before transaction (existing Reload spatial helper unchanged); pending Nearby press records original placement and rejects replaced/moved identity before drag. Final full50runs pending. No re-review.

Final: fixed wall-through Nearby drop — vicinity_safety_test RED15/8fail -> GREEN15/0issues; full2557/2557,50runs. Main native drag blocked preserves equipment/active CH1 MAG29/worldcount; clear path then drops same runtime.
Final: fixed refreshed press dragging substituted/moved item — same safety RED->GREEN, full2557/2557; Main actual mouse-down on Ammo5, delete/refresh first-fit, motion correctly cancels before dragging weapon, same control/runtime preserved. No Minor/Declined to judge; exhaustive Rulings3 above. No re-review. All108 parsers clean. Task0-6 complete; report docs/phase10_1_report.md saved; HEAD0cf3d60/no commit/push/tag.
