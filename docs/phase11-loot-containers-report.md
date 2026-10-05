# Phase 11 — Loot Containers 验收报告

项目：Test_1 / Godot 4.7.2。基线：69b107a（Phase 10.1）。所有改动保留在当前工作区；没有 commit、push、tag。最终顺序矩阵：原 2557 + 新 265 = 2822 assertions，0 失败，58 次运行。独立只读审查未发现 Critical / Important 问题。

1. **新增文件**：`scripts/inventory/loot_container_runtime.gd`、`loot_container_access.gd`、`external_inventory_transfer.gd`、`loot_container_factory.gd`、`loot_container.gd`；`scenes/containers/loot_container.tscn`；8 个新测试套件和测试专用 `tests/container_test_owner.gd`；本报告和实施计划。新脚本附带 Godot 生成的 `.uid`。
2. **修改文件**：`scripts/inventory/inventory_transaction_service.gd`、`dropped_item.gd`；`scripts/player/interaction_input_resolver.gd`、`player_interactor.gd`；`scripts/ui/inventory_ui.gd`、`inventory_grid_view.gd`、`inventory_equipment_slot.gd`；`scenes/levels/test_level.tscn`。原有测试文件未修改。
3. **LootContainerRuntime**：保存 `container_id`、`display_name`、`grid_size`、`inventory_grid`、独立的 `InventoryTransactionService`；事务变化转发 `changed`。没有 UI 引用，注册表反向弱引用 runtime，避免循环持有。
4. **场景结构**：根 `LootContainer:Node3D`，子节点 `Mesh:MeshInstance3D`、`PhysicsBody:StaticBody3D/CollisionShape3D`、`InteractionArea:Area3D/CollisionShape3D`、`DebugLabel3D`。BoxMesh/BoxShape 均为内置几何体。
5. **8×6 Grid**：每个箱子有一块连续的 8×6 格子，界面单格 48px，完整尺寸 384×288px。可以存放枪、弹匣、散弹药和带内容的便携容器。
6. **CONTAINER 所有权**：注册表保存真实物品和 runtime 引用；`get_location()` 返回 `kind=container`、实际 `LootContainerRuntime`、`InventoryGrid` 和 `InventoryPlacement`。没有用 UI、节点路径或名称猜测位置。
7. **与 WORLD 区别**：箱子不属于 InventoryItem，也不属于 `world_items`；箱内物品没有 DroppedItem。已装弹匣继续使用原来的 `weapon_magazine` 位置，跟随实际武器及其注册表。
8. **原子注册**：先验证所有初始布局、便携内容格子、完整注册组、重复物品、重复 runtime、越界及重叠，全部成功才一次提交所有注册和格子归属。失败不产生部分登记。
9. **物品唯一性**：每个原始 `InventoryItemInstance` 的弱所有者必须与登记注册表一致。两个箱子不能共享同一实例；完整组迁移后旧注册表移除所有成员。
10. **Runtime 唯一性**：沿用跨注册表的全局弱 owner 索引及各注册表 runtime 索引；同一个 MagazineInstance 或 WeaponRuntime 不能被不同 Item 包装并分别登记。
11. **F Search**：沿用 PlayerInteractor。提示为 `[F] Search Loot Crate A/B`；短按 F 在松开后打开界面。箱子不支持附近物品管理，长按后松开仍然只 Search 一次。
12. **交互范围**：沿用相机到交互中心 2.5m；2.49/2.50 可打开，2.51 不可。射线必须实际命中 InteractionArea，实体碰撞体不能代替交互区。
13. **墙体遮挡**：打开前和每次访问均重新进行 World 射线检查；箱子自己的实体不视作外部遮挡，其他墙体会阻止交互和操作。
14. **UI 模式**：现有 InventoryUI 增加 `PLAYER / VICINITY / CONTAINER_LOOT`；容器模式保留玩家左侧装备和库存，右侧展示当前箱子。
15. **右侧布局**：显示箱子名称和 8×6 格子，Container 模式不显示 Nearby 面板。测试验证完整矩形位于窗口可见范围。
16. **没有第二套 UI**：继续使用 InventoryGridView、InventoryEquipmentSlot、InventoryDragContext、Ghost、CandidateResolver 和 PlacementPreview。
17. **内部 Drag**：同注册表的移动仍通过现有 move；跨注册表只在 ExternalInventoryTransfer 内提交。原生鼠标拖拽实际验证了两个方向。
18. **Rotation**：R 在拖拽中仅改变预览；提交使用显示的 cell/rotation。非法旋转不改变原物品和布局，合法旋转关闭重开后保留。
19. **Stack/Split**：使用原有上限 60 的堆叠算法和 split；容器选中物品通过其实际注册表拆分，剩余数量和新堆叠都留在容器。
20. **Ammo Loading**：原装弹兼容与容量判断提取成共享内部算法；容器内及跨侧装弹均使用同一实现，没有创建新 MagazineInstance。
21. **Container → Backpack**：明确指定目标格子；成功迁移同一原物品，满格/越界拒绝；不使用自动拾取放置策略。
22. **Container → Rig**：17 发弹匣进入空 Rig 格后立即可用于换弹；移回箱子后不再是玩家备用弹匣候选。
23. **Container → Secure**：手动指定 Secure 格允许转移，仍遵守完整 footprint、兼容和容量规则。
24. **Container → Slot1**：沿用两把长枪的对等装备规则。持久性测试和空当前槽重装覆盖原运行时绑定，不重初始化。
25. **Container → Slot2**：原生拖拽和 Main 实操均验证；当前 Slot1 武器继续保持激活，按 2 后绑定新进入 Slot2 的原 WeaponRuntime。
26. **Player → Container**：支持玩家格子、装备和便携容器到明确箱子格子的原引用迁移。
27. **Active Weapon → Container**：装备槽清空，现有 PlayerInventory 更新取消 Firearm 绑定并隐藏 WeaponMesh；枪械状态存留在箱子中。
28. **WeaponRuntime identity**：完整武器注册组包括同一个已装弹匣的 Item 包装；迁移后 CH、MAG、fire mode、已消耗数量均保持。
29. **MagazineInstance identity**：包装、MagazineInstance、rounds 中每一个 AmmoData 引用和顺序保持，没有重新填满或替换。
30. **便携 Runtime identity**：Rig/Backpack 自身、内部格子和内部物品一起迁移；内部格子的事务归属更新，旧注册表移除这些格子。
31. **Mag17 → Rig → Reload**：Main 实际将两个 30 发备用弹匣拖入箱子，再将原 17 发弹匣拖入 Rig；关闭后按 R，Output 显示 Reloading/Reload complete，枪械装入同一个 17 发实例。
32. **Slot2 → Fire**：Main 实际拖枪到 Slot2、关闭、按 2、左键开火。原 AUTO 枪实际发射两发，MAG17→15，CH1 保持；Output 记录 Projectile 发射、命中箱子的 PhysicsBody 和 HitMarker。
33. **Partial merge**：自动测试 C20→P50 得到 P60、原 C10；原生 UI 也验证部分转移后源仍在箱子。
34. **Reverse merge**：自动测试 P20→C55 得到 C60、原 P15；原生 UI 反向堆叠遵循同一数量守恒。
35. **无 WORLD 中间态**：完整组直接在两边注册表之间迁移；事务没有调用 WorldItemFactory。Main 所有拖拽、换弹和满背包交换期间 WORLD 数始终为原 6。
36. **失败回滚**：访问、源位置、目标 footprint、装备、完整组和唯一性检查都在修改前完成。失败保持原位置、数量、rotation、runtime 和所有权。
37. **Full Container**：完整 8×6 占满后的重叠/越界转移全部拒绝，原 PLAYER Magazine17 和所有弹药引用保持。
38. **Full Player**：明确目标满格拒绝，箱内原物品不变。Main 实际填满 Backpack，先拖出一个 5×2 测试块到箱子，再将原枪拖入腾出的格子，期间无临时 WORLD。
39. **Access Range**：箱子导出 `access_range=3.0`；以玩家身体位置到箱子根位置计算，2.99/3.00 有效，3.01 无效。
40. **Open Range**：2.5m 相机交互范围与 3.0m 身体访问范围分别验证，打开后不要求继续瞄准箱子。
41. **Access lost**：移出范围后关闭 UI、取消 drag、清除 session；缓存绿色候选也不能提交。Main 实际移出范围后上述状态全部清除。
42. **Occlusion lost**：打开后新增遮挡墙也会关闭界面并拒绝旧候选；不穿墙整理库存。
43. **Deletion**：节点 queued-for-deletion 即拒绝提交；释放后 session 清空、drag 清空，UI 生命周期退出也断开武器和库存监听。
44. **Reload Lock**：换弹期间 F Search 拒绝；跨注册表在同一同步提交期间锁住两边，通知回调内再次移动被拒绝，完成后释放锁。
45. **Close/Reopen**：Tab/Esc 关闭，断开外部 runtime listener；箱子节点继续持有原 runtime。重开保留移动、旋转、堆叠、实际引用。
46. **Crates independent**：A/B 各自有独立 runtime/注册表/格子/实例。A 初始 Ammo40/25、Mag30/17、GunCH1MAG17；B 初始 Ammo55/15、Mag12，布局不同。Main 操作 A 后 B55/12 不变。
47. **Vicinity 回归**：原 WorldItem 长按 F 继续进入 Nearby；箱子及内容不进入 Nearby。
48. **World Loot 回归**：原 WorldItem 短按、自动放置、部分拾取、WORLD 注册和掉落行为保留。
49. **Drag UX 回归**：原 grab offset、rotation、raw 优先、16px snap、特殊 LOAD/STACK 优先和完整 preview 边界保留。
50. **WeaponRuntime 回归**：原状态、chamber/cycle、SEMI/AUTO、RPM、混装弹药、持久化逻辑源文件未改。
51. **Reload 回归**：原 Rig-only 候选、tactical/drop、同一 loaded wrapper 和换弹计时逻辑未改。
52. **Damage 回归**：Ammo/Armor/Hurtbox/Body Health/Overall Death/Injury/Reset 的既有生产源文件未改。
53. **Acoustic 回归**：ActorNoiseEmitter、声音总线和真实开枪事件规则源文件未改。
54. **原 2557 assertions**：最终顺序矩阵 2557/2557 全部通过，原测试文件未修改。
55. **新增 assertions**：265/265，0 失败。
56. **总 assertions**：2822/2822，0 失败，58 次运行。
57. **新套件**：runtime 18、ownership 19、interaction 25、transfer 34、runtime_persistence 36、ui 45、gameplay 38、safety 50，均 0 失败/错误/警告。
58. **Parser**：122 个项目/测试 `.gd` 在最终代码上逐个 check-only，Parser Error 0，Warning 0。
59. **Runtime/Warning**：最终 58 次测试运行 Runtime Error 0、Warning 0；Main 实操游戏日志和该次运行的 Editor 新增错误均为 0。开发中发现的生命周期泄漏、退出清理和编辑器新 class 缓存问题已定位修复，没有通过 warning ignore 通过检查。
60. **Main MCP**：使用 Godot AI MCP 的刷新、场景重载、Main 启动、game_eval、真实 F/R/Tab/2 和原生鼠标 press/motion/release；覆盖搜索、17 发换弹、Slot2 Fire、ammo persistence、active unbind、满背包交换、访问失效与 A/B 独立。测试用背包填充仅存在该次运行，重启即恢复正常初始布局。
61. **Addon hashes**：`addons/godot_ai` 313 个基线 SHA256 全部相同；27 个受保护的 Combat/Weapon/Player Movement/Acoustic 文件也全部相同。
62. **Combat 规则**：没有修改现有 Combat、伤害、护甲、受伤、Projectile、Hitscan、枪械、换弹、移动、声音规则。
63. **剩余技术债**：独立审查发现 1 项轻微问题，按审查流程暂不修复：容器模式将已装备物品拖回原装备槽时预览为绿色，但新事务预验证拒绝已占用槽位，返回失败；原物品不移动，不丢失。以后应只允许同注册表/同物品/同槽位的成功 no-op，并增加回归测试。另一个接口边界：新建带内容 Rig/Backpack 应在初始原子注册前装入；运行中直接 external_registry.place 新便携容器不会自动登记内部格子，未来动态 loot 创建需补覆盖。本阶段实际流程均走初始注册或完整组迁移。
64. **Phase12 接口**：外部事务只依赖 external runtime/registry 与 owner 的 `get_external_inventory()`、`can_access(actor)`；没有将 LootCrate 作为唯一可识别 owner。未来尸体库存可接入相同接口；本阶段没有实现尸体库存。

实施决策：用户完整规格作为架构实施授权，使用当前编辑器工作区，不追加审批和提交；撤回时成本是回退本地改动。每个箱子使用独立注册表，以隔离玩家重量和 Reload 候选；成本是必须维护已验证的完整组迁移。箱子长按 F 在松开后 Search；成本是长按期间不提前打开界面。

验证明细和开发期间 RED→GREEN 记录：`%TEMP%/codex-fps-phase11-audit/`。实施计划保留在 `docs/superpowers/plans/2026-10-05-phase11-loot-containers.md`。


独立审查范围裁定：保持既有同注册表通知语义，新跨所有者操作才同时锁住两边；未来自定义同注册表回调需定义重入策略。Save/load、Multiplayer 和具体 Corpse 行为继续依用户要求排除，未来阶段仍需实现与集成测试。

最终交付状态：Main 已干净重启并保持运行（MCP run27/helper live），临时满背包测试填充已清除，恢复正常 Player 初始弹药和 A/B 初始内容。没有提交、推送或打标签。
