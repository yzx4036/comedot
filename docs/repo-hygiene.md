# 仓库卫生：敏感数据审计与清理记录

> 适用对象：**公开**框架仓（`github.com/yzx4036/comedot`）。
> 私有项目仓（含真实业务代号、商业计划、美术采购清单）不在本文管辖范围。

## 1. 审计结论（2026-11-19）

| 检查项 | 手段 | 结果 |
|---|---|---|
| 密钥 / 凭据 / token | 对全部被跟踪文件正则扫描（`sk-`、`ghp_`、`AKIA`、PRIVATE KEY、api_key/token/password 赋值） | **0 命中** |
| 敏感文件名（.env / secret / *.pem / *.key / credential） | 被跟踪清单 + 历史删除记录 | **0 命中**，历史里也从未出现 |
| `.mcp.json` / 编辑器配置 | 人工核对 | 仅 `godot-mcp` stdio 启动配置，无凭据 |
| 业务内容是否曾进框架仓 | `git log -- Game/MyGame*`、`*CommercialPlan*` | **从未进入历史** |
| 提交者邮箱 | `git log --format=%ae` | 上游协作者邮箱 + 本仓维护者公开邮箱，无泄漏 |
| 内部项目代号 / 本机绝对路径 | 关键字扫描 | **有残留**（见 §2），已清理 |

结论：真正的凭据类数据从未进入本仓；需要处理的是「内部业务代号 + 本机路径」这类低危但不应公开的信息。

## 2. 已清理（提交 `62caa282`）

14 个文件里的以下内容已替换为占位符：

| 原内容（类别） | 替换为 |
|---|---|
| 内部业务仓名（框架仓 / 业务仓） | `Comedot_<Prefix><Proj>` / `Comedot_<Prefix><Proj>Game` |
| 内部示例仓名 | `comedot fork` |
| 本机盘符绝对路径 | `D:\path\to\project` |
| 带用户名的临时目录 | `%TEMP%` |
| 真实业务目录名（示例位置） | `MyGame` |

自查命令（发现残留就清）：

```bash
git ls-files -z | xargs -0 grep -nE 'sk-[A-Za-z0-9]{16,}|ghp_|AKIA|PRIVATE KEY'
git ls-files -z | xargs -0 grep -nE '/Users/[a-z]|[A-Za-z]:\\Users\\|[A-Za-z]:\\_Proj'
```

## 3. 历史清洗（已完成，2026-11-19）

内部代号曾留在 3 个历史提交里（仅文档文本，无凭据）。已用 **`git filter-branch --tree-filter` 只重写本仓 16 个提交**（`5c4e8388..develop`）清除：

```bash
FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch -f \
  --tree-filter 'python3 <scrub 脚本>' -- 5c4e8388..<branch>
```

结果与代价：

| 项 | 状态 |
|---|---|
| 历史里的内部代号 / 本机路径 | **0 命中**（`git log -S` 已验证） |
| 起始父提交 `5c4e8388` | **未变**，与上游 `InvadingOctopus/comedot` 的血缘保留 |
| `up_stream` 分支 | 未改写（仍是原始上游引用） |
| 被连带重写的 13 个提交 | 内容与原提交**逐字节相同**，仅哈希变化 |
| 其他机器上的 clone | 需 `git fetch && git reset --hard origin/develop` |
| 下次合并 `up_stream` | 会看到「同内容不同哈希」的提交，多数文件干净合并；`docs/` 里被脱敏的 3 处可能需取本地版本 |
| 回滚 | 本地保留 `backup/pre-scrub-20261119`（未推送） |

> 走这条路线而没有整仓 `filter-repo`，就是因为整仓重写会连上游提交一起换哈希，等于断掉与 `InvadingOctopus/comedot` 的血缘，之后无法再 merge 上游。

## 4. 以后怎么防

1. 真实业务名、本机路径、商业计划只写进**私有项目仓**；公开仓一律用占位符（`<Proj>`、`MyGame`、`<owner>`）。
2. `_ToolScript/` 与 `docs/` 的示例统一用 `MyGame` / `<Prefix><Proj>`。
3. 提交前跑一次 §2 的自查命令，或直接跑 `_ToolScript/verify_project.sh`（会顺带暴露未跟踪的业务外键）。
4. 本仓自带的最小示例业务 `Game/MyGame/` 只放占位场景 + 契约文件 + README，**不放任何真实素材与商业文档**。
