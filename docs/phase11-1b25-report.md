# PHASE 11.1B-2.5 REPORT

状态：**PHASE 11.1B-2.5 COMPLETE**，等待人工审核；未开始 B3。

本阶段只实现全局拖拽 Ghost、统一落点预览和关闭容器直接存入。基线为 `8bfccc9`，旧 3418 项断言、旧数据和场景保持原样。最终 79 组运行：**3629 assertions passed，0 failed**。Main 已恢复初始状态并保持运行。

## 文件与实现

| 编号 | 要求 | 结果 |
|---|---|---|
| 1 | 生产文件 | 修改 `inventory_ui.gd`、`inventory_drag_candidate_resolver.gd`、`inventory_placement_preview.gd`、`portable_container_window.gd`，均在 `scripts/ui/`；没有新增生产脚本。 |
| 2 | 测试 | 新增 `global_drag_ghost_test.gd` 7、`drag_preview_consistency_test.gd` 9、`closed_container_deposit_test.gd` 27、`closed_container_transfer_test.gd` 36、`closed_container_native_test.gd` 114、`global_drag_scroll_test.gd` 7、`b25_review_regression_test.gd` 11，共 211；附 Godot 生成的 UID。没有修改任何旧测试。新增实施计划与本报告。 |
| 3 | Ghost parent | 唯一可见 `InventoryDragGhost` 的 parent 是 `InventoryUI.drag_overlay`，它是独立 `CanvasLayer`。 |
| 4 | 不属于 Grid | Grid 只负责起始抓取点与目标命中；Ghost 在独立画布中，不继承 Grid 的裁剪。 |
| 5 | 不属于 Window | 窗口移动、置顶、滚动不会重新创建或重新挂载 Ghost。 |
| 6 | z-order | Inventory/浮窗 layer 20、Preview layer 21、Ghost layer 22。Ghost 在目标高亮上方。 |
| 7 | clipping | Ghost 脱离 ScrollContainer/Grid 的裁剪链；目标 Preview 仍裁剪到真实 Grid 可见部分，并扣除上层窗口遮挡矩形。 |
| 8 | lifecycle | `begin_drag` 创建；成功、拒绝、取消、关闭 Inventory、相关窗口关闭及来源失效均通过 `finish_drag` 清除。Godot 仍负责 native drag 生命周期。 |
| 9 | rotation | R 修改 drag context 的预览旋转、Ghost caption/footprint，并重新解析同一指针下的候选；提交前不修改 Item 实际旋转。 |
| 10 | 最多一个 | begin 先 finish；一个 overlay 只持有一个 Ghost。Godot native preview 使用不绘制的 `NativeDragAnchor`，不是第二个可见 Ghost。 |
| 11 | Same-grid Preview | 合法格位绿色，实际 Grid 内无效格位红色；越界不伪造目标格位。 |
| 12 | Cross-window Preview | 同一解析/绘制路径，使用目标 Grid 的真实变换、可见边界与窗口层级。 |
| 13 | Main ↔ Window | 共用 InventoryUI 的唯一候选和 Overlay；无需在跨界时重建 Ghost。 |
| 14 | Crate ↔ Window | 来源访问仍由 LootContainerAccess 检查，显示与提交共用原有跨 registry 事务。 |
| 15 | Preview clear | 目标变化替换单一候选；无目标立即隐藏；结束拖拽、来源失效、关闭相关窗口清理。 |
| 16 | Candidate | 沿用 Dictionary：`kind`、`valid`、`grid`、`position`、`rotated`、`snapped`；content 增加真实 `target_item`、外部 `hover_grid/hover_position`、`reason`、目标祖先/位置签名。显示字段包括 footprint、preview/actual/visible rect、视觉窗口与遮挡矩形。 |
| 17 | Preview == Commit | 候选保存确切内部 Grid、格位与旋转；提交只检查此目标是否仍合法，禁止二次找空格或改投其他容器。 |
| 18 | 同位置 no-op | 同 Grid/同位置/同旋转成功返回，不提交 mutation、不发 changed；来源完整 ownership 仍先验证。原装备同槽 no-op 保留。 |
| 19 | Closed Target 识别 | 指针实际命中 Item 外部 footprint，定义具有 `portable_container` capability，即解析 content target。装备上的其他 portable Item 同样可接受存入。 |
| 20 | capability-driven | 不按 Backpack 名称或固定 Item 类型识别，复用既有 capability；未添加新分类框架。 |
| 21 | actual storage | 直接调用目标实例 `get_storage_grids()`；不用 UI 副本、不创建替代 runtime。 |
| 22 | 搜索算法 | 逐个实际直属 Grid 调用既有 `find_first_free_position(item, preview_rotation)`，首个合法格位即结束。 |
| 23 | 多 Grid 顺序 | 按 `get_storage_grids()` 实际返回顺序，每个 Grid 使用原有行优先 first fit。 |
| 24 | 不搜索 descendant | 不递归储物容器；目标本身满即失败，即使子包有空格。 |
| 25 | 不搜索 sibling | 不查询父容器的其他包，鼠标指向哪个实例就只存入哪个实例。 |
| 26 | no-space | 保持 invalid content candidate，红色 `NO SPACE`，原物品不动。 |
| 27 | fragmentation | 仅检查真实连续矩形；总空格够而形状不够仍失败。 |
| 28 | 不 rearrange | Preview 纯查询；没有整理、移动既有物品或合并储物空间的代码。 |
| 29 | Manual rotation | 只试当前预览方向，R 后才试新方向；不自动旋转。 |
| 30 | Short F exception | 未修改 Short F 拾取规划器：World Backpack 仍先当前方向，再 opposite rotation fallback。自动测试和 Main 单独验收。 |
| 31 | 优先级 | actual portable footprint → content；之后才走原 LOAD/MERGE 或普通 placement。 |
| 32 | 无效不 fall-through | invalid content 保留其 kind/reason，不退回外部 parent Grid 放置、不搜其他包。 |
| 33 | valid visual | 整个目标 Item 外部 footprint 绿色，标记 `STORE INSIDE`；内部真实目的地存在 candidate 中。 |
| 34 | invalid visual | 同一 footprint 红色，显示 NO SPACE/SELF/CYCLE OR DEPTH/NOT ALLOWED/BUSY/INVALID OWNERSHIP 等实际原因。 |
| 35 | self | Grid 中拖容器到自身 footprint 为 SELF；自身装备槽按既有成功 no-op 规则处理。 |
| 36 | cycle | 复用 `InventoryOwnershipGraph.would_create_cycle`，A 包含 B 时 A → B 拒绝。 |
| 37 | depth | 复用既有最大深度 32；新增第 33 层拒绝，没有另设宽松规则。 |
| 38 | policy | 复用 portable → Rig/Pocket/Secure 限制和最终事务 destination 校验；不改现有 policy。 |
| 39 | alias | 来源与目标子树收集、目标 registry 登记检查；commit 再验证来源完整子树，same-location shortcut 也不能跳过。 |
| 40 | 同 registry | `reserve_item` → `commit_reservation`，目标为 candidate 记录的真实内部格位。 |
| 41 | reservation | 同/跨 registry 共用既有 reservation；失败 cancel，成功不遗留 lease。WORLD 共用其既有完整拾取事务。 |
| 42 | 同 registry weight | 原对象迁移、lease 期间继续计重；新增 actual reservation、cancel、closed deposit 和通知时重量连续性断言。 |
| 43 | Crate → Closed | 支持直接向实际 Player nested Backpack 存入；不存在必须先在根包找空格的条件。 |
| 44 | Root 中转 | 不经过 Player Root 中间 placement，单次转移直接落到目标内部 Grid。 |
| 45 | External atomicity | 使用既有 `ExternalInventoryTransfer.transfer` 的完整子树/registry 事务，不另写跨容器搬运流程。 |
| 46 | rollback | 访问丢失、锁、目标格位变占用、目标 ancestry 变化时拒绝；取消来源 reservation，保持源位置/identity。 |
| 47 | subtree identity | 测试 C → Rig → Magazine 完整真实边关系，迁移后对象相同。 |
| 48 | runtime identity | 保存原 runtime 引用；同/跨 registry 完整迁移均核验 runtime 相同。 |
| 49 | rounds order | 新测试 mixed A/B/A rounds 原序不变，未加载、卸载或重建弹药。 |
| 50 | WORLD/Vicinity | 支持现有安全 WORLD drag：原 `pickup_world_item_to_grid` 直接存到目标内部 Grid，成功同时撤销 WORLD ownership。 |
| 51 | revalidation | 检查来源位置/旋转/完整子树、锁和 busy、WORLD/Crate 访问、target 实际位置祖先签名、目标真实 storage/格位。候选不合法即失败。 |
| 52 | open/closed | 无需开窗；已开窗也不改变 content 入口与真实目的地。 |
| 53 | live Window | 窗口是 actual Grid view；事务 changed 后原窗口立即刷新，并非复制内容。 |
| 54 | auto open | 未自动打开窗口；成功后原 closed 状态保持。 |
| 55 | hover-open | 未实现。 |
| 56 | chrome | 上层浮窗 title/border/button 区域禁止穿透；不通过 edge snap 命中被滚动隐藏的 Item。 |
| 57 | occlusion | hit-test 只使用顶层命中窗口；Preview 显式扣除覆盖它的上层窗口区域，像素回归测试验证 title 不被低层 preview 染色。 |
| 58 | future Ammo target | 现有候选 kind 与解析/提交分支可增 special target；本次不新增 per-round load。 |
| 59 | future Mag target | 可扩展独立 candidate kind/strategy，UI 只消费候选；本次不实现 explicit reload/weapon chooser。 |
| 60 | B3/B4 | 未实现 scheduler、per-round load/unload、mag → weapon、旧弹匣目的地 planner 等后续逻辑。 |

## 最终验证

最终矩阵与 Main 原生操作分开串行执行，避免共享桌面鼠标相互干扰。Main 验收使用真实 InputEvent、native drag 和原有 UI handlers；fixture 仅存在运行时，未写场景或资源文件。

| 编号 | 要求 | 结果 |
|---|---|---|
| 61 | 原 3418 | 最终全部 3418/0；修改前基线与中途完整回归也均 3418/0。旧测试未修改。 |
| 62 | 新增 | 211/0，7 个新测试。 |
| 63 | 总数 | 3629 passed / 0 failed，79 组运行，所有进程成功退出且具有结果行。 |
| 64 | Parser | 161 个生产与测试脚本逐个 check-only，0 issues；新增 transfer 断言后的该脚本另行 check-only 也通过。 |
| 65 | Runtime | 最终矩阵 0 Runtime Errors；最终 Main run token 9 的 current_run_errors 为空，game/editor 日志无错误。早期测试 fixture 用已移除的 damage 字段已改为 flesh_damage；临时诊断 runner 在 UI 创建前访问节点的错误不在生产文件中，该诊断方式已弃用。历史日志保留。 |
| 66 | Warning | 最终矩阵 0 warnings；最终 Main game/editor 日志 0 warnings。一次临时 MCP 检查片段额外带了未使用的 point/go/click，产生三个 UNUSED_VARIABLE；删除不需要的 helper 后重新检查无新增警告，并以全新 Main 验证。历史记录保留，未关闭 warning 或调用清日志工具。 |
| 67 | Main same-grid | 通过，actual Ammo (0,0) → (0,1)，Ghost 可见、Preview 可见、提交到显示位置、释放后清理。 |
| 68 | Backpack internal | 通过，双击装备 Backpack 开窗，actual Ammo (0,1) → (0,2)，Ghost/Preview/提交一致。 |
| 69 | Main → Window | 通过，Pocket → nested B Window (0,0)，相同真实 Ammo。 |
| 70 | Window → Main | 通过，A Window 与 B Window 均真实拖回 Pocket；Ghost 始终在 global overlay。 |
| 71 | A → B Window | 通过，B → A (0,3)，A → B (2,2)；真实格位与 Preview 相同。 |
| 72 | Closed Deposit | 通过，关闭 B Window，Pocket Ammo → A 中 B 外部 4×5 footprint，green content target；直接进入 B (0,0)，不自动开窗；再双击 B 看见同一个 Ammo。 |
| 73 | no-space | 通过，B 用 5×5 blocker 填满，红色 NO SPACE、Ghost 可见，释放后 Pocket 原 Ammo 不变。fixture changed 后等待 UI 布局完成再开始真实拖拽。 |
| 74 | no-descendant | 通过，B 中 C 占 4×5、其余 1×5 填满，C 内空；仍红色 NO SPACE，源不变。 |
| 75 | cycle | 通过，A → 内含的 B，红色 CYCLE OR DEPTH，装备 A 未变，释放清理。 |
| 76 | Manual Rotate | 通过，2×3 Item → 内部 3×2 target 首先 NO SPACE、实际未旋转；真实 R 后 green，释放后 actual Item 旋转并直接进入目标 (0,0)，原来源格位移除。 |
| 77 | Short F | 通过，实际 WORLD Backpack 当前 4×5 放不下、旋转 5×4 可放；真实短按 F 拾取，actual Item rotated=true，WORLD ownership 撤销，UI 保持关闭。 |
| 78 | Crate → Closed | 通过，真实 Crate Ammo → Window、Window → Crate，再 Crate → closed nested B；最终对象相同、直接 parent=B、owner=Player，无根包中转/no auto-open/no lease。 |
| 79 | same-slot | 通过，装备 A 真实拖回自身槽，successful equipment no-op、changed 事件 0、A 与窗口保留。 |
| 80 | weight | Main 同 registry closed deposit 9.75 → 9.75 kg。Crate Ammo mass 0.48，Player 9.75 → 10.23、Crate 5.51 → 5.03。真实 R 前/中/后 8.238；Arms R 8.226（基础 2.0 ×1.35）；RR 前/中 8.214，WORLD 6 →7 后 7.716，原 outgoing Magazine mass 0.498。旧 Split/Transit 回归通过。 |
| 81 | cleanup | 最后 Main Ghost=0、Preview hidden、drag context/data clear、selection/highlight clear、窗口=0、UI closed。 |
| 82 | addon | 最终 SHA256 313/313 不变；旧 tests/data/scenes 178 文件 SHA256 全部不变；git diff --check 通过。 |
| 83 | Main final | token 9，test_level 主场景保持运行；8.25 kg、MAG29/CH1、AUTO/READY、两只备用 Magazine 各30、背包 Ammo60、WORLD6、Overall150、无伤势、无锁/lease，Player/Firearm physics 均启用。 |
| 84 | 技术债 | 没有 deferred Minor；drag-edge auto-scroll 未增加（用户明确无需）。窗口继续通过 manager close API 操作。原生 UI 自动化存在桌面鼠标/布局时序敏感性：保留两轮失败记录，最终矩阵和 Main 分开运行均通过；未修改旧测试来规避，不据此声称已消除所有平台级自动化波动。 |
| 85 | B3 blocker | 未发现本阶段结构性 blocker；legacy fallback 清理和 per-round scheduler 仍留在明确后续范围。 |
| 86 | 建议进入 B3 | 本阶段可提交人工审核；审核通过后可进入 B3，本轮已停止。 |
| 87 | legacy fallback | legacy runtime-first、1×1 magazine fallback cleanup 保持既有状态，未清理。旧 LOAD 路径冻结，不借本阶段重写。 |
| 88 | Attachment | 未实现。 |
| 89 | Character Stats | 未实现；未改变重量、移动、枪械数值。 |
| 90 | Git | 未 commit/push/tag/reset，未创建 worktree，变更留在当前工作区供审核。 |

## 评审处理与证据

一次最终独立评审发现两项 Important：滚动隐藏容器可通过窗口 chrome 选中；低层 Preview 会绘制到上层窗口 title。补充检查另找到视觉目标窗口关闭未取消子容器候选，以及 same-location no-op 跳过来源 alias 校验。11 项回归先出现 7 项失败，修复后全部通过，含实际像素检查；没有留待以后修复的 Minor。

实施取舍：保留 native drag 和旧 anchor 查询 API，但 anchor 不绘制；代价是 native/可见对象生命周期需要共同清理，已用原生测试覆盖。保留 standalone Preview 的旧越界 contract，UI 显式开启格内红色无效预览；代价是未来 standalone 调用者需明确 opt-in。装备自身同槽成功 no-op、Grid 容器自身 footprint 为 self-invalid，遵循两项明确规则。外部窗口关闭继续使用 manager contract；任意外部直接销毁的扩展不在本轮范围。

审计目录：`C:\Users\疯狂\AppData\Local\Temp\codex-fps-phase11-1b25-audit`。保存基线、各轮矩阵、parser、MCP 操作、hash 与进度 ledger；历史失败不删除。第一轮矩阵与 Main 同时共享桌面鼠标，导致一个 native drag 测试失败，已停止 Main 后改为串行。第二轮出现 old Vicinity 原生拖拽偶发失败，诊断和独立复跑 30/0；未定位到可复现的生产状态逻辑缺陷。最终不改代码/旧测试再跑完整矩阵：3629/0。Main fixture 改变后等待布局完成，最终全部原生验收成功。不把中途失败隐去，也不将它们计入通过断言数。

最终证据：`release-results.json` 与 `release-*.log`（79组），`parser-result.txt` / `parser-*.log`，`hash-audit.json`，`mcp-release-routes1/2.log`、`mcp-release-rejects.log`、`mcp-release-rotate.log`、`mcp-release-shortf.log`、`mcp-release-crate.log`、`mcp-release-weight-r/arms-r/rr.log`、`mcp-release-pristine-verified.log`。中途失败另存 `first-matrix-*`、`second-matrix-*` 与独立诊断日志。最终 Main 验收计入操作证据，不重复加到 assertions 总数。
