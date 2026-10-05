# Phase 11.1A — Same Equipment Slot No-op Fix

验证日期：2026-10-06。Godot 4.7.2 stable，项目 Test_1。

最终结果：原 2822 项 + 新增 171 项 = 2993 assertions passed，0 failed。最终顺序矩阵 59 次运行全部成功；123 个项目/测试脚本逐个 check-only 通过。Main 实际鼠标操作及游戏/编辑器输出检查通过。

1. **原问题的失败路径**：`InventoryEquipmentSlot._drop_data()` → `InventoryUI.commit_drag_candidate()` → `drop_on_equipment()`。旧 Container 模式把玩家自己的装备交给 `ExternalInventoryTransfer.transfer()`，后者先调用 `_valid_pickup_destination(..., true)`；这个拾取目的地检查要求装备槽为空，因原物品仍占着自己的槽而返回 false，尚未进入已有的 `equip()` 同物品分支。

2. **绿色 Preview 与失败 Transaction 的原因**：`InventoryDragCandidateResolver.resolve_equipment()` 允许兼容槽中为 null 或当前同一物品，所以绿色正确；提交错误地使用外部拾取的严格空槽预验证。此次保留 Preview，修正提交路由和事务判定。

3. **修改、新增文件**：no-op 修复涉及 `scripts/inventory/inventory_transaction_service.gd`、`scripts/inventory/external_inventory_transfer.gd`、`scripts/ui/inventory_ui.gd`。Main 启动实际发现 5 条既有命名警告，因此还对 `scripts/inventory/inventory_item_factory.gd`、`scripts/ui/inventory_grid_view.gd` 和前述 UI 文件做了局部变量/参数重命名；没有改变这些警告涉及的算法。新增 `tests/equipment_same_slot_noop_test.gd`、Godot 生成的同名 `.gd.uid`、本报告。没有修改原测试或场景。开始时已有的 `project.godot` 修改保持字节不变。

4. **Same-slot 条件**：经过锁、inventory 和 slot compatibility 检查后，目标持有 exact same `InventoryItemInstance`；该实例属于当前注册表且仍已登记；实际 location 为 equipment；实际 source slot 等于目标 slot。任一条件不满足都不能视为 no-op。

5. **判定层**：最终判定在 `InventoryTransactionService.equip()`，发生于 `register_item()`、`_clear_location()`、槽位写入、旋转重置、changed 信号之前。`ExternalInventoryTransfer` 在访问授权有效后，把同注册表装备操作委托给这个事务，而不是先套用外部拾取的空槽检查。

6. **没有 UI 掩盖**：UI 按物品的实际 owner registry 路由玩家自己的装备操作，不按“同槽”强行报告成功；真正的 identity/location/slot 判定仍由事务负责。测试直接调用事务和 External transfer，均须返回成功。失效访问会话及锁仍在 UI 和 External 入口被拒绝。

7. **返回值**：same-slot 成功返回 bool `true`，非合法 no-op 继续原有验证/真实移动逻辑。没有先移除再装回。

8. **Result 结构**：未新增 NO_OP result 类型，未重构结果体系；当前 bool 接口足以表达成功，零 mutation/signal 表达状态未变。

9. **Ownership**：前后 item identity、owner registry、实际 location、slot、rotation 完全相同。测试用真实事务子类记录注册、提交注册、释放注册、清位置调用，同槽情况下全部为 0。

10. **WeaponRuntime identity**：同槽前后引用和 instance ID 不变。自动测试还保留非零 cooldown、非默认 SEMI 状态，避免只验证初始值。

11. **MagazineInstance identity**：loaded magazine 引用和 instance ID 不变，rounds 的数量、顺序及 AmmoData 引用不变。

12. **CH/MAG/FireMode**：同槽前后保持；cooldown、reload state/type/remaining 同样保持。另设真实 runtime 换弹中快照验证。Main 同槽实操均为 CH1 / MAG29 / AUTO，不发生装填或重置。

13. **Firearm binding**：同槽前后绑定同一 runtime，不解绑、不重绑、不自动选择别的 active slot。实际 Firearm 的 `weapon_state_changed` 在两个 Main no-op 中均为 0；已有 bind/unbind 流程会发布该信号，因此这种回归能发现重复 binding。

14. **Signals 与 UI**：同槽的 registry.changed、inventory.inventory_changed、Firearm.weapon_state_changed、WeaponRuntime.state_changed、external runtime.changed 全部为 0。装备 Control 引用保持，未排队重复 refresh。原 Drag End 流程正常清理 ghost/highlight/source dim/context。

15. **Slot1→Slot1**：Preview VALID；提交 true；物品、runtime、magazine、active slot、binding 不变；原生鼠标释放后拖放状态正常结束。

16. **Slot2→Slot2**：上述 no-op 规则同样通过。Main 中先真实移到 Slot2 再拖回 Slot2，未自动把 active slot 从 Slot1 改成 Slot2。

17. **Slot1→Slot2**：空槽情况下真实移动成功，source 清空、target 为原实例、location 改为 Slot2，发出正常 mutation 通知。Main 原 active Slot1 被移空时按既有规则解绑；此处是正常真实移动，不能要求零信号。

18. **Slot2→Slot1**：自动测试验证真实移动成功，source/target/location 改变、registry 通知一次、原 WeaponRuntime identity 保留；不是 no-op。

19. **Rig**：三个 UI 模式和直接事务入口均验证同槽 true。内部 grid、placement、item、MagazineInstance、rounds 引用/顺序保持，没有递归注销或重建。

20. **Backpack**：三个 UI 模式和直接事务入口均验证同槽 true。内部 grid、placement、item、stack 状态保持。

21. **Identity 与 Definition**：A/B 共享同一个 ItemDefinition，拥有不同 InventoryItemInstance/WeaponRuntime。B 放入 A 占用的槽仍失败；不通过 display_name、item_id、WeaponData 或资源定义判断同物品。

22. **Occupied 回归**：不同实例占槽继续失败且两者状态保持；拖拽途中 source 被另一实例替换的 stale candidate 失败；兼容性失效、锁、null/非法槽、foreign owner、实际 grid location 被伪装成装备的情况均拒绝。WORLD 或 CONTAINER 来源不能伪装成 same-slot no-op。

23. **Container Mode**：六类装备全部通过 same-slot Preview/commit/状态/信号/清理验证。玩家自己的装备直接路由玩家事务；真正外部来源继续 External transfer。原 Container range/LOS/closed/access/reload lock 测试保持通过。

24. **Normal Inventory Mode**：六类装备同槽行为全部通过；包含真正原生 mouse press/motion/release 验证，保留原 UI refresh 和 Drag End 行为。

25. **Vicinity Mode**：六类装备同槽行为全部通过；包含原生鼠标验证。WORLD 物品仍使用原 WORLD 拾取入口，不能被玩家注册表路由误判为 no-op。

26. **Container transfer 回归**：新增测试实际执行 Container→空 Slot2、Player Slot1→Container、Container→空 Slot1，验证原实例/runtime 和 active bind/unbind 保持原规则；Container→已占用 Slot1 继续拒绝。原完整组迁移、容器持久化和所有权测试未改且通过。

27. **原 2822 assertions**：修改前新跑基线 2822/2822；最终代码再次 2822/2822，0 failed。原测试文件 SHA256 全部保持，没有修改 gameplay expectation。FPS、伤势、Armor、Damage、Acoustic、WeaponRuntime、Reload、Hitscan/Projectile、World Loot、Vicinity、Drag UX、Container 测试均保留。

28. **新增 assertions**：最终正常渲染的 `equipment_same_slot_noop_test.gd` 为 171/171；其中包含三个 UI 模式的原生鼠标检查。开发时 headless 路径 159/159（不包含 12 项原生窗口检查），不把这次运行重复计入总数。新增测试先在修复前复现 15 项失败，再验证修复后通过；未向生产逻辑添加测试钩子。

29. **总 assertions**：2993/2993，0 failed，59 次顺序运行。原生窗口测试不并行运行，避免窗口焦点互相干扰。

30. **Parser / Runtime / Warning**：最终 123 个 scripts/tests check-only，0 parser errors、0 warnings。最终 59 次测试运行 0 runtime errors、0 warnings。最终 Main 游戏日志及编辑器 Debugger 错误/警告行均为 0。首次 Main 实操暴露的 5 条 CONFUSABLE_LOCAL_DECLARATION / SHADOWED_VARIABLE_BASE_CLASS 已通过重命名修复；没有 clear logs、关闭警告或 warning ignore。修复后重新跑完整 2993 项和全部解析检查。

31. **Main MCP 实际鼠标验证**：通过 Godot AI MCP 启动 Main，实际 F 搜索 LootCrateA，发送原生鼠标 press/motion/release，依次完成 Slot1→Slot1、Slot1→空 Slot2、Slot2→Slot2。两个 no-op 都为绿色、原引用/快照不变、五类信号为 0、无 UI 重建、ghost/highlight/dim/context 清理；事务提交入口复核 true。关闭界面后实际按 2，绑定原 runtime，CH1/MAG29/AUTO 保持；左键持有约 0.12 秒真实射出两发，MAG29→27、CH1/AUTO 保持，输出有 Projectile fired/impact 及 Hit，无错误。未绕过 Firearm 射击算法。验收结束重新启动 Main 恢复正常初始布局。

32. **Addon**：基线 313 个 `addons/godot_ai` 文件 SHA256 全部保持；未修改插件文件。验证证据保留于 `%TEMP%/codex-fps-phase11-1a-audit/`：baseline/release results、逐脚本 parser logs、最终 MCP native/fire/output logs、hash check。

33. **第二个技术债**：没有修改动态插入已含物品 Rig/Backpack 时内部 Grid 自动登记的行为。External 注册/完整组迁移及 LootContainerFactory/Runtime 相关实现保持；ItemFactory 仅局部变量重命名。该技术债仍留后续单独处理。本次没有 commit、push 或 tag。
