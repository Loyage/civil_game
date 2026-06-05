# Civilization

一个使用 Godot 4 开发的回合制文明建设原型项目。

项目当前重点是建立可扩展的策略游戏运行时基础，包括大地图生成、局部小地图、基础 UI、地图生成器预览工具，以及后续城市、科技、存档等模块的迭代空间。

## 当前状态

- 引擎：Godot 4
- 语言：GDScript
- 开发环境：Nix dev shell
- 主游戏入口：`game/scenes/main/Main.tscn`
- 地图生成器预览入口：`game/scenes/dev/MapGeneratorPreview.tscn`
- 设计文档：`doc/documents`
- 任务文档：`doc/tasks`

## 开发环境

### Nix 环境

进入开发环境：

```bash
nix develop
```

开发环境会提供常用工具：

- `godot4`
- `mdbook`
- `rg`
- `jq`
- `just`

也可以不进入交互 shell，直接用 `nix develop -c ...` 执行命令。

### 非 Nix 环境

如果不使用 Nix，需要手动安装以下工具：

- Godot 4.6 或兼容的 Godot 4.x 版本
- Git
- mdBook

Windows 常见安装方式：

```powershell
winget install Git.Git
winget install GodotEngine.GodotEngine
winget install Rustlang.Rustup
cargo install mdbook
```

macOS 常见安装方式：

```bash
brew install git
brew install --cask godot
brew install mdbook
```

如果不使用 Homebrew，也可以直接下载 Godot：

```text
https://godotengine.org/download/
```

安装后确认命令可用：

```bash
git --version
godot --version
mdbook --version
```

不同平台的 Godot 命令名可能不同，常见是 `godot`、`godot4`，或者需要直接运行 Godot 可执行文件。下文命令中的 `godot4` 可以替换为你本机实际的 Godot 命令。

## 打开游戏

用 Godot 编辑器打开项目：

```bash
nix develop -c godot4 --editor project.godot
```

非 Nix 环境：

```bash
godot4 --editor project.godot
```

直接运行主游戏：

```bash
nix develop -c godot4 --path .
```

非 Nix 环境：

```bash
godot4 --path .
```

主场景配置在 `project.godot`：

```text
res://game/scenes/main/Main.tscn
```

## 打开地图生成器预览器

地图生成器预览器用于输入 seed 和参数，直观看到大地图生成结果，并查看选中地块的小地图。

直接运行预览场景：

```bash
nix develop -c godot4 --path . --scene res://game/scenes/dev/MapGeneratorPreview.tscn
```

非 Nix 环境：

```bash
godot4 --path . --scene res://game/scenes/dev/MapGeneratorPreview.tscn
```

也可以在 Godot 编辑器里打开：

```text
game/scenes/dev/MapGeneratorPreview.tscn
```

## 运行 mdBook

设计文档位于：

```text
doc/documents
```

启动本地文档服务：

```bash
cd doc/documents
mdbook serve
```

构建静态文档：

```bash
cd doc/documents
mdbook build
```

构建输出目录由 `doc/documents/book.toml` 配置，当前为：

```text
target/documents-book
```

## 目录说明

```text
game/
  scenes/       Godot 场景
  scripts/      GDScript 运行时代码
  data/         游戏配置和数据

doc/
  documents/    mdBook 设计文档
  tasks/        任务拆分和开发进度
```

## 协作规则

仓库协作规则见：

```text
AGENTS.md
```

关键要求：

- 需求不清楚时先提问，不擅自决定。
- 问题优先提供 `A / B / C` 选项。
- 代码变更需要同步 `doc/tasks` 和 `doc/documents`。
- 默认不运行程序验证，除非用户明确要求。
