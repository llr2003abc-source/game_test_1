# Phase 8A Gameplay Acoustic Implementation Plan

> **For agentic workers:** Use executing-plans to implement this plan task-by-task. The user approved spec v3 and explicitly requested implementation in the current session. Execute inline; preserve the current editor checkout.

**Goal:** Gameplay acoustic events for five movement modes, landing, and real shots, usable by Player and AI actors.

**Architecture:** Controllers submit actual movement observations to ActorNoiseEmitter. The emitter and Firearm publish AcousticEvent through GameplayAcoustics; listeners depend only on the event signal and radius query.

**Tech Stack:** Godot 4.7.2, GDScript, Windows, Godot AI MCP, existing command-line SceneTree tests.

**Spec:** ../specs/2026-10-04-gameplay-acoustic-design.md (v3).

## Global Constraints

- INJURED > ADS > other modes for footsteps; fixed injured speed 2.5 m/s, radius 15m, including ADS.
- Sneak/ADS: 5m, 0.9m, 0.25m; Walk: 15m, 1.2m, 0.30m; Sprint: 30m, 1.4m, 0.40m.
- Landing is one independent 20m event, without a simultaneous ordinary footstep.
- Only true shots emit gunshot, at muzzle position with the character source; Test Rifle radius 200m.
- No AI implementation, real audio, plugins, or addons/godot_ai edits.
- Existing tests remain; four assertions affected by the approved injury contract are updated explicitly.

## Review Focus

1. ADS toggles while injured must not reset distance or change radius.
2. Mode change followed by stopping must not emit twice.
3. Spawn/teleport must not produce a false footstep; a true airborne landing must produce one event.
4. An AI actor must emit itself as source rather than Player or the emitter Node.
5. Projectile impact, empty fire, and reloading must not produce additional gunshot events.

## Task 1: Event boundary and hearing

Files: acoustic_event.gd, acoustic_event_bus.gd, debug_acoustic_listener.gd, acoustic_event_test.gd, project.godot Autoload.

Interfaces: AcousticEvent fields position/radius/category/source/timestamp; static is_event_audible(Vector3, AcousticEvent); bus emit_sound(Vector3,float,StringName,Node), sound_emitted(AcousticEvent); listener events:Array[AcousticEvent], clear_events(). Autoload is GameplayAcoustics, class_name is AcousticEventBus.

- [x] Write a guarded failing test against the real bus and listener. Boundary fixture:
  ```gdscript
  for radius in [5.0, 15.0, 20.0, 30.0, 200.0]:
      bus.emit_sound(Vector3(4, 2, 7), radius, &"gunshot", source)
      var event = listener.events.back()
      check(Event.is_event_audible(event.position + Vector3(radius, 0, 0), event), "inclusive boundary")
      check(not Event.is_event_audible(event.position + Vector3(radius + 0.1, 0, 0), event), "outside boundary")
  ```
- [x] Run `Godot --headless --path . --script res://tests/acoustic_event_test.gd`; expect feature-missing FAIL, not parser failure.
- [x] Implement typed event, StringName categories, monotonic timestamp, generic bus and listener; register class scripts before dependent editor loads. Hearing uses squared 3D distance <= radius squared.
- [x] Run the event test; expect all assertions PASS, no warnings.

## Task 2: ActorNoiseEmitter

Files: actor_noise_emitter.gd, actor_noise_test.gd.

Interfaces: MovementMode enum; source:Node export; observe_movement(Vector3,Vector3,bool,MovementMode,bool); reset_position(Vector3,bool,MovementMode,bool); effective noise selection prioritizes INJURED over aiming ADS.

- [x] Write failing tests using real emitter, bus and two independent sources. One fixture:
  ```gdscript
  emitter.reset_position(Vector3.ZERO, true, WALK, false)
  emitter.observe_movement(Vector3(0.4, 0, 0), Vector3(5, 0, 0), true, WALK, false)
  emitter.observe_movement(Vector3(0.4, 0, 0), Vector3.ZERO, true, SPRINT, false)
  check(listener.events.size() == 1 and listener.events[0].category == &"footstep_walk", "old mode flush exactly once")
  ```
- [x] Run actor_noise_test; expect missing-feature FAIL.
- [x] Implement a single distance loop and flush helper, grounded gating, landing edge and explicit source. Initial observation is a baseline. Air clears residual; landing sends once and returns. Track actual XZ displacement and preserve complete-step remainder.
- [x] Test 30/60/120Hz literal expected one-second totals 3/4/6/4/3 for Sneak/Walk/Sprint/ADS/Injured after stopping, partial stops, all effective mode changes, landing and non-Player source. Expect PASS.

## Task 3: Player modes, injury and real gunshot integration

Files: player_controller.gd, player.tscn, body_injury_component.gd, weapon_data.gd, test_rifle.tres, firearm.gd, project.godot Input Map, acoustic_gameplay_test.gd, two changed injury regression tests.

- [x] Write gameplay test against saved scenes: Input Map, real CharacterBody movement, Player emitter source, muzzle gunshot position, SEMI/AUTO, RPM, both FireModels, empty/reloading, mixed ammo, and a non-Player holder using the actual Firearm.
- [x] Change the four approved injury-contract assertions before production: torso-only multiplier 0.8, legs-neutral movement multiplier, injured actual speeds 2.5 including ADS. Run and observe intended failures.
- [x] Export normal/aim/sneak/sprint/injured speeds; resolve injured, aiming, Ctrl, Shift, Walk in that order; keep camera/input/recoil handling. After move_and_slide submit noise observation. INJURED uses fixed speed; others use torso multiplier. Preserve jump multiplier.
- [x] Add Player emitter with source NodePath(".."). Remove obsolete legs movement export and its contribution, retaining all other injury rules.
- [x] Add Shift/Ctrl actions and gunshot radius. Publish gunshot once after a successful shot in the common branch; keep damage and firing rate code intact.
- [x] Run gameplay test and updated injury tests; expect PASS with no errors or warnings.

## Task 4: Save, review and complete verification

- [x] Save/reload scenes through Godot AI MCP, verify actual exported references remain serialized, refresh UID import cache if needed.
- [x] Run all baseline suites (both FireModels where applicable) plus the three acoustic suites; count PASS lines and record failures/errors/warnings.
- [x] Parse every script using `--check-only --script`.
- [x] Review diff against v3, especially the five Review Focus cases. Test any discovered defect before fixing.
- [x] Launch main scene through MCP; inspect current game Output and editor errors since baseline cursor, test input and capture final state.
- [x] Compare the 313 addon hashes and unrelated protected files to the pre-change backup.
- [x] Update execution record and report actual counts, changed files, explicit injury regression updates, and any remaining limitations.

## Execution record

- Ruling: work in the current project checkout because the user requested the running Godot project; a separate checkout would disconnect editor verification.
- Ruling: the user explicitly authorized implementation after reviewing v3; the plan is recorded and executed without another approval stop.
- Ruling: preserve single-agent execution from the reviewed spec; perform a separate final review pass without delegating implementation.
- Baseline backup: %TEMP%/codex-fps-stage8a-backup, including addon SHA256 manifest. No commits or pushes required for delivery.

## Verified delivery (2026-10-05)

- Baseline: 894 assertions passed, 0 failed before runtime edits. Four existing injury assertions were updated for the approved fixed 2.5 m/s leg-injured mode; their expected failures were observed before implementation.
- Event boundary suite: 41 passed. Actor noise suite: 336 passed. Gameplay acoustic suite: 82 passed. New total: 459 assertions.
- Final full matrix: 1353 passed, 0 failed across 16 runs. The final review added 60 actor mode-transition assertions; that suite was rerun and replaced its earlier result. Other suite sources and runtime behavior were unchanged.
- Parser validation: all 39 scripts checked with --check-only; 0 errors, 0 warnings. Updated actor test was checked again after adding final-review coverage.
- Separate review covered source identity, INJURED > ADS priority, partial stop/mode settlement, air/landing transitions, common successful-shot publication, Projectile impact/expiration, and protected damage logic. No further production changes were needed.
- MCP saved Player and TestLevel, verified serialized emitter source and retained injury references, ran main scene, applied a 12-step movement/ADS/jump/fire input sequence, and checked game/editor logs. Main scene was restarted to leave a fresh playable state: MAG 29, CHAMBER 1, SPARE MAGS 2.
- Current run: Godot 4.7.2 official, helper live, no current errors or warnings. Final runtime screenshot: %TEMP%/codex-fps-stage8a-final-game.png. Test logs: %TEMP%/codex-fps-stage8a-final-*.log.
- Protection: all 313 addons/godot_ai SHA256 hashes unchanged. Of 83 baseline project files, only the 9 listed task files changed; protected damage/armor/projectile/ammo/hit-marker files are unchanged. git diff --check passed.
- Editor incident: an in-memory force reload during save verification caused one native c0000005 engine crash. The editor was restarted and scenes loaded normally; subsequent saves, two main-scene runs, input checks and Output reads succeeded. The engine crash root cause is not claimed fixed. The MCP write guard also rejected a save while playing; stopping before saving resolved that call without file changes.
- No Enemy AI, real audio assets, plugins, inventory, or additional gameplay systems were added. Cover/Standoff remains deferred.