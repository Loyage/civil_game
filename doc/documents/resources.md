# 资源模块

资源模块负责在地图生成最后阶段生成可扩展的动物和矿产资源。

## 目标

- 大地图只记录某个地块包含哪些资源类型。
- 小地图进入或预览时，根据大地图资源类型生成具体地格位置。
- 首版资源静止存在，不实现移动、采集、刷新或经济效果。
- 资源定义与生成逻辑分离，后续新增动物或矿物时优先改 JSON 定义。

## 资源定义

资源定义文件：

```text
game/data/resources/animals.json
game/data/resources/minerals.json
```

加载入口：

```text
game/scripts/resources/resource_definition_catalog.gd
```

当前 schema：

| 字段 | 含义 |
| --- | --- |
| `id` | 稳定资源 id，例如 `cow`、`iron`。 |
| `name` | 中文显示名。 |
| `category` | `animal` 或 `mineral`。 |
| `allowed_biomes` | 大地图允许生成的主体 biome。 |
| `allowed_terrain_flags` | 小地图允许落点的地貌 bitmask 名称。 |
| `spawn_chance` | 大地图候选地块生成概率。 |
| `min_count/max_count` | 动物在小地图中的个体数范围。 |
| `min_cells/max_cells` | 矿产在小地图中的矿点范围。 |
| `color` | 预览显示颜色。 |

首批动物：

- 牛 `cow`
- 马 `horse`
- 老虎 `tiger`

首批矿产：

- 金矿 `gold`
- 铁矿 `iron`
- 铜矿 `copper`

## 大地图生成

源码：

```text
game/scripts/resources/world_resource_generator.gd
```

地图生成管线新增 `resources` 阶段，位于 `environment` 和 `final` 之间。

大地图生成逻辑：

1. 只在 `resources` 和 `final` 阶段写入资源。
2. 对每个地块读取资源定义。
3. 先按 `allowed_biomes` 判断大地图候选地块。
4. 对候选资源使用 `seed + tile_key + resource_id` hash 计算生成概率。
5. 当前使用稀疏生成策略，每个地块最多记录一种资源类型。
6. 结果写入 `TileState.resource_ids`。

## 小地图生成

源码：

```text
game/scripts/resources/local_resource_generator.gd
```

小地图资源生成发生在高度、水体、河流、地貌标签之后。

动物生成规则：

- 动物拥有 `instance_id`，方便未来保存、移动或行为系统引用。
- 每种动物在小地图中生成 `1..3` 个个体。
- 动物必须落在资源定义允许的 `terrain_flags` 地格上；找不到合格地格则不生成。
- 同类型动物不能占用同一个地格。

矿产生成规则：

- 矿产当前不需要唯一实例 id。
- 每种矿产生成 `2..5` 个相邻或近邻地格，表现为小矿脉。
- 优先落在资源定义允许的 `terrain_flags` 地格上；找不到时退化到任意非水陆地。
- 同类型矿产不能占用同一个地格，不同类型资源允许重叠。

小地图结果写入：

```text
LocalMapState.resource_instances
```

当前资源实例不写入小地图缓存。缓存命中后会用同一 seed 和同一地块资源列表重新派生资源位置，因此保持确定性。

## 预览显示

`MapGeneratorPreview` 新增 `资源` view：

- 大地图资源视图：有资源的地块显示资源定义颜色；无资源地块显示压暗地形。
- 小地图资源视图：资源地格显示资源定义颜色；无资源地格显示压暗地貌。
- 地块/地格信息面板显示资源中文名。

## 扩展方式

新增资源优先修改 JSON：

1. 在 `animals.json` 或 `minerals.json` 增加定义。
2. 配置 `allowed_biomes` 控制大地图候选区域。
3. 配置 `allowed_terrain_flags` 控制小地图落点。
4. 如需新 category，再扩展 `LocalResourceGenerator` 的放置策略。
