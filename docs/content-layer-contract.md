# Content layer and future weapon contracts

Phase 11.1B-0，2026-10-07。本文明确区分已实现 Foundation 和未来 Gameplay，不能把静态 schema 测试视为配件系统已经可用。

## 已实现的静态定义与实例边界

- ItemDefinition.item_id 是稳定、唯一的内容定义 ID；display_name 只用于显示。category 推导 `has_capability()`（weapon/magazine/ammo_stack/portable_container）；不另外保存一组可能矛盾的能力 bool。grid_size/visual_scene/weight 为通用 Inventory 元数据，专门参数通过 weapon_data/ammo_data/magazine_data/container_data 引用。
- WeaponData.definition_id / weapon_name / weapon_category / supported_fire_modes / 默认 fire_mode / RPM / recoil / Hip 与 ADS spread / max_range / fire_model / gunshot radius / base_ergonomics / bare_weight_kg / animation_family / base_attachment_slots / reload_profiles 是静态模板。
- WeaponRuntime 持有当前 chamber AmmoData、实际 loaded MagazineInstance、selected fire mode、cooldown、reload remaining/type/state；模板不保存这些状态。
- AmmoData.definition_id 唯一，ammo_type_id 是可共享的 caliber interface；flesh_damage/armor_damage/bullet_level/round_weight_kg 与基础弹道属性来自这一发 AmmoData。
- MagazineData.definition_id 唯一，magazine_type_id 是可共享的 mechanical interface；compatible_ammo_type_ids、capacity、empty_weight_kg、animation_family/default_ammo 是静态定义。外部尺寸来自其 ItemDefinition，不复制第二份 footprint。
- MagazineInstance.rounds 保存实际 AmmoData 引用和顺序，不写回 MagazineData。当前 push_round 的低层 API 不负责兼容验证；玩家装弹事务负责该校验，未来外部 loader 也必须先校验。
- ArmorData.definition_id 是稳定内容 ID；三个现有护甲资源显式配置，护甲公式、等级、耐久和保护区域不变。
- PortableContainerData.definition_id / grid_sizes 定义布局。Rig 可有任意个不同尺寸 compartment；Backpack 当前保留一个 grid。每次 Factory 创建独立 grids/placements。无参旧 fixture 构造器使用当前默认 layout Resource，新内容必须从 Factory 显式传入自己的布局。
- Ammo/Weapon/Magazine/Container/Attachment 的 definition_id 均是不同于兼容接口的内容 ID。现有 ItemDefinition 的 item_id 无需为改名重构。未来 DefinitionRegistry 将这些 ID 解析为 Resource，并拒绝重复 ID；B0 不实现注册表或 Save/Load。

## 伤害与每发弹道

实际 chamber → WeaponFireResult.fired_round → Hitscan/Projectile → DamageInfo.ammo_data → ArmorCalculator。WeaponData、MagazineData 和 AttachmentData 不能成为 flesh/armor/bullet level 的第二权威来源。

未来每发 ShotContext 可以保存 `base AmmoData velocity × Weapon/Barrel velocity multiplier` 的实际初速；modifier 默认 1.0。Projectile 使用这次 ShotContext 的数值，不执行 `ammo_data.muzzle_velocity *= multiplier`。B0 没有新增枪管/速度 modifier Gameplay。

## 换弹时序（已实现）

ReloadTimingProvider.get_base_duration(WeaponData, incoming MagazineData, chamber_is_empty) 是纯数据函数，Stored Runtime 同样可以调用，不依赖 Firearm binding。

WeaponData.reload_profiles 按 weapon_animation_family / magazine_animation_family 匹配；空 family 是 wildcard，匹配更精确的 profile 优先。同分按配置顺序，内容作者避免重叠等优先级 profile。动作依据开始换弹前 chamber 是否为空：Tactical 或 Empty。原 WeaponRuntime.ReloadType.TACTICAL/DROP 仍只决定旧弹匣回 Rig 或掉 WORLD，不能用 DROP 替代 Empty。

有该动作的 Animation 则取 length，否则取对应 fallback。没有匹配 profile 则取原 WeaponData.reload_time（兼容旧 Definition）。当前 test Rifle profile 的 Tactical/Empty 都为 2.0，保留旧平衡。

最终时长 = provider base × 当前 Coordinator tactical/drop multiplier × BodyInjury reload multiplier。Arms 当前为 1.35。将来动画播放：speed_scale = animation.length / effective_duration；不修改共享 Animation.length。Stored Weapon 的 Inventory reload 事务/时钟推进归 B1，实现前不能宣称 Inventory 中任意枪都能主动换弹。

## 配件 schema（仅静态准备）

AttachmentSlotDefinition：slot_id、slot_interface、compatibility_tags、visual_transform。WeaponData.base_attachment_slots 是数组，不写死为 optic/muzzle/grip/stock 四字段。

AttachmentData：definition_id、display_name、compatible_slot_interfaces、weight_kg、provided_slots。Adapter 可以提供新的 optic slot，另一个定义可安装在这个接口上；身份是内容 ID，兼容性是 interface/tag。

未来配件本体必须是 InventoryItemInstance，有 ItemDefinition 指向专门 AttachmentData。Attachment runtime 保存安装的真实 ItemInstance 和 slot path，而不是把 Resource 当作唯一运行时对象。完整安装/拆卸事务、Context Actions、视觉拼接、动画都未实现。

## B1 子树与重量接入契约（未来）

当前注册器仍负责实际 loaded magazine wrapper 与 portable 内容。未来统一 Collector 的输入是一个 InventoryItemInstance root 和 owner registry，输出无重复的实际 ItemInstance 集合、storage grids 与带角色的 ownership edges。

边角色至少有：container:<grid/placement>、weapon_magazine、attachment:<hierarchical slot path>。一把枪可以同时拥有 loaded magazine edge 和任意 attachment edges，不能把两个角色存在同一个无角色槽或单一 child 字段。查询必须返回已经存在的 magazine/attachment wrapper identity，不能在每次遍历时复制 Item。AmmoData rounds/chamber 是共享定义引用，不伪装成 InventoryItemInstance child。

Collector/事务必须在 mutation 之前拒绝 cycle、同实例多位置、跨 owner alias、无效 grid/placement；将移动/掉落/拾取的整个组迁移，不分别重新初始化 runtime。动态 populated Rig/Backpack 的自动登记第二技术债没有在 B0 修复。

未来重量从根 ownership 位置递归：Weapon bare + Attachment subtree + Loaded magazine empty + 该 magazine 实际 rounds weights + Chamber round；Portable base + 各 compartment children；Loose ammo = round_weight_kg × 实际 stack_count；Generic 用 ItemDefinition.weight。专门 Weight 字段是未来类型权威，不能再把同一 loaded child 作为 registry root 重复相加。WORLD root 不计玩家携重，container内部/attachment/weapon_magazine child 不能又被当作根重复计重。

当前 ItemInstance.get_weight 和 Player 总重量仍是旧 flat 算法，专门 weight 元数据默认 0.0，不改变既有平衡；B1 才接入递归重量/UI。这里定义的是未来算法，不是 B0 已完成能力。

## Stat resolver（已实现 base，未来 modifiers）

WeaponStatResolver.resolve(runtime) 返回独立 ComputedWeaponStats base snapshot，包含当前 loaded magazine Definition。数值及 slot 数组可以在 snapshot 中改动，不会写回 WeaponData；slot Resource 本身仍是共享静态定义，消费者不修改它。

未来 stat 输入还将包括 Attachment Item tree 和必要 context。每 stat 的顺序冻结为 Base → additive sum → multiplicative product → clamp。OVERRIDE 必须是有明确优先级、唯一获胜者的少量配置，不能用数组最后遍历者隐式覆盖。AttachmentData 的 stat modifier schema/应用仍未实现，不从现有 empty schema 宣称完整 Modifier 功能。Injury 与 ADS context 继续独立于共享 WeaponData。

Ergonomics 当前只保留/计算，不影响 ADS、sway、stamina、reload 或 weapon switch。Magazine 不修改 Damage，可在未来只通过 weight/capacity/animation family 等上下文影响操作。没有创建任何每枪独立 Gameplay 脚本。
