class_name FrameworkFeatureCatalog
extends RefCounted

## comedot 框架功能清单。
##
## 数据来源：`Components/`、`AutoLoad/`、`Resources/`、`Scenes/`、`Scripts/`、`Templates/`、`UI/`、`addons/` 的真实文件。
## 组件条目与磁盘文件双向对照见 [method verifyCoverage]，框架新增组件时会报「未录条目」。


#region 构建

static var _cache: Array[FrameworkFeature]


## 返回全部功能条目（首次调用时构建并缓存）。
static func getFeatures() -> Array[FrameworkFeature]:
	if _cache.is_empty():
		_cache = _build()
	return _cache


## 返回按出现顺序排列的类别名。
static func getCategories() -> PackedStringArray:
	var categories: PackedStringArray = PackedStringArray()
	for feature in getFeatures():
		if not categories.has(feature.category):
			categories.append(feature.category)
	return categories


static func _build() -> Array[FrameworkFeature]:
	var features: Array[FrameworkFeature] = []

	# ---- AI ----
	features.append(FrameworkFeature.new("TimerAgentComponentBase", "AI", "定时驱动的简单 AI 代理基类（实验）", "res://Components/AI/TimerAgentComponentBase.gd"))

	# ---- 战斗 ----
	features.append(FrameworkFeature.new("BulletModifierComponent", "战斗", "修改 GunComponent 发射出的弹体（伤害/附加特效）", "res://Components/Combat/BulletModifierComponent.gd"))
	features.append(FrameworkFeature.new("BulletlessGunComponent", "战斗", "冷却式武器，直接在目标点造成伤害（无弹道）", "res://Components/Combat/BulletlessGunComponent.gd"))
	features.append(FrameworkFeature.new("DamageComponent", "战斗", "Area2D 命中框，对受击框造成伤害，支持阵营过滤与命中率", "res://Components/Combat/DamageComponent.gd", "res://Tests/Combat/CombatTest.tscn"))
	features.append(FrameworkFeature.new("DamageOverTimeComponent", "战斗", "定时持续伤害，无需持续接触（中毒/燃烧）", "res://Components/Combat/DamageOverTimeComponent.gd"))
	features.append(FrameworkFeature.new("DamageRayComponent", "战斗", "用 RayCast2D 只命中每帧第一个接触目标", "res://Components/Combat/DamageRayComponent.gd"))
	features.append(FrameworkFeature.new("DamageReceivingComponent", "战斗", "Area2D 受击框，把伤害转给生命值，支持阵营过滤", "res://Components/Combat/DamageReceivingComponent.gd"))
	features.append(FrameworkFeature.new("DamageRepeatingComponent", "战斗", "定时对仍接触中的敌对目标重复伤害（陷阱/炮塔）", "res://Components/Combat/DamageRepeatingComponent.gd"))
	features.append(FrameworkFeature.new("FactionComponent", "战斗", "给实体挂一个或多个阵营，用于伤害与关系过滤", "res://Components/Combat/FactionComponent.gd"))
	features.append(FrameworkFeature.new("GunComponent", "战斗", "冷却式弹道武器，枪身/支点/枪口可编辑，UI 可拦截开火", "res://Components/Combat/GunComponent.gd"))
	features.append(FrameworkFeature.new("HealthComponent", "战斗", "生命值容器，处理伤害、死亡与销毁", "res://Components/Combat/HealthComponent.gd"))
	features.append(FrameworkFeature.new("InvulnerabilityOnHitComponent", "战斗", "受击后短暂无敌（命数制/受击硬直）", "res://Components/Combat/InvulnerabilityOnHitComponent.gd"))
	features.append(FrameworkFeature.new("KnockbackOnHitComponent", "战斗", "受击时击退 CharacterBody2D", "res://Components/Combat/KnockbackOnHitComponent.gd"))
	features.append(FrameworkFeature.new("ShieldedHealthComponent", "战斗", "护盾/护甲属性先吸收伤害，再扣生命", "res://Components/Combat/ShieldedHealthComponent.gd"))
	features.append(FrameworkFeature.new("TileDamageComponent", "战斗", "按 TileSet 自定义数据破坏瓦片（实验）", "res://Components/Combat/TileDamageComponent.gd", "res://Tests/Combat/DestructibleTilesTest.tscn"))

	# ---- 核心 ----
	features.append(FrameworkFeature.new("Component", "核心", "一切组件与实体的抽象基类", "res://Components/Component.gd"))
	features.append(FrameworkFeature.new("DebugComponent", "核心", "实体调试数值/标签/图表显示", "res://Components/DebugComponent.gd"))
	features.append(FrameworkFeature.new("NodeModifierComponentBase", "核心", "增删组件、删节点、销毁实体的基类", "res://Components/NodeModifierComponentBase.gd"))

	# ---- 控制 ----
	features.append(FrameworkFeature.new("AbilityControlComponent", "控制", "把输入转成技能释放，并按需创建目标选择组件", "res://Components/Control/AbilityControlComponent.gd"))
	features.append(FrameworkFeature.new("AbilityTargetingComponentBase", "控制", "技能目标选择组件基类", "res://Components/Control/AbilityTargetingComponentBase.gd"))
	features.append(FrameworkFeature.new("AbilityTargetingCursorComponentBase", "控制", "带光标/准星的目标选择基类", "res://Components/Control/AbilityTargetingCursorComponentBase.gd"))
	features.append(FrameworkFeature.new("AbilityTargetingMouseComponent", "控制", "鼠标选择世界位置或可被技能选中的实体", "res://Components/Control/AbilityTargetingMouseComponent.gd"))
	features.append(FrameworkFeature.new("AbilityTargetingPositionComponent", "控制", "摇杆/位置式目标选择（手柄友好）", "res://Components/Control/AbilityTargetingPositionComponent.gd"))
	features.append(FrameworkFeature.new("AimingCursorComponent", "控制", "瞄准准星：移动+朝向+拴系+静止隐藏的组合", "res://Components/Control/AimingCursorComponent.gd"))
	features.append(FrameworkFeature.new("AsteroidsControlComponent", "控制", "小行星/坦克式转向+推进+刹车（一站式）", "res://Components/Control/AsteroidsControlComponent.gd"))
	features.append(FrameworkFeature.new("BasicOverheadControlComponent", "控制", "俯视直接位移，不走 CharacterBody2D 物理", "res://Components/Control/BasicOverheadControlComponent.gd"))
	features.append(FrameworkFeature.new("ClimbComponent", "控制", "平台游戏攀爬：梯子/绳索/崖壁，含抓取与跳离", "res://Components/Control/ClimbComponent.gd", "res://Tests/ClimbTest.tscn"))
	features.append(FrameworkFeature.new("ClimbTileMapComponent", "控制", "瓦片地图梯子攀爬（实验）", "res://Components/Control/ClimbTileMapComponent.gd"))
	features.append(FrameworkFeature.new("InputComponent", "控制", "共享输入状态，玩家/AI/演示都可写入", "res://Components/Control/InputComponent.gd"))
	features.append(FrameworkFeature.new("JumpComponent", "控制", "跳跃输入与垂直速度", "res://Components/Control/JumpComponent.gd"))
	features.append(FrameworkFeature.new("MouseRotationComponent", "控制", "让节点朝向鼠标旋转", "res://Components/Control/MouseRotationComponent.gd"))
	features.append(FrameworkFeature.new("MouseTrackingComponent", "控制", "移动到鼠标位置（瞬时或渐进）", "res://Components/Control/MouseTrackingComponent.gd"))
	features.append(FrameworkFeature.new("MovementFacingComponent", "控制", "按输入移动方向旋转节点", "res://Components/Control/MovementFacingComponent.gd"))
	features.append(FrameworkFeature.new("PositionControlComponent", "控制", "无物理的直接定位（光标/相机）", "res://Components/Control/PositionControlComponent.gd"))
	features.append(FrameworkFeature.new("RandomInputComponent", "控制", "定时生成随机输入（NPC 游荡/演示模式）", "res://Components/Control/RandomInputComponent.gd"))
	features.append(FrameworkFeature.new("ScrollerControlComponent", "控制", "横版卷轴：恒定推进并保底 X/Y 速度", "res://Components/Control/ScrollerControlComponent.gd"))
	features.append(FrameworkFeature.new("ThrustControlComponent", "控制", "前后推进与刹车", "res://Components/Control/ThrustControlComponent.gd"))
	features.append(FrameworkFeature.new("TileBasedAsteroidsControlComponent", "控制", "网格版小行星控制（转向+前后移动）", "res://Components/Control/TileBasedAsteroidsControlComponent.gd"))
	features.append(FrameworkFeature.new("TileBasedControlComponent", "控制", "把输入转成网格格子移动", "res://Components/Control/TileBasedControlComponent.gd"))
	features.append(FrameworkFeature.new("TileBasedControlComponentBase", "控制", "网格控制组件基类（步进延迟/等到位）", "res://Components/Control/TileBasedControlComponentBase.gd"))
	features.append(FrameworkFeature.new("TileBasedMouseControlComponent", "控制", "网格坐标吸附到鼠标指针", "res://Components/Control/TileBasedMouseControlComponent.gd"))
	features.append(FrameworkFeature.new("TurningControlComponent", "控制", "左右输入转向（枪/车体）", "res://Components/Control/TurningControlComponent.gd"))

	# ---- 数据 ----
	features.append(FrameworkFeature.new("StatModifierComponent", "数据", "定时修改属性（回复/中毒/耗蓝）", "res://Components/Data/StatModifierComponent.gd"))
	features.append(FrameworkFeature.new("StatsComponent", "数据", "属性资源容器，按名与 UID 索引", "res://Components/Data/StatsComponent.gd"))

	# ---- 玩法 ----
	features.append(FrameworkFeature.new("AbilityComponent", "玩法", "存储实体的技能/法术/指令", "res://Components/Gameplay/AbilityComponent.gd", "res://Tests/Abilities/AbilityTest.tscn"))
	features.append(FrameworkFeature.new("AbilityReactionComponent", "玩法", "被选为技能目标后执行的反应（激活/对话/开关）", "res://Components/Gameplay/AbilityReactionComponent.gd"))
	features.append(FrameworkFeature.new("AbilityTargetableComponent", "玩法", "标记实体可被技能选中", "res://Components/Gameplay/AbilityTargetableComponent.gd"))
	features.append(FrameworkFeature.new("ComponentSwapperComponent", "玩法", "运行时按组件集增删组件（实验）", "res://Components/Gameplay/ComponentSwapperComponent.gd"))
	features.append(FrameworkFeature.new("InjectorComponent", "玩法", "碰撞时把自己的子节点注入对方实体（上 Buff）", "res://Components/Gameplay/InjectorComponent.gd"))
	features.append(FrameworkFeature.new("InventoryComponent", "玩法", "存储实体拥有的物品", "res://Components/Gameplay/InventoryComponent.gd", "res://Tests/Inventory/InventoryTest.tscn"))
	features.append(FrameworkFeature.new("LevelUpComponent", "玩法", "经验类属性满值时弹升级 UI", "res://Components/Gameplay/LevelUpComponent.gd"))
	features.append(FrameworkFeature.new("ModifyOnTimerComponent", "玩法", "定时增删组件/节点或销毁实体", "res://Components/Gameplay/ModifyOnTimerComponent.gd"))
	features.append(FrameworkFeature.new("StatModifierOnDeathComponent", "玩法", "死亡时改属性（得分/经验/命数）", "res://Components/Gameplay/StatModifierOnDeathComponent.gd"))
	features.append(FrameworkFeature.new("TimerComponentBase", "玩法", "依赖 Timer 的组件基类", "res://Components/Gameplay/TimerComponentBase.gd"))
	features.append(FrameworkFeature.new("UpgradesComponent", "玩法", "记录已拥有的升级", "res://Components/Gameplay/UpgradesComponent.gd", "res://Tests/Upgrades/UpgradeTest.tscn"))

	# ---- 交互 ----
	features.append(FrameworkFeature.new("InteractionComponent", "交互", "可交互目标（由交互控制器触发）", "res://Components/Interaction/InteractionComponent.gd", "res://Tests/InteractionTest.tscn"))
	features.append(FrameworkFeature.new("InteractionControlComponent", "交互", "玩家交互控制器，触发范围内目标（节点须为 Area2D）", "res://Components/Interaction/InteractionControlComponent.gd"))
	features.append(FrameworkFeature.new("InteractionMouseControlComponent", "交互", "触发鼠标悬停下的特定交互", "res://Components/Interaction/InteractionMouseControlComponent.gd"))
	features.append(FrameworkFeature.new("InteractionWithCooldownComponent", "交互", "带冷却的交互目标", "res://Components/Interaction/InteractionWithCooldownComponent.gd"))
	features.append(FrameworkFeature.new("InteractionWithCostComponent", "交互", "带属性花费的交互（配合 StatsVisualComponent）", "res://Components/Interaction/InteractionWithCostComponent.gd"))
	features.append(FrameworkFeature.new("MineableComponent", "交互", "可采集：消耗型属性限制重复采集（采矿/伐木）", "res://Components/Interaction/MineableComponent.gd"))
	features.append(FrameworkFeature.new("ModalInteractionComponent", "交互", "弹出模态 UI 并暂停实体", "res://Components/Interaction/ModalInteractionComponent.gd", "res://Tests/ModalUITest.tscn"))
	features.append(FrameworkFeature.new("PortalInteractionComponent", "交互", "门/传送点，支持钥匙等载荷需求", "res://Components/Interaction/PortalInteractionComponent.gd"))
	features.append(FrameworkFeature.new("TextInteractionComponent", "交互", "循环文本交互（告示牌/对话，实验）", "res://Components/Interaction/TextInteractionComponent.gd"))

	# ---- 移动 ----
	features.append(FrameworkFeature.new("AttachmentComponent", "移动", "逐帧把目标节点摆到本组件位置", "res://Components/Movement/AttachmentComponent.gd"))
	features.append(FrameworkFeature.new("ChaseComponent", "移动", "通过写输入方向朝目标移动", "res://Components/Movement/ChaseComponent.gd"))
	features.append(FrameworkFeature.new("IndependentPathFollowComponent", "移动", "沿 Path2D 移动且各自独立进度", "res://Components/Movement/IndependentPathFollowComponent.gd"))
	features.append(FrameworkFeature.new("LinearMotionComponent", "移动", "直线运动，高性能弹体首选", "res://Components/Movement/LinearMotionComponent.gd"))
	features.append(FrameworkFeature.new("NavigationComponent", "移动", "NavigationAgent2D 寻路避障", "res://Components/Movement/NavigationComponent.gd", "res://Tests/PathfindingTest.tscn"))
	features.append(FrameworkFeature.new("PathFollowComponent", "移动", "用 PathFollow2D 沿路径推进", "res://Components/Movement/PathFollowComponent.gd"))
	features.append(FrameworkFeature.new("PlatformerPatrolComponent", "移动", "平台敌人左右巡逻（需角落探测）", "res://Components/Movement/PlatformerPatrolComponent.gd"))
	features.append(FrameworkFeature.new("PositionClampComponent", "移动", "每帧把位置限制在范围内", "res://Components/Movement/PositionClampComponent.gd"))
	features.append(FrameworkFeature.new("RandomMovementComponent", "移动", "直接随机移动（原型够用）", "res://Components/Movement/RandomMovementComponent.gd"))
	features.append(FrameworkFeature.new("RelativePathMovementComponent", "移动", "按相对位移序列定时移动", "res://Components/Movement/RelativePathMovementComponent.gd"))
	features.append(FrameworkFeature.new("RideableComponent", "移动", "可被骑乘（RemoteTransform2D 偏移）", "res://Components/Movement/RideableComponent.gd"))
	features.append(FrameworkFeature.new("SpinComponent", "移动", "每物理帧旋转", "res://Components/Movement/SpinComponent.gd"))
	features.append(FrameworkFeature.new("TetherComponent", "移动", "拴系：限制在目标最大半径内", "res://Components/Movement/TetherComponent.gd"))
	features.append(FrameworkFeature.new("TileBasedLinearMotionComponent", "移动", "网格八方向直线移动", "res://Components/Movement/TileBasedLinearMotionComponent.gd"))
	features.append(FrameworkFeature.new("TileBasedPositionComponent", "移动", "网格坐标映射：边界/占位/碰撞/跨格移动", "res://Components/Movement/TileBasedPositionComponent.gd"))
	features.append(FrameworkFeature.new("TileBasedRandomMovementComponent", "移动", "网格随机步进，可重掷被挡的移动", "res://Components/Movement/TileBasedRandomMovementComponent.gd"))
	features.append(FrameworkFeature.new("WaveMotionComponent", "移动", "正弦/余弦波浪运动（轴向或圆周）", "res://Components/Movement/WaveMotionComponent.gd", "res://Tests/WaveMovementTest.tscn"))

	# ---- 物品 ----
	features.append(FrameworkFeature.new("CollectibleComponent", "物品", "可拾取物基类，载荷驱动拾取行为", "res://Components/Objects/CollectibleComponent.gd"))
	features.append(FrameworkFeature.new("CollectibleInventoryComponent", "物品", "拾取后加入背包", "res://Components/Objects/CollectibleInventoryComponent.gd"))
	features.append(FrameworkFeature.new("CollectibleStatComponent", "物品", "拾取后增减属性", "res://Components/Objects/CollectibleStatComponent.gd"))
	features.append(FrameworkFeature.new("CollectorComponent", "物品", "检测可拾取物并执行其载荷", "res://Components/Objects/CollectorComponent.gd"))
	features.append(FrameworkFeature.new("DropOnDeathComponent", "物品", "死亡时按权重掉落场景", "res://Components/Objects/DropOnDeathComponent.gd"))

	# ---- 物理 ----
	features.append(FrameworkFeature.new("AreaCollisionComponent", "物理", "Area2D 碰撞信号（不留常驻接触列表）", "res://Components/Physics/AreaCollisionComponent.gd"))
	features.append(FrameworkFeature.new("AreaComponentBase", "物理", "依赖 Area2D 的组件基类", "res://Components/Physics/AreaComponentBase.gd"))
	features.append(FrameworkFeature.new("AreaContactComponent", "物理", "追踪当前接触中的对象列表", "res://Components/Physics/AreaContactComponent.gd", "res://Tests/AreaTest.tscn"))
	features.append(FrameworkFeature.new("CharacterBodyComponent", "物理", "统一每帧只调一次 move_and_slide", "res://Components/Physics/CharacterBodyComponent.gd"))
	features.append(FrameworkFeature.new("CharacterBodyDependentComponentBase", "物理", "依赖移动流程前后执行的组件基类", "res://Components/Physics/CharacterBodyDependentComponentBase.gd"))
	features.append(FrameworkFeature.new("CornerCollisionComponent", "物理", "四角探测地面/墙/顶（需 Sprite2D）", "res://Components/Physics/CornerCollisionComponent.gd"))
	features.append(FrameworkFeature.new("GravityComponent", "物理", "独立重力（勿与平台物理同用）", "res://Components/Physics/GravityComponent.gd"))
	features.append(FrameworkFeature.new("GunRecoilComponent", "物理", "开火后坐力反推 CharacterBody2D", "res://Components/Physics/GunRecoilComponent.gd"))
	features.append(FrameworkFeature.new("ModifyOnCollisionComponent", "物理", "碰撞满足条件时增删组件或销毁（弹体命中）", "res://Components/Physics/ModifyOnCollisionComponent.gd"))
	features.append(FrameworkFeature.new("OverheadPhysicsComponent", "物理", "俯视运动物理：摩擦与速度处理", "res://Components/Physics/OverheadPhysicsComponent.gd"))
	features.append(FrameworkFeature.new("PlatformerPhysicsComponent", "物理", "平台游戏物理：重力/加速/摩擦", "res://Components/Physics/PlatformerPhysicsComponent.gd"))
	features.append(FrameworkFeature.new("PushRigidBodyComponent", "物理", "让 CharacterBody2D 推动 RigidBody2D", "res://Components/Physics/PushRigidBodyComponent.gd"))
	features.append(FrameworkFeature.new("TileCollisionComponent", "物理", "上报与瓦片地图的碰撞及具体格子坐标", "res://Components/Physics/TileCollisionComponent.gd"))
	features.append(FrameworkFeature.new("VelocityClampComponent", "物理", "速度钳制（后坐力/击退叠加时必用）", "res://Components/Physics/VelocityClampComponent.gd"))

	# ---- 回合制 ----
	features.append(FrameworkFeature.new("TurnBasedAnimationComponent", "回合制", "按回合信号播 AnimationPlayer/AnimatedSprite2D 动画", "res://Components/TurnBased/TurnBasedAnimationComponent.gd"))
	features.append(FrameworkFeature.new("TurnBasedComponent", "回合制", "回合流程组件基类（begin/execute/end）", "res://Components/TurnBased/TurnBasedComponent.gd"))
	features.append(FrameworkFeature.new("TurnBasedCounterComponent", "回合制", "显示当前回合数与阶段（调试用）", "res://Components/TurnBased/TurnBasedCounterComponent.gd"))
	features.append(FrameworkFeature.new("TurnBasedStateUIComponent", "回合制", "回合状态 UI（实验，面向主 UI 实体）", "res://Components/TurnBased/TurnBasedStateUIComponent.gd"))
	features.append(FrameworkFeature.new("TurnBasedTileBasedControlComponent", "回合制", "轮到该实体时执行网格移动", "res://Components/TurnBased/TurnBasedTileBasedControlComponent.gd"))
	features.append(FrameworkFeature.new("TurnBasedTileBasedGravityComponent", "回合制", "回合制伪重力（实验）", "res://Components/TurnBased/TurnBasedTileBasedGravityComponent.gd"))
	features.append(FrameworkFeature.new("TurnBasedTileBasedPlatformerControlComponent", "回合制", "回合制平台控制层（实验）", "res://Components/TurnBased/TurnBasedTileBasedPlatformerControlComponent.gd"))

	# ---- 视觉 ----
	features.append(FrameworkFeature.new("AnimationComponentBase", "视觉", "驱动 AnimatedSprite2D 的视觉组件基类", "res://Components/Visual/AnimationComponentBase.gd"))
	features.append(FrameworkFeature.new("BlinkPauseComponent", "视觉", "闪烁并暂停后移除自身（出生/死亡特效）", "res://Components/Visual/BlinkPauseComponent.gd"))
	features.append(FrameworkFeature.new("CameraComponent", "视觉", "增强相机组件，实体移除时保住视野", "res://Components/Visual/CameraComponent.gd"))
	features.append(FrameworkFeature.new("CompassComponent", "视觉", "指向目标的罗盘指示", "res://Components/Visual/CompassComponent.gd"))
	features.append(FrameworkFeature.new("DamageVisualComponent", "视觉", "受伤视觉反馈（含被护盾吸收）", "res://Components/Visual/DamageVisualComponent.gd"))
	features.append(FrameworkFeature.new("HealthVisualComponent", "视觉", "生命值变化视觉反馈（含治疗）", "res://Components/Visual/HealthVisualComponent.gd"))
	features.append(FrameworkFeature.new("HideWhenStationaryComponent", "视觉", "静止时隐藏，恢复移动时显示", "res://Components/Visual/HideWhenStationaryComponent.gd"))
	features.append(FrameworkFeature.new("LabelComponent", "视觉", "实体上的动画标签（实验）", "res://Components/Visual/LabelComponent.gd"))
	features.append(FrameworkFeature.new("NodeFacingComponent", "视觉", "朝向另一个节点（瞄准/朝向光标）", "res://Components/Visual/NodeFacingComponent.gd"))
	features.append(FrameworkFeature.new("OffscreenRemovalComponent", "视觉", "离屏后请求删除实体（可延迟）", "res://Components/Visual/OffscreenRemovalComponent.gd"))
	features.append(FrameworkFeature.new("OverheadAnimationComponent", "视觉", "俯视四向 idle/walk 动画（命名约定）", "res://Components/Visual/OverheadAnimationComponent.gd"))
	features.append(FrameworkFeature.new("PlatformerAnimationComponent", "视觉", "平台游戏动画状态机", "res://Components/Visual/PlatformerAnimationComponent.gd"))
	features.append(FrameworkFeature.new("ShapeDrawComponent", "视觉", "矢量形状绘制（原型/调试，实验）", "res://Components/Visual/ShapeDrawComponent.gd"))
	features.append(FrameworkFeature.new("StatsVisualComponent", "视觉", "属性变化时弹文字气泡", "res://Components/Visual/StatsVisualComponent.gd"))
	features.append(FrameworkFeature.new("TileBasedAnimationComponent", "视觉", "按网格移动播动画", "res://Components/Visual/TileBasedAnimationComponent.gd"))
	features.append(FrameworkFeature.new("TileBasedSightComponent", "视觉", "视野/亮度计算（数据型，实验）", "res://Components/Visual/TileBasedSightComponent.gd"))

	# ---- 运行时 / 编辑器 / 资源 / 载荷 / 参数 / 生成 / 工具 / UI / 场景 / 模板 ----
	features.append(FrameworkFeature.new("Debug", "运行时", "日志/监视值/图表，printLog/printWarning/printError", "res://AutoLoad/Debug.gd", ""))
	features.append(FrameworkFeature.new("GameState", "运行时", "全局状态、玩家注册、存档读档、随机数、事件总线", "res://AutoLoad/GameState.gd", ""))
	features.append(FrameworkFeature.new("Global", "运行时", "框架常量、节点组、自定义数据键、工具方法", "res://AutoLoad/Global.gd", ""))
	features.append(FrameworkFeature.new("GlobalInput", "运行时", "输入动作名、标签与全局快捷键", "res://AutoLoad/GlobalInput.gd", ""))
	features.append(FrameworkFeature.new("GlobalSonic", "运行时", "音乐、音效与脚本生成蜂鸣（跨场景存活）", "res://AutoLoad/GlobalSonic.gd", ""))
	features.append(FrameworkFeature.new("GlobalUI", "运行时", "常驻覆盖层、暂停视觉与场景转场", "res://AutoLoad/GlobalUI.gd", ""))
	features.append(FrameworkFeature.new("PauseOverlay", "运行时", "暂停覆盖层（Esc 打出；由 GlobalUI 管理，不要在别处重复实例化）", "res://UI/PauseOverlay.tscn", ""))
	features.append(FrameworkFeature.new("SceneManager", "运行时", "场景切换与导航栈 push/pop，含转场动画", "res://AutoLoad/SceneManager.gd", ""))
	features.append(FrameworkFeature.new("Settings", "运行时", "用户设置持久化（配置文件读写）", "res://AutoLoad/Settings.gd", ""))
	features.append(FrameworkFeature.new("TurnBasedCoordinator", "运行时", "回合调度：顺序与 begin/execute/end 阶段（需 ComedotProjectSettings.isTurnBasedGame 才保留）", "res://AutoLoad/TurnBasedCoordinator.gd", ""))
	features.append(FrameworkFeature.new("ComedotProjectSettings", "运行时", "项目级设置资源：主场景、GlobalData、音乐、回合时长", "res://addons/Comedot/ComedotProjectSettings.gd", ""))
	features.append(FrameworkFeature.new("ComedotPlugin", "编辑器", "编辑器坞：组件列表与常用操作", "res://addons/Comedot/Comedot.gd", ""))
	features.append(FrameworkFeature.new("ComponentsDock", "编辑器", "扫描 Components/ 并一键添加实体与组件", "res://addons/Comedot/ComponentsDock.gd", ""))
	features.append(FrameworkFeature.new("GameProjectInitializer", "编辑器", "生成新游戏的目录骨架（leafFolders）", "res://addons/Comedot/GameProjectInitializer.gd", ""))
	features.append(FrameworkFeature.new("GameplayResourceBase", "资源", "带身份/名称/描述/图标的资源基类", "res://Resources/GameplayResourceBase.gd", ""))
	features.append(FrameworkFeature.new("GlobalData", "资源", "全局 StringName→Variant 存储，可绑定到节点属性", "res://Resources/GlobalData.gd", ""))
	features.append(FrameworkFeature.new("Stat", "资源", "属性资源（生命/法力/弹药/经验）", "res://Resources/Stats/Stat.gd", ""))
	features.append(FrameworkFeature.new("StatWithModifiers", "资源", "带修饰器叠加的属性", "res://Resources/Stats/StatWithModifiers.gd", ""))
	features.append(FrameworkFeature.new("StatCost", "资源", "属性花费描述（技能/交互的代价）", "res://Resources/Stats/StatCost.gd", ""))
	features.append(FrameworkFeature.new("StatDependentResourceBase", "资源", "依赖属性的资源基类", "res://Resources/Stats/StatDependentResourceBase.gd", ""))
	features.append(FrameworkFeature.new("Ability", "资源", "可选动作/技能/法术，可带属性花费与目标要求", "res://Resources/Abilities/Ability.gd", ""))
	features.append(FrameworkFeature.new("PlatformerDash", "资源", "冲刺技能载荷（ScriptPayload 目标）", "res://Resources/Abilities/PlatformerDash.gd", ""))
	features.append(FrameworkFeature.new("InventoryItem", "资源", "背包物品", "res://Resources/InventoryItem.gd", ""))
	features.append(FrameworkFeature.new("Upgrade", "资源", "升级条目", "res://Resources/Upgrade.gd", ""))
	features.append(FrameworkFeature.new("ComponentSet", "资源", "组件类型集合（运行时换组件）", "res://Resources/ComponentSet.gd", ""))
	features.append(FrameworkFeature.new("StateMachine", "资源", "通用状态机资源", "res://Resources/StateMachine.gd", ""))
	features.append(FrameworkFeature.new("TimedStateMachine", "资源", "带计时的状态机资源", "res://Resources/TimedStateMachine.gd", ""))
	features.append(FrameworkFeature.new("GridDictionary", "资源", "以坐标作键的网格字典", "res://Scripts/Data/GridDictionary.gd", ""))
	features.append(FrameworkFeature.new("TileMapCellData", "资源", "运行时每格元数据（配合 TileMapLayerWithCellData）", "res://Resources/TileMapCellData.gd", ""))
	features.append(FrameworkFeature.new("Payload", "载荷", "可投递效果的抽象基类（信号/回调/脚本/属性/节点）", "res://Resources/Payloads/Payload.gd", ""))
	features.append(FrameworkFeature.new("SignalPayload", "载荷", "发一个信号", "res://Resources/Payloads/SignalPayload.gd", ""))
	features.append(FrameworkFeature.new("CallablePayload", "载荷", "调用一个函数/方法", "res://Resources/Payloads/CallablePayload.gd", ""))
	features.append(FrameworkFeature.new("NodePayload", "载荷", "实例化并挂载一个场景到目标节点", "res://Resources/Payloads/NodePayload.gd", ""))
	features.append(FrameworkFeature.new("ScriptPayload", "载荷", "调用指定 GDScript 的函数", "res://Resources/Payloads/ScriptPayload.gd", ""))
	features.append(FrameworkFeature.new("ComponentPayload", "载荷", "在目标实体上增删组件", "res://Resources/Payloads/ComponentPayload.gd", ""))
	features.append(FrameworkFeature.new("StatModifierPayload", "载荷", "修改属性", "res://Resources/Payloads/StatModifierPayload.gd", ""))
	features.append(FrameworkFeature.new("RidePayload", "载荷", "骑上载具（配合 RideableComponent）", "res://Resources/Payloads/RidePayload.gd", ""))
	features.append(FrameworkFeature.new("Collection", "载荷", "可复用条目序列/堆叠/循环/随机集合基类", "res://Resources/Collections/Collection.gd", ""))
	features.append(FrameworkFeature.new("TextSequence", "载荷", "文本序列（对话/告示牌）", "res://Resources/Collections/TextSequence.gd", ""))
	features.append(FrameworkFeature.new("ColoredTextSequence", "载荷", "带颜色的文本序列", "res://Resources/Collections/ColoredTextSequence.gd", ""))
	features.append(FrameworkFeature.new("OverheadMovementParameters", "参数", "俯视运动物理参数", "res://Resources/Parameters/OverheadMovementParameters.gd", ""))
	features.append(FrameworkFeature.new("PlatformerMovementParameters", "参数", "平台物理参数（物理/跳跃/攀爬共用）", "res://Resources/Parameters/PlatformerMovementParameters.gd", ""))
	features.append(FrameworkFeature.new("PlatformerJumpParameters", "参数", "跳跃参数", "res://Resources/Parameters/PlatformerJumpParameters.gd", ""))
	features.append(FrameworkFeature.new("AsteroidsMovementParameters", "参数", "小行星控制参数", "res://Resources/Parameters/AsteroidsMovementParameters.gd", ""))
	features.append(FrameworkFeature.new("ScrollerMovementParameters", "参数", "卷轴控制参数", "res://Resources/Parameters/ScrollerMovementParameters.gd", ""))
	features.append(FrameworkFeature.new("GunParameters", "参数", "武器参数（与具体枪节点解耦）", "res://Resources/Parameters/GunParameters.gd", ""))
	features.append(FrameworkFeature.new("Spawner", "生成", "通用生成器：准备/校验/实例化，含总量与并发限制", "res://Scripts/Gameplay/Spawner.gd", ""))
	features.append(FrameworkFeature.new("SpawnerSequenceBase", "生成", "按场景路径序列生成的基类", "res://Scripts/Gameplay/SpawnerSequenceBase.gd", ""))
	features.append(FrameworkFeature.new("SpawnerList", "生成", "顺序循环生成（可空路径当延迟）", "res://Scripts/Gameplay/SpawnerList.gd", ""))
	features.append(FrameworkFeature.new("SpawnerRandom", "生成", "按权重随机生成", "res://Scripts/Gameplay/SpawnerRandom.gd", ""))
	features.append(FrameworkFeature.new("SpawnerStack", "生成", "栈式生成，耗尽后发信号、可重新填充", "res://Scripts/Gameplay/SpawnerStack.gd", ""))
	features.append(FrameworkFeature.new("RandomPlaceholder", "生成", "按概率决定加载或跳过的实例占位", "res://Scripts/Gameplay/RandomPlaceholder.gd", ""))
	features.append(FrameworkFeature.new("ReplaceWithRandomScene", "生成", "按权重把自己替换成别的场景", "res://Scripts/Gameplay/ReplaceWithRandomScene.gd", ""))
	features.append(FrameworkFeature.new("GameOver", "生成", "监听 gameDidOver 显示结束 UI 并暂停", "res://Scripts/Gameplay/GameOver.gd", ""))
	features.append(FrameworkFeature.new("ApplyGlobalData", "生成", "把 GlobalData 键绑定到 NodePath 属性", "res://Scripts/Data/ApplyGlobalData.gd", ""))
	features.append(FrameworkFeature.new("RegisterGlobalNodeName", "生成", "把节点注册到 SceneManager.globalNodeNames", "res://Scripts/Data/RegisterGlobalNodeName.gd", ""))
	features.append(FrameworkFeature.new("TileMapLayerWithCellData", "生成", "带运行时每格元数据的 TileMapLayer", "res://Scripts/Data/TileMapLayerWithCellData.gd", ""))
	features.append(FrameworkFeature.new("LubanLoader", "生成", "Luban 配置表加载（JSON→运行时表）", "res://Scripts/Data/LubanLoader.gd", ""))
	features.append(FrameworkFeature.new("PopulateTest", "生成", "Spawner 家族综合测试场景（场景内 %唯一名 有告警，直接跑会刷日志）", "res://Scripts/Gameplay/Spawner.gd", ""))
	features.append(FrameworkFeature.new("Tools", "工具", "内建类型的全局静态辅助函数入口", "res://Scripts/Tools/Tools.gd", ""))
	features.append(FrameworkFeature.new("NodeTools", "工具", "节点相关静态辅助", "res://Scripts/Tools/NodeTools.gd", ""))
	features.append(FrameworkFeature.new("RectTools", "工具", "矩形/几何静态辅助", "res://Scripts/Tools/RectTools.gd", ""))
	features.append(FrameworkFeature.new("AreaTools", "工具", "Area2D 静态辅助", "res://Scripts/Tools/AreaTools.gd", ""))
	features.append(FrameworkFeature.new("CollisionTools", "工具", "碰撞层/掩码静态辅助", "res://Scripts/Tools/CollisionTools.gd", ""))
	features.append(FrameworkFeature.new("TileMapTools", "工具", "瓦片地图静态辅助", "res://Scripts/Tools/TileMapTools.gd", ""))
	features.append(FrameworkFeature.new("FileSystemTools", "工具", "目录遍历/按扩展改名等文件系统辅助", "res://Scripts/Tools/FileSystemTools.gd", ""))
	features.append(FrameworkFeature.new("EditorTools", "工具", "编辑器模式判断与编辑器专用操作", "res://Scripts/Tools/EditorTools.gd", ""))
	features.append(FrameworkFeature.new("Animations", "工具", "动画相关静态辅助", "res://Scripts/Visual/Animations.gd", ""))
	features.append(FrameworkFeature.new("Camera", "工具", "相机静态辅助（震动等）", "res://Scripts/Visual/Camera.gd", ""))
	features.append(FrameworkFeature.new("FakeParallax", "工具", "假视差（无需 ParallaxBackground）", "res://Scripts/Visual/FakeParallax.gd", ""))
	features.append(FrameworkFeature.new("CopyShapeFromCollisionPolygon", "工具", "从碰撞多边形复制形状（画/遮罩）", "res://Scripts/Visual/CopyShapeFromCollisionPolygon.gd", ""))
	features.append(FrameworkFeature.new("CreateSpriteFramesFromSheet", "工具", "从精灵表切出 SpriteFrames", "res://Scripts/Visual/CreateSpriteFramesFromSheet.gd", ""))
	features.append(FrameworkFeature.new("CycleColor", "工具", "循环变色", "res://Scripts/Visual/CycleColor.gd", ""))
	features.append(FrameworkFeature.new("Flicker", "工具", "闪烁", "res://Scripts/Visual/Flicker.gd", ""))
	features.append(FrameworkFeature.new("SnapToMouse", "工具", "吸附到鼠标", "res://Scripts/Visual/SnapToMouse.gd", ""))
	features.append(FrameworkFeature.new("Spin", "工具", "简易自旋（非组件）", "res://Scripts/Visual/Spin.gd", ""))
	features.append(FrameworkFeature.new("MoveRandomly", "工具", "简易随机移动（非组件）", "res://Scripts/Visual/MoveRandomly.gd", ""))
	features.append(FrameworkFeature.new("StatUI", "UI", "单个属性的数值显示（可绑定 StatsComponent）", "res://UI/Views/StatUI.tscn", "res://UI/Views/StatUI.tscn"))
	features.append(FrameworkFeature.new("StatBar", "UI", "属性条", "res://UI/Views/StatBar.tscn", "res://UI/Views/StatBar.tscn"))
	features.append(FrameworkFeature.new("StatPips", "UI", "属性点（命数/血格的圆点表现）", "res://UI/Views/StatPips.tscn", "res://UI/Views/StatPips.tscn"))
	features.append(FrameworkFeature.new("GameplayResourceUI", "UI", "玩法资源通用显示气泡", "res://UI/Views/GameplayResourceUI.tscn", "res://UI/Views/GameplayResourceUI.tscn"))
	features.append(FrameworkFeature.new("InventoryItemUI", "UI", "背包物品条目", "res://UI/Views/InventoryItemUI.tscn", "res://UI/Views/InventoryItemUI.tscn"))
	features.append(FrameworkFeature.new("UpgradeUI", "UI", "升级条目显示（需先赋一个 Upgrade 资源）", "res://UI/Views/UpgradeUI.tscn", ""))
	features.append(FrameworkFeature.new("UpgradeChoiceUI", "UI", "升级三选一面板（需先喂选项列表）", "res://UI/Views/UpgradeChoiceUI.tscn", ""))
	features.append(FrameworkFeature.new("BusVolumeUI", "UI", "音量总线滑条", "res://UI/Views/BusVolumeUI.tscn", "res://UI/Views/BusVolumeUI.tscn"))
	features.append(FrameworkFeature.new("LongPressButton", "UI", "长按按钮", "res://UI/Buttons/LongPressButton.tscn", "res://UI/Buttons/LongPressButton.tscn"))
	features.append(FrameworkFeature.new("PauseButton", "UI", "暂停按钮（跟 SceneManager 暂停态同步）", "res://UI/Buttons/PauseButton.tscn", "res://UI/Buttons/PauseButton.tscn"))
	features.append(FrameworkFeature.new("AbilityButton", "UI", "技能按钮（冷却遮罩，需先赋 Ability）", "res://UI/Buttons/AbilityButton.tscn", ""))
	features.append(FrameworkFeature.new("BlinkingLabel", "UI", "闪烁标签", "res://UI/Labels/BlinkingLabel.tscn", "res://UI/Labels/BlinkingLabel.tscn"))
	features.append(FrameworkFeature.new("FadingLabel", "UI", "淡出标签", "res://UI/Labels/FadingLabel.tscn", "res://UI/Labels/FadingLabel.tscn"))
	features.append(FrameworkFeature.new("TextCyclingLabel", "UI", "循环文本标签", "res://UI/Labels/TextCyclingLabel.tscn", "res://UI/Labels/TextCyclingLabel.tscn"))
	features.append(FrameworkFeature.new("CameraFollowingLabel", "UI", "跟随相机的标签（需先指定相机）", "res://UI/Labels/CameraFollowingLabel.tscn", ""))
	features.append(FrameworkFeature.new("ModalUI", "UI", "模态弹窗容器", "res://UI/ModalUI.tscn", "res://Tests/ModalUITest.tscn"))
	features.append(FrameworkFeature.new("Chart", "UI", "折线/柱状图表控件", "res://UI/Chart.tscn", "res://UI/Chart.tscn"))
	features.append(FrameworkFeature.new("ChartWindow", "UI", "图表窗口（Debug 用）", "res://UI/ChartWindow.tscn", "res://UI/ChartWindow.tscn"))
	features.append(FrameworkFeature.new("InputMapUI", "UI", "输入动作表查看/编辑", "res://UI/InputMapUI.tscn", "res://UI/InputMapUI.tscn"))
	features.append(FrameworkFeature.new("InputActionUI", "UI", "单个输入动作绑定行", "res://UI/InputActionUI.tscn", "res://UI/InputActionUI.tscn"))
	features.append(FrameworkFeature.new("InputActionEventUI", "UI", "单个输入事件绑定行", "res://UI/InputActionEventUI.tscn", "res://UI/InputActionEventUI.tscn"))
	features.append(FrameworkFeature.new("TreeSearchBox", "UI", "树形搜索框", "res://UI/TreeSearchBox.tscn", "res://UI/TreeSearchBox.tscn"))
	features.append(FrameworkFeature.new("CustomLogEntryUI", "UI", "调试日志条目", "res://UI/CustomLogEntryUI.tscn", "res://UI/CustomLogEntryUI.tscn"))
	features.append(FrameworkFeature.new("MainMenuButtons", "UI", "主菜单按钮组", "res://UI/Menus/MainMenuButtons.tscn", "res://UI/Menus/MainMenuButtons.tscn"))
	features.append(FrameworkFeature.new("OptionsUI", "UI", "设置面板", "res://UI/Menus/OptionsUI.tscn", "res://UI/Menus/OptionsUI.tscn"))
	features.append(FrameworkFeature.new("HUDTemplate", "UI", "HUD 模板（血条等常用布局）", "res://Templates/HUDTemplate.tscn", "res://Templates/HUDTemplate.tscn"))
	features.append(FrameworkFeature.new("SpawnArea", "场景", "区域生成器（在区域内生成实体）", "res://Scenes/Gameplay/SpawnArea.tscn", ""))
	features.append(FrameworkFeature.new("SpawnEdge", "场景", "屏幕边缘生成器", "res://Scenes/Gameplay/SpawnEdge.tscn", ""))
	features.append(FrameworkFeature.new("SpawnPoint", "场景", "固定点生成器", "res://Scenes/Gameplay/SpawnPoint.tscn", ""))
	features.append(FrameworkFeature.new("SpawnTimer", "场景", "定时生成器", "res://Scenes/Gameplay/SpawnTimer.tscn", ""))
	features.append(FrameworkFeature.new("SpawnWaveTrigger", "场景", "波次触发生成", "res://Scenes/Gameplay/SpawnWaveTrigger.tscn", ""))
	features.append(FrameworkFeature.new("SpawnLocationTrigger", "场景", "到达位置触发生成", "res://Scenes/Gameplay/SpawnLocationTrigger.tscn", ""))
	features.append(FrameworkFeature.new("PopulateArea", "场景", "按密度填充区域内实体", "res://Scenes/Gameplay/PopulateArea.tscn", ""))
	features.append(FrameworkFeature.new("OnScreenTrigger", "场景", "进入画面时触发", "res://Scenes/Gameplay/OnScreenTrigger.tscn", ""))
	features.append(FrameworkFeature.new("PlayerSpawnPosition", "场景", "玩家出生点标记", "res://Scenes/Gameplay/PlayerSpawnPosition.tscn", ""))
	features.append(FrameworkFeature.new("CooldownTimer", "场景", "带可视化进度环的冷却计时器", "res://Scenes/Gameplay/CooldownTimer.tscn", "res://Scenes/Gameplay/CooldownTimer.tscn"))
	features.append(FrameworkFeature.new("TextBubble", "场景", "文字气泡", "res://Scenes/Decorations/TextBubble.tscn", ""))
	features.append(FrameworkFeature.new("GameplayResourceBubble", "场景", "玩法资源气泡（数值飘字）", "res://Scenes/Decorations/GameplayResourceBubble.tscn", "res://Scenes/Decorations/GameplayResourceBubble.tscn"))
	features.append(FrameworkFeature.new("Lightning", "场景", "闪电装饰效果", "res://Scenes/Decorations/Lightning.tscn", "res://Scenes/Decorations/Lightning.tscn"))
	features.append(FrameworkFeature.new("RectangleAreaTemplate", "场景", "矩形 Area2D 模板", "res://Templates/RectangleAreaTemplate.tscn", "res://Templates/RectangleAreaTemplate.tscn"))
	features.append(FrameworkFeature.new("OverheadSceneTemplate", "模板", "俯视玩法整场景模板（含玩家与相机）", "res://Templates/Scenes/OverheadSceneTemplate.tscn", "res://Templates/Scenes/OverheadSceneTemplate.tscn"))
	features.append(FrameworkFeature.new("PlatformerSceneTemplate", "模板", "平台玩法整场景模板", "res://Templates/Scenes/PlatformerSceneTemplate.tscn", "res://Templates/Scenes/PlatformerSceneTemplate.tscn"))
	features.append(FrameworkFeature.new("PlayerEntityTemplate-Overhead", "模板", "俯视玩家实体", "res://Templates/Entities/PlayerEntityTemplate-Overhead.tscn", ""))
	features.append(FrameworkFeature.new("PlayerEntityTemplate-OverheadCombat", "模板", "俯视玩家实体（带战斗）", "res://Templates/Entities/PlayerEntityTemplate-OverheadCombat.tscn", ""))
	features.append(FrameworkFeature.new("PlayerEntityTemplate-Platformer", "模板", "平台玩家实体", "res://Templates/Entities/PlayerEntityTemplate-Platformer.tscn", ""))
	features.append(FrameworkFeature.new("PlayerEntityTemplate-TileBased", "模板", "网格玩家实体（棋盘/回合制）", "res://Templates/Entities/PlayerEntityTemplate-TileBased.tscn", ""))
	features.append(FrameworkFeature.new("MonsterEntityTemplate-Platformer", "模板", "平台怪物实体", "res://Templates/Entities/MonsterEntityTemplate-Platformer.tscn", ""))
	features.append(FrameworkFeature.new("BulletEntityTemplate", "模板", "弹体实体模板", "res://Templates/Entities/BulletEntityTemplate.tscn", ""))
	features.append(FrameworkFeature.new("TemplateGunComponent", "模板", "武器组件模板（改它做自己的枪）", "res://Templates/Weapon/TemplateGunComponent.tscn", ""))
	features.append(FrameworkFeature.new("CharacterBodyEntityTemplate", "模板", "CharacterBody2D 实体模板", "res://Templates/Entities/CharacterBodyEntityTemplate.tscn", ""))
	features.append(FrameworkFeature.new("AreaEntityTemplate", "模板", "Area2D 实体模板", "res://Templates/Entities/AreaEntityTemplate.tscn", ""))
	features.append(FrameworkFeature.new("AnimatedSpriteEntityTemplate", "模板", "动画精灵实体模板", "res://Templates/Entities/AnimatedSpriteEntityTemplate.tscn", ""))
	features.append(FrameworkFeature.new("CollectibleEntityTemplate", "模板", "可拾取物实体模板", "res://Templates/Entities/CollectibleEntityTemplate.tscn", ""))
	features.append(FrameworkFeature.new("InteractiveEntityTemplate", "模板", "可交互实体模板", "res://Templates/Entities/InteractiveEntityTemplate.tscn", ""))
	features.append(FrameworkFeature.new("SpriteEntityTemplate", "模板", "最简精灵实体模板", "res://Templates/Entities/SpriteEntityTemplate.tscn", ""))
	features.append(FrameworkFeature.new("TreesWithGunsExampleScene", "模板", "示例：会开枪的树（组件组合示范）", "res://Templates/Examples/TreesWithGunsExampleScene.tscn", "res://Templates/Examples/TreesWithGunsExampleScene.tscn"))
	features.append(FrameworkFeature.new("ComponentSwappingExampleScene", "模板", "示例：运行时换组件集", "res://Templates/Examples/ComponentSwappingExampleScene.tscn", "res://Templates/Examples/ComponentSwappingExampleScene.tscn"))
	features.append(FrameworkFeature.new("GhostExampleEntity", "模板", "示例：幽灵实体（部件组合）", "res://Templates/Examples/GhostExampleEntity.tscn", ""))

	return features

#endregion


#region 自检

## 递归收集某个目录下的全部 `.gd` 脚本路径。
##
## 不用框架的 FileSystemTools：它的静态函数在本构建里调用会报
## 「Nonexistent function ... in base 'GDScript'」（框架自身 GlobalSonic 也踩到），
## 这里直接用 DirAccess，行为可控。
static func _collectScriptPaths(rootPath: String) -> PackedStringArray:
	var results: PackedStringArray = PackedStringArray()
	var pending: PackedStringArray = PackedStringArray([rootPath])

	while not pending.is_empty():
		var folder: String = pending[pending.size() - 1]
		pending.remove_at(pending.size() - 1)

		for directory in DirAccess.get_directories_at(folder):
			pending.append(folder.path_join(directory))

		for fileName in DirAccess.get_files_at(folder):
			# 用 get_extension() 精确判断：contains("gd") 会把 `.gd.uid` 也算进来
			if fileName.get_extension() == "gd":
				results.append(folder.path_join(fileName))

	results.sort()
	return results


## 与磁盘双向对照。
## 返回 { covered, total, notListed: PackedStringArray, broken: PackedStringArray, demoCount }
##   notListed = Components/ 下存在但没有对应条目的组件脚本
##   broken    = 条目引用的 sourcePath / demoScenePath 不存在
static func verifyCoverage() -> Dictionary:
	var listedPaths: Dictionary = {}
	var broken: PackedStringArray = PackedStringArray()
	var demoCount: int = 0

	for feature in getFeatures():
		if not feature.sourcePath.is_empty():
			listedPaths[feature.sourcePath] = true
			if not ResourceLoader.exists(feature.sourcePath):
				broken.append(feature.sourcePath)
		if feature.hasDemo():
			demoCount += 1
			if not ResourceLoader.exists(feature.demoScenePath):
				broken.append(feature.demoScenePath)

	# Components/ 下的组件脚本（只算 .gd，排除 .gd.uid 这类副产物）
	var componentScripts: PackedStringArray = _collectScriptPaths("res://Components")

	var notListed: PackedStringArray = PackedStringArray()
	for path in componentScripts:
		if not listedPaths.has(path):
			notListed.append(path)

	return {
		"covered": componentScripts.size() - notListed.size(),
		"total": componentScripts.size(),
		"notListed": notListed,
		"broken": broken,
		"demoCount": demoCount,
	}

#endregion
