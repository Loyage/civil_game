# resources 模块任务

## 目标

资源模块负责在地图生成最后阶段生成动物和矿产资源，并为后续移动、采集、经济系统预留扩展点。

## 职责边界

- 大地图记录资源类型列表，不记录具体小地图位置。
- 小地图根据大地图资源类型生成具体地格资源实例。
- 首版资源静止，不实现移动、战斗、采集、刷新。
- 资源定义使用 JSON，生成逻辑使用 GDScript。

## 核心数据结构

- `TileState.resource_ids: PackedStringArray`
- `LocalMapState.resource_instances: Array`
- `animals.json`
- `minerals.json`

## 主要流程

1. `MapGenerationPipelineResult` 增加 `resources` 阶段。
2. `BigMapSummaryGenerator` 在 `resources/final` 阶段调用 `WorldResourceGenerator`。
3. `WorldResourceGenerator` 按 seed、tile_key、resource_id hash 选择稀疏资源。
4. `LocalMapGenerator` 在地貌标签之后调用 `LocalResourceGenerator`。
5. `LocalResourceGenerator` 按资源定义和地格地貌生成资源实例。
6. 预览工具和信息面板显示资源。

## 场景/脚本拆分

- `game/scripts/resources/resource_definition_catalog.gd`
- `game/scripts/resources/world_resource_generator.gd`
- `game/scripts/resources/local_resource_generator.gd`
- `game/data/resources/animals.json`
- `game/data/resources/minerals.json`

## 输入输出

- 输入：世界 seed、地块 biome、terrain_tags、小地图 terrain_flags。
- 输出：大地图 `resource_ids`、小地图 `resource_instances`。

## 依赖关系

- 依赖 `map_generator` 阶段管线。
- 依赖 `local_map` 的 `terrain_flags`。
- 依赖 UI 和预览工具展示结果。

## 风险

- 稀疏度参数过低可能导致测试时资源不明显。
- 动物必须匹配地貌，部分资源地块可能因小地图内部无合格地格而没有动物实例。
- 当前未实现资源缓存保存，未来加入可采集/可移动资源时必须补存档和缓存策略。

## Checklist

- [x] 设计资源定义 JSON schema
- [x] 新增首批动物资源
- [x] 新增首批矿产资源
- [x] 新增大地图资源生成器
- [x] 新增小地图资源生成器
- [x] 新增 `resources` 地图生成阶段
- [x] 大地图写入 `TileState.resource_ids`
- [x] 小地图写入 `LocalMapState.resource_instances`
- [x] 地图生成器预览支持资源视图
- [x] 信息面板显示资源中文名
- [ ] 设计资源保存/存档协议
- [ ] 设计动物移动或行为系统
- [ ] 设计资源采集和产出系统
