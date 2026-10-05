# Phase 10 — World Loot & Pickup 验收报告

最终结果：**2168 assertions passed，0 failed**（原1892 + 新增276）。Godot 4.7.2，94个项目及测试脚本解析通过。完整测试及最终 Main 运行：0 Parser Error、0 Runtime Error、0 Warning。以下按需求的58项记录；不创建提交、推送或标签。

1. **新增文件**：7个生产脚本：
   - `res://scripts/inventory/inventory_item_factory.gd`
   - `res://scripts/inventory/pickup_placement_policy.gd`
   - `res://scripts/items/world_item_factory.gd`
   - `res://scripts/items/world_loot_spawn_point.gd`
   - `res://scripts/items/world_loot_test_area.gd`
   - `res://scripts/player/player_interactor.gd`
   - `res://scripts/ui/interaction_prompt.gd`
   
   2个场景：`res://scenes/items/weapon_1_visual.tscn`、`res://scenes/levels/world_loot_test_area.tscn`。7个测试文件见第52项；14个脚本UID由Godot生成。文档为本报告和实施记录 `docs/superpowers/plans/2026-10-05-phase10-world-loot.md`。

2. **修改文件**：`project.godot`；`data/items/primary_weapon_1_item.tres`；`scenes/items/dropped_item.tscn`、`scenes/player/player.tscn`、`scenes/levels/test_level.tscn`；`scripts/inventory/`中的 `dropped_item.gd`、`inventory_item_instance.gd`、`inventory_transaction_service.gd`、`item_definition.gd`、`player_inventory_component.gd`。共10个原文件。所有既有测试、玩家控制、Firearm、WeaponRuntime、MagazineInstance、伤害、护甲、伤势、声音和拖拽UI脚本未修改。

3. **DroppedItem泛化**：保留原类名、`.item`和Area3D路径，扩展为通用世界表现。支持Ammo、Magazine、Weapon、Rig、Backpack和普通物品；它不创建Runtime、不维护第二套数量。

4. **结构**：DroppedItem(Node3D) → VisualRoot(Node3D)、Area3D → CollisionShape3D，以及可选DebugLabel3D。使用Definition提供的基础几何场景；无视觉资源时使用简单BoxMesh。交互BoxShape依据视觉尺寸适度放大。

5. **实例关系**：WorldItem引用原InventoryItemInstance；其runtime_state仍是原MagazineInstance、WeaponRuntime或ContainerRuntime。拾取/丢弃搬移同一实例，不复制状态。

6. **WORLD所有权**：事务服务的world_items记录Item→世界节点，get_location仍是位置查询入口。重复WORLD表现、跨注册表重复原Item、跨注册表用不同包装共享同一Runtime都会被拒绝。Item与Runtime所有者索引使用弱引用，避免持有已失效注册表。

7. **WorldItemFactory**：统一生成世界表现和WORLD登记；检查库存锁、源位置、重复世界节点、原实例注册。另提供已有Drop Reload预留WORLD的物化入口，以及前方落点的地面射线定位。

8. **InventoryItemFactory**：仅负责关卡初始化创建真实Item/Runtime；Ammo定义与数量、弹匣初始弹量、武器真实Chamber/Loaded Magazine、Rig/Backpack独立运行时均在此初始化。WorldItem不负责重建它们。

9. **PlayerInteractor**：独立节点负责摄像机中心射线、目标筛选、提示及请求分发；调用通用can_interact/get_interaction_prompt/interact接口。拾取算法、放置决策和库存UI不在Interactor内。

10. **F输入**：新增Input Map `interact = F`。按键请求在物理帧处理；不直接在输入回调修改物品所有权。

11. **距离**：默认2.5m。中心射线限制2.5m，并检查摄像机至目标交互位置的距离，边界包含2.5m；扩大Area不会扩展拾取距离。

12. **墙体遮挡**：使用最近命中射线；墙、地面和普通Target物理体优先阻挡后方Loot。不存在穿墙寻找下一个可交互节点的循环。

13. **层/Mask**：Loot沿用Interaction第5层（bit16），Area mask0；玩家交互射线mask25（World1、TargetBody8、Interaction16），collide_with_areas=true，排除Player RID。Loot不加入World/Hurtbox/TargetBody碰撞层。

14. **Prompt UI**：独立CanvasLayer/Label位于准星下方，通过prompt_changed接收文本；鼠标过滤为IGNORE。目标离开、删除或库存打开时清空隐藏，不截获库存拖拽。

15. **Ammo提示**：读Item.stack_count，例如Weapon 1 L2 Ammo x60；部分拾取后即时变为x50。

16. **Magazine提示**：读MagazineInstance真实弹量及其Definition容量，例如17 / 30，不以ItemDefinition猜测当前弹量。

17. **Weapon提示**：读WeaponRuntime，显示CH 1 / MAG 17。它不会从WeaponData重置枪内状态。

18. **WORLD→Inventory事务**：验证锁、WORLD归属和目标合法性，计算只读合并/放置计划，验证注册后再提交。全部拾取成功立即关闭Area layer并queue_free；部分拾取保留节点；失败不移除WORLD来源。结果含success、accepted_count、remaining_count。

19. **Placement Policy**：独立静态策略，使用现有网格first-free及装备兼容检查；策略仅返回计划，不搬移物品，不依赖库存UI。

20. **Weapon优先级**：兼容空装备槽→Backpack；装备已占用不替换已有枪。已有Active Weapon保持绑定；没有Active且成功进入武器槽时启用该枪。

21. **Magazine优先级**：已装备Rig→Backpack。进入Backpack仍遵守原Rig-only Reload规则，未偷偷增加换弹来源。

22. **Ammo优先级**：先按Backpack→Pockets→Rig合并兼容Ammo；剩余量按同顺序找空位。

23. **Generic优先级**：Backpack→Pockets→Rig，不使用武器专用装备槽。

24. **Rig拾取**：仅进入兼容空Rig装备槽；占用时拒绝，不替换、不自动存入另一个容器。

25. **Backpack拾取**：仅进入空Backpack装备槽；保留原容器和内部物品，拒绝自动套包。

26. **Secure排除**：自动拾取候选不含Secure，显式拾取目标也拒绝Secure。玩家此前的手动Secure操作仍保持原规则；不能因为普通容器满了而自动使用Secure。

27. **Ammo Auto Merge**：只合并同Ammo类别与item_id，限制目标max_stack。计划先算可接收量，成功后扣除原世界源。完全合并的源从注册表移除并立即退役视觉。

28. **Partial Stack**：实际Main夹具中，库存已有50发、仅能再接收10发、世界60发；F后库存60、世界50，总110不变，源Item和节点不变。提示更新x50。

29. **No Space**：没有合并容量且无合法空位时accepted_count=0；世界节点、弹量、Runtime和提示保留。之后再按F也不会丢物品。

30. **F Spam**：完整成功先取消交互Layer并改变所有权，再等待queue_free；重复请求无法再次取得WORLD资格。部分成功后按最新真实数量及剩余容量重新计算，数量守恒。

31. **Magazine identity**：17发世界弹匣拾取、Drop Reload后拾回、再次装枪，Item与MagazineInstance都保持相同引用和Instance ID。

32. **Mixed Ammo**：混装A/B/A/C拾取和再换弹时，所有AmmoData引用及顺序保持，不统一改成默认弹药。

33. **WeaponRuntime identity**：世界枪的独立Runtime与当前装备枪不同；拾取保留原Runtime。跨注册表共享Runtime包装及多个枪共享同一Loaded Magazine均被事务校验拒绝。

34. **Chamber**：测试世界枪CH1；拾取仍CH1。没有通过重新initialize或chamber来改变已有枪内弹药。

35. **Loaded Magazine**：测试世界枪MAG17；注册真实Loaded Magazine物品包装供后续Reload使用。已有包装只允许transit或已属于同一把枪，不能挪用WORLD、Grid或另一把枪的弹匣。

36. **FireMode**：测试枪AUTO，拾取保持selected_fire_mode。SEMI/AUTO原有回归通过。

37. **Container contents**：Rig/Backpack内部原网格、物品包装、弹匣弹量、Runtime引用及布局保持；注册内容时先验证整组，失败不部分收编。测试包含已有内容的容器拾取和从Rig再次换弹。

38. **Drop Reload拾回**：Main通过真实双R产生17发旧弹匣，在玩家前方约0.8m稳定放置；摄像机瞄向它并真实F拾回，原Runtime及弹序不变。

39. **再次Reload**：Main实测移除其他备用弹匣作为夹具，发射一发后真实单R换入拾回的17发弹匣；结果为同一Loaded Magazine、MAG17/CH1，原弹序保持。未修改选择/换弹规则。

40. **Player阻挡**：Loot仅为Area3D、mask0，Player mask不含16；实际CharacterBody move_and_slide穿过世界弹匣的测试通过。

41. **Projectile阻挡**：Hitscan及Projectile的原射线mask均不含16；在真实Loot节点上验证忽略Area。Main真实Projectile击中Floor、生成原HitMarker，未被掉落弹匣阻挡。

42. **Navigation阻挡**：Loot没有PhysicsBody3D或NavigationObstacle3D，不纳入导航障碍；未增加Navigation/AI系统。场景中的遮挡墙是普通World几何，正常阻挡世界射线和玩家。

43. **Occlusion测试**：新场景墙后mag17不可见且F无效；绕至无墙一侧可取得。新墙已缩至1.2m宽，避免占用原弹道靶的射击线路；旧弹道168项回归恢复通过。

44. **边界**：自动测试与Main MCP实测均为2.49m允许、2.5m允许、2.51m拒绝。Main以摄像机实际global forward布置临时边界夹具，避免鼠标视角造成方向误差。

45. **Inventory Open**：Main真实Tab打开库存后提示隐藏、F不拾取；关闭后恢复。原拖拽候选70项、原生拖拽UX75项全部通过。

46. **Reload Lock**：Main真实R进入换弹时，库存锁为true，F不改变世界物品；换弹完成后锁解除。没有通过绕过锁进行普通世界拾取。

47. **测试区**：test_level新增WorldLootTestArea实例：Ammo60、Magazine30、Magazine17、Weapon CH1/MAG17/AUTO、Backpack、Rig，以及标签和墙。原默认装备、Target_01/02/03和DamageableTarget保留。普通主场景自动初始化；独立自定义SceneTree测试显式调用spawn_loot，避免改变原测试夹具。

48. **Main MCP验证**：实际连接Godot4.7.2编辑器并运行Main；F ammo60、mag17及Weapon、墙体阻挡、2.49/2.5/2.51、Tab、R锁、满库存部分合并/无空间/F重复、双R17发掉落→F回收→再次R换入均通过。边界、满库存及指定弹量由MCP布置运行时夹具；输入使用真实F/Tab/R事件。最终重启正常主场景，清除夹具变化。

49. **原1892**：1449旧战斗/移动/声音/Runtime + Phase9库存298 + 拖拽候选70 + 拖拽UX75 =1892，全部通过；旧测试内容和预期未修改。

50. **新增Assertions**：276，其中包含最后审阅发现的运行时重复所有权和弹匣重复归属测试，以及完整Ammo合并源退役、移除玩家脚本的兼容测试。

51. **总数**：1892+276 = **2168通过，0失败**。

52. **新测试Suite**：

| 测试文件（res://tests/） | Assertions | Failures |
| --- | ---: | ---: |
| world_item_test.gd | 44 | 0 |
| world_ownership_test.gd | 34 | 0 |
| player_interaction_test.gd | 17 | 0 |
| world_pickup_test.gd | 49 | 0 |
| pickup_placement_policy_test.gd | 20 | 0 |
| world_runtime_persistence_test.gd | 69 | 0 |
| world_loot_gameplay_test.gd | 43 | 0 |
| 合计 | 276 | 0 |

53. **Parser**：94个项目/测试GDScript通过--check-only；最终事务文件在审阅修复后再次检查通过，无warning ignore或关闭警告。

54. **Runtime/Warnings**：最终全套测试输出与新Main运行均无Parser/Runtime/Warning。开发过程中发现并修复了测试脚本接口/缩进错误、新墙干扰旧射线、无玩家脚本的Actor兼容问题，以及两处所有权漏洞；RED日志保留，未隐藏问题。

55. **Addon保护**：addons/godot_ai/文件数313，**313/313 SHA256不变**。额外66个既有Gameplay/UI/测试脚本保护哈希全部不变。

56. **Gameplay规则**：没有修改移动、ADS、伤势倍率、声音、RPM、Fire Cycle、Ammo Damage、护甲、伤害区、健康/Death/Reset、Projectile、单/双R选择与时长、Rig-only reload、兼容策略或拖拽规则。新增的是WORLD表现、交互、拾取事务与测试地图。

57. **技术边界**：当前WORLD注册表属于单玩家库存上下文；未实现共享世界/多人所有权、存档、随机Loot、容器嵌套、动态物理或Inventory Drop UI。自动拾取沿用当前rotation与first-free，不尝试自动旋转；地面Drop使用稳定朝向和固定小高度。本阶段不新增这些扩展。

58. **Phase11准备**：通用Item/Runtime身份、WORLD生命周期、显式事务、独立placement policy及通用Interact接口已可供Loot Container复用。Phase11仍需要新增容器所有权与转移事务、容器打开交互和相关测试；本阶段没有提前实现Loot Container。

实施取舍及代价（实施记录中的全部Rulings）：

- 保留DroppedItem旧名称/API，避免平行世界物品体系；代价是通用类沿用历史名字。
- WORLD仅走显式pickup事务，普通move/equip继续拒绝；未来调用者必须使用正确入口。
- 按摄像机至交互位置检查2.5m，保持边界；地面物品距离包含垂直差。
- 保留当前rotation及原first-free，不自动旋转；可能需要手动腾出对应朝向的空间。
- 沿用单玩家注册表，使用弱引用保护原Item及跨注册表Runtime唯一性；多人共享WORLD另阶段设计。
- Weapon ItemDefinition明确引用Loaded Magazine定义；新武器定义若带初始弹匣需提供该引用。
- Debug测试区仅正常SceneTree自动初始化，自定义测试树显式调用；自定义应用SceneTree使用该测试区时也需显式初始化。

一次独立最终审阅：0 Critical、2 Important、0 Minor；两个Important均已用失败测试复现并修复，完整回归再次通过。没有延期或未解决审阅事项。未修改addons，未新增第三方资源/插件，未创建Enemy AI、存档、Loot Container或额外Gameplay系统。

