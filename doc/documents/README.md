# Civilization Runtime Design

本目录是项目运行时模块设计文档的 mdBook 入口，用于记录已经开始实现的模块设计说明。它和 `doc/tasks` 的职责不同：

- `doc/tasks`：开发过程 TODO、里程碑、进度追踪。
- `doc/documents`：已经落地到代码中的设计思路、模块边界、数据流和后续扩展依据。

## mdBook

本目录保留普通 Markdown 文件结构，同时通过 `book.toml` 和 `SUMMARY.md` 组织为 mdBook。

构建命令：

```sh
mdbook build doc/documents
```

构建输出目录：

```text
target/documents-book
```

## 当前文档

- [地图模块](./map.md)：地图生成、地块数据、地图渲染、地图交互与寻路查询设计。
- [地图生成器](./map_generator.md)：地图生成器抽离、生成配置、调试输出和开发期预览工具设计。
- [局部地图](./local_map.md)：世界地块展开为 `256 x 256` 局部地图的生成、缓存、渲染和交互设计。
- [UI 模块](./ui.md)：基础 HUD、地块信息面板，以及 `map`/`ui` 同级调度设计。

## 编写约定

只有当某个模块开始编写逻辑代码后，才在本目录新增对应设计文档。尚未实现的模块不提前写设计说明，避免文档对实现方向形成错误约束。

文档使用普通 Markdown 编写，并尽量保持 mdBook / Markdoc 友好：标题层级清晰、表格和列表保持简单、避免依赖特定渲染器的语法。
