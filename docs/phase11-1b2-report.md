# Phase 11.1B-2 完成报告

本报告记录 B2-0、B2-1、B2-2 的实际实现与验收。基线 HEAD 为 `24ce1e5`，本阶段不提交 Git，不进入 B3。最终测试与运行状态以报告末尾的审计结果为准。

1. **B2-0 文件。** 新增 `scripts/inventory/inventory_reservation.gd`；修改 `inventory_transaction_service.gd`、`inventory_weight_calculator.gd`、`external_inventory_transfer.gd`、`scripts/weapons/weapon_runtime.gd`、`reload_coordinator.gd`。UI 阶段另外把 `loot_container_access.gd` 的持续访问权限与暂时事务锁分开。
2. **Reservation ownership。** `InventoryReservation` 保存真实 Item、原始位置与旋转、所属 registry 的 WeakRef 和 RESERVED / COMMITTING / COMMITTED / CANCELLED 阶段；没有复制 Item、Runtime 或 rounds。
3. **TRANSIT。** TRANSIT 是暂时没有物理位置；Item 仍注册于原 registry。只有明确持有 reservation 的 TRANSIT 才属于计重的 carried root。普通未放置的注册测试物品没有被全部纳入计重。
4. **Reservation root/edge。** `get_direct_parent()` 对有效脱离位置的 reservation 返回 `edge_role=reservation`，parent=null。存在正常物理 parent 时保留该边；reservation 此时只是事务 lease，不再另加一条计重边。
5. **Ownerless gap。** 内部移动与换弹不清空 owner；跨 registry 同步提交直接替换 owner 引用，没有先设 null 的中间步骤。公开通知在完整提交后发送。
6. **Double count。** `get_location_count()` 仅在没有物理位置时计入 reservation。重量继续通过 OwnershipGraph 的单次访问、alias/cycle/registry 校验；loaded magazine 与 nested contents 不重复计重。
7. **Weapon→reservation。** 换弹前先追踪原 loaded magazine。实际换枪匣后，原 weapon edge 消失，旧匣立即成为已保留逻辑 root，覆盖 runtime 的 reload_finished 通知顺序。
8. **Reservation→weapon。** 新匣在 Grid 脱离前建立 reservation；真正装入 WeaponRuntime 后改由 weapon_magazine edge 承担 ownership，再释放 lease。
9. **Grid→reservation。** `reserve_item()` 验证完整 subtree，记录实际 placement 后脱离 Grid。原 registry、所有子物品与 runtime identity 保留。
10. **Reservation→Grid。** `commit_reservation()` 先验证真实 Grid、位置、旋转和 policy，再放置、结束 lease、通知。普通 move/equip/complete placement 等入口不能直接夺取已保留物品。
11. **R 重量。** Main 的真实 R 输入：8.238 → 中途 locked 8.238 → 完成 8.238 kg，reload type=Tactical，结束时无遗留 lease。
12. **受伤 R。** Main：8.226 → 中途 locked 8.226 → 完成 8.226 kg。Arms multiplier=1.35，基础时间=2.0，实际时间=2.7 秒。
13. **RR 中途。** Main 真实双击 R：8.214 kg；等待中 locked、DROP type，仍为8.214 kg。
14. **RR WORLD。** 旧匣29发，实际重量0.15+29×0.012=0.498 kg。WORLD commit 后8.214→7.716 kg；同一旧 Item 创建真实掉落节点。
15. **Cancel。** `ReloadCoordinator.cancel_reload()` 恢复原候选 Grid、原加载匣、实际 rounds/chamber，结束 lease、解除锁。普通 reservation cancel 也恢复原位置、旋转与 subtree 重量。
16. **失败事务。** 非法位置、满 Grid、无效时间、错误 split 数量先失败或回滚到原保留状态；不会减少数量、重建 runtime 或失去重量。新增测试覆盖 failed commit 与 failed begin。
17. **跨 registry。** 提交前仍归 source；提交后同一 subtree 归 destination，source/destination 重量等量反向变化，公开回调看到完整终态。没有 WORLD 中转。
18. **重量扩展。** Calculator 仅扩展 root 选择，加入有效 reservation root；遍历与 runtime/实际 rounds 的质量计算仍使用原共享 OwnershipGraph。Player 与 Crate 使用相同规则。
19. **没有 UI cache。** Player header、Crate header、窗口 total、Inspect 全部调用共享 Calculator。窗口不保存另一份物品重量。
20. **Health。** Health、BodyHealth、Injury、Armor、damage pipeline 文件均未改动；旧回归与文件哈希复核。
21. **TimingProvider。** 原 `ReloadTimingProvider`、Rig-only 选择、tactical/drop 策略保留；未变成另一套计时架构。
22. **Arms。** 原 Arms×1.35 保留，通过 executor 的原 InjuryComponent 读取，不修改 WeaponData。
23. **浮窗文件。** 新增 `scripts/ui/portable_container_window.gd`、`portable_window_manager.gd`；修改 InventoryUI / GridView / EquipmentSlot / VicinityLootPanel。新增 actions 相关文件见39–45。
24. **Window contract。** PortableContainerWindow 是 view-only，直接引用 actual Item 的 storage grids，不注册、复制、迁移或拥有 inventory。
25. **唯一窗口。** 同一 Item 重复双击或 Open Container 返回同一 Control，只置前；不同 Item，即使同一 Definition，也各有窗口。
26. **Identity key。** manager Dictionary 以实际 InventoryItemInstance 为 key；没有按 Definition ID 或显示名称去重。
27. **Z-order。** 打开、重复打开、点击窗口时只调整 surface 的 child 顺序。标题可拖动，位置有 viewport 边界；大 layout 通过 ScrollContainer 查看，viewport 改变时保持窗口可访问。
28. **父子。** 从窗口打开子 portable 时记录 parent_window；同时保留真实物品祖先位置签名，物理 parent 与 UI parent 不混为一谈。
29. **Parent close。** A→B→C：关闭A递归关闭B/C；关闭B保留A。关闭只销毁 view，不改变 Item/Runtime/owner/weight。
30. **Parent move。** A 的位置、祖先、registry、WORLD commit 或 access 变化会关闭A及其窗口后代。每帧及 change 通知校验真实状态。
31. **Child move。** Main 中把B在A中移动：只关闭B/C，A保留。对应自动测试也通过。
32. **Same-slot。** 原 successful no-op 不产生 change/mutation；Main 验证A窗口及后代的 Control identity 全部保留，registry signal=0。
33. **Backpack。** 外部4×5，实际内部5×5；窗口显示的就是 runtime.grid，含实际套包、实际 Ammo stacks。
34. **Rig。** 遍历 actual storage grids 构造 views；新增测试覆盖2×2、3×1、1×3的三格异构 Rig，未写死四格1×2。
35. **Cross-window drag。** 复用原 DragContext、Ghost、Preview、Snap、CandidateResolver 与 Transaction。Main 原生输入验证 Main pocket→nested B、B→A、A→Main pocket，均 green preview、真实提交、ghost 清除、11.25 kg守恒。Crate/Window 通路复用 ExternalInventoryTransfer。
36. **Deep nesting。** A→B→C 的实际 Grid 支持人工操作与独立窗口；F 的 root-only/current-orientation-first/opposite fallback 行为未修改。
37. **Cycle preview。** A拖到后代B：候选invalid、提交失败；Graph仍拒绝 self/ancestor/alias。标题、header、margin 也不会接受背后 equipment 或 WORLD 落点。
38. **Weight UI。** Main 图中 Player11.25、A5.22、B3.72、C2.22 kg，均来自相同递归计算；窗口没有独立累加逻辑。
39. **Resolver。** 新增 `scripts/inventory/item_action_resolver.gd`，通过 capabilities、实际 ownership/access/busy/location 返回可执行动作。
40. **Descriptor。** 新增 `item_action_descriptor.gd`，含id、label、enabled、disabled_reason、payload；保留UNLOAD / RELOAD_WITH ID，无可点击占位动作。
41. **Executor。** 新增 `item_action_executor.gd`，在执行瞬间再次 resolve/revalidate，调用真实 inspection、portable open、WORLD drop 或 transaction split。菜单不执行伤害、装填或 ownership 算法。
42. **Capability 结果。** Player普通物品/Weapon/Magazine：Inspect、Drop；portable再加Open Container；Ammo加Split。Crate portable只有Inspect/Open，未加入Crate Drop；BUSY返回空列表。
43. **Inspect。** 新增 `item_inspection.gd`：name/id/category/capabilities/外部尺寸/base/contents/total；Mag容量/interface/实际composition与empty/rounds mass；Weapon实际CH/MAG/mode/interfaces/bare/loaded/chamber total与base ergonomics；Bag/Rig实际内部尺寸。只读测试通过，没有虚构final recoil。
44. **Drop subtree。** 沿用原 WorldItemFactory 与 transaction；Main A/B/C+Ammo40/20只新增一个WORLD root visual，5.22 kg一次从Player扣除，后代仍保留实际parent/Runtime。
45. **Split UI。** 新增 `scripts/ui/ammo_split_dialog.gd`，Slider与SpinBox双向同步，Confirm/Cancel。旧Split按钮保留以兼容既有测试，但同样调用Executor，最大值随 selected actual count 更新。
46. **动态范围。** 真实count60→max59；53→max52。不存在固定59逻辑；只允许1..actual count-1。
47. **Split prevalidation。** 确认时重新检查实际Item、owner、位置、ancestor、runtime、count、access、lock/busy；同一实际Grid先找合法空位，再改变source数量。
48. **Split atomicity。** source与new stack各持有明确reservation；锁定同步提交、注册与实际 placement 完成后再通知。失败没有半个新stack或source扣减；完成释放两个lease。
49. **Split weight。** 观察reserve、register、locked notification阶段均守恒。Main无空间Pocket split保留60发及重量；nested C成功split成20/40，Player11.25→11.25 kg。
50. **Stale menu。** 新增 `scripts/ui/item_context_menu.gd`。Item使用WeakRef与identity/location/count签名；移位、owner/ancestor变动、drop/delete、数量变化、drag、事务、窗口/Inventory关闭或新菜单均关闭或使旧操作无效。
51. **重新验证。** Descriptor仅供显示，Executor再查真实状态；SplitDialog确认必须与实际签名一致，stale count/location/access不会继续执行。
52. **Future BUSY。** `is_item_busy()` 查询现有reservation/registry lock，并提供Callable hook；busy RMB无菜单。manager另提供before_close hook；没有实现Magazine BUSY scheduler或逐发操作。
53. **旧3216。** 64个原执行配置完整运行；原脚本与期望未改，旧测试最终3216/3216通过。
54. **B2新增。** 8个测试脚本，共202 assertions，全部通过，详情见下表。
55. **总计。** 最终72个执行配置，3418 assertions passed，0 failed。
56. **Parser。** 最终154个生产/测试脚本逐个`--check-only`，0 Parser Errors。
57. **Runtime。** 最终全测试与正常Main验收无runtime error。早期RED、cache登记问题与临时MCP辅助脚本错误没有清日志，详见过程记录。
58. **Warnings。** 最终全测试、154个parser检查、正常Main均0 Godot warnings；无新增warning_ignore或警告关闭。
59. **MCP mid R。** r16512002-13真实输入，8.238 kg，中途locked/type1/remaining1.783，完成8.238。
60. **MCP injured R。** 同一验收run，8.226 kg，中途remaining2.467，基础2.0×1.35，结束8.226。
61. **MCP RR。** 同一验收run，8.214 locked→7.716 WORLD；0.498 kg实际旧匣，无残留reservation。
62. **MCP floating。** 最终窗口验收r17757030-17：真实GUI双击root/nested、重复不重建、三窗actualGrid、标题原生拖动、原生Close按钮递归关闭全部通过。
63. **MCP dragging。** 三方向真实鼠标press/motion/release成功，green candidates与actual placements一致；weight11.25，ghost全部结束。
64. **MCP context。** 原生RMB在Magazine/Backpack/Ammo给出2/3/3项菜单；从实际菜单信号打开Inspect，签名与重量不变；cycle/noop验收通过。
65. **MCP Split。** 真实菜单打开dialog，Slider13→Spin13，Spin7→Slider7；无空间0 mutation；nested成功20/40、重量守恒。
66. **MCP Drop/F。** 菜单Drop后11.25→6.03 kg，WORLD仅一个root。摄像机真实指向掉落、真实短F输入，原A回到Backpack slot，原全部identity与child parent保留，重量恢复11.25，WORLD恢复6 roots。
67. **MCP same-slot。** 原候选与提交入口成功，registry signal=0，全部3窗口identity保留；旧171 assertions继续通过。
68. **Addon。** SHA256比较313/313相同，无增删改。同时191个受保护原测试/资源/场景/combat/player/project文件全部保持原hash。
69. **Main final。** 最终重新启动初始test_level，run=r18064424-18。MCP只读确认Player8.25 kg、MAG29/CH1、AUTO/READY、2个30发备用匣、Ammo60、WORLD6、0 reservations、无伤势/浮窗/Split dialog，Inventory关闭且unlocked，Player/Firearm physics启用。当前game日志只有helper注册信息，无error/warning；Editor保留早期class登记导致的4条历史错误，当前run从cursor4开始，没有新增错误。Godot版本4.7.2-stable，Main保持运行。
70. **技术债。** 保留明确冻结的legacy runtime-first1×1 magazine fallback；窗口签名/weight即时计算在原型规模使用，没有性能缓存或未测量优化。
71. **B3 blocker。** B2的reservation、可访问窗口、动作与busy/close接口已到位；后续仍需按B3规格实现逐发行为与完整busy生命周期。未擅自开始。
72. **进入B3建议。** B2验收后可进入B3的正式设计与测试；先由用户给出后续范围。
73. **Round transfer。** 没有MagazineRoundTransferAction、逐发load/unload。
74. **Explicit reload。** 没有B4 explicit magazine reload、Magazine→Weapon drop target、target chooser或old-mag ancestor search。
75. **Attachments。** 未实现附件装备、安装或卸载。
76. **Character stats。** 未实现Character Stats/Skills/FinalGunplayResolver；WeaponStatResolver仍actor-independent。
77. **Encumbrance。** 重量只用于数据/Debug UI，不影响movement、gunplay、Health。无负重效果、存档、AI或新插件。
78. **Git。** HEAD仍24ce1e5；没有commit、push、tag、reset或新worktree；所有改动留在当前项目供检查。

## 新增测试

| 测试 | assertions |
|---|---:|
| reservation_ownership_test | 36 |
| transit_weight_continuity_test | 33 |
| portable_window_test | 24 |
| portable_window_lifecycle_test | 21 |
| portable_window_native_test | 12 |
| item_context_action_test | 29 |
| split_reservation_test | 28 |
| b2_review_regression_test | 19 |
| 合计 | 202 |

## 修改与新增文件

原文件修改共10个：`scripts/inventory/{inventory_transaction_service,inventory_weight_calculator,external_inventory_transfer,loot_container_access}.gd`；`scripts/weapons/{weapon_runtime,reload_coordinator}.gd`；`scripts/ui/{inventory_ui,inventory_grid_view,inventory_equipment_slot,vicinity_loot_panel}.gd`。

新增生产脚本9个：`inventory/{inventory_reservation,item_action_descriptor,item_action_resolver,item_action_executor,item_inspection}.gd`；`ui/{portable_container_window,portable_window_manager,item_context_menu,ammo_split_dialog}.gd`。新增测试8个如上表，并有Godot自动生成的UID sidecar。本报告及`docs/superpowers/plans/2026-10-07-b2-runtime-windows-actions.md`是新增文档。场景、Data资源、InputMap均未修改。

## 审阅与过程记录

一次独立只读审阅提出三处Important问题：临时锁误关闭Crate窗口、chrome穿透到背后equip/WORLD目标、窗口越界不可访问。新增review regression先复现11处失败，再修复为19/19；公共complete placement绕过reservation也纳入修复。原生窗口测试再次12/12通过。没有第二次审阅、没有延后minor。

实际裁定：保留legacySplit按钮的兼容入口，但共享Executor且动态范围；lease在物理edge存在时不是第二个parent；split同步内部没有生产yield/通知暴露部分提交，保留锁内提交并测试各可观察阶段；窗口即时校验与质量计算暂不添加缓存，性能优化须有测量依据。这些都没有改变用户冻结的B3/B4或旧测试范围。

裁定成本与边界：保留旧Split入口意味着额外维护一个UI入口；lease计重依赖物理edge与reservation互斥选根，若未来改变该合同必须继续验证重复计重；Split的原子性依赖当前同步、无yield/外部回调的提交段，未来异步化需要重新审查；即时窗口校验在大量窗口/物品时可能增加帧开销，需测量后再优化。冻结的legacy fallback依照B4边界保留，仍是已知技术债；后续B3/B4不在本次实现内。无延后minor或未修复Important问题。

初期完整B2-0运行在live Editor与headless import共享class cache时出现InventoryReservation登记丢失；通过MCP刷新脚本entry/scan登记，随后完整3216重新通过。初期新测试fixture几何不合法、observer测试自身Callable引用循环，以及原生drag ghost被误当窗口，均定位并修复。review修复后原生fixture改为两个实际可见、不互相遮挡的窗口位置；旧期望未改。

MCP辅助验收曾把三个换弹合并进一次超过8秒的eval，被bridge终止；后来改用真实game_manage输入与短步骤。另有辅助脚本使用屏幕外坐标及错误的PlayerInteractor属性导致eval错误；改用实际1152×648 viewport与真实Node路径后，正常完整验收run全部通过。这些错误属于辅助验收记录，没有关闭警告或清空Output掩盖。

审计目录：`C:\Users\疯狂\AppData\Local\Temp\codex-fps-phase11-1b2-audit`。包含原baseline、B2-0完整gate、RED/GREEN日志、最终release72矩阵、154个parser日志、MCP输入/中途重量/完整窗口动作验收、截图、addon/protected SHA与进度ledger。最终计数和恢复状态由release与MCP终态证据确认。
