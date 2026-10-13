# Comedot 框架入门学习指南（本 fork 版）

> **版本说明：** 本指南基于 Godot **4.8**（本 fork `config/features = PackedStringArray("4.8", "C#")`）的 Comedot 框架，API 可能随版本迭代而变化。
> **fork 说明：** 本 fork 无上游的 `Scripts/Start.gd` 启动脚本，启动职责由 AutoLoad 体系承担；本指南已按本 fork 实况修正启动相关描述（上游协议对照见附录 B）。
> 源自 `_Doc/学习指南.md`（2026-10-13 并入 docs）· 已融合 `_Doc/Note/` 概念笔记。

---

## 目录

1. [框架概述](#1-框架概述)
2. [目录结构详解](#2-目录结构详解)
3. [核心概念](#3-核心概念)
4. [快速开始：学习路径](#4-快速开始学习路径)
5. [制作一个简单游戏](#5-制作一个简单游戏)
6. [AutoLoad 全家桶](#6-autoload-全家桶)
7. [资源系统（Resources）](#7-资源系统resources)
8. [回合制游戏](#8-回合制游戏)
9. [编码规范与最佳实践](#9-编码规范与最佳实践)
10. [调试技巧](#10-调试技巧)
11. [常见问题与反模式](#11-常见问题与反模式)

---

## 1. 框架概述

Comedot 是一个基于 **实体-组件（Entity-Component）** 组合模式的 Godot 2D 游戏框架。

### 核心思想

| 概念 | 说明 |
|------|------|
| **Entity（实体）** | 游戏角色或对象的"脚手架"节点，本身不含游戏逻辑，依靠子节点组件来实现行为 |
| **Component（组件）** | 封装单一行为的可复用节点，如跳跃、射击、生命值、摄像机等 |
| **组合 > 继承** | 通过将多个组件拼接到实体上构建复杂游戏对象，而非创建深层继承链 |

### 与传统 ECS 的区别

Comedot **没有"系统（System）"层**——组件直接相互通信（通过 `coComponents` 字典 + 信号），避免了纯 ECS 的复杂性，同时保留了 Godot 场景树的直观性。

### 适用游戏类型

横版平台游戏、俯视角 RPG、射击游戏、回合制策略、拼图解谜、砖块游戏等 2D 游戏类型均有对应的模板和组件支持。

---

## 2. 目录结构详解

```
comedot/
├── Components/          ← ⭐ 核心：可复用行为单元（场景+脚本对）
│   ├── Combat/          ← 战斗：生命值、伤害、无敌帧、子弹等
│   ├── Control/         ← 控制：玩家输入、AI、鼠标旋转等
│   ├── Physics/         ← 物理：角色体、平台跳跃、俯视移动等
│   ├── Movement/        ← 移动：爬梯、追踪、路径点等
│   ├── Visual/          ← 视觉：动画、特效、摄像机等
│   ├── Gameplay/        ← 玩法：收集品、升级、计时器等
│   ├── Interaction/     ← 交互：对话、机关、触发区域等
│   ├── Data/            ← 数据：属性统计、行动点等
│   ├── Objects/         ← 对象：子弹、爆炸、生成器等
│   ├── TurnBased/       ← 回合制专用组件
│   ├── AI/              ← AI 行为组件
│   ├── Component.gd     ← ⭐ 所有组件的基类
│   └── Component.tscn   ← 组件基础场景
│
├── Entities/            ← 实体：聚合组件的容器节点
│   ├── Characters/      ← 角色实体（玩家、NPC）
│   ├── Objects/         ← 对象实体（道具、机关）
│   ├── Nodes/           ← 特殊节点实体
│   ├── TurnBased/       ← 回合制实体
│   ├── Entity.gd        ← ⭐ 所有实体的基类
│   └── Entity.tscn
│
├── AutoLoad/            ← 全局单例（自动加载）
│   ├── Global.gd        ← 全局常量、组名、标志
│   ├── GameState.gd     ← 跨场景游戏状态
│   ├── SceneManager.gd  ← 场景切换与导航栈
│   ├── Debug.tscn       ← 调试工具与日志（含 Debug.gd 脚本）
│   ├── Settings.gd      ← 玩家偏好设置（自动存档）
│   ├── GlobalInput.gd   ← 输入动作定义
│   ├── GlobalUI.tscn    ← 全局 UI 管理
│   ├── GlobalSonic.tscn ← 全局音频管理
│   └── TurnBasedCoordinator.tscn  ← 回合制协调器
│
├── Resources/           ← 数据资源类
│   ├── Stats/           ← 属性统计（生命、弹药等）
│   ├── Actions/         ← 动作/技能资源
│   ├── Collections/     ← 集合资源
│   ├── Payloads/        ← 数据载荷（用于组件间通信）
│   ├── Parameters/      ← 参数资源
│   └── Upgrade.gd       ← 升级/强化系统
│
├── Scripts/             ← 非实体/组件的共享脚本
│   ├── Tools.gd         ← 通用工具函数
│   ├── Data/            ← 数据管线
│   ├── Mono/            ← C# 支持（含 Luban 配置服务）
│   └── Visual/          ← 动画/视觉辅助
│
├── Templates/           ← ⭐ 快速开始模板
│   ├── Scenes/          ← 完整场景模板（平台、俯视角）
│   ├── Entities/        ← 预设实体模板
│   └── Examples/        ← 示例场景（含可玩演示）
│
├── Scenes/              ← 框架内置场景（Logo、菜单、暂停等）
├── Tests/               ← 手动测试场景
├── UI/                  ← 可定制 UI 控件（血条、弹药、技能按钮等）
├── Assets/              ← 第三方资源（字体、图标、瓦片等）
├── docs/                ← 开发文档（本逆向蒸馏文档集）
└── Game/                ← 你的游戏专属目录（本 fork 现为框架闭环示例）
```

> **原则：** 框架代码在 `Game/` **以外**；你的游戏代码放在 `Game/` 里，或在现有目录下创建子文件夹（如 `Scenes/MyGame/`）。
>
> ⚠️ **关于 `Scripts/Start.gd`**：上游文档（含本指南的早期版本）描述的 `Scripts/Start.gd` 启动脚本**在本 fork 中不存在**。本 fork 的启动由 AutoLoad 体系承担，详见 §3.3 与附录 B。

---

## 3. 核心概念

### 3.1 Component（组件）

组件是 Comedot 的核心。每个组件：

- 必须是 **`.tscn` + `.gd` 的成对文件**
- 脚本必须 `extends Component`（或其子类）
- 必须加入 `components` 节点组
- 根节点类型按职责选择：
  - 纯逻辑 → `Node`
  - 需要位移/视觉 → `Node2D`
  - 特定用途 → 直接用目标节点类型（`Timer`, `Area2D` 等）

**组件间通信：通过 `coComponents` 字典**

```gdscript
# 在某个 Component 脚本中访问兄弟组件
var healthComponent: HealthComponent = coComponents.get(&"HealthComponent")
if healthComponent:
	healthComponent.health.value -= 10
```

**声明依赖：覆写 `getRequiredComponents()`**

```gdscript
func getRequiredComponents() -> Array[Script]:
	return [HealthComponent, FactionComponent]  # 告诉框架此组件依赖这两个组件
```

### 3.2 Entity（实体）

实体是"脚手架"节点，本身不包含游戏逻辑：

- 脚本 `extends Entity`（继承自 `Node2D`）
- 必须加入 `entities` 节点组
- 持有 `components` 字典（由每个组件在 `NOTIFICATION_PARENTED` 时自动注册）
- 提供 `getSprite()`, `getArea()`, `getBody()` 等快捷访问方法

```gdscript
# Entity 自动管理组件字典，无需手动操作
# 在任意子组件中访问父实体
var entity: Entity = parentEntity
var gun: GunComponent = entity.components.get(&"GunComponent")
```

### 3.3 框架启动流程（本 fork 实况）

> ⚠️ **与上游的差异**：上游依靠 `Scripts/Start.gd` 作为根启动脚本（`Start._enter_tree()` → `setupGameState()`；`Start._ready()` → `startComedot()` → `applyGlobalFlags()`），并在 `Global.hasStartScript` 上打启动标记。**本 fork 无该文件**（无 `Scripts/Boot/`），启动职责由各 AutoLoad 自行完成。详见 `architecture-asbuilt.md` §2.3。

实况启动链：

```
project.godot (run/main_scene)
	└─→ Scenes/Launch/Logo/IOLogoScene.tscn（class_name LogoSceneIO extends Node2D）
			├─ Logo 动画/跳过处理（期间临时禁用暂停快捷键）
			└─→ SceneManager.transitionToScene(GameFrame.tscn)
					└─ GameFrame 主菜单（MainMenuButtons）
							└─→ GameState.startMainScene()（读取 Settings.mainGameScenePath）
									└─→ Game 层由 override.cfg 覆盖为 res://Game/Example/ExampleScene.tscn
```

AutoLoad 启动顺序（`project.godot` 实况，从先到后）：

```
Global → Settings → Debug → SceneManager → GlobalInput → GameState → GlobalUI → GlobalSonic → TurnBasedCoordinator
```

关键机制：

- **`Settings` 早于正常场景启动**：`Settings` 在 `NOTIFICATION_PARENTED` 阶段即加载 `user://…Settings.cfg` 与项目覆盖，早于 `_enter_tree()`/`_ready()`。启动代码可以提前读取设置，不必等待 `Settings._ready()`。
- **早期日志**：AutoLoad 生命周期日志应使用 `Debug.printAutoLoadLog()`（见 §10）。
- **框架检查**：`Debug.performFrameworkChecks()` 检查 `Global.hasStartScript` 是否被设置；本 fork 无 Start 脚本，该提示会以警告形式出现——**属已知漂移，非故障**。
- 新项目若采用上游协议（`addons/Comedot/GameProjectInitializer.gd` 生成的 `Scripts/Boot/*Start.gd` 骨架），子类的 `_enter_tree()` 与 `_ready()` 必须调用 `super`。

---

## 4. 快速开始：学习路径

### 阶段一：运行示例，感受框架（30 分钟）

1. 在 Godot 中打开 `project.godot`
2. 按 **F5** 运行整个项目（看 Logo → GameFrame → Example 流程）
3. 在文件系统中找到 `Templates/Scenes/PlatformerSceneTemplate.tscn`，按 **F6** 单独运行它
4. 同样运行 `Templates/Examples/TreesWithGunsExampleScene.tscn` 和 `Templates/Examples/ComponentSwappingExampleScene.tscn`
5. 打开这些场景，在场景树中观察 Entity → Component 的层级结构

### 阶段二：理解组件，阅读代码（1 小时）

按以下顺序阅读关键脚本：

| 文件 | 学习重点 |
|------|----------|
| `Components/Component.gd` | `coComponents`, `getRequiredComponents()`, 生命周期 |
| `Entities/Entity.gd` | `components` 字典, `registerComponent()`, 快捷访问方法 |
| `Components/Combat/HealthComponent.gd` | 典型组件的结构：参数、信号、生命周期 |
| `Components/Physics/CharacterBodyComponent.gd` | 物理应用组件 |
| `AutoLoad/SceneManager.gd` | 场景切换与栈式导航 |

### 阶段三：从模板开始，修改实体（1-2 小时）

1. 复制 `Templates/Entities/PlayerEntityTemplate-Platformer.tscn` 到你的游戏目录
2. 在 Godot 场景编辑器中打开，查看各个组件的 Inspector 参数
3. 修改参数（跳跃高度、移动速度等），按 **F6** 测试变化
4. 尝试添加/删除组件（用"实例化子场景" Shift+Ctrl+A）

### 阶段四：创建你的第一个自定义组件（2-4 小时）

参见下一章的完整流程。

### 阶段五：集成 AutoLoad 和资源（持续学习）

- 使用 `Settings.anyName = value` 存储玩家设置
- 使用 `SceneManager.transitionToScene(...)` 切换场景
- 使用 `Debug.printLog(...)` 输出带颜色的调试信息

---

## 5. 制作一个简单游戏

### 5.1 创建玩家实体

**方法一（推荐）：** 使用现有模板

直接复制 `Templates/Entities/PlayerEntityTemplate-Platformer.tscn` 到你的游戏场景。

**方法二：** 从零手动创建

```
1. 创建 CharacterBody2D 节点
2. 挂载脚本 Entities/Characters/PlayerEntity.gd
3. 添加子节点：AnimatedSprite2D, CollisionShape2D, Camera2D
4. 设置物理碰撞层：players 层，mask 设为 terrain
```

### 5.2 添加控制与移动

在玩家 Entity 下，用 **Shift+Ctrl+A（实例化子场景）** 添加以下组件（**注意顺序很重要！**）：

**横版平台游戏（跑跳）：**
```
PlayerEntity
├── JumpComponent.tscn              ← Components/Physics/
├── PlatformerPhysicsComponent.tscn ← Components/Physics/
├── CharacterBodyComponent.tscn     ← Components/Physics/ （必须在物理组件之后）
└── InputComponent.tscn             ← Components/Control/ （必须在最后）
```

**俯视角 RPG / 飞行游戏：**
```
PlayerEntity
├── OverheadPhysicsComponent.tscn
├── CharacterBodyComponent.tscn
└── InputComponent.tscn
```

**基于瓦片的棋盘游戏：**
```
PlayerEntity
├── TileBasedPositionComponent.tscn
├── TileBasedControlComponent.tscn
└── InputComponent.tscn
```

> ⚠️ **重要：** 添加组件必须用"实例化子场景"（Shift+Ctrl+A），**不要**用"添加子节点"（Ctrl+A），后者不会包含组件的内部子节点！

### 5.3 添加战斗系统

```
PlayerEntity
├── FactionComponent.tscn       ← 设置 Faction = players
├── HealthComponent.tscn        ← 配置最大生命值
├── DamageReceivingComponent.tscn
└── InvulnerabilityOnHitComponent.tscn  （可选：受击无敌帧）

EnemyEntity
├── FactionComponent.tscn       ← 设置 Faction = enemies
├── HealthComponent.tscn
├── DamageReceivingComponent.tscn
└── DamageComponent.tscn        ← 接触时对玩家造成伤害
```

### 5.4 添加枪械

```
PlayerEntity 或任意 Entity
├── GunComponent.tscn           ← Components/Combat/
│   └── （可在 Inspector 配置子弹预制体、射速、弹药等）
└── MouseRotationComponent.tscn ← Components/Control/ （可选：跟随鼠标朝向）
```

### 5.5 场景设置

你的主场景：

```
MyGameScene (Node2D)
├── TileMapLayer      ← 地形
├── PlayerEntity
└── ...
```

- **本 fork 现况**：主场景由 `Game/override.cfg` 覆盖指向 `res://Game/Example/ExampleScene.tscn`；框架默认（`project.godot`）为 Logo 启动链。
- **上游协议（本 fork 不适用）**：主场景根节点挂 `Scripts/Start.gd` 或 `extends Start` 的子类（Inspector 配置 `mainGameScenePath`、`musicFolder` 等）。若你的项目采用上游协议骨架（`Scripts/Boot/*Start.gd`），记得子类必须调用 `super`。

### 5.6 场景切换

```gdscript
# 跳转到另一个场景
SceneManager.transitionToScene(preload("res://Scenes/MyGame/Level2.tscn"))

# 带动画切换
SceneManager.transitionToScene(preload("res://..."), true) # true = 使用过渡动画

# 返回上一个场景
SceneManager.popScene()
```

### 5.7 创建自定义组件

当你需要游戏特有的行为时，创建新组件：

**步骤：**
1. 在 `Components/` 的适当子目录（或 `Game/Components/`）新建场景
   - 纯逻辑 → 根节点选 `Node`
   - 需要显示 → 根节点选 `Node2D`
2. 将根节点加入 `components` 组（Inspector → 节点组）
3. 右键根节点 → 附加脚本，继承 `Component`

```gdscript
## 示例：一个让实体在受到伤害时闪烁的组件
class_name BlinkOnDamageComponent
extends Component


#region Parameters

@export var blinkDuration: float = 0.2
@export var blinkCount: int = 3

#endregion


func getRequiredComponents() -> Array[Script]:
	return [HealthComponent, DamageReceivingComponent]


func _ready() -> void:
	super._ready()
	# 连接兄弟组件的信号
	var damageReceiving: DamageReceivingComponent = coComponents.get(&"DamageReceivingComponent")
	if damageReceiving:
		damageReceiving.didReceiveDamage.connect(onDamageReceiving_didReceiveDamage)


func onDamageReceiving_didReceiveDamage(_damage: int) -> void:
	# 执行闪烁逻辑...
	pass
```

---

## 6. AutoLoad 全家桶

框架提供以下全局单例，在任何脚本中均可直接使用：

| 单例 | 主要用途 |
|------|---------|
| `Global` | 全局常量、节点组名（`Global.Groups.players` 等）、音频总线名 |
| `GameState` | 跨场景的游戏状态字典，存储关卡进度、解锁状态等；同时是全局事件总线（`statUpdated`/`gameDidOver`/`playersChanged` 等信号） |
| `SceneManager` | 场景切换、导航栈管理、暂停/恢复 |
| `Settings` | 玩家偏好（音量、全屏等），自动保存到配置文件（`NOTIFICATION_PARENTED` 阶段即加载） |
| `GlobalInput` | 输入动作名称常量，避免魔法字符串；处理全局快捷键 |
| `GlobalUI` | 全局 UI 节点管理（HUD、弹窗、转场蒙版等） |
| `GlobalSonic` | 音效与音乐播放（`GlobalSonic.playMusic(...)`, `GlobalSonic.playSFX(...)`） |
| `Debug` | 调试日志：`Debug.printLog()`, `Debug.printWarning()`, `Debug.printTrace()`；早期日志用 `Debug.printAutoLoadLog()` |
| `TurnBasedCoordinator` | 回合制游戏的全局协调器（非回合制项目会在启动时被移除） |

### 常用示例

```gdscript
# 保存/读取玩家设置（自动持久化）
Settings.masterVolume = 0.8
var vol: float = Settings.masterVolume

# 跨场景状态
GameState.globalData[&"playerScore"] = 9999
var score: int = GameState.globalData.get(&"playerScore", 0)

# 查找场景中所有玩家实体
var players: Array[Node] = get_tree().get_nodes_in_group(Global.Groups.players)

# 场景切换
SceneManager.transitionToScene(preload("res://Scenes/GameOver.tscn"))

# 调试日志（带颜色、时间戳）
Debug.printLog("玩家跳跃", self)
Debug.printWarning("找不到组件！", self)
```

---

## 7. 资源系统（Resources）

Comedot 提供了多种 `Resource` 子类用于数据驱动开发：

| 资源类 | 用途 |
|--------|------|
| `Stat` | 带上下限的数值属性（生命值、弹药、经验等） |
| `Action` | 玩家/AI 可执行的技能或动作 |
| `Upgrade` | 强化/升级项，安装到 `UpgradesComponent` |
| `InventoryItem` | 背包物品 |
| `ComponentSet` | 组件集合，用于动态批量添加/切换行为 |
| `TileMapCellData` | 运行时瓦片格数据 |

**资源的设计原则：**

- 资源**只存储数据和验证函数**
- 资源**不存储它被谁使用**（那是组件的职责）
- 资源通过"请求流"传递，而非直接赋值，以确保唯一性

```gdscript
# 在 Inspector 中配置 HealthComponent 使用的 Stat 资源
@export var health: Stat  # 在编辑器中拖入一个 .tres 文件

# 运行时访问
if health.value <= 0:
	# 角色死亡
	pass
```

---

## 8. 回合制游戏

### 快速设置

1. **项目设置 → AutoLoad**，确认 `TurnBasedCoordinator` 已启用（非回合制项目会在启动时自动移除它）
2. 场景中添加继承自 `TurnBasedEntity` 的实体
3. 为实体创建继承自 `TurnBasedComponent` 的组件
4. 将"下一回合"按钮或玩家输入连接到 `TurnBasedCoordinator.startTurnProcess()`

### 回合周期

每个回合，所有回合制对象按顺序经历三个阶段：

```
processTurnBegin()
	↓
processTurnUpdate()
	↓
processTurnEnd()
```

你的 `TurnBasedComponent` 只需覆写这三个方法之一或多个：

```gdscript
class_name MyTurnBasedComponent
extends TurnBasedComponent


func processTurnBegin() -> void:
	super.processTurnBegin()
	# 回合开始时的逻辑（如恢复行动点）


func processTurnUpdate() -> void:
	super.processTurnUpdate()
	# 主要回合逻辑（移动、攻击等）


func processTurnEnd() -> void:
	super.processTurnEnd()
	# 回合结束时的清理
```

---

## 9. 编码规范与最佳实践

### 9.1 命名规范

| 类型 | 规范 | 示例 |
|------|------|------|
| 变量/函数 | camelCase | `playerHealth`, `getComponent()` |
| 常量 | camelCase（本框架特殊约定） | `maxHealth`, `defaultSpeed` |
| 类型/类名 | PascalCase | `HealthComponent`, `PlayerEntity` |
| 布尔值 | 以 `is/has/should` 开头 | `isAlive`, `hasAmmo`, `shouldLoop` |
| 信号 | `did/will` + 动词 | `healthDidZero`, `willRemoveFromEntity` |
| 信号处理函数 | `on[发送者]_[信号名]` | `onHealthComponent_healthDidZero` |
| 文件名 | 清晰+后缀标识 | `MonsterEntity.gd`, `JumpComponent.tscn` |

### 9.2 缩进与格式

```gdscript
# ✅ 正确：使用 Tab 缩进
func _ready() -> void:
	var health: int = 100  # 静态类型声明
	if health > 0:
		print("alive")

# ❌ 错误：使用空格缩进
```

### 9.3 代码结构顺序

每个脚本文件按以下顺序组织：

```gdscript
## 文件/类的文档注释

class_name MyComponent
extends Component

#region Parameters（@export 参数，外部接口）
@export var speed: float = 200.0
#endregion

#region State（内部状态）
var currentVelocity: Vector2 = Vector2.ZERO
#endregion

#region Signals
signal didJump
#endregion

#region Dependencies（节点引用）
@onready var timer: Timer = $Timer
#endregion

#region Life Cycle
func _enter_tree() -> void: pass
func _ready() -> void: pass
func _exit_tree() -> void: pass
#endregion

#region 其他功能函数
func doSomething() -> void: pass
#endregion

#region Debug
func printDebugInfo() -> void: pass
#endregion
```

### 9.4 组件的最佳实践

```gdscript
# ✅ 用 coComponents 访问兄弟组件（框架推荐方式）
var health: HealthComponent = coComponents.get(&"HealthComponent")

# ✅ 声明依赖关系
func getRequiredComponents() -> Array[Script]:
	return [HealthComponent]

# ✅ 在 _ready() 中连接信号，不要在 _enter_tree()
func _ready() -> void:
	super._ready()
	coComponents.get(&"DamageReceivingComponent").didReceiveDamage.connect(onDamage)

# ✅ 信号处理函数命名规范
func onDamageReceivingComponent_didReceiveDamage(amount: int) -> void:
	pass

# ✅ 子类必须调用 super
func _ready() -> void:
	super._ready()  # 绝对不能省略！

# ❌ 不要把游戏特有逻辑写进框架组件，应创建子类或新组件
```

### 9.5 实体的最佳实践

```gdscript
# ✅ 不要在 Entity 脚本中写游戏逻辑，把逻辑放进 Component
class_name PlayerEntity
extends Entity

# Entity 只做"配置"，不做"行为"
# 游戏逻辑全在子 Component 中

# ✅ 用 findFirstComponentSubclass 查找继承关系
var controller := findFirstComponentSubclass(PhysicsComponent)
```

### 9.6 资源最佳实践

```gdscript
# ✅ 资源只含数据，不含引用使用者的逻辑
class_name MyItemResource
extends GameplayResourceBase

@export var itemName: String = "神剑"
@export var damage: int = 100

# ❌ 不要在资源中引用组件或节点
# var ownerComponent: InventoryComponent  ← 错误！
```

---

## 10. 调试技巧

### 10.1 组件级调试开关

每个组件和许多脚本都有 `debugMode` 属性，在 Inspector 中勾选即可输出详细日志：

```gdscript
# 在 Inspector 勾选 debugMode 后，框架会自动打印该组件的详细运行信息
# 无需修改代码
```

### 10.2 Debug AutoLoad

```gdscript
Debug.printAutoLoadLog("某 AutoLoad 启动")  # AutoLoad 早期生命周期日志（最轻量）
Debug.printLog("普通信息", self)            # 普通日志
Debug.printWarning("警告", self)            # 黄色警告
Debug.printError("错误", self)              # 红色错误
Debug.printHighlight("高亮信息", self)      # 彩色高亮
Debug.printTrace("追踪调用栈", self)        # 带调用栈
```

**方法选型表：**

| 方法 | 适用场景 |
| --- | --- |
| `Debug.printAutoLoadLog()` | AutoLoad 生命周期与启动顺序消息（`NOTIFICATION_PARENTED`、早期 `_ready()`） |
| `Debug.printDebug()` | 受 `shouldPrintDebugLogs` 控制的调试用低优先级消息 |
| `Debug.printLog()` | Debug 状态可用后的常规富日志输出 |
| `Debug.printTrace()` | 调试构建中的栈感知定位 |
| `Debug.printWarning()` / `Debug.printError()` | 不应被调试日志设置隐藏的用户可见警告/错误 |

AutoLoad 日志规范：

- 不要给 AutoLoad 加直接 `print()`；统一走 `Debug.printAutoLoadLog()` 保持输出一致。
- 标准 AutoLoad 日志颜色为 `Global.Colors.logAutoload`。
- 新增框架检查项优先加到 `Debug.performFrameworkChecks()`，保持集中可预测。

### 10.3 实时变量图表

使用 `DebugComponent` 或 `ChartWindow` 实时监控任意变量（如速度、生命值随时间的变化）：

1. 在实体下添加 `Components/DebugComponent.tscn`
2. 配置要监控的属性路径，如 `../CharacterBodyComponent:body:velocity:x`

### 10.4 命令行语法检查

```powershell
# Windows PowerShell（headless 静态检查；以本仓库为例）
godot --headless --check-only --path "E:\_Proj\GDProj\Comedot_GDGameProjZero" --script res://Components/MyComponent.gd --log-file "C:\Users\E_Ye\AppData\Local\Temp\godot-check.log"
```

> 提示：headless 模式下如遇 `user://logs` 写入失败导致启动崩溃，显式传入可写的 `--log-file` 路径（见 `AGENTS.md`）。

### 10.5 Runtime 自动化回归

Godot MCP CLI 提供了运行中输入模拟与调试输出读取能力，详见 `godot-mcp-automation.md`。当前仓库的回归标记链路见 `Game/AGENTS.override.md`。

---

## 11. 常见问题与反模式

### ❌ 反模式：用"添加子节点"而非"实例化子场景"添加组件

```
❌ 错误：Ctrl+A → 添加子节点 → 选择组件脚本
✅ 正确：Shift+Ctrl+A → 实例化子场景 → 选择组件 .tscn 文件
```

原因：直接添加节点不会包含组件的内部子节点（Timer、碰撞体等），导致运行时崩溃。

### ❌ 反模式：在 Entity 脚本中写游戏逻辑

```gdscript
# ❌ 错误
class_name PlayerEntity
extends Entity

func _process(delta: float) -> void:
	if Input.is_action_pressed("jump"):  # 游戏逻辑不应在实体里
		velocity.y = -300

# ✅ 正确：创建 JumpComponent，把跳跃逻辑放在里面
```

### ❌ 反模式：继承组件而不保留 super 调用

```gdscript
# ❌ 危险：忘记调用 super
class_name MyJumpComponent
extends JumpComponent

func _ready() -> void:
	# 忘记 super._ready()，父类初始化逻辑不会执行！
	pass

# ✅ 正确
func _ready() -> void:
	super._ready()
	# 你的逻辑...
```

### ❌ 反模式：直接引用其他场景的节点路径

```gdscript
# ❌ 脆弱：路径硬编码，场景结构一变就崩溃
var player = get_node("/root/GameScene/PlayerEntity")

# ✅ 健壮：通过组和信号通信
var players = get_tree().get_nodes_in_group(Global.Groups.players)
```

### ❌ 反模式：用 -1 表示"无效值"

```gdscript
# ❌ 坏习惯：后续计算全部复杂化
@export var maxLevel: int = -1  # -1 表示无限

# ✅ 正确：用独立布尔标志
@export var allowInfiniteLevels: bool = true
@export var maxLevel: int = 10
```

### ⚠️ 常见崩溃原因

| 原因 | 解决方案 |
|------|----------|
| 缺少依赖组件 | 检查 `getRequiredComponents()` 中声明的依赖是否都已添加 |
| 组件顺序错误 | `CharacterBodyComponent` 必须在物理组件之后；`InputComponent` 必须在最后 |
| 首次加载项目时报错 | 关闭并重新打开项目，让 Godot 重新导入所有资源 |
| 子类化组件后行为异常 | 检查是否在所有覆写方法中调用了 `super` |
| 组件参数配置有误 | 在 Inspector 中仔细检查所有 @export 字段的值 |
| `Debug` 报"缺少 Start 脚本"警告 | 本 fork 已知漂移（无 `Scripts/Start.gd`），非故障；不影响运行 |

---

## 附录 A：学习路线 Checklist

- [ ] 从 `project.godot` 运行项目，确认启动场景流程（Logo → GameFrame → Example）
- [ ] 阅读 `AutoLoad/` 各单例，总结启动职责（对照 §3.3）
- [ ] 追踪 AutoLoad 交互：`Debug`、`Settings`、`SceneManager`、`TurnBasedCoordinator`
- [ ] 确认 `Settings` 在 `NOTIFICATION_PARENTED` 加载偏好，并理解为何早于 `_enter_tree()`
- [ ] 阅读 `Debug.printAutoLoadLog()`，分清哪些启动消息该用它而不是普通调试日志
- [ ] 从 `Components/` 挑一个组件，梳理其数据流
- [ ] 从 `Entities/` 挑一个实体，梳理其挂载的组件组合
- [ ] 完成一次实际改动并在笔记中记录验证步骤

## 附录 B：上游 Start 协议对照（本 fork 不适用）

> 压缩自 `_Doc/Note/30-Flow/StartReading-StartGd.md` 与 `_Doc/Note/00-Concepts/AutoloadAndStartFlow.md`。本 fork 无 `Scripts/Start.gd`；以下为**上游协议**要点，供对照与新项目骨架参考。

- **职责**：从启动场景根节点引导框架状态；向 AutoLoad 应用导出标志；按需配置回合制运行时。
- **生命周期**：`_enter_tree()` → `setupGameState()`（更新 `Settings.mainGameScenePath`、合并 `GameState.globalData`、实例化 `gameStateNodes`）；`_ready()` → `startComedot()`（打 `Global.hasStartScript` 标记、框架检查）→ `applyGlobalFlags()`（Debug/UI、音乐、回合制协调器）。
- **关键导出**：`mainGameScenePath`、`initialGlobalData`、`gameStateNodes`、`musicFolder`/`musicFileToPlayOnStart`/`shouldPlayRandomMusicIndex`、`isTurnBasedGame` 与回合延时、Debug 标志。
- **Gotchas**：`Settings` 不等待 `_ready()` 就加载配置；早期 AutoLoad 日志用 `printAutoLoadLog()`；`isTurnBasedGame=false` 时 `TurnBasedCoordinator` 被移除（之后访问会崩，属设计）；回合延时最小守卫 `minimumTurnDelay = 0.05`。

## 附录 C：推荐学习清单

### 入门必读（按顺序）

1. `README.md` — 框架概览
2. `HowTo.md` — 常见任务操作指南
3. `Templates/Scenes/PlatformerSceneTemplate.tscn` — 运行并研究
4. `Components/Component.gd` — 组件基类
5. `Entities/Entity.gd` — 实体基类

### 进阶（按需阅读）

6. `Conventions.md` — 编码约定（风格/命名/设计哲学）
7. `docs/best-practices.md` — 框架实践指南
8. `docs/architecture-asbuilt.md` — as-built 架构逆向（模块依赖与风险）
9. `AutoLoad/SceneManager.gd` — 场景管理
10. `AutoLoad/GameState.gd` — 全局状态管理
11. `Resources/Stats/` — 属性统计系统
12. `docs/luban-config-tables.md` — Luban 配置表（C#/GDScript 桥）

### 特定功能

- 战斗系统 → `Components/Combat/` + `Tests/` 对应测试场景
- 回合制 → `Components/TurnBased/` + `Entities/TurnBased/` + `Tests/TurnBased/`
- UI → `UI/` + `Templates/HUDTemplate.tscn`
- 瓦片地图 → `Components/Movement/` 中的 TileBased 系列
- 自动化测试 → `docs/godot-mcp-automation.md`

---

> 📬 更多问题，可在 [Discord](https://discord.gg/jZG3cBFt7u) 找 @Syntaks.io，或参考 `AGENTS.md` 了解 AI 助手的使用指引。
>
> 框架仓库：https://github.com/invadingoctopus/comedot
