# B1 portable subtree design

用户完整B1附件和最新F自动旋转补充为实施授权；采用最小原事务扩展，不重复B0系统，不提交Git。

- Item提供 `get_owned_child_edges(context)`，边字典包含parent_item/child_item/edge_role/grid/placement。Container adapter读真实grids，WeaponRuntime adapter读实际loaded实例和稳定wrapper；Factory/Item构造只创建一次初始wrapper，遍历不创建Item。未来runtime可追加attachment边，不改DFS。
- Grid弱引用owner_item，直接父由真实placement/edge推导。capability portable在backpack/external允许，在rig/pocket/secure拒绝。cycle基于实例和runtime，MAX_TRAVERSAL_DEPTH32保护坏数据。
- InventoryOwnershipGraph返回valid/reason/items/runtimes/edges/grids。只读DFS检查重复Item/Runtime/Grid、depth、placements/overlap/policy、wrapper/interface、registry/parent一致。register_complete_subtree先完整验证、prepare，后同步commit全部成员及grids。simple place拒绝未注册populated container，返回false与明确last_failure_reason，0mutation；高层complete placement、equip/drop/pickup使用显式complete路径。
- 跨Registry transfer复用graph，双锁commit全部实际成员及grids；同registry只变root location；WORLD只有rootvisual，内部仍同registry，拾取/drop保持所有identity。
- InventoryWeightCalculator复用同graph，唯一重量来源并真实遍历mixed rounds，返回明确valid/weight/reason。Player/Crate/WORLD各从实际roots开始，不sum所有registry成员，不缓存，不读Health/PlayerController，不影响Gameplay数值。
- Backpack1外4×5/旋转5×4、内5×5。F先空装备槽，再RootBackpack；Backpack套入先当前rotation后另一orientation。Preview/commit同plan，不改existing items。其他候选规则、Secure排除、HoldF不变。
- Weight UI最小更新两位小数；Container模式显示Player/Contents。射击和Reload通过既有signals刷新，不改操作时序和伤势。

成功：原3080回归（仅显式尺寸旧期望可改）、新增nested/policy/graph/registration/transfer/weight/F测试通过；逐脚本check-only、Main真实F+transfer+drop+weight+shoot/R+nativeNoop；addon313不变；Main恢复初始，报告102项后停B1。
