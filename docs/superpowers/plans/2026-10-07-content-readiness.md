# Phase 11.1B-0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking. User scope authorizes current-editor local execution; no commits/push/tags or isolated editor checkout.

**Goal:** 数据化同类内容与换弹时序，提供未来配件/重量契约，保留全部现有 Gameplay。

**Architecture:** 专门 Resource 定义静态内容，Factory 创建独立 Runtime。ReloadTimingProvider 集中 family/profile/animation/fallback，伤势仍在调用侧施加。Attachment 只做 schema，重量只准备专属数据与契约。

**Tech Stack:** Godot 4.7.2 stable、GDScript、现有 SceneTree assertion suites、Godot AI MCP。

**Spec:** `docs/superpowers/specs/2026-10-07-content-readiness-design.md`；原用户附件完整 B0 需求；审查证据 `docs/phase11-1b0-content-audit.md`。

## Global Constraints

- 原 2993 assertions 不改；无数值再平衡；不改 `addons/godot_ai`。
- 不实现完整 Attachment Gameplay、动态 populated Rig/Bag 注册、B1 递归重量应用。
- Definition Resource 不存运行时数量/状态；Ammo 是唯一肉体/护甲/等级来源。
- 当前 Main 的 Rig 4×1×2、Backpack 5×5、Reload 2.0、Arms ×1.35 保持。
- 不 commit / push / tag。

## Review Focus

- 无效或缺失布局不能 silently 创建错误 Runtime；Factory 返回 null，不发布半成品。
- 同一 layout Resource 多次构造不能共享 grids/placements。
- 同 family 多 profile 时精确优先，旧 interface 标签不等于具体 Definition identity。
- Empty timing 不能与 DROP 处置策略混淆；replacement magazine family 才是换入上下文。
- Animation length / computed snapshots 不得修改共享 Resource；injury 只改本次 duration。

### Task 1: Content foundation + public contracts

**Files:** 新建 PortableContainerData、AttachmentSlotDefinition、AttachmentData、ComputedWeaponStats、WeaponStatResolver；修改 ItemDefinition/WeaponData/AmmoData/MagazineData、Rig/Bag Runtime、InventoryItemFactory、Main 初始创建、storage query；配置已有 data .tres。测试 `tests/content_extensibility_test.gd`。

**Interfaces:** Factory 仍 `create(definition,count=1,magazine_rounds=-1)`；container_data.grid_sizes；runtime.get_storage_grids()；ItemDefinition.has_capability(&"weapon"/&"magazine"/&"ammo_stack"/&"portable_container")；WeaponStatResolver.resolve(runtime) → independent ComputedWeaponStats。

- [x] 写实际内容扩展测试，先用 FileAccess/动态 load guard 检测缺少 Foundation，避免把 parser error 当 RED。
- [x] 运行 headless 新套件，确认因缺失布局/契约失败。
- [x] 实现 Resource + Factory/Runtime 最小改动；当前 data 填 ID/接口和原 layout，不修改数值。
- [x] 运行新套件和原 Rig、Factory、container、runtime、same-slot 相关套件，检查无错误/警告。

```gdscript
var layout = PortableContainerData.new()
layout.grid_sizes = [Vector2i(1,2), Vector2i(2,2), Vector2i(1,1)]
var item = InventoryItemFactory.create(rig_definition)
check(item.runtime_state.grids.size() == 3, "different layout creates three independent storage grids")
```

### Task 2: Animation-ready reload timing

**Files:** 新建 ReloadAnimationProfile、ReloadTimingProvider、当前 test rifle profile；修改 WeaponData profile 引用、ReloadCoordinator / legacy Firearm 时间来源。测试 `tests/weapon_definition_contract_test.gd`。

**Interfaces:** `ReloadTimingProvider.get_base_duration(data:WeaponData,magazine:MagazineData,empty:bool)->float`；`ReloadAnimationProfile` 两个 family、两种 Animation、两种 fallback。

- [x] 写无 profile fallback、精确 family/wildcard、不匹配、Tactical/Empty、动画长度、资源不变、stored runtime 和 Arms ×1.35 测试。
- [x] 运行新套件，确认 provider 不存在而 RED，非 parser failure。
- [x] 实现选择/解析，并替换两处时间公式中的基础时间；保留原策略 multiplier 和 injury。
- [x] 运行全部原 2993 与新套件，检查总量、失败、错误、警告。

```gdscript
var tactical_duration = ReloadTimingProvider.get_base_duration(data, replacement.definition, false)
var empty_duration = ReloadTimingProvider.get_base_duration(data, replacement.definition, true)
check(tactical_duration == 2.0 and empty_duration == 3.0, "independent fallback timings")
```

### Task 3: Review / Main / report

**Files:** `docs/phase11-1b0-content-readiness-report.md`，只读审查包和验证 logs 放临时 audit 目录。

- [x] 运行所有 scripts/tests check-only，按退出码和 ERROR/WARNING 检查。
- [x] 使用 requesting-code-review 做一个只读最终审查；important/critical 问题用 RED→GREEN 修复，minor 留明确记录。
- [x] 顺序运行最终全矩阵；MCP 刷新/启动 Main，检查初始布局、同槽 no-op、真实射击/换弹、Output 和 Editor。
- [x] SHA256 对比原测试/受保护 gameplay/addon，确认无提交；输出 60 项报告、5 类内容新增步骤和剩余技术债。

没有 commit 步骤：用户明确禁止。完整原矩阵 runner 在 `%TEMP%/codex-fps-phase11-1b0-audit/`，默认只顺序运行 native tests。执行记录与裁定写同目录 progress.md，保留以便中断后继续。
