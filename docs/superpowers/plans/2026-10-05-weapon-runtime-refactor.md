# Phase 8B — Stateful WeaponRuntime 执行记录与迁移计划

规格：用户附件 `17b2b2d0-a779-4824-aa2a-955a7d3d94aa/貼上的文字.txt`，95 节要求；用户明确暂停 Phase 9，先执行该重构。

## 不变契约

30 发初始枪内总量 = Magazine 29 + Chamber 1；两只 Legacy 备用弹匣；SEMI 单次触发；AUTO 的时间余量；600 RPM；Tactical 保留 Chamber；Empty Reload 30→29+1；实际 fired_round；Arms Reload ×1.35；当前 Projectile 默认、全部世界射击反馈、原 HUD 文案。原 1353 项预期不修改。

WeaponRuntime 为 RefCounted，只引用 WeaponData/AmmoData/MagazineInstance/结果对象，不引用 Actor、SceneTree、Input、HUD 或 Inventory。Firearm 保留世界射击、触发输入、视觉反馈和 Legacy spare provider。兼容属性只能委托，不保存镜像。

## 接口

- WeaponRuntime.initialize(data, magazine=null, chamber=null)：只设置明确给定状态，不生成弹药、不自动装膛；新枪启动由 Firearm 显式准备满弹匣并 chamber。
- chamber_next_round()、get_magazine_round_count()、try_fire() -> WeaponFireResult。
- tick(delta, allow_catch_up=false)：非法时间无操作；倒计时非负。AUTO 请求的过期时间余量只用于当前 tick 补足应发射次数，闲置时不囤积未来 burst。
- can_begin_reload(replacement)、begin_reload(replacement, duration, type=TACTICAL)、finish_reload() -> WeaponReloadResult。外部计算伤势后的 duration；Runtime 不搜索 provider。
- state_changed、reload_finished(result)：Runtime 完成交换，Firearm 用原 Magazine 引用更新 Legacy provider 后发布原 HUD signal。
- Firearm.bind_runtime(runtime)、unbind_runtime()：断开旧 signal、释放 trigger/aim、保留外部 Runtime 全部实例状态；无绑定时不射击、不发反馈。

## 十步迁移与验证

- [x] 1. 先写独立 Runtime RED 测试，再实现 Runtime、FireResult、ReloadResult，验证 GREEN。
- [x] 2. Chamber 移为 Runtime 真状态；相关旧测试通过后继续。
- [x] 3. Loaded Magazine 移为 Runtime 真引用；验证同一对象与 Mixed Ammo。
- [x] 4. Fire mode 移为独立 Runtime 选择；验证共享定义不共享状态。
- [x] 5. RPM/cooldown 移入 Runtime；验证 30/60/120Hz 与长 tick。
- [x] 6. Reload 状态/时间/待换弹匣移入 Runtime；验证旧 Tactical/Empty/Injury。
- [x] 7. Firearm 仅消费成功 FireResult；成功/失败两模型集成测试。
- [x] 8. HUD 使用 Runtime 驱动的原状态 signal，验证绑定与解绑刷新。
- [x] 9. 审计 Firearm 的委托属性、绑定生命周期和状态唯一性；独立审核。
- [x] 10. 全量原 1353 + 新测试、解析检查、MCP main 输入/Output、313 addon 哈希复核。

## Review Focus

1. AUTO 长 tick 和 30/60/120Hz 不能失去余量或积累 idle burst；SEMI 不使用补发额度。
2. bind/unbind 不重置 Ammo/FireMode/Cooldown/Reload，不让旧 Runtime signal 再污染当前 HUD。
3. 失败 EMPTY/COOLDOWN/RELOADING/DISABLED 不产生 Projectile、Recoil、Muzzle 或 Gunshot。
4. Reload 完成只交换一次、旧 Mag 原引用返回 provider，完成帧不再开火。
5. 负 delta、NaN/INF、非法 RPM/duration 不消耗弹药或污染计时状态。

## Rulings 与记录

- Ruling: 用户提供的书面规格及第49节十步顺序是本次执行依据，用户已明确要求先重构；不增加另一次设计审批。若理解错误，可通过小范围未提交改动撤回。
- Ruling: 保留当前编辑器 checkout 和工作区既有 addons/dialogue_manager、addons/sky_3d、demo 与用户修改；不新建 checkout，不 commit/push/tag。
- Ruling: 执行附加的独立审核，仅作只读代码审查，不并行改生产代码。
- 保护基线：%TEMP%/codex-fps-stage8b-audit，313 addon 哈希、97 项项目文件哈希与原 Firearm 源码。

- Baseline: 16 runs, 1353 PASS / 0 FAIL / 0 CLI errors or warnings. Existing editor cursor=12 contains demo OBJ missing-MTL imports; no FPS parser errors. Runtime test RED: missing 3 required files, exit 1; GREEN: 61 assertions. Steps 2/3 related runs: 246 PASS each, 0 issues.

- Steps 4/5/6: 246 PASS each. Step 5 RED: HUD missed successful Runtime cycle because the old chamber helper returned without publishing; connecting Runtime.state_changed restored both original failing shot/HUD assertions. No expected-value changes. Ruling: introduce the planned HUD signal bridge in Step 5 to keep every intermediate stage playable; Step 8 verifies the complete binding bridge.
- Integration RED: old Firearm lacked bind_runtime/unbind_runtime, 1 failed guarded assertion, exit 1.
- Steps 7/8: 280 PASS / 0 FAIL / 0 issues. New integration 34 assertions cover both fire models, actual mixed-ammo DamageInfo, failed shot feedback, restored Runtime before ready, node free, signal disconnect/reconnect, and detached reload progress. HUD stays unchanged and receives the Runtime-driven Firearm bridge.
- Full pre-review suite: original 1353 + new 95 = 1448 PASS / 0 FAIL / 0 CLI issues. All 44 FPS GDScripts passed --check-only without warnings.
- Final independent read-only review: one P2, finite tiny RPM can make 60/RPM infinite. Numeric probe confirmed float("1e-308") reproduces (literal 1e-308 is parsed as zero by this engine). New test RED 62 assertions / 1 fail; interval validation before consumption GREEN 62 / 0. No other required findings or deferred minors.
- Final: Ruling: detached Runtime reload completion is consumed by the external provider via reload_finished, rather than adding inventory bookkeeping to Runtime — this keeps actor-neutral state and explicit Phase 9 boundary; an external caller that fails to consume the result will lose its provider tracking, not the Magazine references in the completion result.
- MCP temporary movement-eval script had an extra indentation and entered a debugger break; corrected the test snippet and restarted main. Production scripts remained clean. Real main input verified WASD 5.0, Sprint 7.5, Sneak 2.5, ADS 3.0/FOV→55, jump and mouse look.
- Final fix verification: full 18 runs = original 1353 + Runtime 62 + integration 34 = 1449 PASS / 0 FAIL / 0 CLI errors or warnings. All 44 scripts passed final --check-only. Existing 97 baseline files: only scripts/weapons/firearm.gd changed; all original tests and WeaponData/scenes/project settings unchanged by this work. Addon 313/313 SHA256 unchanged and file count unchanged.
- MCP main gameplay: default Projectile, initial 29+1/spares2; SEMI held 0.45s = 1 shot, 1 Projectile, 1 muzzle/recoil and 1 gunshot; armor retained its B1/A3 flesh blocking. Unequipped target armor for a runtime-only probe: actual fired Ammo damage 30, Overall 150→120. Tactical reload retained Chamber and returned the exact 27-round magazine, during-reload shots0, new30+1. AUTO 0.55s = 6 shots/6 gunshots at600RPM. Remaining25 fired to EMPTY, another0.35s trigger gave0shots/0gunshots/muzzle off. Empty Reload =29+1. Runtime-only Hitscan probe generated no Projectile and actual Ammo damage30, Overall150→120. Restart restored all temporary inspection fixtures and default gameplay data.
- Main gameplay test run Output: 109 info lines, no runtime errors/warnings; editor Logger cursor stayed12, no new entries. The original 12 demo OBJ/MTL import errors remain outside this refactor. Save performed while stopped; attempted main restart to restore default state. No commit/push/tag.
- Final restart encountered an editor-native crash (Windows Event 1000, exception 0xc0000005, Godot executable offset0x3e86b7f); MCP disconnected after project_run timed out. This is separate from the completed clean gameplay script run. Reopening the saved project with the same Godot binary to restore editor/MCP, without changing project settings or addons. Native-crash root cause is not established by script tests.
- Recovery: first reopen briefly found the old server's9500 socket occupied; after the old server exited, restarted only the recovery editor. Session test-1@777a5acb13ff7445 connected, Godot/plugin/server4.7.2/4.3.0/4.3.0. Main successfully relaunched, helper live, initial29+1/spares2, default Projectile. Fresh session game/editor logs both have0errors/0warnings. Historical demo import failures were not changed or suppressed; no new native crash observed after recovery. Final hash audit still only Firearm changed among97 original files and313 addons unchanged; HEAD4d4d736 unchanged.
- Final: fixed RPM interval overflow — float("1e-308") disabled-shot assertion RED→GREEN; final suite1449/1449. No deferred minors. Finishing choice already given by the user: keep branch phase-3-damage-1 and workspace in place, no Git integration or cleanup.
