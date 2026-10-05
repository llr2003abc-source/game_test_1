# Phase 9.1 — Inventory Drag UX 报告

范围仅为库存拖拽 UI。WeaponRuntime、MagazineInstance、Reload、弹药兼容、Damage、Armor、Movement、Acoustics、InventoryGrid 和 Transaction 均未修改。未进行 commit、push 或 tag。

1. **原问题根因**：GridView 把鼠标所在格直接当成物品左上格，没有保存物品内部抓取偏移；原 Ghost 也以鼠标为左上角。抓住弹匣下半部时，候选位置因此向下错一格。

2. **文件变更**：修改 `scripts/ui/inventory_ui.gd`、`inventory_grid_view.gd`、`inventory_equipment_slot.gd`。新增 UI 文件 `inventory_drag_context.gd`、`inventory_drag_candidate_resolver.gd`、`inventory_drag_ghost.gd`、`inventory_placement_preview.gd`；新增测试 `tests/inventory_drag_candidate_test.gd`、`inventory_drag_ux_test.gd`，以及相应 Godot `.uid`。文档为本报告及 `docs/superpowers/plans/2026-10-05-phase9_1-drag-ux.md`。

3. **Grab Offset**：保存实际 LMB 按下位置，减去原物品矩形左上角得到像素偏移。Context 引用原 Item、来源 Grid/Equipment、原位置及原旋转，不复制物品或运行时状态。

4. **Ghost**：独立 Control 绘制半透明矩形，显示完整名称、弹药数量或弹匣实有发数及当前旋转尺寸。它只读取 Context，不拥有或修改 Gameplay state。

5. **鼠标锚点**：`ghost_top_left = mouse_global_position - grab_offset_pixels`。Main 实测上、中、下抓取偏移分别为 `(24,12)`、`(24,48)`、`(24,75)`，Ghost 一直保持对应偏移。

6. **旋转锚点**：记录抓取点在原尺寸中的归一化 `(u,v)`，按 R 用新尺寸重算像素偏移。例如弹匣 `(24,75)` 从 1×2 转为 2×1 时变为 `(48,37.5)`；再次旋转恢复原值，重复旋转无累计漂移。真实 Item.rotated 只在事务成功后改变。

7. **Placement Preview**：单独绘制候选落点覆盖层，读取统一 resolver 的结果；不调用 place/remove/move。离开全部容器后隐藏，Ghost 仍存在至拖拽结束。

8. **合法性反馈**：绿色表示 VALID，红色表示 INVALID，并显示 LOAD、MERGE 或设备整槽反馈。Ghost 和覆盖层均使用 `MOUSE_FILTER_IGNORE`。

9. **完整 Footprint**：弹匣显示 1×2，旋转显示 2×1；Weapon 显示 5×2，按 R 立即显示 2×5。覆盖层位于原物品之上，原位置仅视觉变暗。

10. **候选解析**：`InventoryUI.update_drag_candidate()` 统一选择目标，`InventoryDragCandidateResolver` 解析 Grid/Equipment。Grid 用 Ghost 左上角相对目标 Grid 的坐标，按 floor 映射原始格；负坐标不会被截断为零。

11. **预览与 Drop 一致**：Context 保存完整候选字典。原生 `_drop_data()` 只提交已显示的 Grid、cell、rotation 或交互目标，不重新使用鼠标格计算。最终仍由原 Transaction 验证并原子提交。

12. **Snap Radius**：默认 **16px**，Inspector 调整范围为 12–18px；48px 的格子没有使用整格强吸附。

13. **候选搜索**：合法 raw 立即返回，不吸附。非法 raw 仅检查相邻八格，像素欧氏距离必须 `<=16px`；每个 Grid 至多 raw 加八个邻格，禁止全空间找空位。

14. **最近与稳定顺序**：选择屏幕距离最近的合法候选；距离相同保留固定行优先顺序。测试使用 20px 格子构造两个同时位于 16px 半径内的候选，验证最近及重复运行的稳定性；实际 UI 保持 48px。

15. **Rig 吸附**：每个独立 1×2 Grid 单独解析。轻微偏出边缘时显示整个槽的落点；鼠标处于格间空隙时，父级 DragSurface 也能接收合法的小范围 Drop。

16. **不跨 Rig 槽**：每次候选只属于一只 InventoryGrid，并调用其原 `can_place()`。2×2、旋转后的 2×1 弹匣、已占用槽都不会绕过规则；不会偷偷旋转回来。

17. **Ammo → Magazine**：鼠标命中弹匣任意格，整只弹匣高亮 LOAD；兼容性、剩余容量和 reload lock 均纳入只读预览。释放调用原 `load_ammo_into_magazine()`。Main 实测 17→30，散弹药 60→47。

18. **Stack**：相同 item_id 且存在容量时，整组目标高亮 MERGE；满组或不同 ID 显示非法，不混用 Grid footprint。Main 实测 27+20→47，合并后背包只保留一组散弹药。

19. **Equipment**：整槽高亮，没有 Grid Snap。Main 实测 Weapon→Primary 合法，Weapon→Pistol 非法；取消后原 WeaponRuntime 保持装备。优先级为 Grid 内特殊 LOAD/MERGE，再 Equipment，最后普通 placement。

20. **Cancel 与数据更新**：ESC、Tab、非法 Drop 或外部库存变化会移除 Ghost、覆盖层和来源变暗效果。拖拽开始不提前移除真实物品。独立审阅发现的“外部变化导致旧预览残留”已用测试复现并修复：只对当前 Drop 自身的通知延迟刷新，其他变化取消拖拽并刷新，保留外部事务结果。

21. **上/中/下抓取测试**：自动测试包含真正 LMB 按下、拖动和松开，也包含原生 force_drag 测试。三种抓取均提交原 Item 到相同 cell `(0,0)`。Main MCP 再次验证三种实际鼠标拖拽成功，开始至释放前来源保持不变。

22. **Rotation 测试**：验证预览尺寸和 offset 立即更新、真实 rotation 不提前变化、重复 R 无漂移、旋转弹匣不能进 Rig，以及合法旋转 Drop 同时提交移动和旋转。Main MCP 实测 Weapon 5×2→2×5→5×2，并通过 ESC 取消。

23. **8/16/17px 边界**：自动与 Main MCP 实测均为 8px 吸附、16px 吸附、17px 不吸附；非法释放保留来源物品。另测占用、过大误差、合法 raw 不吸附、稳定 tie 和格间空隙释放。

24. **原 1747 项回归**：原有 18 次旧阶段测试合计 1449，Phase 9 的 14 套测试合计 298；预期结果没有修改。覆盖 FPS、Hitscan/Projectile、伤害与护甲、身体健康/伤势、声音、WeaponRuntime、弹匣、换弹和库存事务。

25. **新增 Assertions**：候选逻辑 70 项，渲染/原生拖拽与事务集成 75 项，合计 **145**。其中新增的外部目标占用、来源转移和弹药数量变化测试经历明确 RED→GREEN。

26. **总数**：**1892 assertions passed，0 failed**（1747+145）。

27. **Parser / Runtime / Warning**：80 个项目及测试 GDScript 通过 `--check-only`。最终完整测试输出及新 Main 运行检查无 Parser Error、Runtime Error 或 Warning。开发中使用旧 Transform2D 接口的解析错误已修复；MCP 临时探测表达式问题也已修正后重启验证，没有隐藏或关闭警告。

28. **Main MCP 验证**：Tab 打开库存；弹匣三种真实抓取和落点；Ammo/Magazine/Weapon Ghost；Weapon Footprint 与 R；8/16/17px；LOAD、MERGE、Equipment；ESC 清理均已验证。最终游戏重新启动，清除测试夹具造成的运行时库存变化，保持正常主场景运行。

29. **Addon 保护**：`addons/godot_ai/` **313/313** 文件 SHA256 不变；额外保护的 Gameplay、资源、场景及 project.godot 共 **72/72** 文件 SHA256 不变。

30. **Gameplay 规则**：未修改 WeaponRuntime、MagazineInstance、单/双 R、战术/丢弃换弹、Rig-only reload、兼容规则、碰撞、伤害、运动或声音。所有 placement/load/merge/equip 最终仍调用原事务。

实施取舍及代价：

- 按已完整指定的需求直接实施，并沿用当前 Editor 工作副本；未建立隔离分支。若用户撤回，需要撤销这些本地可逆改动。
- raw 使用 floor，合法 raw 优先；旋转采用归一化锚点；非法 raw 才进行 16px、固定行优先吸附。合法但未贴齐边缘的位置不会被“纠正”到另一格，符合精准放置优先的要求。
- 保留旧显式 cell UI 帮助函数供既有测试使用，真实鼠标 Drop 则提交统一缓存候选。未来直接调用帮助函数时，要区分 cell API 和鼠标坐标 resolver。
- 由 UI 父容器接收格间空隙 Drop；目标检测扫描控件矩形，实际 placement 搜索始终局部。未来更换 UI 层级时，需要保留可接收这种 Drop 的父级控件。

独立审阅无 Critical、Minor 或未判定事项；一个 Important 已经用 RED→GREEN 修复，并完成全套回归。没有遗留的审阅问题。证据和实施记录保留在本地，未创建 Git 提交。
