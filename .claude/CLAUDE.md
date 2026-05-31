# Comedot Framework

Godot 4.7 2D 组件化游戏框架。开源，托管于 github.com:yzx4036/comedot。

## 关键文档
- `AGENTS.md` — 完整 AI 协作指南（项目结构、命名规范、工作流）
- `Conventions.md` — GDScript 编码规范（绝对权威，冲突时以此为准）
- `HowTo.md` — 常用操作指南

## 核心架构
- **Entity + Component** 模式（类 ECS）
- `Components/` + `Entities/` — 框架核心
- `Game/` — 独立 Git 仓库，游戏业务代码
- **两个仓库隔离**：框架 git 忽略 `Game/`，不要跨仓库混用 git 命令

## AI 迁移状态
- ✅ **当前主要 AI 工具：Claude Code**
- ❌ GitHub Copilot — 已弃用（`.github/copilot-instructions.md` 保留仅供历史参考）
- ❌ Junie — 已弃用（`.junie/` 保留仅供历史参考）
- ❌ Codex — 已弃用

## 工作规则
- 所有编码规范以 `Conventions.md` 为准
- `Game/` 子树工作前先读 `Game/Cd_ProjectZero/Docs/ProjectPrompt.md`
- 不要编辑任何文件除非明确要求
- 忽略 `Temporary/` 和 `Lab/` 目录的所有内容
- Godot MCP 自动化参考 `_Doc/GodotMcpCliAutomationGuide.md`

## 提交规范
- 中文描述，`[feat]` / `[fix]` 前缀
- 框架提交到根仓库，游戏提交到 `Game/` 仓库
- 用 `提交dev` 触发自动分析提交
- 用 `合并up_stream到dev` 触发上游合并
