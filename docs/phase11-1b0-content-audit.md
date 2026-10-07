# Phase 11.1B-0 — pre-refactor content audit

2026-10-07，基线 HEAD f6a4359，开始时工作树干净。用户附件是本阶段的架构规格；实现仅限低风险 Foundation。Godot AI MCP 已重新确认 Test_1 / Godot 4.7.2 stable，运行测试前停止 Main。以下结果在生产代码重构之前记录。

## A — 测试 Fixture，可以保留

`tests/` 中 Weapon1/Magazine1/Rig1/Backpack1 资源路径、默认 30 发、4 个 Rig 格、5×5 Backpack、60 发 Ammo 均是明确测试输入；不修改旧断言。Firearm 的 `use_legacy_test_provider()` 和两个 spare magazines 属于旧阶段显式测试入口，不是 Main 的 Inventory reload 来源。新增测试内容仅存在测试进程，不加入 Main。

## B — 初始/Demo 内容，可以保留

`PlayerInventoryComponent.initialize_loadout()` 的具体 Definition、两只备用弹匣、60 发 loose ammo；`LootContainerFactory.create()` 的 A/B 内容及其数量/位置；TestLevel 的 SpawnPoint 和 visual scenes；所有 `data/*.tres` 的内容 ID、默认数值、兼容标签。它们是当前 Demo 配置，不是通用 Gameplay 的 item-name 分支。玩家六个 pockets、3×3 Secure、六个 equipment slots 是当前玩家槽位/规则配置，不是 Rig layout，B0 不调整。

## C — 通用 Gameplay 的问题及处理

| 位置 | 发现 | 本阶段处理 |
|---|---|---|
| `rig_container_runtime.gd:5` | Runtime 写死 4 × 1×2 | 布局迁入 PortableContainerData，Factory 显式传入；保留无参构造的 legacy 默认 Resource，兼容旧 fixture |
| `backpack_container_runtime.gd:3` | Runtime 写死 5×5 | 同上，Backpack 当前单 grid，不扩展多 grid UI |
| `inventory_item_factory.gd` | Rig/Bag 创建未读取具体布局 | 从 ItemDefinition.container_data 构造、拒绝无效布局 |
| `weapon_data.gd:8` | 默认具体 magazine_1 标签 | 通用默认改空，当前 .tres 显式保存旧标签 |
| `ammo_data.gd:5` | 默认具体 weapon1_ammo 标签 | 通用默认改空，已有 Ammo .tres 显式配置 |
| `magazine_data.gd:5-6` | 默认具体内容兼容标签 | 同上；现有字段的语义规范为稳定 interface，不为改名重构 |
| `reload_coordinator.gd:63` / `firearm.gd:157` | 两处直接用 reload_time，无法独立解析 Tactical/Empty/动画 | 统一 ReloadTimingProvider；保留原 2.0 秒、Drop multiplier、Arms ×1.35 |
| `inventory_transaction_service.gd:60-78` | 注册递归认识 loaded magazine、Rig/Bag | B0 仅存储 grid 使用公共查询接口；Attachment item ownership/完整 collector 只写 B1 接入契约，不创建 Attachment Runtime |
| `inventory_item_instance.gd:get_weight()` / Player get_total_weight | 重量只是 ItemDefinition.weight × stack，非真实子树重量 | 明确保留到 B1；B0 预留 Ammo round / Magazine empty / Weapon bare weight，禁止宣称递归重量已实现 |
| `inventory_ui.gd` external header | 写死显示 8×6 | 显示实际 runtime.grid_size |
| `inventory_ui.gd` split max 59 | 当前 60 发栈的界面上限 | 明确 UI 技术债；B1 Context Action 阶段改为当前实际 stack 的 split limit，本次不改 Split UX |
| `DroppedItem._ready()` | World visual 支持 PackedScene，但 bounds 只聚合直接 MeshInstance3D | 普通自带 primitive 资源可工作；复杂层级模型 bounds 留视觉阶段，不引入第三方资源 |
| `Firearm` | Camera/Player/WeaponMesh 路径固定于现有 Player scene | 共享执行器没有具体 item ID 判断；通用 Held model / Animation adapter 为未来视觉工作，不每枪新建 Gameplay 脚本 |

## 已经符合契约

Ammo→实际 chamber→WeaponFireResult.fired_round→Hitscan/Projectile→DamageInfo→ArmorCalculator：flesh_damage、armor_damage、bullet_level 均来自实际 AmmoData。WeaponData 没有 damage。

Magazine rounds 按真实引用顺序保留，MagazineInstance 独立。Reload compatibility 使用 magazine_type_id/interface；load ammo 使用 compatible_ammo_type_ids；同 item_id 的 stack merge 比较是类型相同的规则，不是具体内容硬编码。

InventoryItemFactory 按 category 分配 Runtime，WorldItemFactory/DroppedItem 从 visual_scene 或 primitive fallback 构造，不识别 Weapon1 等名字。UI/装备/拾取主要按 category、runtime、geometry、policy 决定行为；Rig UI 遍历 runtime.grids，已无需固定 count。

## 边界冻结

不做完整 Attachment Gameplay、不做递归重量应用、不做 Portable Container 动态登记第二技术债、不改变 Armor/Body Health/Acoustic/Movement/Reload 选择或掉落规则。稳定 ID 与兼容接口严格区分：Definition ID 唯一，interface 可共享。内容层优先小 Resource；不会重写 Inventory、WeaponRuntime 或 UI。
