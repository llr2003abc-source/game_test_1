# Phase 10.1 验证报告

Godot 4.7.2 / Test_1。已完成，包含一次独立终审、两项缺陷修复、修复后全量回归，以及 Main MCP 实际鼠标复验。

## 35 项结果

| # | 项目 | 实现与验证 |
|---|---|---|
| 1 | 两个长枪槽 | PRIMARY / SECONDARY 枚举保留，两槽共用长枪类别与 WeaponRuntime 兼容规则；UI 为 WEAPON SLOT 1 / 2。 |
| 2 | Weapon1 兼容性 | 实际 ItemDefinition 的 allowed_equipment_slots 为 [0,1]；PISTOL、KNIFE 仍拒绝。自定义资源明确声明的限制保留。 |
| 3 | 1 / 2 切换 | 测试及 Main MCP 真实按键均通过：Slot2 绑定原 CH1/MAG17/AUTO，Slot1 恢复原 CH1/MAG29；没有重新初始化运行时。 |
| 4 | 浮动预览根因 | 父 DragSurface 仍会解析近邻网格；非法 raw cell 留在 candidate 中，旧渲染器只排除 kind=none，仍绘制 INVALID placement。 |
| 5 | 越界原因 | preview_rect 直接由 grid_origin + cell × cell_size 计算，没有检查 footprint 是否位于目标网格内。 |
| 6 | 修复 | 传入真实 grid_rect；无合法 raw / snap 的 placement 不渲染；所有网格 footprint 必须被 grid_rect 完全包含。保留 Ghost 和候选状态，未使用 clip_contents 掩盖问题。 |
| 7 | 8 / 16 / 17 px | 非法 raw 的有效近邻：8、16 px 吸附并显示网格内预览；17 px 不吸附且隐藏格子预览，Ghost 保留。合法 raw 继续优先，不因指针靠边而人为失效。纯逻辑及真实原生拖拽覆盖 Rig、Backpack、Secure、1×2 / 5×2。 |
| 8 | PickupPreviewResult | RefCounted 保存 can_accept_all、accepted_count、remaining_count、reason；NONE / NO_SPACE / PARTIAL_SPACE / INVENTORY_LOCKED / INVALID_TARGET。纯查询，不发送 changed 或修改弹量、位置。 |
| 9 | 满包提示 | 只读预览 accepted_count=0 且 NO_SPACE 时显示“背包已满”、F 拾取和长按 F 管理附近物品。 |
| 10 | 部分空间 | 显示“空间不足：可拾取 10 / 60”；同一自动放置计划用于预测和提交。 |
| 11 | F Resolver | 独立 InteractionInputResolver 记录按住、计时和目标弱引用；短按松键提交一次，长按取消短拾取并请求管理 UI。忽略 echo。 |
| 12 | Hold 阈值 | Inspector 默认 0.35 秒。0 / 0.34 秒松键短拾取；0.35 / 0.50 秒只管理一次。纯逻辑与实际 Interactor 均验证。 |
| 13 | 取消条件 | 目标改变、超距、删除、所有权改变、其他途径打开库存、鼠标释放、Reload lock、Esc；取消后松键不会补发拾取。 |
| 14 | Vicinity Mode | 复用现有 InventoryUI、装备、Rig、Pocket、Backpack、Secure、Ghost、旋转、Snap 和预览；普通 Tab 模式保持。 |
| 15 | Nearby 布局 | 右侧 8 列虚拟格子；至少 6 行，随物品增长；ScrollContainer 可实际纵向滚动，目标物品黄色描边。稳定列表不会每帧重建控件。 |
| 16 | 范围 | Nearby 以角色位置测距，默认 3 m，2.9 / 3.0 可见，3.01 不可见。Short F 继续从摄像机按原 2.5 m 验证。 |
| 17 | 墙体过滤 | 摄像机到物品的 World / TargetBody 射线被阻挡则排除；墙后 2 m 不显示；提交时重新查询当前范围与遮挡。 |
| 18 | 所有权 | Nearby 只有展示引用，未创建或注册 InventoryGrid；物品 location 始终 WORLD，直到正式事务成功。 |
| 19 | Virtual Grid | 按实际尺寸与 rotation 确定 footprint，以确定性的逐行 first-fit 排列；显示格子不映射 3D 坐标。按下鼠标后若刷新改变该位置或物品身份，取消此次待开始的拖拽，避免换成另一件物品。 |
| 20 | WORLD → Player | 显式 grid / cell / rotation / equipment / merge / load 入口；UI 提交重新验证 WORLD、范围、遮挡及 lock；失败不迁移。 |
| 21 | Player → WORLD | 使用既有 drop_item_to_world 事务和 WorldItemFactory，移除原位置后建立唯一 WORLD 所有权与世界表现。 |
| 22 | Nearby → Rig | 实际鼠标验证同一 MagazineInstance 17 发进入指定 Rig，立即增加 Reload candidate。 |
| 23 | Nearby → Backpack | 满包腾出 1×2 空间后，实际鼠标把同一 17 发弹匣拖入背包；提交格子与显示候选完全一致。 |
| 24 | Nearby → Slot1 / 2 | 通用长枪策略支持两槽；实际世界枪进入 Slot2 保留 CH1/MAG17/AUTO，Slot1 active 不被自动替换。 |
| 25 | Inventory → Nearby | 实际鼠标拖放成功，每次恰好一个 World Visual；生成在前方约 0.8 m、轻微横向偏移、向下射线落地，位于玩家碰撞体外。提交前检查通向落点的 World / TargetBody 射线；墙体阻挡时拒绝并保留原物品，不将它传到墙后。Nearby → Nearby 不支持重排。 |
| 26 | Runtime identity | ItemInstance、WeaponRuntime、MagazineInstance、Container Runtime 均复用原引用；Round 顺序、Chamber 和 FireMode 不复制或重置。 |
| 27 | Secure | 明确的 Nearby 拖入可用 Secure；普通 F 自动拾取仍排除 Secure。手动 17 发弹匣进入 Secure 已验证。 |
| 28 | Reload Lock | 锁定时长按不能打开可编辑 Vicinity；已缓存的绿色候选也无法绕过提交时锁检查；显示“当前无法整理”。 |
| 29 | 满包完整流程 | Main MCP 实际运行：满包提示 → Hold F → 附近目标和另一件 Loot → 两次背包拖出生成 WORLD → 腾空间 → 原弹匣17拖入背包 → 再进 Rig 成为 Reload candidate。 |
| 30 | 原回归 | 原 2168 项全部通过。四处旧测试只调整 fixture：F press 加 release；三处 bag/full 测试先占满两个长枪槽。断言数量与原运行时保障保持。 |
| 31 | 新增断言 | 389 项，9 个测试套件，全部通过；含独立审阅后新增的 15 项安全回归。 |
| 32 | 总计 | **2557 assertions passed，0 failed，50 次测试运行**（含 HITSCAN / PROJECTILE）。 |
| 33 | 解析 / 运行 / 警告 | **108 个 .gd --check-only 全通过，0 parser errors / warnings**。全套测试 0 runtime errors / warnings；Main MCP 实际鼠标操作与 Editor 新增日志均无错误或警告。结束时重新启动正常 Main，清除临时测试状态。 |
| 34 | Addon | addons/godot_ai：313 / 313 SHA256 unchanged。 |
| 35 | 原规则 | 未修改 WeaponRuntime、Firearm、Reload、Damage、Armor、Movement、Acoustics 生产规则；相关 27 个原文件哈希不变。改动仅限本阶段兼容性、库存交互、展示和可选横向 Drop 偏移。无 commit / push / tag。 |

## 文件

修改生产文件：data/items/primary_weapon_1_item.tres；scripts/inventory/{equipment_component,dropped_item,inventory_transaction_service}.gd；scripts/items/world_item_factory.gd；scripts/player/player_interactor.gd；scripts/ui/{inventory_ui,inventory_placement_preview}.gd。

新增生产文件：scripts/inventory/{pickup_preview_result,vicinity_loot_query}.gd；scripts/player/interaction_input_resolver.gd；scripts/ui/{vicinity_loot_layout,vicinity_loot_panel}.gd，以及 Godot 生成的对应 .uid。

调整旧测试的准备条件：tests/{pickup_placement_policy,player_interaction,world_loot_gameplay,world_runtime_persistence}_test.gd。

| 新测试 | 通过数 |
|---|---:|
| long_gun_slot_test | 15 |
| placement_preview_bounds_test | 99 |
| pickup_preview_transaction_test | 25 |
| interaction_input_resolver_test | 26 |
| vicinity_loot_test | 34 |
| vicinity_ui_test | 30 |
| interaction_hold_integration_test | 43 |
| placement_preview_native_test | 102 |
| vicinity_safety_test | 15 |
| **合计** | **389** |

## 独立终审修复

终审只进行了一次，发现两项 Important/P2，无 Critical、Minor 或搁置项。新增 vicinity_safety_test 先在旧实现下复现 8 个失败，再经最小修复得到 15 / 15 通过，0 错误或警告；随后重新执行全套 2557 项，通过。两项修复均经 Main MCP 实际鼠标操作复验通过，未再次派发审阅。

- 靠墙 Drop：只在新的 UI WORLD drop 提交前增加遮挡检查；阻挡时拒绝、不改变所有权，也不生成世界表现。未改变现有 Reload 的落点计算行为。
- Nearby 按下后刷新：保存原按下物品与 placement 起点，开始拖拽前同时核对；被替换、删除或移位时取消。稳定布局继续保留原 grab offset。

测试和 Main MCP 输出证据保存在 `%TEMP%/codex-fps-phase10_1-audit`。首次全矩阵的三项旧长时间测试达到人为 1200 帧停止上限后，已提高运行上限到 6000 帧完成验证；未通过改变生产逻辑或隐藏错误处理这一测试运行器问题。

## 实施判断

1. 用户完整规格作为直接实施授权，在当前编辑器工作目录修改并保留未提交成果；如果撤回，需要还原这些本地改动。
2. 两槽统一类别兼容，但保留其他资源显式 allowed_equipment_slots 限制；实际 Weapon1 允许 [0,1]。其他刻意受限资源仍需修改自身定义才能扩展槽位。
3. 原测试保留断言数量，按新 F 松键语义及两槽兼容性调整四处准备条件；比较的是等价场景，而非已经被本阶段替换的旧输入或单槽假设。
