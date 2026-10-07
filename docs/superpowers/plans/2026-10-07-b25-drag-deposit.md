# Phase 11.1B-2.5 Implementation Plan

> **For agentic workers:** Use executing-plans inline, test-driven-development and verification-before-completion. User requests this checkout and prohibits commit/push/tag/reset; retain the audit ledger outside the project.

**Goal:** One unclipped global cursor ghost, visible grid previews above floating windows, and explicit portable-content drag targets using actual direct storage.

**Architecture:** Retain InventoryDragContext and Dictionary candidates. InventoryUI owns overlay CanvasLayers; the native Godot drag preview is a non-rendering anchor. Existing PlacementPreview consumes the same candidate as commit. Resolver adds container_content; commit uses existing move, WORLD pickup or ExternalInventoryTransfer.

**Tech Stack:** Godot 4.7.2 stable, GDScript, existing tests and Godot AI MCP.

**Spec:** C:/Users/疯狂/.codex/attachments/c21d6c23-b1b9-45bb-9fcb-d605691621ed/貼上的文字.txt

## Global Constraints

- Preserve all 3418 old assertions and gameplay expectations; preserve addon 313 hashes.
- Manual drag uses current preview_rotation only; Short F opposite fallback unchanged.
- No descendants/siblings/rearrangement/hover-open; no B3/B4 or unrelated systems.
- No Git mutations; final pristine Main running; retain historical errors.

## Review Focus

- Source or target window disappears during native drag: no dangling ghost/preview.
- Scroll and overlapping window chrome: no hidden lower target or floating fabricated cells.
- Target ancestry/ownership/busy changes between green preview and commit: reject without source mutation.
- Equipped portable self drop: preserve same-slot no-op; grid self-content target must reject.
- Cross-registry complete subtree with runtime rounds: one commit, identity and equal-opposite weight.

## Task 1: Global visuals

Files: inventory_ui.gd, inventory_placement_preview.gd, portable_container_window.gd; tests/global_drag_ghost_test.gd and tests/drag_preview_consistency_test.gd.
Interfaces: begin_drag produces the single actual InventoryDragGhost; create_preview returns a non-rendering native anchor retaining old introspection API. update_drag_candidate updates one overlay preview from candidate.preview_rect.

- [x] Add tests: assert actual ghost parent is a global overlay, count<=1, rotation and cleanup; assert floating/same-grid in-bounds invalid candidate is visible and legacy out-of-bounds remains hidden.
- [x] Run new tests against B2: expected failure on missing global parent and hidden/under-window preview.
- [x] Create preview layer21 and ghost layer22 owned by UI; follow pointer; preserve native notification lifecycle and old test APIs.
- [x] Run new and old drag/preview/window tests: expected 0 failures.

## Task 2: Closed direct deposit

Files: inventory_drag_candidate_resolver.gd, inventory_ui.gd; tests/closed_container_deposit_test.gd, tests/closed_container_transfer_test.gd.
Interfaces: container_content candidate holds target_item, actual grid, exact position/rotation, target ancestry signature and reason. Direct search iterates get_storage_grids and find_first_free_position; common graph/policy/access validation.

- [x] Add RED tests for capability target, direct-only first fit, full/fragmented/cycle/self/depth/alias/policy/rotation, state revalidation and cross-registry/WORLD.
- [x] Resolve portable hit before parent placement; invalid remains content target. Use existing complete graph and validation, no mutation in preview.
- [x] Commit recorded cell, recheck target signature/access/busy and actual geometry; same-grid exact location returns true without signal.
- [x] Run new tests and old3418: expected all pass unchanged.

## Task 3: Native acceptance and report

Files: tests/closed_container_native_test.gd and docs/phase11-1b25-report.md.
Interfaces: real root.push_input through existing native drag; Main MCP uses same handlers, no production test hooks.

- [x] Native RED/GREEN coverage of pointer ghost, previews, window chrome, direct deposit, reject and rotation.
- [x] One independent final review; Important findings reproduced RED then fixed in one pass, full suite green.
- [x] Run all old/new tests and all scripts check-only; compare hashes. Verify Main acceptance17 scenarios, restore pristine Main.
- [x] Answer all90 report items with measured evidence; stop before B3, no Git changes beyond uncommitted files.
