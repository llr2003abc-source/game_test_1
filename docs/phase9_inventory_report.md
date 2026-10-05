# Phase 9 实施报告

最终验收：原有1449项 + 新增298项 = **1747 assertions passed，0 failed**。74个FPS脚本解析通过。以下按用户要求的70项逐项记录。

1. 新增文件：`scripts/inventory/`11个脚本；`scripts/ui/`3个；`scripts/weapons/reload_coordinator.gd`、`reload_input_resolver.gd`；`data/items/`5个定义、`data/ammo/weapon1_level2_round.tres`；`scenes/items/`掉落场景及4个几何外观、`scenes/ui/inventory_ui.tscn`；14个新测试及本报告/实施计划。Godot自动生成配套UID。
2. 修改文件：`project.godot`、`scenes/player/player.tscn`、`scripts/player/player_controller.gd`、`scripts/weapons/{ammo_data,ammo_hud,firearm,magazine_data,weapon_data}.gd`；5个旧集成测试夹具：acoustic_gameplay、firearm_runtime_integration、firearm_state、fps_regression、injury_gameplay。没有修改旧断言预期/数量。
3. PlayerInventoryComponent聚合Equipment、Transaction/Runtime Registry、6个Pocket、Secure、当前Rig/Backpack和ReloadCoordinator。容器卸下仍保留原Runtime及内容。
4. ItemDefinition只保存静态ID、名称、类别、格尺寸、max_stack、weight、装备槽限制、Ammo/Magazine/Weapon定义和几何场景引用。
5. InventoryItemInstance保存definition、stack_count、rotated和runtime_state；不复制武器/弹匣内部状态。
6. 武器绑定原WeaponRuntime；弹匣绑定原MagazineInstance；Rig/Backpack各自绑定原容器Runtime。
7. Transaction先验证位置、尺寸、锁、兼容性及引用唯一性，再提交；移动/旋转/装备/堆叠/拆分/装弹都通过同一入口。
8. InventoryGrid保存尺寸和Placement，占格检查使用矩形边界与交集；允许移动、合法旋转及自动找空位。
9. Item位置从已登记Grid、Equipment、WeaponRuntime.loaded_magazine和World记录解析，不在UI复制位置。身份Registry拒绝重复Runtime包装、重复容器占位及已有归属的重复接管。
10. Equipment为六个独立槽，不是连续Grid；预装内容的容器在装备提交前原子验证并登记内部物品。
11. PRIMARY要求武器类别/WeaponRuntime及槽许可；当前装备Primary Weapon1。
12. SECONDARY支持允许该槽的武器，当前为空。
13. PISTOL要求Pistol类别及WeaponRuntime，当前为空。
14. KNIFE保留Melee槽，当前为空；没有新增近战系统。
15. RIG要求Rig类别及RigContainerRuntime；只有当前装备Rig提供换弹候选。
16. BACKPACK要求Backpack类别及BackpackContainerRuntime；卸下后内部物品不销毁。
17. 1/2/3/4选择对应武器槽；空槽保持原有效武器；Reload时拒绝切换。
18. 活跃装备变化时Firearm bind/unbind原Runtime；Firearm继续执行射线/投射物、散布、后坐力、命中和声音。
19. 武器放进Backpack后保留Runtime、弹匣、Chamber、模式与冷却；真实MCP拖放验证同一Runtime。
20. Rig为4个独立1×2 Grid，不能横跨槽位，不能利用移出replacement之后的空间保存旧弹匣。
21. Pocket为6个独立1×1 Grid，不能合并空格。
22. Backpack内部5×5，可保存旋转后的武器。
23. Backpack物品外部3×4。
24. Secure为连续3×3；支持合法放置/旋转/堆叠/拆分/装弹。仅尺寸合法的Rig可放入，Backpack外部3×4无法放入。没有死亡持久化规则。
25. Primary Weapon1外部5×2，关联现有Test Rifle定义及实际WeaponRuntime。
26. Magazine1外部1×2，使用现有30发定义，每只运行时实例独立。
27. Weapon1 Level2 Ammo物品1×1、max_stack60，独立L2资源flesh40/armor30；初始Backpack60发。
28. AmmoData增加稳定ammo_type_id，默认weapon1_ammo；未改变旧Test Round伤害/弹道数值。
29. MagazineData增加magazine_type_id=magazine_1和compatible_ammo_type_ids。
30. WeaponData增加compatible_magazine_type_ids，测试枪允许magazine_1。
31. Ammo→Magazine按类型ID验证；错误弹药不消耗、不改变rounds。
32. Magazine→Weapon由ReloadCoordinator验证类型ID；不兼容或空弹匣不能作为replacement。
33. 装弹数量取request、loose_count、剩余容量三者最小值，push真实AmmoData引用；零堆叠从原位置及登记中移除。
34. 堆叠只合并同ID弹药，受max_stack限制；拆分先确认数量和位置合法再扣原堆叠。验证40+30→60+10及20发拆分。
35. Mixed Ammo保持原引用顺序；追加装弹不会替换旧rounds，掉落A/B/A/C顺序不变。
36. ReloadInputResolver只把输入解析成TACTICAL/DROP请求，不查询Inventory。
37. Double Tap窗口0.22秒，使用delta累计；忽略按键echo，UI打开取消pending。
38. Single R等待窗口结束才请求换弹。
39. Double R在窗口内只发一次DROP，不再补发TACTICAL。
40. 没有兼容且非空的装备Rig弹匣时，两种请求都完全不动作。
41. 空兼容弹匣不是候选；不会借Double R执行卸弹匣。
42. Tactical先验证旧弹匣真实可放空间，保留Chamber，换入replacement；旧弹匣原实例返回Rig。
43. Rig满或空格碎片不能放旧1×2弹匣时，Single R自动改为DROP。
44. Double R强制DROP，但仍先要求有效replacement；换弹时间保持WeaponData基础值，可叠加类型/伤势倍率。
45. DroppedItem保存原InventoryItemInstance→原MagazineInstance→原rounds。Area仅layer5(16)/mask0；不会阻挡移动、射线、投射物或导航。
46. ReloadCoordinator登记并锁定原replacement；成功后通过WeaponReloadResult.old_magazine查Registry，旧物品返回Rig或进入World；新物品位置直接由Runtime.loaded_magazine推导，完成只提交一次。
47. Main不生成、不查询legacy spare_magazines；兼容入口只由旧测试显式调用且重复调用安全。
48. HUD MAG/CHAMBER来自实际Runtime；SPARE MAGS来自当前装备Rig中兼容非空弹匣数；无武器显示NO ACTIVE WEAPON。
49. Tab背包使用48px格子、文字和基础控件，窗口不暂停游戏；打开释放鼠标并屏蔽MouseLook/Fire/ADS/Reload/快捷槽，关闭重新捕获并阻止残留点击开枪。
50. Equipment为左栏六槽。
51. Rig为右上4个独立1×2。
52. Pockets在Rig下方，Backpack在右栏下方。
53. Secure位于右下3×3。
54. 使用Godot原生Control drag/drop；实测原生Ammo拖放和Weapon移出/重新装备，交易成功后刷新视图。
55. R旋转拖动预览，落点验证通过才提交；装备槽中的物品不保存旋转状态，重新装备恢复未旋转。
56. Invalid Drop不删除源物品、不修改Runtime或旋转；关闭Tab还取消真正的Viewport原生拖动。
57. Ammo拖到Magazine调用装弹事务；MCP实测补3发：60→57，旧弹匣27→30。1×1弹药格数量单独一行，完整名称可查看tooltip/选中信息。
58. 保留WeaponRoot BoxMesh；Player身体挂纯视觉Rig/Backpack BoxMesh，装备状态同步可见性；Magazine/Ammo也有基础几何资源。
59. 装备外观无PhysicsBody、无导航阻挡；掉落物只保留未来交互查询Area。
60. 原1449项全部通过，0失败；旧测试只使用兼容夹具/等待新Single R确认窗口，伤势断言直接读取Runtime.reload_remaining，预期值不变。
61. 新增298项全部通过。
62. 总1747项全部通过，0失败。
63. 各新Suite见下表。
64. `scripts/`和`tests/`全部74个GDScript经--check-only通过；覆盖原44+脚本及新增实现/测试。
65. 最终Main无Parser/Runtime Error和GDScript Warning。修复新best未显式初始化警告，移除旧Firearm未使用的私有_reload_remaining代理；未添加warning ignore、未关闭warning。
66. MCP实际Main验证：29+1初始化、Rig2弹匣、Backpack60弹药；W/ADS/Jump/AUTO、Impact、Tab；原生Ammo装弹、R预览旋转Weapon→Backpack、NO ACTIVE WEAPON/隐藏枪、原Runtime重新装备；Single R Tactical和Double R一次世界掉落。
67. Phase9基线开始(04:32)后未发现新0xc0000005记录。Windows中03:50的c0000005记录早于本次基线。一次临时MCP inspector在UI未打开时索引空字典引起EVAL_RUNTIME_ERROR/debugger停顿，已纠正前置条件并重启Main；不属于生产脚本/native crash。
68. addons/godot_ai313文件SHA256逐项一致，0变化，0增删。
69. 当前限制：保留显式旧测试provider；运行时内部集合只支持经事务API修改。没有保存/死亡持久化、Loot、Pickup、负重惩罚；重量仅Debug显示，静态定义未指定重量时为0。没有新增Enemy/AI。
70. 已有原Item/Runtime引用、World位置记录、DroppedItem和交互Area可供下一阶段接入。正式Pickup实现前，WORLD→Inventory事务明确拒绝，防止留下第二个世界表现；没有实现任何拾取交互。

|新增Suite|通过assertions|失败|
|---|---:|---:|
|inventory_grid|41|0|
|inventory_transaction|13|0|
|container_inventory|27|0|
|secure_container|4|0|
|equipment_component|20|0|
|inventory_runtime_state|9|0|
|ammo_magazine_compatibility|17|0|
|rig_reload|45|0|
|reload_input_resolver|11|0|
|weapon_equipment|14|0|
|inventory_ui|21|0|
|dropped_magazine|11|0|
|inventory_edge_cases|41|0|
|inventory_gameplay|24|0|
|合计|298|0|

审查与裁决：执行计划要求的一次独立只读审查完成，2个Important问题均经复现失败→修复通过，并再次执行整套回归；没有遗留Minor。接管预装容器现在先验证全部内容/所有权，再原子登记，重复包装或重复占位不产生部分提交。

计划裁决完整记录：最新180节规格及明确实施顺序视为执行授权（若理解改变，成本为可逆的未提交修改）；使用当前Editor项目且不创建额外Checkout/commit/push/tag（以后Git整合由用户决定）；Rig外部2×2沿用此前草稿（若改尺寸，成本为一个定义及占格测试调整）；换弹锁定整个Inventory采用规格允许的简化策略（成本为换弹期间暂不能整理物品）；初始枪/备用弹匣保留旧Test Round，散装L2另建资源（成本为初始与后装弹药数值不同，保持既有伤害基线）。

对审查未作判断项的裁决：正式Pickup/Loot、持久化和容器套容器扩展按规格排除；World已有受理事务的所有权问题仍必须修复，现已拒绝World转移。任意直接写内部集合不属于支持入口，调用方必须使用Transaction，若未来绕过需补同样一致性验证。GUI/Editor warning验收由主执行者实际MCP验证；旧截图不代表最终UI，最终窗口使用修正后的不透明背景和数量行。

证据：实施计划`docs/superpowers/plans/2026-10-05-phase9-inventory.md`；完整测试/RED→GREEN/哈希与MCP诊断在`%TEMP%/codex-fps-phase9-audit/`。未创建任何commit/push/tag。
