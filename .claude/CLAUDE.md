# Comedot Framework

Godot 4.7 2D 组件化游戏框架。开源，托管于 github.com:yzx4036/comedot。

## 关键文档
- `AGENTS.md` — 完整 AI 协作指南（项目结构、命名规范、工作流）
- `Conventions.md` — GDScript 编码规范（绝对权威，冲突时以此为准）
- `HowTo.md` — 常用操作指南
- `_Doc/BestPractices.md` — 框架层最佳实践（启动流程、架构模式、反模式）
- `_Doc/FrameworkLayerChanges.md` — 框架层变更影响面与联动更新规则

## 核心架构
- **Entity + Component** 模式（类 ECS）
- `Components/` + `Entities/` — 框架核心
- `Game/` — 独立 Git 仓库，游戏业务代码
- **两个仓库隔离**：框架 git 忽略 `Game/`，不要跨仓库混用 git 命令

## AI 迁移状态
- ✅ **Claude Code** — 当前唯一 AI 工具
  - `.claude/CLAUDE.md` — 框架层规范（本文件）
  - `.claude/settings.json` — 权限/hooks 配置
  - `.ai/mcp/mcp.json` — Godot MCP 连接配置
- ❌ GitHub Copilot — 已弃用，`.github/copilot-instructions.md` 顶部已加弃用声明
- ❌ Junie — 已弃用，`.junie/` 为空目录
- ❌ Codex — 已弃用，无残留
- 📋 `.github/prompt-guide.md` — 通用 Prompt 模板参考（非工具特定，保留可用）

## 工作规则
- 所有编码规范以 `Conventions.md` 为准
- `Game/` 子树工作前先读 `Game/Cd_ProjectZero/Docs/ProjectPrompt.md`
- 不要编辑任何文件除非明确要求
- 忽略 `Temporary/` 和 `Lab/` 目录的所有内容
- Godot MCP 自动化参考 `_Doc/GodotMcpCliAutomationGuide.md`
- 框架层最佳实践参考 `_Doc/BestPractices.md`（启动流程、SceneManager、Turn-Based、反模式）
- 框架层变更联动规则参考 `_Doc/FrameworkLayerChanges.md`（改 X 必须同步更新 Y 的文档清单）
- 项目学习路线参考 `_Doc/Note/LearningRoadmap.md`

## 提交规范
- 中文描述，`[feat]` / `[fix]` 前缀
- 框架提交到根仓库，游戏提交到 `Game/` 仓库
- 用 `提交dev` 触发自动分析提交
- 用 `合并up_stream到dev` 触发上游合并

---

## 框架规则（摘要自 AGENTS.md）

### 目录结构与高价值路径
- `Components/` — 可复用玩法行为单元（.tscn + .gd 成对）
- `Entities/` — 组件容器节点
- `AutoLoad/` — 全局单例（Global、Settings、SceneManager、Debug、GlobalUI、GlobalSonic、TurnBasedCoordinator 等）
- `Scripts/` — 非实体/组件的共享脚本（含 `Start.gd` 启动引导）
- `Resources/` — 数据/资源类（Stat、Action、Upgrade 等）
- `Tests/` — 手动可玩测试场景（`*Test.tscn` + 可选伴生脚本）
- `Temporary/`、`Lab/` — 实验/临时目录，始终忽略
- `Scripts/Tools/Tools.gd` — 全局静态辅助函数集合

### 现有子系统（优先复用，避免重复造轮）
- **战斗/伤害**：`DamageComponent`、`DamageReceivingComponent`、`FactionComponent`、`HealthComponent`、`KnockbackOnHitComponent`
- **属性/数值**：`Stat`、`StatsComponent`、`StatUI`
- **收集品**：`CollectibleComponent`、`CollectorComponent`
- **交互**：`InteractionComponent`、`InteractionControlComponent`
- **特殊动作**：`Action`、`ActionsComponent`、`ActionControlComponent`
- **回合制**：`TurnBasedCoordinator`、`TurnBasedEntity`、`TurnBasedComponent`
- 搜索框架时用功能同义词查找，很可能已有现成组件

### 验证与测试
- 运行时验证：编辑器 F5（运行项目）或 F6（运行当前场景）
- 手动测试场景放在 `Tests/` 目录
- 无头语法检查：`godot --headless --check-only --path <项目路径> --script res://路径/脚本.gd --log-file /tmp/comedot.log`
- 若无头运行时不可用，用静态读码/lint 做保守验证
- Godot MCP 可用时优先使用 MCP 工具进行自动化测试

### Code Review 规则
- 忽略 `Temporary/` 和 `Lab/` 内容
- 标记 `@experimental` 的代码优先级降低，除非稳定代码依赖它
- 忽略 `Game/` 内容（除非任务明确涉及具体游戏）
- `null` 守卫不必到处添加：核心对象缺失时 crash 比静默失败更好

### 组件/实体生成规则
- Component 必须是 `.tscn` + `.gd` 成对，继承 `Component.gd`
- Component `class_name` 必须定义，Entity `class_name` 也必须定义
- 根节点类型匹配职责：纯逻辑 `Node`、可视化 `Node2D`、专用 `Timer`/`Area2D`
- 组件根加入 `components` group，实体根加入 `entities` group + 玩法 group（`players`、`enemies`、`turnBased` 等）
- 游戏层实体/组件用 `GP` 前缀
- 实现玩法前先搜索框架现有组件/实体，优先复用和扩展
- 新玩法行为应优先实现为组件而非实体脚本

### 常见 Godot 陷阱（补充）
- **禁止 shadowing**：局部变量/参数不与继承属性同名
- **Float 比较**：用 `is_equal_approx()` / `is_zero_approx()` 代替 `==` / `!=`
- **类型转换**：避免直接 `as`/`is`，用 `get_node(".") as Type` 或 `is_instance_of()`
- **不要用 `-1` 表示无效数值**，用独立 bool flag

---

## 编码规范（摘要自 Conventions.md，冲突时以 Conventions.md 为准）

### 缩进与空格
- **Tab**，不是空格（GDScript 是缩进敏感语言）
- 不同代码段落之间用 **2 个空行** 分隔（函数、属性、信号、region 之间）

### 命名
- **camelCase** 用于一切：变量、函数、常量、信号、枚举值
- **Capitalized** 仅用于类型名（class_name、enum 名）
- 短首字母缩写可全大写：`UINode`、`HUDColor`
- **禁止 underscore**，唯一例外：信号处理函数 `on[Emitter]_[signal]`

### Boolean 命名
- 以 `is` / `has` / `should` 开头：`isEnabled`、`hasWeapon`、`shouldRespawn`
- 函数参数中的 bool 可用动词：`skipEmptyCells`
- 避免与函数名混淆：`showDebugInfo` → 应用 `isDebugInfoVisible`

### 函数命名
- 用**祈使动词**：`doSomething()`、`checkValidity()`
- `get` 前缀 = 快速获取（成员访问）：`getComponent(…)`
- `find` 前缀 = 慢搜索（遍历子节点等）：`findComponent(…)`
- `add` 前缀 = 添加已有对象到容器：`addText(…)`
- `create` 前缀 = 创建新对象并添加到容器：`createLabel(…)`
- bool 参数在上游没有参数标签时，在调用点加尾注：`doAction(obj, true, false) # logResult, skipCooldown`

### 信号命名
- 形式：`{对象}{时态}{事件}` — `healthDidDecrease`、`willRemoveFromEntity`
- 信号名用 `did` 或 `will` 标明时态
- 无时态变体的可省略：`onCollide`

### 信号处理函数
- 形式：`on[发射者]_[信号名]`
- 如果脚本就在发射者节点上：`on[信号名]`
- 短单词可省略下划线：`onAreaEntered`（不是 `onArea_entered`）
- **这是唯一允许 underscore 的地方**

### 文件命名
- 清晰精确，加后缀：`MonsterEntity.gd`、`MonsterAttackComponent.gd`
- 不必短，可以长：`TurnBasedTileBasedPlatformerControlComponent`
- 独立脚本用动词：`Spin.gd`、`SnapToMouse.gd`
- Game/ 层实体/组件加 `GP` 前缀：`GPBanditEntity.gd`

### 代码顺序（脚本文件内）
1. Header 文档注释
2. `class_name` 和 `extends`
3. `@export` 参数（外部接口优先）
4. State（内部状态属性）
5. Signals
6. Dependencies（@onready var 等）
7. Life Cycle（`_enter_tree` → `_ready` → `_exit_tree`，按 Godot 调用顺序）
8. 其他函数
9. Debugging / 临时实验代码
- 用 `#region` / `#endregion` 包裹（除非段落很短 < 4 行）

### 静态类型
- **优先强类型**：`var number: int = 42`，少用 `:=`
- `:=` 仅在编码时类型不确定时使用

### 常见陷阱
- **禁止 shadowing**：不让局部变量/参数与继承属性同名（如 `body`）
- **Float 比较**：用 `is_equal_approx()` / `is_zero_approx()` 代替 `==` / `!=`
- **类型转换**：避免 `as` / `is` 直接转换（Godot parser 可能报错），改用：
  ```gdscript
  var otherNode := nodeToCast.get_node(^".") as CastedType
  # 或
  if is_instance_of(someNode, CastedType):
  ```
- **不要用 `-1` 表示无效数值**，用单独的 bool flag：`allowInfiniteLevels = true` 而非 `maxLevel = -1`

### 注释标签
- `TODO:` / `FIXME:` — 自解释
- `TBD:` / `CHECK:` — 不确定的临时方案
- `DESIGN:` — 解释"为什么这样做"的决策
- `DEBUG:` — 提交前应注释或删除
- `FIXED` / `SOLVED` / `DONTTOUCH` — 已解决棘手问题，不要改
- `WORKAROUND:` — Godot 引擎 bug 的临时绕过
- `CREDIT:` — 代码/资源来源
- `THANKS:` — 建议/灵感的来源

### 组件设计原则
- Components 必须是 `.tscn` + `.gd` 成对，继承 `Component.gd`
- 根节点类型应与组件职责匹配：纯逻辑用 `Node`、可视化用 `Node2D`、专用用专用节点（`Timer`、`Area2D`）
- 组件根加入 `components` group，实体根加入 `entities` group
- **General over Specific**：设计可复用的通用组件，如 `ModifyOnCollisionComponent` 而非 `RemovalOnCollisionComponent`
- 优先用现有属性/参数解决问题，再新增变量
- Component `class_name` 必须定义，Entity `class_name` 也必须定义

### Resources
- Resources 应**只包含数据和校验**，不持有使用者的引用
- "唯一" Resource 的传递应通过 "request" 流程 + 信号

### 其他
- 不追求过度简化组件，每个组件专注一个明确任务
- 性能优化前先保证正确性
- 代码注释不使用 BBCode

---

## 常用操作（摘要自 HowTo.md）

### 创建 Entity
1. 选合适的 Godot 节点（`CharacterBody2D`、`Node2D` 等）
2. 附加 `Entities/` 下对应脚本（如 `PlayerEntity.gd`）
3. 添加子节点：`Sprite2D`、`CollisionShape2D`、`Camera2D` / `CameraComponent`
4. 设置物理碰撞层和遮罩
5. 根节点加入 `entities` group + 其他预设 group（`players`、`enemies` 等）

### 添加 Component 到 Entity
- 用 **"Instantiate Child Scene"**（Shift+Ctrl+A），不是 "Add Child Node"
- 或从 FileSystem 拖 `.tscn` 文件到 Entity 节点
- ❌ 不要拖 `.gd` 脚本到 Entity 上

### 玩家控制
- 平台跳跃：`JumpComponent` + `PlatformerPhysicsComponent`
- 俯视移动：`OverheadPhysicsComponent`
- 格子移动：`TileBasedControlComponent` + `TileBasedPositionComponent`
- 都需要 `CharacterBodyComponent`（在以上组件之后）
- 都需要 `InputComponent`（放在最后，因为输入事件向上传播）

### 战斗系统
- `FactionComponent`（设置 faction）+ `HealthComponent` + `DamageReceivingComponent`
- 怪物加 `DamageComponent` 接触伤害
- 可选：`HealthVisualComponent`、`InvulnerabilityOnHitComponent`
- 注意设置正确的碰撞层/遮罩

### 创建新 Component
1. 在 `Components/` 分类子目录中创建 Scene
2. 根节点类型：纯逻辑 `Node`、可视化 `Node2D`、专用用专用节点（`Timer`）
3. 根节点加入 `components` group
4. 附加脚本 → Inherits 填 `Component` → 选模板
5. `class_name` 必须定义

### 自定义扩展（易 → 强）
1. 启用场景实例的 "Editable Children" 改内部子节点
2. 创建继承现有组件 scene 的新 scene
3. 创建子类 `extends DamageComponent`，覆盖方法 + `super`
4. 直接修改原始 scene/script（影响所有实例）
5. 创建全新组件

### Turn-Based 回合制
1. 确保 `TurnBasedCoordinator` Autoload 启用
2. 用 `TurnBasedEntity` 和 `TurnBasedComponent`
3. 连接 UI/输入到 `TurnBasedCoordinator.startTurnProcess()`
4. 每回合：`processTurnBegin()` → `processTurnUpdate()` → `processTurnEnd()`

### 常见问题排查
- 首开项目报错 → 关闭重开（Godot 重新 import 资源）
- 子类组件不工作 → 检查是否需要 `super._ready()` 或 `super.overriddenMethod()`
- 碰撞不触发 → 检查碰撞层/遮罩设置
- Component 顺序 → 输入组件应在最后
- 辅助工具 → `Scripts/Tools/Tools.gd`、`Debug.gd` AutoLoad、`DebugComponent`、`ChartWindow`
- debugMode 属性 → 很多组件自带，开启可输出调试日志/可视化
