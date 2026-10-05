# Phase 11 Loot Containers Implementation Plan

> Use executing-plans inline with TDD and one fresh final read-only reviewer. User supplied the implementation spec and explicitly forbids commits/push/tags.

Goal: independent external inventories, original-reference atomic player/container transfers, existing UI and interaction reuse.
Spec: C:/Users/疯狂/.codex/attachments/a07d3d52-ab58-47f5-b3a7-a1e6a0e0136c/貼上的文字.txt (all161 sections read).
Base:69b107a clean. Godot4.7.2 Test_1 editor stopped. Audit:%TEMP%/codex-fps-phase11-audit. No addon/combat/reload/movement/acoustic rule changes.

Architecture: Each LootContainerRuntime owns an InventoryTransactionService and an8x6 InventoryGrid. Existing global runtime-owner checks protect across registries. ExternalInventoryTransfer validates a live actor/container access session, locks both registries, moves complete registration groups and portable child grids by reference, then emits changes. WORLD is never a transfer intermediate. Same-container layout/stack/split/load use the existing algorithms. UI adds a container mode/grid view to existing drag resolution; range/occlusion/deletion closes and cancels access.

- [x] Task0 baseline: rerun2557, capture313 addon and protected production SHA256.
- [x] Task1 Runtime/registration: RED runtime and ownership tests (8x6, placement/move/rotation/stack/split, duplicates/invalid placements/foreign owners/deep items); implement loot_container_runtime and atomic register_external_container + CONTAINER location in transaction_service; GREEN plus old inventory suites.
- [x] Task2 external transfers: RED access/transfer/persistence tests; implement access and external transfer, whole nested group adoption, two-registry lock, same-container/shared ammo helper paths, active equipment binding, no WORLD history, failed rollback. GREEN plus old2557 relevant.
- [x] Task3 node/interaction/factory: RED interaction/gameplay tests; deterministic A/B crate data, primitive scene world body + independent interaction area, short/long capability F, 2.5 open /3.0 access/LOS; GREEN.
- [x] Task4 UI: RED container_ui/safety tests; existing InventoryUI container mode replaces Nearby, same grid view/ghost/rotation/snap/load/merge/equipment, data-driven partial refresh and source-placement protection, close/reopen/deleted/range/occlusion/lock/input protections; GREEN/native tests.
- [x] Task5 level/Main: two separate crates behind firing targets, preserve old world loot; Main MCP actual F/drag17rig/reload/weapon slot2/fire/ammo/drop fullbag/close-walk-reopen/A-B independence; no clone/temp WORLD audit.
- [x] Task6 all tests/parsers: original2557 plus8+ new suites, all .gd check-only, noerrors/warnings,313hashes, fresh final review fixes RED->GREEN + full matrix, report64points, normal Main running. No re-review.

Pre-flight interfaces: runtime registry gets explicit external owner, not UI/name/path; transfer includes existing loaded-magazine wrapper and all nested grids; external source cannot use player-only ordinary move; UI resolves source.get_owner_registry; all external commits require valid access at transaction boundary. Different registries keep external loot out of player weight and reload candidates. Readonly category data shared, all runtime instances independent.
Ruling: treat the user's full161-section specification as authorized architectural implementation, use current editor checkout, retain uncommitted files and audit rather than add approval/commit gates — cost if withdrawn is reverting local changes.
Ruling: each crate gets its own registry instead of adding crates to the player registry — preserves independent ownership/weight/lifetime; cost is explicit atomic registration-group migration is required and tested.
Ruling: container long-held F waits for release to search; only targets declaring hold support invoke Vicinity — cost is crate search occurs on release, consistently with the supplied short-F input design.

Review Focus:
1. Cross-registry atomicity and entire loaded-magazine/portable-content identities, global runtime owner registry, no stale source grids or duplicate location.
2. Access checks in transfer boundary (wrong/closed session, foreign crate, queue deletion, actor/node movement, walls, reload lock) and locking across signals/reentrant callbacks.
3. Shared ammo helpers partial/full consume/merge/load/split, count conservation and source registry ownership, no WORLD.
4. Interaction area vs physical crate body, world occlusion and threshold capabilities, old WorldItem tap/hold remains unchanged.
5. UI safe source/grid pending press changes, cached commit vs preview, partial refresh, close listener cleanup and container runtime persistence; original2557 fixtures unchanged unless explicit new authored geometry obstructs tests (then change scene placement, not old assertions).
Task0 complete: baseline2557/2557,50runs,0issues. Task1 missing runtime/registry RED3fail -> runtime18+ownership19 GREEN0errors/warnings; lifetime self-retaining lambda regression RED -> bound callback GREEN. Old inventory transaction13/portable27/worldownership34 unchanged.

Task2 complete: transfer24 and persistence33, original-reference whole weapon/portable-child migration, source/dest locks, partial merge/load, Secure, close/range/LOS/locks. Test callback lifetime fixed by disconnect; zero errors/warnings.
Task3 complete: actual rendered F/tap/long25, 2.5m open and3m actor access, wall/area/body rules and deterministic separate crates. Typed RID ternary corrected using typed empty array+append.
Task4 complete: native UI34, gameplay30, safety50 GREEN; source move/replacement guard, partial view redraw, distance/LOS/deletion/runtime/lock rejection, lifecycle disconnect before firearm exit signals. Eight suites233new assertions. Full58run matrix now running.

Task5 complete: real Main MCP F Search, native Rig spares->crate +17->Rig, Tab/R original17 loaded, ammo60->crate close/reopen, gun->Slot2 then2 AUTO actual projectile firing MAG17->15 +crate physics impact, active gun->crate unbind, full bag block->crate then original gun->bag with same spent runtime; access loss closes, B55/12independent, A persist same originals. WORLD6 unchanged all steps. Main run26 Output/info11, editor since72 errors0/warnings0. Initial editor incremental class cache stale: refreshed5new script entries and scanned; clean successful Main. Original parser122/122 clean, addon313 and protected27 unchanged. First matrix uncovered UI exit plain actor firearm-property error fixed; old interaction17 clean. Overlapping native windows disturbed Vicinity30; serial rerun30clean. Final matrix required after fresh review.
Review package: baseline/head both69b107a since user forbids commits. Stock review-package rejects empty commit ranges; audit/review-package.diff contains git diff -U8 plus all untracked gd/tscn/md. This follows first Ruling: review working tree without any staging/commit or branch changes.
Final sequential full matrix: old2557 unchanged +new265 =2822/2822,58runs,0issues (release-results.json). New18/19/34/36/25/45/38/50. Finalhash addon313/313unchanged, protected27/27unchanged, addoncurrentcount313. git diff --check clean. Finalparser122 started; review pending.
Final review: one fresh read-only gpt-6-astra/high reviewer, all production changes/eight suites reviewed; Critical0 Important0 Minor1. Full2822/2822 clean, parser122/122 clean. No fix pass/re-review needed.
Final: minor (deferred): container mode same equipped item dropped back onto original slot gets valid green preview but transfer prevalidation rejects occupied same slot; item remains original, no loss/ownership corruption. Future change should permit same-registry same-slot no-op only, with RED->GREEN coverage.
Final: Ruling: runtime-time insertion of newly constructed populated portable containers via external_registry.place is not a Phase11 gameplay producer — authored loot initializes atomically before registration and all runtime moves use complete group migration — cost is a future dynamic loot producer must add child-grid adoption coverage or initialize before registration.
Final: Ruling: retain existing same-registry mutation notification semantics; both registries locked for new cross-owner transactions — matches requested cross-owner lock boundary and avoids redesigning old inventory transactions — cost is future custom same-registry signal callbacks need their own reentry policy.
Final: Ruling: save/load, multiplayer and concrete corpse behavior remain excluded; only external owner interface prepared — explicit user scope and verified current gameplay — cost is those future phases still require implementation and integration tests.
Task6 verification: old2557 +new265=2822/2822 0fail;58runs0errors0warnings. All122 gd check-only0errors0warnings;313addonSHA+27protectedSHA unchanged; originaloldtestfiles unchanged; git diff --check clean. Main clean restart pending.


Task6 complete: finalreview noCritical/Important, oneMinor disclosed/deferred and all3declined-scope decisions ledgered. NormalMain run27 ready/is_playing true, noerrors; production untouched afterclean2822and122parser. No commits/push/tags. Report64points finalized.

