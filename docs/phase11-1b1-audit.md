# Phase 11.1B-1 pre-implementation audit

2026-10-07。开始时工作树干净，HEAD e9b6999；Godot AI MCP 确认 Test_1 / 4.7.2 stable，Main 已停止。基线61次运行已确认3080/3080。addon开始快照313文件，临时证据 `%TEMP%/codex-fps-phase11-1b1-audit`。

现状：Item 保存弱 owner registry；location由实际grids/placements、equipment、loaded magazine、world_items推导。Registry owner不是直接父级。Grid只知道transactions，没有所属Item。Rig/Bag layout已数据化，UI遍历实际grids。Factory生成Runtime，Weapon loaded wrapper目前由注册遍历临时创建，这是B1必须修正的身份缺口。

`_registration_group()` 按Weapon/Rig/Bag递归，缺visited/depth；register_item提交成员但未原子采用内部grids，Player `_on_inventory_changed()` 事后register_grid，是populated容器第二技术债。ExternalInventoryTransfer已同步preflight+双锁commit，但依赖上述group。不能推翻事务：接入只读通用graph和完整登记，保留commit/changed/Rig reload/no-op路径。

Grid当前同时禁止Rig/Backpack嵌套、Pocket未显式拒绝小portable、Secure按几何；改为portable capability+storage kind政策，并由Grid parent identity进行cycle检查。现Backpack外3×4、内5×5；按本次明确设计外改4×5。

Pickup已有root-only候选（RootBag、Pockets、RootRig），没有递归查询；当前已装备Rig/Bag后直接失败。B1允许只套入RootBag。用户最新修改覆盖附件B1-35/B1-67及对应测试：仅Backpack自动套包允许当前方向优先、失败后尝试另一方向；不旋转已有Item，不整理，不进入nested bag。其他物品保留既有rotation规则。

重量当前flat：ItemDefinition.weight×count，Player直接sum registry成员。现5个可拾取ItemDefinition与Weapon/Mag/Ammo重量皆默认0；新计算按专门类型唯一Source，ItemDefinition.weight只用于portable/generic。用户值Weapon3.5、Mag0.15、L2 round0.012、Rig1、Bag1.5；初始mag实际test_round同样明确配置0.012以维持4.01示例，不改伤害。其他Ammo为可测试数据，明确配置同默认质量0.012，未添加平衡机制。

原场景、Health/Injury、Firearm射击、WeaponRuntime state、ReloadCoordinator/TimingProvider、Acoustic保持。B2窗口/Context、B3逐发装退、B4显式换弹、Attachment Gameplay、负重效果禁止。
