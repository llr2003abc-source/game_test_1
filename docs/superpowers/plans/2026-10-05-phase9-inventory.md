# Phase 9 Inventory Implementation Plan

> Execute inline with executing-plans and TDD; one read-only final review. No commits/push/tag and no checkout change.

**Goal:** Implement the user's 180-section Phase 9 inventory/equipment/rig reload specification.
**Spec:** C:/Users/疯狂/.codex/attachments/320fe8ae-9a59-4196-9a47-1d90705caf01/貼上的文字.txt
**Architecture:** WeaponRuntime and MagazineInstance remain gameplay state owners. Registered containers/equipment/world references determine item location; transactions validate before mutation. Runtime completion is consumed by ReloadCoordinator. UI is a reader and transaction client.
**Tech:** Godot4.7.2, GDScript, base geometry, no extra plugins.

## Constraints and decisions
- Preserve 1449 baseline assertions except explicitly obsolete legacy spare source and single-R timing contracts; log any test fixture changes.
- Protect addons/godot_ai313 files, no injury/armor/projectile/acoustic production changes.
- Ruling: latest written user spec and explicit12-step execution order authorize implementation without another approval round; old shelved design is historical, superseded where inconsistent. Reversible uncommitted code is the cost if interpretation changes.
- Ruling: use current editor checkout and preserve unrelated assets/settings. No Git integration menu: user has already instructed keeping changes in place without commit/push/tag.
- Ruling: Rig external2x2 from the earlier draft; lock all inventory mutations during reload, as latest spec allows. No WeaponItemState, no granular locks.
- Initial loaded/rig magazines use existing Test Round; loose L2 ammo gets a separate resource. IDs link these without changing old ballistic/damage values.
- Grid placement is the sole position owner; location lookup scans registered grids/equipment/runtime magazine references/world records. Identity registry wraps each runtime once. No location mirror in UI or Weapon item.
- Legacy provider is explicit test compatibility only; inventory-managed main never generates or searches legacy spare arrays.

## Review Focus
1. Transactions cannot duplicate/drop a runtime on failed placement, split, rotate, equip, or ammo loading.
2. Rig free space is measured before selecting magazine removal; fragmented free cells do not make a1x2 slot.
3. Reload lock covers public Grid and Equipment mutations, and commit reconciles exact old/new runtime identities once.
4. UI drag preview never mutates production item rotation/location before drop; Tab cancels pending R and prevents ghost shots.
5. Unarmed/unequipped weapons cannot Fire/ADS/Reload, and re-equipping preserves Runtime state without generating ammo.

## Ordered tasks: each RED → implementation → related GREEN
- [x] 1. ItemDefinition/Instance/Placement/Grid/Transaction; inventory_grid_test + inventory_transaction_test.
- [x] 2. Four Rig grids, six pockets, backpack5x5/external3x4, secure3x3; container + secure tests.
- [x] 3. Equipment and actual WeaponRuntime ownership/binding; equipment + runtime persistence tests.
- [x] 4. Stable ammo/magazine/weapon compatibility IDs; compatibility tests.
- [x] 5. Ammo loading + stack/split conservation; compatibility/transaction tests.
- [x] 6. Rig-only ReloadCoordinator, lock and result consumption; rig_reload tests.
- [x] 7. Pure single/double R resolver at0.22s, echo/disable/cancel; resolver tests.
- [x] 8. Main formal loadout/HUD and legacy provider separation; all original weapon suites.
- [x] 9. Player1/2/3/4 input, active permissions and visual state; weapon_equipment tests.
- [x] 10. Inventory UI with real drag/drop/rotation/loading/split and input gating; UI tests.
- [x] 11. Minimal dropped item, geometry and non-blocking layer5; rig_reload/world persistence tests.
- [x] 12. Full old/new regression, all script parsers, MCP stopped save/main inputs/UI, addon hashes, independent review.

## Evidence
Audit directory: %TEMP%/codex-fps-phase9-audit. Initial HEAD19010d7, working tree clean. MCP4.3.0 session connected; project stopped before editing.
Baseline1449/1449,0issues. Steps1-3 RED missing required implementations then GREEN: Grid41, Transaction13, Containers27, Secure4, Equipment20, Runtime persistence9. A typed-array fixture assignment was corrected to append; no production workaround.
Steps4/5 compatibility IDs RED3 then loading API RED1, GREEN17. Step6 coordinator RED missing then GREEN45 including all unavailable candidate cases and tactical/drop/full-space matrix; replacement goes TRANSIT only after successful begin, public transactions locked. Step7 resolver RED missing then GREEN11 (single/double/echo/UI cancellation/30-60-120Hz).
Step8 main RED missing PlayerInventory then GREEN14. Default Main generates no legacy arrays. Explicit use_legacy_test_provider added to five old suites (and actor fixture) whose scope is pre-inventory weapon behavior, preserving all expected values. FPS single-R fixture waits14 physics ticks after R to reflect0.22s confirmation, without changing its expected Reload/Chamber/RPM results. Formal rig/equipment behavior has separate new tests.

Steps8-11 GREEN: related baseline281/2810issues after fixing idempotent legacy helper and Ready-owned R resolver; no stale spare clearing or orphan Nodes. Native drag cancellation RED1 -> GREEN19 UI assertions; preview uses viewport-native drag, R and Tab cancellation. Dropped9 preserves original wrapper/runtime/mixed A B A C refs, layer5 only. Edge34 includes rig source exclusions, pre-removal fragmented slots, empty/no-magazine reload, registry, secure stack/split/load conservation. Wrong-grid public mutators and malformed equipment runtimes RED5 -> GREEN34. Main gameplay24 covers actual key routing, injury2.7s, global lock, single/double R, visuals and original containers. Full old1449/1449, new287/287,74 script parsers0issues. One script check failure while new DroppedItem class had not been imported was fixed by editor filesystem scan, not changing production types.

MCP Main verification: actual Tab opens12grids/sixequipment; full opaque panel and ammo count line visible (quantity clipping RED -> GREEN21). One ephemeral inspector tried indexing equipment before UI was open, caused diagnostic EVAL_RUNTIME_ERROR and debugger stop; game restarted, inspector preconditions corrected. This was not production script error or native crash. Native mouse automation requires Window.grab_focus(), pointer warp and layout process-frame settlement; no addon changes. After focus, native ammo drop loaded3 (60->57,27->30), native R preview rotated actual weapon into backpack, executor unbound/HUD NO ACTIVE WEAPON/mesh hidden, native re-equip restored same Runtime30+1/reset rotation. Real key single R tactical and double R drop completed; one world original magazine,1availableRigmag. Latest game run r3388716-4 Output only info, no runtime errors. Main W/ADS/Jump/AUTO and world impacts exercised via MCP input sequence. All outstanding review gates still require fresh reviewer and final suites/hashes.

Final review: one fresh read-only reviewer, no Critical/Minor,2Important. Fixed WORLD->grid ownership leak by rejecting World transfers pending future pickup: dropped test RED4 -> GREEN11. Fixed prepopulated container adoption atomically registering children and rejecting duplicate runtime wrappers/occupied existing owners/duplicate standalone placements: edge RED3 then alias RED2 -> GREEN41. Final: fixed both findings — reproduction RED->GREEN, old suite1449/1449 and new298/298, total1747/1747,0issues. No re-review needed under inline execution skill. Editor warnings required additional editor evidence beyond CLI: best=null and removal of unused Phase8B private reload timer proxy (fixture reads actual Runtime) -> latest Main editor logs0warnings/errors. All74 parsers pass again.
Final: Ruling: formal Pickup/Loot, persistence/nesting expansion remain excluded; world transfer is rejected rather than implementing pickup — cost: future pickup must explicitly retire World representation. Ruling: arbitrary internal field/collection writes remain unsupported; all supported mutations use transactions — cost if callers bypass API: invariants need equivalent validation. Ruling: GUI/editor-warning clearance verified by executor via actual MCP, old screenshot superseded by inventory-ui-final.png — cost: native automation needs focused game window.
Final verification Main r4448677-5 saved while stopped then launched, initial29+1/Rig2/loose60/legacy0; Tab12grids/sixslots verified. Both editor/game logs clean. Addon313files SHA256 unchanged. No commit/push/tag. Windows historical c0000005 at03:50 predates Phase9 audit baseline04:32; no new native-crash event during this phase. Full70-point report docs/phase9_inventory_report.md. No deferred minors.
