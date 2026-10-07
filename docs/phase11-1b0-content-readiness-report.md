# Phase 11.1B-0 — Content Extensibility & Weapon Architecture Readiness

2026-10-07。项目 Test_1，Godot 4.7.2 stable，基线 HEAD `f6a4359`。状态：PHASE 11.1B-0 COMPLETE。最终 3080 assertions passed，0 failed；132 scripts/tests check-only passed；Main 与编辑器 0 Parser/Runtime Errors、0 Godot Warnings；313/313 addon SHA256 unchanged。

## 文件范围

新增生产脚本 7 个（各有 Godot `.uid`）：

- `scripts/inventory/portable_container_data.gd`
- `scripts/weapons/attachment_slot_definition.gd`
- `scripts/weapons/attachment_data.gd`
- `scripts/weapons/computed_weapon_stats.gd`
- `scripts/weapons/weapon_stat_resolver.gd`
- `scripts/weapons/reload_animation_profile.gd`
- `scripts/weapons/reload_timing_provider.gd`

新增资源 3 个：`data/containers/rig_1_layout.tres`、`data/containers/backpack_1_layout.tres`、`data/weapons/test_rifle_reload_profile.tres`。

新增测试 2 个（各有 `.uid`）：`tests/content_extensibility_test.gd`、`tests/weapon_definition_contract_test.gd`。

修改生产脚本 13 个：`scripts/combat/armor_data.gd`；`scripts/inventory/` 下的 `item_definition.gd`、`rig_container_runtime.gd`、`backpack_container_runtime.gd`、`inventory_item_factory.gd`、`player_inventory_component.gd`、`inventory_transaction_service.gd`；`scripts/ui/inventory_ui.gd`；`scripts/weapons/` 下的 `ammo_data.gd`、`magazine_data.gd`、`weapon_data.gd`、`reload_coordinator.gd`、`firearm.gd`。

修改资源 15 个：8 个现有 `data/ammo/*.tres`、3 个 `data/armor/*.tres`、`data/items/rig_1.tres`、`data/items/backpack_1.tres`、`data/magazines/test_30rd_magazine.tres`、`data/weapons/test_rifle.tres`。只配置定义 ID、原兼容接口、布局引用、动画 family/profile，不改变原伤害、容量、尺寸或战斗数值。

文档：本报告、`docs/phase11-1b0-content-audit.md`、`docs/content-layer-contract.md`、`docs/superpowers/specs/2026-10-07-content-readiness-design.md`、`docs/superpowers/plans/2026-10-07-content-readiness.md`。

没有修改原测试、任何场景、PlayerController、WeaponRuntime、DamageInfo、ArmorCalculator、Health/BodyHealth/Injury、Projectile、Acoustic 或 `project.godot`。独立审查后的 ArmorData 改动只有 ID 元数据，没有改护甲公式。

## 60 项报告

1. **Audit 发现。** 重构前已写审计：Rig Runtime 固定 4×1×2、Backpack Runtime 固定 5×5；通用 Ammo/Magazine/Weapon 默认兼容标签绑定 Demo；两处换弹直接读取 `reload_time`；External UI 标题写死 8×6；注册器了解特定 runtime 子结构；重量是 flat；Split UI 上限 59；World bounds 只聚合直接 Mesh。具体分类见审计表。

2. **测试 Fixture。** 原 `tests/` 内 Weapon1/Magazine1/Rig1/Backpack1 路径、30 发、4 compartments、5×5、60 发栈是明确输入，可保留。原 118 个测试及 UID 文件 SHA256 全部不变。Firearm 的显式 legacy provider 是旧测试入口，Main 不使用它。

3. **Main 初始 Content。** `initialize_loadout()` 和 LootContainerFactory 的定义路径、两只备用弹匣、60 发 loose ammo、Crate A/B 内容位置是 Demo 配置。玩家 pockets/Secure/equipment 的现有规则不属于 Rig 内容布局。临时 WeaponB、AmmoB、大弹匣/包只在测试进程创建，没有加入 Main。

4. **已修复的通用硬编码。** Rig/Bag 布局移到 PortableContainerData，Factory 显式读取；通用兼容默认值改为空、旧资源显式配置原标签；两处换弹接入同一 TimingProvider；外部 UI 显示实际 grid_size；内部 storage 查询使用 `get_storage_grids()` 公共接口。

5. **仍存在的硬编码及原因。** 无参 Rig/Bag 构造器仍指向默认 layout Resource，兼容原 fixture；正常 Factory 不接受缺失布局。Split max59、复杂嵌套 world model bounds、固定 Player Camera/Muzzle 节点路径保留，分别属于 B1 Context Action 与视觉适配工作。没有新增具体 item ID/name Gameplay 分支。

6. **ItemDefinition。** 通用稳定 `item_id`、显示名、category、footprint、stack、weight、装备政策、visual_scene，以及专门定义引用。`has_capability()` 从 category 推导 weapon/magazine/ammo_stack/portable_container，不另存互相矛盾的能力 bool。RPM/伤害/弹匣内部容量未堆入该类。

7. **WeaponData。** 静态裸枪模板：ID/name/category、支持模式和默认模式、RPM、recoil、Hip/ADS spread、range、fire_model、gunshot radius、mag interface、animation family、bare weight、base ergonomics、base slots、reload profiles。不保存当前 chamber/弹匣/cooldown/选择模式。

8. **WeaponRuntime。** 继续拥有当前 chamber 实际 AmmoData、loaded MagazineInstance、selected_fire_mode、cooldown、reload/state/type。没有重写其逻辑。Active 和 Stored 枪使用同一 Runtime，只有 Active 绑定 Firearm。

9. **AmmoData。** 唯一实际弹药定义：稳定 ID、ammo_type_id、flesh/armor damage、bullet_level、round_weight_kg、原 muzzle_velocity/gravity/flight-time。新增 weight 是 B1 准备值，不接入当前 flat 重量。

10. **MagazineData。** 稳定 ID、机械兼容 interface、兼容 ammo interfaces、capacity、default Ammo、empty_weight_kg、animation_family。外部 footprint 仍由 ItemDefinition 表达，避免两份尺寸来源。

11. **MagazineInstance。** 实际 rounds 引用、顺序和数量；每次 Factory 构造独立实例。混装顺序不写回静态 MagazineData。低层 push_round 继续是容器 API，玩家装弹事务负责接口校验。

12. **Portable Definition。** 新 PortableContainerData 保存稳定 ID 和 `Array[Vector2i] grid_sizes`，不保存 placements/contents。缺失、空、非正尺寸 Factory 返回 null；Backpack 当前明确只支持一个 internal grid。

13. **Rig Layout。** 每条 layout entry 创建独立 InventoryGrid，允许异构 compartments。测试 1×2、2×2、1×1 和大弹匣专用 2×3 多格。当前 Rig1 仍配置四个 1×2。现有 UI 遍历 runtime grids，无固定四格规则。

14. **Flesh Damage Source。** Chamber → `WeaponFireResult.fired_round` → Hitscan/Projectile → DamageInfo 使用这发 Ammo。WeaponData 不新增 damage。本阶段实际同枪两发测试分别为 30、50。

15. **Armor Damage Source。** ArmorCalculator 仍读取实际 fired Ammo 的 armor_damage/bullet_level，测试实际引用分别对应 30/70 和 L1/L4；Armor 公式不变。Magazine/Weapon 不作为第二伤害来源。

16. **Ammo compatibility。** 使用 AmmoData.ammo_type_id 与 MagazineData.compatible_ammo_type_ids；不同定义可以共享口径。旧资源显式保留 `weapon1_ammo` 作为接口标签，不能把它误当作唯一内容 ID。

17. **Magazine compatibility。** 使用 MagazineData.magazine_type_id 与 WeaponData.compatible_magazine_type_ids。旧 `magazine_1` 保留为机械接口；临时 6/9 发不同尺寸弹匣共享另一个接口，错误接口自动排除。

18. **Weapon compatibility。** 不通过 weapon_name/item_id 判断。Factory 按类别、Runtime 按定义、Reload 按接口和 geometry。新增同类枪不需修改所有旧枪的具体弹匣 ID 列表。

19. **Interface 方案。** 稳定 definition_id 表示具体内容，StringName interface/tag 表示可共享兼容协议；两者不同。未来 rail/thread/barrel 接口沿用这规则，当前没有虚构其完整验证器。

20. **Weapon animation family。** WeaponData.animation_family 可由多把相似枪共享；当前 test rifle 为 `test_rifle`，Provider 不识别具体枪名。

21. **Magazine animation family。** MagazineData.animation_family 定义弹匣操作族；当前为 `test_30rd`。不同机械兼容弹匣可以配置不同操作时序。

22. **TimingProvider。** 纯数据 `get_base_duration(WeaponData, incoming MagazineData, empty)`。匹配 weapon/mag families，空值 wildcard、较具体优先，同优先级按配置顺序。取动作 Animation.length 或动作 fallback；无匹配 profile 保留原 reload_time。Stored Runtime 无需 Firearm 即可解析。

23. **Tactical fallback。** 匹配 ReloadAnimationProfile.fallback_tactical_duration；没有 profile 使用旧 WeaponData.reload_time。当前 profile 2.0 秒，不再在 Coordinator 散落具体数值。

24. **Empty fallback。** 独立 fallback_empty_duration；当前也是 2.0 秒，避免重平衡。Empty 依据换弹开始前 chamber 为 null，和旧弹匣 TACTICAL/DROP 处置策略互相独立。

25. **Animation 替换。** 为匹配 family/profile 的 Tactical 或 Empty 字段配置实际 Animation，就使用其 length。另一动作仍可 fallback。当前只测试真实 Animation Resource 长度解析，没有添加播放系统。

26. **Arms Injury。** 最终时长 = Provider base × 原 tactical/drop policy multiplier × Injury reload multiplier。原 Arms ×1.35 保持；2 秒变 2.7 秒，4 秒 Animation 测试变 5.4 秒。未来 speed_scale = animation.length/effective_duration；不改共享 Animation.length。播放速度调整未实现。

27. **Slot readiness。** AttachmentSlotDefinition 提供 slot_id、slot_interface、compatibility_tags、visual_transform；WeaponData.base_attachment_slots 是数组，不是固定 optic/muzzle/grip/stock 四字段。

28. **Attachment readiness。** AttachmentData 只提供 ID/display/interface/weight/provided_slots 静态 schema。Stat modifier 执行、真实 Item 定义链接、安装 Runtime/事务仍是未来契约。

29. **provided_slots。** Adapter 可定义下一层 optic slot，测试 base receiver mount → adapter → picatinny slot 数据。没有把静态引用测试描述为已经安装 Scope。

30. **StatResolver。** 已实现 base snapshot：读取 Runtime.weapon_data 和当前 loaded mag definition；不接入新的数值影响、不改共享 Definition。要求调用者传入已初始化 Runtime。

31. **ComputedWeaponStats。** RPM/range/spread/recoil/ergonomics/bare weight 的独立标量和独立 slot 数组；mag/slot Resource 是共享只读定义引用。允许修改 snapshot 数值/数组，不保证修改 slot Resource 深层字段安全，消费者不得写这些定义。

32. **Modifier 方案。** 文档冻结 Base → ADD sum → MULTIPLY product → CLAMP；OVERRIDE 必须明确优先级和唯一胜出者。当前没有实现 modifier registry、计算器或配件效果，避免提前扩张系统。

33. **Ergonomics。** WeaponData.base_ergonomics 和 ComputedWeaponStats.ergonomics 可保存/读取。未影响 ADS/sway/stamina/reload/switch；现有 Gameplay 不变。

34. **Attachment subtree。** 文档要求未来 attachment 为真实 InventoryItemInstance，安装/拆下保留 identity，完整组迁移。B0 仅 schema/契约，不新增实际 ownership collector 或安装 API。

35. **Magazine 与 Attachment 共存。** 未来带角色 edges：`weapon_magazine`、`attachment:<hierarchical slot path>`、`container:<grid/placement>`。不同角色不共享单 child 字段；Collector 返回现有真实 wrapper，不在每次遍历中复制物品。当前测试证明静态 slot context 和实际 loaded mag 共存，运行时树需 B1/B2 落实。

36. **未来重量公式。** Weapon bare + attachment subtree + mag empty + 真实 magazine rounds + chamber；portable base + contents；loose ammo 按实际栈。只从 ownership roots 计算，loaded/attachment child 不重复计入，WORLD 不计携重。当前仍 flat，没有宣称递归重量可用。

37. **Stable ID。** ItemDefinition 保留 item_id；Weapon/Ammo/Magazine/Portable/Attachment/Profile 使用 definition_id，现有 ArmorData 也补齐，三个 Armor ID 非空且不同。display_name 不作为持久化 key。没有全局重复 ID 扫描器。

38. **Registry。** B0 不需要完整 DefinitionRegistry；未来 Save/Load、LootTable、Trader/Quest 时实现 ID 解析和全局唯一校验。现在资源路径只用于内容配置/测试，核心无名称分支。

39. **Inventory Factory。** 同一 Factory 根据 category + 专门定义构造各 Runtime；新 WeaponB、6/9 发 mag、异构 Rig/大包均直接适配。正常 portable 路径拒绝无效/缺失 layout，不发布半成品。

40. **World Factory。** 未修改核心，通过 ItemDefinition.visual_scene 或 primitive fallback。WeaponB 实际 spawn，保持同 Item/Runtime identity。复杂嵌套模型 bounds 仍有已披露限制。

41. **Context Actions。** has_capability 已提供类型查询入口；未来 magazine→Unload/Reload With、portable→Open、ammo→Split。B0 没有新 Context Menu，不宣称全部行为已改为统一 capability dispatcher。

42. **Weapon smoke。** WeaponA 与 WeaponB 使用同一 Factory/Inventory/Firearm；B 为 200 RPM、bare3.5kg、ergonomics42、不同 interface。实际 firing cooldown 为 0.3 秒，A 和另一个 B 实例状态保持独立；无专门 B Gameplay 脚本。

43. **Ammo smoke。** A/B 同 caliber，damage30/50、armor30/70、level1/4、roundweight0.01/0.015。混装 cycle 顺序正确，真实 Hitscan receiver 的 DamageInfo 保留每发引用；ArmorCalculator 读取实际引用。重量字段仅准备，不参与伤害或当前携重。

44. **Magazine smoke。** 6 发2×2、9 发2×3、emptyweight0.18/0.25，共享 interface。Geometry can_place、实例容量、Reload选择和错误接口拒绝通过。真实 tactical reload 换入同9发实例，保留 chamber，old depleted mag 回 Rig，ownership 正确且锁释放。

45. **新增 Weapon 实际步骤。** 创建 WeaponData（稳定 ID、基础参数、默认/支持模式、mag interface、family/base slots）；创建 primary/secondary/pistol ItemDefinition（稳定 item_id、footprint、weight、WeaponData、初始 magazine_item_definition、可选 visual_scene）；如需时序创建/引用 Profile；在 Demo/spawn 配置引用并通过 Factory 创建。现有 Hitscan/Projectile、Firearm、Reload 核心无需修改。当前 held placeholder 不自动切换新模型。

46. **新增 Ammo 实际步骤。** 创建 AmmoData，配置稳定 ID、caliber、flesh/armor/level、roundweight、基础弹道；创建 AMMO ItemDefinition 配 stack/footprint/weight/visual 和 ammo_data；装进兼容 magazine 或内容 spawn。无需改 Firearm/ArmorCalculator/UI。新机制型弹药仍需单独 Gameplay 阶段。

47. **新增 Magazine 实际步骤。** 创建 MagazineData（ID、interface、口径列表、capacity/defaultammo、emptyweight/family）；创建 MAGAZINE ItemDefinition（ID、size、weight、visual、引用）。如不同动画时长再配置对应 Profile。只要 interface 兼容并且 inventory geometry 可容纳，不改 Reload 核心。

48. **新增 Backpack 实际步骤。** 创建单 grid PortableContainerData（ID/internal尺寸）；创建 BACKPACK ItemDefinition（ID/external size/weight/visual、container_data）；Factory 创建并按现有装备/拾取 policy 放置。测试外5×6、内7×6。当前包实际外3×4、内5×5，未按需求举例改为4×5。多 grid bag、装满容器动态登记和新政策需 B1。

49. **新增 Rig 实际步骤。** 创建 layout Resource，填写任意数量/不同尺寸 compartments；RIG ItemDefinition 引用并设置 footprint/weight/visual；Factory 创建，UI 遍历实际 grids。无需改 Rig count/Reload 类型代码；可容纳弹匣由实际 geometry 决定。现有 LootTable/Loadout 配置仍需显式加入新内容。

50. **仍需新代码的内容。** 新武器机制（pump/bolt/jam 等）、新动作政策、新 Item 类型、完整配件安装/模型拼接、特殊弹药效果、复杂视觉 bounds、音频/动画执行器、多 grid bag UI。现有已支持类型的参数变化不需要每枪专属 GDScript。

51. **纯数据目标边界。** 同类枪/Ammo/Mag/Rig/单grid包可纯 Resource 创建并共用 Gameplay，临时内容实际证明。完整任意武器外观/声音/动画作者流程还缺 held representation adapter、资源引用执行、DefinitionRegistry、Loot/SpawnTable 和 B1完整 ownership/重量；不能把 B0 等同完整内容工具链。

52. **原回归。** 原2993 assertions全部通过，59次运行，0问题；原测试 SHA256 全部不变。涵盖 same-slot no-op（171）、LootContainer、World/Vicinity、Inventory/Reload、WeaponRuntime/Acoustic、FPS、Combat/Armor/BodyHealth 和 Projectile。原矩阵包含 rendered/native 测试以及 Hitscan/Projectile 两种模式。

53. **新增测试。** 87 assertions：content_extensibility_test 58；weapon_definition_contract_test 29。含重要 Armor ID 缺口的 RED4→GREEN29 和两项审查证据补强。测试修正期间一次脚本属性名错误已修复，不把那次退出码0算成功。

54. **总数量。** 最终2993 +87 =3080，61次运行，0失败、0日志问题，退出码全部0。按 PASS 计数，同时检查退出码、结果汇总和 ERROR/WARNING，不能只看 assertions。

55. **Parser / Main。** 最终132 scripts/tests check-only通过，0 errors/warnings。MCP运行Main并确认Rig4×1×2、包内5×5/外3×4、29+1、600RPM、Tactical/Empty基础2秒。F打开实际CrateA；原生同槽拖放有效预览，身份/状态/绑定/控件不变、五类信号均0、无重建、拖放反馈清理。Tab关闭后实际左键AUTO发射两发，MAG29→27，Projectile正常impact并生成原HitMarker；R实际换弹锁定/完成→MAG30+CH1。临时Arms状态下实际2.7秒换弹完成，共享2秒资源不变。读取完整本次game21行与editor0行，无错误/警告。最后停止并重新运行Main，确认伤势/位置/库存恢复初始、29+1且保持运行；最后game只有初始化info、editor空。一次MCP读取因窗口后台返回EVAL_GAME_NOT_READY，聚焦后读取成功；该连接就绪问题不是Godot脚本错误，没有隐藏/清空日志。

56. **Addon hashes。** 313 baseline /313 current，SHA256全部不变；无新增/删除。project.godot同样不变，HEAD仍f6a4359。原118个测试和UID文件全部原样，所有场景原样。

57. **未实现完整 Attachment。** 没有配件拖放、安装事务、Workbench、UI、模型拼装、动画或 stats Gameplay。测试仅证明 schema 可表达嵌套 slot 并与已装弹匣共存。

58. **平衡保持。** 当前 Rifle600RPM、30发总初装29+1、原 damage/Armor规则、Hip/ADS/recoil、Reload2.0、Arms1.35、Rig4×1×2、Bag5×5和外3×4都不变。新 weight/ergonomics字段未接入 Gameplay。没有修改移动/伤势/Acoustic规则。

59. **剩余技术债与审查裁定。** 原动态 populated portable 登记第二债→B1；通用真实子树 Collector/attachment edges、cycle/alias拒绝、递归重量→B1/B2；legacy无参默认layout→兼容适配器，正常Factory要求显式；Split59→Context Action；nested bounds/固定Camera及模型→视觉适配；supported modes当前是定义元数据，任意新输入模式限制尚未接入；profile同分按配置顺序，作者避免重叠；stored timing可解析但Inventory显式换弹未实现。独立只读审查Critical0/Important1/Minor2：Armor稳定ID补齐；A/B隔离与大弹匣真实换弹补强。共享slot Resource只读、flatweight和futureownership边界均明确保留，没有用第二轮审查扩大范围。

60. **进入 B1。** 最终矩阵与Main已通过，建议进入Phase11.1B-1。优先落实complete ownership subtree、动态populated container登记、递归重量和Item Interaction；沿用此处stable ID/interface/layout/timing契约。不要提前插入完整配件Gameplay。没有commit、push或tag，全部改动留在当前工作树。

## 验证证据位置

`%TEMP%/codex-fps-phase11-1b0-audit/` 保存 baseline/release runner与每套件日志、`release-results.json`、132份 `parser-*.log`、RED/GREEN、SHA256基线/结果、MCP运行日志和`progress.md`。这些是本机审计证据，不提交进项目，也不修改日志以隐藏错误。
