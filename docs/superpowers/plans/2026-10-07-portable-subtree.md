# B1 Portable Subtree Implementation Plan

> REQUIRED SUB-SKILL: executing-plans，当前编辑器本地顺序实施，最后一次只读review；不commit/push/tag。

**Goal:** 完整identity-safe容器嵌套、原子登记/迁移、递归重量和Root-only F自动套包（允许新包旋转）。
**Spec:** docs/superpowers/specs/2026-10-07-portable-subtree-design.md + 用户完整附件/最新修正。
**Architecture:** Item/runtime child adapter→只读Graph→既有Registry commit/Transfer→共享Weight遍历。
**Tech:** Godot4.7.2 GDScript、SceneTree tests、Godot AI MCP。

## Constraints / Review Focus

- 原3080、no-op、Rig-only reload、伤害/Acoustic保持；不改addon，不做B2/B3/B4/Attachment/encumbrance。
- Validate不得构造wrapper或修改registry；注册的完整图破损、不同owner、duplicate/cycle/overlap/depth都拒绝且0mutation。
- 装入自身descendant、跨域冲突、WORLD子孙误计根、current/chosen rotation Preview差异是关键边界。
- Reload wrapper可以改变，必须返回当前真实registry wrapper；未绑定Actor也可计算/注册。
- 即便policy rejects小portable，不能靠当前尺寸碰巧拒绝。

### Task1 — graph/policy/atomic registration
- [x] 写missing-foundation RED + nesting/invalid/depth/parent/loaded identity/complete/simple guard测试。
- [x] 实现Item/Weapon child adapter、Graph、Grid owner/policy/cycle、完整注册；保留原事务signature/no-op。
- [x] 运行新suite和原完整矩阵，B1明确冲突按人工授权修正。

### Task2 — transfer/WORLD/F/size
- [x] 写nested cross-owner/failed snapshots/WORLD/Root-only/5×4 fallback RED。
- [x] 复用Graph扩展transfer/drop/pickup，修改Backpack资源外尺寸，F仅Backpackrotation fallback。
- [x] 仅更新明确旧尺寸/套包/Secure冲突并记行号与人工授权；运行旧矩阵和新suite。

### Task3 — recursive weight
- [x] 写纯计算精确实例重量、mixedAmmo、rootNoDouble、invalid graph、fire/reload/transfer delta RED。
- [x] 实现共享graph weight，配置全部当前可拾取重量，最小UI更新，不接入负重Gameplay。
- [x] 新/旧全矩阵通过；检查actor independent保护文件hash。

### Task4 — review/verification/report
- [x] 一个fresh-context只读最终review；重要问题一次RED/GREEN修复，minor记录。
- [x] 最终全矩阵、所有parser、MCP Main完整验收、addon/hash与Git检查。
- [x] 输出102项报告，恢复Main，结束B1，不启动B2。

执行ledger保留于本机audit目录，因禁止commit不能删除证据。
