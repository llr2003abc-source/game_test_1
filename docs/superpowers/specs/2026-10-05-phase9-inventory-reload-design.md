# Phase 9 — Equipment、Inventory 与 Rig Reload 设计草稿 v1

状态：按用户要求搁置，先执行 Phase 8B WeaponRuntime 重构。本文尚未实施；其中旧的 WeaponItemState 接入建议以后应改为直接使用 WeaponRuntime。本文是用户附件 68 节要求的代码接入设计，不宣称 Phase 9 已实施。

需求来源：用户附件 `dd9113c1-7699-4a9d-9228-36035c06663d/貼上的文字.txt`。

## 1. 目标、保护范围与当前事实

建立真实的角色物品数据层，以 Equipment、Rig、Pockets、Backpack、Secure Container 管理物品；同一 MagazineInstance 在 Inventory、枪内和世界之间转移。UI 展示数据并提出操作请求，不保存第二份库存。

保留 FPS、伤势、声音、RPM、弹膛、Mixed Ammo、Projectile/Hitscan、Ballistics、Armor、Damage、BodyHealth、BodyInjury。禁止第三方插件、AI、背包嵌套、持久化、拾取系统、动画与战斗系统重写。

- 编辑器：Godot 4.7.2 official；项目 Test_1，主场景 `res://scenes/levels/test_level.tscn`。Godot AI MCP 当前可连接，编辑器处于 stopped/ready。
- 已有 Firearm._ready 创建枪内弹匣与两只备用弹匣；R 立即 request_reload；完成时交换弹匣并保留 Chamber。
- 当前默认 FireModel 是 PROJECTILE；本阶段保留，不改回 Hitscan。
- 当前 AmmoData 为 flesh_damage、armor_damage、bullet_level、muzzle_velocity、gravity_scale、max_flight_time；不恢复旧 damage 字段。
- Test Round 是 L1 / flesh_damage 30；已有 test_level_2_round.tres 是 L2 / flesh_damage 40。保持现有伤害、护甲和弹道参数。
- 目前尚无 Inventory、Equipment 或容器 UI。
- 工作区已有 26 个 addon 文件和 project.godot 未提交改动。保护以本次开始时磁盘 SHA256 为准，保留用户改动，不按旧 Git 版本覆盖。已记录 313 个插件文件基线到 `%TEMP%/codex-fps-stage9-audit/addon-hashes.json`。
- 本轮实际重新运行原 16 次测试矩阵：1353 PASS、0 FAIL、0 Parser/Runtime/Warning 输出；两套显式 Projectile 回归报告 mode=PROJECTILE。插件复核 313/313 哈希未变。此次尚未进行 Phase 9 新增脚本解析或新增功能测试。

## 2. 接入方式选择

推荐：增加 Inventory 数据层和装备协调接口，Firearm 保留已验证的运行时射击逻辑，只替换装备权限、Magazine Item 绑定和 Reload 来源。所有库存操作经过统一事务入口。

另一种方式是把 Chamber、RPM、Reload Timer 全部迁到新的 WeaponRuntime 模型，再让 Firearm 仅作表现层。这会扩大对已验证代码的改动，本阶段不采用。也不维护“Inventory 弹匣”和 spare_magazines 两套镜像数据。

实施顺序为数据模型 → 容器与装备 → 兼容装弹 → Rig Reload → 输入与装备权限 → UI → 全量回归。它们组成一个完整 Phase 9，不增加独立 Loot/Inventory UI 框架。

## 3. 静态定义与运行时实例

`ItemDefinition extends Resource`：item_id、display_name、ItemCategory、grid_size、max_stack、weight、可选 icon；另用静态 ammo_data、magazine_data、weapon_data 引用关联已有定义。

ItemCategory：GENERIC、AMMO、MAGAZINE、PRIMARY_WEAPON、SECONDARY_WEAPON、PISTOL、MELEE、RIG、BACKPACK。定义必须满足尺寸 >= 1、max_stack >= 1；当前只有 AMMO 可使用 max_stack > 1。无图标时使用文字及基础 ColorRect，不加载第三方图像。

`InventoryItemInstance extends RefCounted`：definition、stack_count、rotated、runtime_state。实例身份是运行时对象本身；item_id 是静态类型 ID，不能用于区分两只实际弹匣。

| 物品 | ID / 分类 | 外部尺寸 | Stack | 运行时状态 |
| --- | --- | --- | --- | --- |
| Backpack 1 | backpack_1 / BACKPACK | 3×4 | 1 | BackpackContainer：连续 5×5 |
| Rig 1 | rig_1 / RIG | 2×2，本文补充默认值 | 1 | RigContainer：四个独立 1×2 |
| Weapon 1 Level 2 Ammo | weapon1_ammo_level2 / AMMO | 1×1 | 60 | AmmoData 静态引用，数量在 item.stack_count |
| Magazine 1 | magazine_1 / MAGAZINE | 1×2 | 1 | 原有 MagazineInstance |
| Primary Weapon 1 | primary_weapon_1 / PRIMARY_WEAPON | 5×2 | 1 | WeaponItemState，引用现有 Firearm 与枪内 Magazine Item |

Rig 外部尺寸原附件未指定，草稿选 2×2，和内部四槽没有关系。未指定的物品 weight 默认 0；可通过 Inspector 配置，测试使用非零值验证重量计算，不增加负重减速。

Firearm 是 Node，不能直接放入类型为 RefCounted 的 runtime_state。`WeaponItemState extends RefCounted` 只作为现有 Firearm 的绑定对象及 loaded_magazine_item 的持有者；不复制 Chamber、计时器或弹药数组。UI 不持有真实所有权。

## 4. 容器与所有权

Player 增加 PlayerInventoryComponent、EquipmentComponent、SecureContainerComponent、ReloadInputResolver，以及 Inventory UI。PlayerInventoryComponent 协调六个独立 Pocket Grid 和跨容器操作；装备 Rig/Backpack 的内部状态保存在对应物品的 runtime_state。

- RigContainer：`Array[InventoryGrid]`，长度 4，每个 1×2；显示横排不改变数据边界。
- Pockets：六个 1×1，绝不合并为 6×1。
- BackpackContainer：单个 5×5。
- SecureContainerComponent：固定一个 3×3，不实现死亡保留或 Raid persistence。
- EquipmentComponent：六个分类槽，不属于 Grid。
- Gun：WeaponItemState 持有 loaded_magazine_item；其 runtime_state 和 Firearm.loaded_magazine 必须是同一个 MagazineInstance。
- DroppedItem：持有同一个 InventoryItemInstance，不 clone、不补满、不删除其 rounds。

每个 Item 同一时刻只能有一个真实所有者：一个 Grid placement、一个 Equipment slot、一个 WeaponItemState，或一个 DroppedItem。跨容器转移验证源仍持有该对象后提交；陈旧 UI Drag Payload 不能重复移动已经转走的物品。避免 Item 与 Grid 相互强引用形成 RefCounted 循环。

拒绝 Backpack/Rig 放入 Backpack/Rig，即附件列出的四种嵌套。Pockets 因尺寸放不下它们。固定 Secure 不是可嵌套物品：Rig 2×2 可存入 Secure 并保留内部状态；Backpack 3×4 无法放入 3×3 Secure，非法拖放恢复原位。本阶段不扩大 Secure 或添加背包套娃来提供非法落点。

## 5. Grid 与事务接口

`InventoryPlacement extends RefCounted` 保存 item 和 position。InventoryGrid 是真实 placements 数据的所有者。

InventoryGrid 提供 can_place、place_item、remove_item、move_item、rotate_item、find_first_free_position、auto_add_item、get_total_weight。位置使用 Vector2i；无可用位置返回 Vector2i(-1, -1)。有效尺寸从 ItemDefinition.grid_size 与 rotated 得到。

操作顺序固定：验证 source/definition/数量/边界/占用/分类/Reload 锁 → 计算结果 → 一次提交 → 发布变化信号。失败不改变 placement、rotation、stack 或所有权。测试在操作前后比较完整状态，而不只比较返回值。

跨容器 transfer、Equipment equip/unequip、stack merge、split、ammo loading 均由数据协调入口执行，UI 不直接写数组或字段。

- 普通 Grid 旋转 90°：先检查新尺寸合法，再修改 item.rotated。Equipment 不使用 Grid rotation。
- Stack：仅同 item_id 且同 AmmoData 定义的 AMMO 合并，最多 60；保留未合并余量。兼容口径相同不代表不同等级/弹种可以堆为同一 Stack。
- split_stack(source, amount)：只允许 0 < amount < source.stack_count；先确认新实例可放入目标位置，再一次提交。无空间不得先扣 source。
- auto_add_item：先规划完整 Stack 合并与摆放，空间不足时整体失败，不留下部分合并结果。
- Grid get_total_weight：按物品静态重量 × stack_count 计算；容器的内容由其运行时容器接口汇总，不把装备容器内容再作为第二份物品计重。

## 6. 稳定 ID、装弹与弹药守恒

AmmoData 增加 ammo_type_id；MagazineData 增加 magazine_type_id 与 compatible_ammo_type_ids；WeaponData 增加 compatible_magazine_type_ids。当前口径为 weapon1_ammo，弹匣类型为 magazine_1。不以 display_name 判断兼容。

MagazineInstance 继续保存 `rounds: Array[AmmoData]`，pop_round 返回真实 AmmoData。push_round 在追加前检查容量及 Ammo type 兼容；Mixed Ammo 可以由同口径的 L1/L2/L4/L5 组成，不能把不兼容弹药混入。

`load_ammo_into_magazine(ammo_item, magazine_item, requested_amount) -> int`：依次验证两个 Item 分类、运行时 MagazineInstance、AmmoData ID、容量、Stack 和锁定状态。转入量为 requested、剩余容量、Stack 数量的最小值；失败返回 0 且不修改任何一方。

例：60 Stack + 17/30 Mag 请求 30 → 转入 13 → Stack 47、Mag 30。Stack 归零时在同一次事务中移除它的 placement，不能留下可拖动的零数量物品。

初始测试 Loadout：Primary Weapon 1、Rig 1、Backpack 1；其余武器槽和六 Pocket 为空；Secure 固定存在。Magazine A 在枪内，Magazine B/C 在 Rig 前两槽，后两槽为空。三只都是独立 MagazineInstance，共享 MagazineData。Backpack 中 L2 Ammo ×60。

为保持旧伤害回归，A/B/C 预装原 Test Round L1（每只 30），枪先 chamber 一发，得到 MAG 29 + CHAMBER 1；L2 loose Stack 使用已有 L2 40 flesh_damage，不改变护甲伤害曲线。所有这些 Ammo 共享 weapon1_ammo 类型。现有 90 发预装加 60 发 loose 是固定 Loadout，总计 150，不由 Reload 再生成弹药。

守恒测试分别统计所有 Stack、所有 Magazine、Chamber、DroppedItem 与已发射轮数；同一 MagazineItem 引用只能计一次。

## 7. Equipment 与武器权限

EquipmentSlotType 为 PRIMARY、SECONDARY、PISTOL、KNIFE、RIG、BACKPACK，对应严格分类检查。EquipmentComponent 保存六个槽及 active_weapon_slot。

1/2/3/4 选择相应槽；空槽请求失败并保持现有 Active Weapon。Reload 期间禁止切换。第一批只提供 Primary Weapon 1，不新增其他枪械或刀具攻击系统。

Firearm 必须在实际 set_trigger / set_aiming / request_reload 和发射入口确认自己是已装备且激活的武器；直接调用 Firearm 也不能绕过装备权限。

Primary → Backpack：同一 Weapon Item 与运行时状态转移；立即释放 Trigger、关闭 Weapon ADS、隐藏第一人称 Weapon Visual、通知 HUD 无活动武器，保留 Magazine 和 Chamber。重新装备并激活时恢复该实例，不重新生成 Ammo。

PlayerController 查询 nullable active firearm，不再假设永远持枪。无枪时仍可移动、跳跃、Mouse Look，Camera 恢复非 ADS FOV；Phase 8A 的伤势和移动声音规则保持。

## 8. Reload Input Resolver

ReloadInputResolver 只解析 R。导出 reload_double_tap_window = 0.22，提供 tactical_reload_requested 与 drop_reload_requested，不读取 Inventory 或 Firearm。

- 真实首次 R press 开启窗口；release 不计次数。
- 第二次真实 press 在窗口内（边界 <= 0.22）发一次 Drop 请求，清除 Single pending。
- 窗口结束无第二次 press，发一次 Tactical 请求。
- 若第二次 press 超过窗口，先结算旧 Single，再把新 press 当新窗口的第一次。
- InputEventKey.echo 无条件忽略，不能按住 R 产生 Double。
- Inventory 打开或鼠标控制退出时清除未完成输入窗口，不能关闭 UI 后补发过时 Reload。
- UI 打开时 R 是 Inventory rotation，不交给 Reload Resolver。

测试通过显式时间驱动纯解析逻辑；实际输入使用真实 InputEventKey/Action 边沿。旧 R 回归夹具加入 0.22 秒确认时序，不能继续期待首帧进入 RELOADING。

## 9. Rig Reload 事务

所有候选来源只有当前 Equipped Rig 四个 Grid。Backpack、Pocket、Secure 不在查询范围；未装备 Rig 内的 Mag 也不能供换弹。

Replacement 条件：真实 Rig placement、category MAGAZINE、runtime_state 是 MagazineInstance、magazine_type_id 匹配当前 Weapon、至少一发合法 Ammo。select_reload_magazine 选 round count 最大者，数量相同按 Slot/placement 稳定顺序选择。

第一项 Gameplay 检查为 find_valid_replacement_magazine。无候选时返回 NONE，不卸载、不 Drop、不改 Chamber/Inventory、不进入 RELOADING、不发未来 Reload 事件。

| 输入 | Compatible loaded replacement | 开始前能保存旧 Mag | 结果 |
| --- | --- | --- | --- |
| Single R | 无 | 任意 | NONE |
| Double R | 无 | 任意 | NONE |
| Single R | 有 | 有 | TACTICAL |
| Single R | 有 | 无 | DROP |
| Double R | 有 | 任意 | DROP |

决定旧 Mag 空位时，Replacement 仍在 Rig。四个 Slot 都只剩一个单格时，不把零碎空间合成 1×2；四槽满弹匣时不利用将要取出的 Replacement Slot。

ReloadType 为 NONE、TACTICAL、DROP，Firearm 保存当前 reload_type。WeaponData 用 tactical_reload_time_multiplier 与 drop_reload_time_multiplier（默认均 1）预留时间差异；最终时间继续为 reload_time × 对应 ReloadType 倍率 × 原 Arms injury multiplier。

为保留现有时间语义，等待期间枪内旧 Magazine 与 Chamber 保持原引用；不允许开火。开始时锁定当前 Weapon Item、装备 Rig、Old/Replacement Magazine Item，并为 Tactical 保留开始前确认的目标格，防止 Inventory UI 在计时中移走或装弹这些对象。其他不相关库存操作仍可执行，SceneTree 不暂停。

时间结束时通过一次数据事务提交：

1. 再核对已锁定引用的归属。
2. Old Magazine Item 转到预留 Rig 位置或生成的 DroppedItem。
3. Replacement 从 Rig placement 转为 WeaponItemState.loaded_magazine_item。
4. Firearm.loaded_magazine 指向同一 runtime_state。
5. 已有 Chamber 保持；空 Chamber 则 chamber_next_round 一次，30 → MAG 29 + CHAMBER 1。
6. 释放锁、更新 READY/EMPTY、发布 Inventory/HUD 状态。完成帧不额外射击。

不实现玩家主动 Reload Cancel。场景退出时只释放该事务的锁，不补满、clone 或吞掉 Item。已有“满 Magazine + Chamber 忽略重复换弹”的防重复规则保留。

停止使用内部 spare_magazines 作为 Gameplay Source。若保留兼容只读查询，它必须从 Equipped Rig 实时计算，不能再有独立可变数组，也不能被 clear/append 用作操作接口。旧测试改用真实 Rig 夹具操作。

## 10. DroppedItem、Collision 与装备模型

DroppedItem 场景：Node3D → MeshInstance3D + Area3D/CollisionShape3D。独立 Physics Layer 5：Interaction，layer bit 16，mask 0。保留 World/Player/Hurtbox/TargetBody 四层；既有 Hitscan 与 Projectile 的 mask 1 | 4 不包含 Interaction。

DroppedItem 持有原 Item，保持原 MagazineInstance、17 发及 Mixed Ammo 顺序。使用枪口/角色附近合法调试位置生成基础 BoxMesh；本阶段不加 RigidBody、抛掷模拟、拾取输入或 Loot。

Rig/Backpack/Weapon 装备视觉仅 Node3D/MeshInstance3D。没有 Body、Area 或 CollisionShape，不挡角色、导航、射线和弹道。Ammo Debug Visual 使用基础 CylinderMesh 或 BoxMesh。

## 11. Inventory UI

Inventory UI 独立 CanvasLayer/Control；绑定 PlayerInventory/Equipment signals，通过数据查询渲染。Tab 开关，无 SceneTree.pause。

打开时 cursor visible，立即关闭 Fire/Weapon ADS，取消 pending reload 输入，禁止 Look、Fire、ADS、Reload 与 1/2/3/4。关闭时 captured 并等待 Fire release，避免关闭窗口那次鼠标点击开枪。现有 Esc 行为保留；Inventory 打开时点击不得意外 Capture Mouse。

布局：左 Equipment 六槽；右上 Rig 四个独立 1×2；下方 Pockets 六个独立 1×1；下半区域 Backpack 5×5 与其右下 Secure 3×3。默认格 48×48，基础 Panel/ColorRect/Label，布局适应当前窗口，不增加美术依赖。

Drag Payload 只携带真实 Item 引用、来源和预览 rotation；开始 Drag 不移除原 placement。合法 Drop 调数据事务，非法 Drop 或 Tab 关闭时取消预览，原数据不动。

Ammo → Ammo 调 merge；Ammo → Magazine 调 load_ammo_into_magazine；其余 Drop 调 Grid/Equipment transfer。拖动中 R 只旋转预览，Drop 时校验；Grid 中选中物品 R 调原子 rotate_item。Equipment 物品不旋转。

Split 使用选中 Ammo 后的小型数量输入与确认按钮，先找到目标空位再提交；容量不足保留原 Stack。界面同时显示 Magazine 实际 rounds / capacity、Ammo stack_count、武器当前 Chamber 与 Reload 状态，不从名称推测数据。

UI 非法操作只显示简短失败原因（空间不足/类型不符/换弹中锁定），不输出 Godot 错误，不吞掉物品。

## 12. 文件边界

预计新增脚本：

- scripts/inventory/item_definition.gd、inventory_item_instance.gd、inventory_placement.gd、inventory_grid.gd
- scripts/inventory/rig_container.gd、backpack_container.gd、secure_container_component.gd
- scripts/inventory/player_inventory_component.gd、equipment_component.gd、weapon_item_state.gd
- scripts/inventory/reload_transaction.gd、dropped_item.gd
- scripts/player/reload_input_resolver.gd
- scripts/ui/inventory_screen.gd、inventory_grid_view.gd、inventory_equipment_slot.gd

新增资源 data/items/ 五种正式 ItemDefinition；新增 scenes/inventory/inventory_screen.tscn、dropped_item.tscn。不创建通用网络、存档、事件命令总线或复杂 UI 框架。

最小修改范围：现有 AmmoData/MagazineData/WeaponData 的 ID 或时间字段；MagazineInstance 的兼容追加校验；Firearm 的绑定/权限/Reload；PlayerController 的 active weapon 与 Inventory/Input；Ammo HUD；Player 场景和 TestLevel UI；project.godot 的 Tab/1/2/3/4 与 Interaction 名称；少量现有数据资源及回归夹具。

不修改 DamageInfo、Hurtbox、HealthComponent、BodyHealth/BodyInjury、Armor、BallisticProjectile、AcousticEvent/Bus/Emitter 和 HitMarker 的生产实现。

## 13. 测试与验收矩阵

保留全部已有测试及 1353 项功能断言。迁移只调整 Setup、所有权查询、Reload 输入等待和必要显示文案，不删测试，不以恒真条件或 warning ignore 绕过。逐条报告任何被新规则明确取代的断言；禁止宣称旧即时 R 或可变备用数组语义仍未改变。

至少增加附件要求的九套测试：

| Suite | 必测内容 |
| --- | --- |
| inventory_grid_test.gd | 尺寸、越界、占用、移动/跨 Grid 原子性、旋转失败保持、自动加入失败无部分合并、weight |
| container_inventory_test.gd | 四个独立 Rig、六个独立 Pocket、背包 5×5/外部 3×4、禁止跨槽与嵌套、实例独立 |
| equipment_component_test.gd | 六类 Equipment 限制、空槽不收枪、1/2/3/4、Reload 锁与不得重复拥有 Item |
| ammo_magazine_compatibility_test.gd | 稳定 ID、错误 Ammo/杂志全不变、17→30 消耗13、两只空 Mag 消耗60、Mixed Ammo、Stack 60+10、split 非法参数 |
| weapon_equipment_test.gd | 移到背包后 Fire/ADS/Reload 禁用，重新装备保留 Chamber/Magazine，直接调用不能绕过，空 Slot 保持原 Active |
| rig_reload_test.gd | Single/Double 全结果矩阵、最满兼容候选、只搜索当前 Rig、碎片空间、不得利用候选腾空、Empty Reload、锁、Dropped 原实例与守恒 |
| reload_input_resolver_test.gd | 首按不执行、0.22 内 Double 仅一次 Drop、窗外两次 Single、精确边界、echo、UI 打开取消 pending |
| secure_container_test.gd | 固定连续 3×3、place/move/rotate/stack/split、Secure Mag 不参与 Reload、不做死亡持久化 |
| inventory_ui_test.gd | Tab/cursor、不暂停、布局与独立格、真实 Drag/旋转/非法恢复、Stack/Split/装弹、UI 控制屏蔽、数据 signal 更新 |

重点的失败快照包括：无兼容 Replacement 时枪/Chamber/Rig/world 子节点/state 全保持；错误 Ammo Loading 两侧都保持；非法 transfer/rotation/split/自动加入全保持。构造错口径/错弹匣的测试资源仅供测试，不引入第二种实际装备。

标准 Magazine 1 的 1×2 尺寸使其无法进入任何 Pocket，这项直接测试必须失败且不改原位。为独立证明“即使 Pocket 中有兼容弹匣也不能换弹”，另用外部尺寸 1×1 的测试用 Magazine Item 夹具合法放入 Pocket；不能为了构造测试破坏 Grid 的尺寸限制。

全量运行两个 FireModel 的原回归；Projectile CLI 参数使用已有测试实际支持的 `-- --projectile`。新增测试断言数以最终真实 PASS 行为准，不预填结果。

运行所有非 addon 脚本的 --check-only。通过 Godot AI MCP 先 stop，再 save，正常加载而不在播放中强制写场景；启动 main，实际验证 Tab、Drag、1、Fire、Single/Double R、Rig Full、Wrong Mag 和 Ammo Loading，检查当前 run 的 Output、Parser/Runtime/Warnings。

## 14. 本次设计自检与待确认默认值

- 本文覆盖用户附件 1–68 节；原测试夹具与新 Reload/Input 语义的变化已单独列明，未伪称“旧即时 R 行为不变”。
- 解决 Resource 与运行时数量、RefCounted 与 Firearm Node、Rig 离散空格与连续空间、Replacement 腾位、Inventory UI 与 Reload 竞争等接口矛盾。
- 本文采用的补充默认值：Rig 外部 2×2；初始保留三只预装 L1 弹匣加 Backpack L2×60；Reload 结束时原子交换；换弹仅锁相关物品与目标格；Secure 允许存入尺寸合法的 Rig。
- 实际基线结果、插件保护复核与后续实施计划必须记录真实证据。本阶段尚无新增断言或 Phase 9 运行结果。
- 用户审阅本文后再编写详细实施计划；默认保持当前 Editor checkout，单代理在本会话实施。用户可明确覆盖技能工作流，要求按其附件直接实施。
