# MyGame 业务配置表

业务自己的 Luban 表，与框架 `_ConfigTables/` 同构但互不干扰。

## 一条命令

```bash
_ConfigTables/gen_all_configs.sh --build    # 在项目根执行：框架表 + 业务表 → 合并 → 编译
```

## 目录

```
Game/MyGame/_ConfigTables/
├── Excel/
│   ├── luban.conf              业务 target 配置（topModule 必须是 Y0Studio.Config）
│   └── Datas/
│       ├── __tables__.xlsx     表清单（MyGame.TbLevel / MyGame.TbGameSetting）
│       ├── __beans__.xlsx      自定义结构（本示例为空）
│       ├── __enums__.xlsx      业务枚举（MyGame.EDifficulty）
│       └── GameTables.xlsx     数据（Levels / Settings 两个 sheet）
├── Configs/
│   ├── Bin/                    生成出的 .bytes（临时，由 gen_all_configs.sh 拷进运行目录）
│   └── Json/                   可直接看的 JSON
└── gen_code_business.sh        只生成业务表
```

## 当前两张表

| 表 | 模式 | 内容 |
|---|---|---|
| `TbLevel` | map | 4 个关卡：id / 名称 / 难度 / 敌人数 / 时限 / boss 标记 |
| `TbGameSetting` | one | 开局金币 / 最高关卡数 / 是否自动存档 |

运行时读取：

```gdscript
var tb: Tb = Tb.new(lubanConfigService)
var level: Dictionary = tb.row(&"mygame_tblevel", 1)
print(level["Name"])          # 新手村   ← 键是 PascalCase
print(tb.oneVal(&"mygame_tbgamesetting", &"StartingGold"))   # 100
```

## 改表的注意事项

细节见 `Game/MyGame/Tests/Regression/README.md` 的「配置表链路」一节，最要紧三条：

1. **改 Excel 就复制框架的 `_ConfigTables/Excel/Datas/*.xlsx` 再改内容**，不要从零建 sheet —— 合并单元格结构（`*items` 是 `H1:L1`）丢了以后 Luban 会报「缺 alias 列」
2. **业务 C# 落在 `Scripts/Mono/Luban/Configs/GameAutoGen/`**，不能放 `Game/` 下（`<Compile Remove="Game/**" />` 会把它排除）
3. **`.bytes` 不要直接输出到 `Assets/Configs/GameConfigs`** —— Luban 生成前清空目录，会把框架表删掉

验收：`Game/MyGame/Tests/Regression/runAll.sh`（含 `CheckBusinessConfigTables`）
