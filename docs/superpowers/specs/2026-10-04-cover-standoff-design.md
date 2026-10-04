# Cover-first / Standoff 战斗 AI 设计草稿

状态：待用户审阅；尚未实现产品代码或运行新增 AI 测试。

## 目标与当前项目

普通远程 Enemy 发现 Player 后优先选掩体，没有有效掩体时保持距离。不得把 Player 当前坐标作为普通战斗的导航目标，不新增追击状态。

2026-10-04 检查结果：Godot AI MCP 可访问 Test_1，编辑器版本为 4.7.2-stable，当前打开 test_level.tscn，游戏已停止。项目具有 Firearm、两种射击模式、弹匣与弹膛、护甲、身体 HP 和伤势实现，但没有 Enemy、NavigationAgent3D、导航区域或感知代码。Phase 7 文件目前包含未提交改动，必须保留。

用户给出的行为规则是本设计的依据。为使规则可运行，本草稿假设新增一个最小 Enemy 和专用战斗测试地图；原射击测试地图及主场景设置保持现状，战斗地图通过编辑器运行指定场景测试。

## 需要确定的规则交叉点

HidePosition 会主动让 Enemy 与 Player 失去 LOS。若同时要求“任何 COMBAT 失去 LOS 立即 SEARCH”，则不能让隐藏期间一直保持 COMBAT。

推荐方案：严格遵守 LOS 规则。失去 LOS 即停止 Trigger，进入 SEARCH，冻结 last_known_target_position；保留选中的掩体、既定导航目的地和隐藏等待计时。SEARCH 可按最后已知位置选择一个可达 PeekPoint 并移动过去观察，不能向 Player 或最后已知位置追赶。只有感知重新确认 Player 可见，才能回到 COMBAT 并射击。这样隐藏阶段会暂时显示 SEARCH，但仍能完成 Hide → Peek → Burst → Return 循环。

另一方案：有意藏入掩体时保持 COMBAT/HIDE，但冻结目标位置且禁止射击；意外遮挡才进入 SEARCH。这更接近通常的掩体状态机，但需要对用户“无论 COMBAT，只要失去 LOS 就 SEARCH”增加例外。因此不推荐默认采用。

感知层允许进行重新发现检测，但只有检测成功才能向行为层发布新的目标位置。不可见期间，移动、瞄准、掩体评分和距离决策只能使用冻结的最后一次可见观察，不能利用墙后的真实位置。

## 最小组件与场景

- scripts/ai/cover_point.gd：CoverPoint，根节点和 HidePosition / PeekLeft / PeekRight 均为 Marker3D，根加入 cover_points group。开发者手工放置，不生成动态掩体。
- scripts/ai/enemy_controller.gd：CharacterBody3D 控制器。管理感知结果、AIState、掩体子阶段、导航移动、距离策略和 Burst 请求。暂不引入 Behavior Tree、GOAP 或额外服务框架。
- scenes/ai/cover_point.tscn：可手动放置的标记场景。
- scenes/enemies/enemy.tscn：基础几何外观、CollisionShape3D、NavigationAgent3D、观察位置，以及 Head/Camera3D/WeaponRoot 层级中的现有 Firearm。Enemy 的 Camera3D 不设为 current。
- scenes/levels/combat_test_level.tscn：基础几何地面、遮挡墙、手工 CoverPoint、烘焙导航、Player 和一个 Enemy；支持有掩体及无掩体测试。
- tests/cover_combat_test.gd 和 tests/standoff_combat_test.gd：使用真实导航和 World 碰撞验证行为，不以模拟“有效掩体”代替几何验证。

Enemy 与 Player 的射击接入现有 Hurtbox / BodyHealthComponent / HealthComponent。Player 当前没有 Hurtbox，需为实战验证增加四区域 Hurtbox，并排除射手自己的全部碰撞 RID；身体部位归零不直接死亡的规则保持不变。Enemy 同样复用现有伤害组件，不新增另一套伤害系统。

## Cover 验证与评分

Cover 的三个位置表示角色脚部落点。World LOS 验证使用这些点加观察高度，避免地面把脚部射线误判为有效遮挡。

在 cover_search_radius（草稿默认 40m）内查询手工点。HidePosition 必须具有完整可达路径，路径末端实际到达点附近；不把返回一条部分路径视为成功。Player 观察位置到 Hide 观察位置的 World 射线必须被实体掩体阻挡。至少一侧 Peek 必须可达，且到目标观察位置没有 World 遮挡。World 使用已有 layer 1；Hurtbox 不参与遮挡判定。

距离 Player 小于 minimum_combat_distance 的掩体不作为常规候选。通过验证后，按路径长度和距离 preferred_combat_distance 的偏差评分，距离 15–35m 的位置优先。不可遮挡或不能 Peek 的点直接淘汰，不用评分弥补安全性不足。评分使用实际导航路径距离，而不是 Enemy 到点的直线距离。

cover_reevaluation_interval 默认 2s。只有目标确实可见时才使用新的观察重新验证；隐藏期间只用最后已知位置。当前点失效时重新选择，找不到有效点且目标可见则 STANDOFF，不可见则 SEARCH。

## 状态、导航与射击

AIState 使用 IDLE、SEEK_COVER、COMBAT、STANDOFF、SEARCH。COMBAT 的掩体子阶段为 HIDE、MOVE_TO_PEEK、BURST、RETURN_TO_HIDE。死亡由 Overall Health 的 died 信号停用控制与 Trigger，不由 zone_destroyed 触发。

发现目标：记录可见观察 → find_best_cover() → 有效掩体则 SEEK_COVER，导航目标只设为 HidePosition；无掩体则 STANDOFF。到达掩体后先等待，再选择 LOS 有效且可达的 PeekPoint。两侧都有效时随机选择；两侧无效时按重新评估间隔换掩体或 SEARCH。

移动全部通过 NavigationAgent3D 的路径、CharacterBody3D.velocity 和 move_and_slide()。到点后停止水平移动，不通过 global_position / transform 直接移位。

Burst 默认为随机 2–5 发，以 Firearm.shot_fired 统计真正发射数量。Enemy 只调用 set_trigger()、set_aiming() 和 request_reload()；不调用 _fire_shot()、改写冷却时间或直接扣弹药。达到 Burst 数量立即释放 Trigger，返回 Hide。低帧率也不得超过 Burst 数量或绕过 RPM。

SEEK_COVER 移动中仅在目标仍可见且距离小于 emergency_distance（8m）时允许短 Burst 防御射击。其他时间不移动射击。空仓时走现有换弹流程，备用弹匣耗尽不凭空补弹。

## STANDOFF

参数默认 minimum=15m、preferred=25m、maximum=35m。vision_range 草稿默认 60m，感知使用有限视距、视野方向和 World LOS。

- 距离 15–35m：面对可见目标，短 Burst；每隔随机 1–3s 选择左移、右移或原地保持。
- 距离小于 15m：寻找远离目标的导航退路，目标是恢复到约 25m。无法找到合法退路则保持原地，不改为冲向目标。
- 距离超过 35m，但仍在视野内且 LOS 有效：允许远距离 Burst，不向前追击。
- 超出视距或 LOS 失效：释放 Trigger，冻结观察并 SEARCH。

退路与横移候选既要可达，也要保证导航路径不会为了绕障碍而主动向目标推进。若路径或下一步方向违反保持距离约束，则取消移动。STANDOFF 不存在 MoveTo Player，也不逐帧把导航目标改成 Player 坐标。

## Firearm 接入与碰撞

保留现有 Firearm 的弹匣、弹膛、RPM、散布、后坐力、枪口反馈、两种射击模型和 process_impact 伤害入口。复用现有 Head/Camera3D/WeaponRoot 层级，使射手仍是武器上方的 CharacterBody3D。此阶段不进行整套枪械架构重写。

射线及 Projectile 都排除所属射手的身体和所有子 Hurtbox RID。World + Hurtbox 的原射击 Mask 保持有效，世界碰撞继续挡住 Hide 位置的攻击。移动碰撞保持 Player / World / TargetBody 语义；Enemy 的身体层按独立命名层接入，不把 Hurtbox 当移动障碍。

PlayerController 的输入、ADS、跳跃和伤势倍率计算保持现状。新增 Player Hurtbox 后，应验证自我射击排除与已有伤势组件绑定仍正确。

## 验收与回归

新增测试必须证明：

1. 无遮挡的 Cover 无效；Hide 有遮挡且 Peek 有 LOS 时有效；不可达 Hide / Peek 不入选。
2. 多个 Cover 选择更合理的路径和战斗距离；特别近的点不优先。
3. 首次发现优先 SEEK_COVER，目的地为 Hide 而非 Player；抵达后不继续靠近玩家。
4. Peek 可发射真实 Firearm Burst；Hide 的 World 实体挡住玩家 Hitscan 和 Projectile。
5. 每次 Burst 为 2–5 发，600 RPM 仍生效，低帧率不超发。
6. 玩家移动后按间隔重新验证，不每帧挑点；失去 LOS 后 last_known_target_position 和导航目标不会追随隐藏玩家。
7. 无 Cover 进入 STANDOFF；25m 不接近，10m 退后，40m 可见时不追击；横移经过合法导航且不穿墙。
8. 三种战斗状态失去 LOS 均 SEARCH；主动隐藏后的观察循环仍可重新获得可见目标。
9. Enemy 射击使用真正 fired_round；双方自身 Hurtbox 不会导致自伤；原有 Armor → Hurtbox → BodyHealth → Overall → Injury/Death 不变。
10. 原 Phase 7 的 894 项断言全部保留并重新运行；新增脚本解析检查、编辑器启动、Output 和 Warnings 均检查。

测试先失败再实现。尚未执行以上新增测试，新增断言数量以实现后的实际运行结果为准。不得修改 addons/godot_ai，不安装插件，不改写现有未提交的 Phase 7 改动。

## 下一步

用户审阅此草稿，确认严格 LOS 与主动隐藏的处理方式，以及新增最小 Enemy / 专用测试地图的范围。确认后再写实施计划，按单代理方式执行，不派生子代理。
