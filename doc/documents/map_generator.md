# Map Generator Module Design

`map_generator` 模块负责世界地图生成算法。当前实现已经从旧的“按大地图地块直接随机派生地貌”改为“世界骨架 + 连续函数采样 + 大地图摘要”的结构，为后续 RimWorld 式局部地图懒加载提供连续的全局坐标基础。

## 当前实现范围

- `MapGenerationConfig` 承载地图生成配置。
- `MapGenerator.generate(config)` 根据配置生成 `MapState`，内部委托 `world_generation` 模块完成骨架生成和大地图摘要。
- `WorldSkeletonGenerator` 生成全局山脉折线和河流下坡路径。
- `WorldFunctionSampler` 基于全局坐标 `worldX/worldY` 采样高度、温度、湿度、河流强度和 biome。
- `BigMapSummaryGenerator` 对每个大地图地块按 `summary_sample_resolution` 采样内部地格，生成平均高度、最低/最高高度和主体 biome。
- `SubMapGenerator` 先保留接口，不接入现有 `LocalMapGenerator`。
- `MapGenerationDebugWriter` 负责把生成结果写入调试 JSON。
- `MapLoader` 保留原有 `load_generated_map()` 入口，但内部只负责读取 JSON、构建配置、调用生成器和触发调试输出。
- 新增独立开发场景 `MapGeneratorPreview.tscn`，用于输入 seed 和参数后预览生成结果。

## 文件结构

| 文件 | 职责 |
| --- | --- |
| `game/scripts/map_generation/map_generation_config.gd` | 地图生成配置对象，保存 seed、尺寸、阈值、生成参数和起始城市。 |
| `game/scripts/map_generation/map_generator.gd` | 世界地图生成入口，调用 `WorldSkeletonGenerator` 和 `BigMapSummaryGenerator`。 |
| `game/scripts/map_generation/map_generation_debug_writer.gd` | 调试输出写入器，负责写出 `user://generated_map.json`。 |
| `game/scripts/world_generation/world_skeleton.gd` | 世界骨架数据，保存全局山脉、河流和按大地图地块建立的索引。 |
| `game/scripts/world_generation/world_skeleton_generator.gd` | 根据 seed 和配置生成世界骨架。 |
| `game/scripts/world_generation/world_function_sampler.gd` | 基于全局坐标采样连续世界函数。 |
| `game/scripts/world_generation/big_map_summary_generator.gd` | 把连续世界函数汇总为大地图 `MapState`。 |
| `game/scripts/world_generation/sub_map_generator.gd` | 小地图生成接口占位，后续接入懒加载小地图。 |
| `game/scenes/dev/MapGeneratorPreview.tscn` | 开发期地图生成器预览场景。 |
| `game/scripts/dev/map_generator_preview.gd` | 预览场景脚本，调用正式 `MapGenerator.generate(config)` 并渲染预览图。 |

## 数据流

正式游戏流程：

```text
MapRoot
  -> MapLoader.load_generated_map()
      -> MapGenerationConfig.load_from_dictionary(raw_config)
      -> MapGenerator.generate(config)
          -> WorldSkeletonGenerator.generate(config)
          -> BigMapSummaryGenerator.generate(config, skeleton)
              -> WorldFunctionSampler.sample*(worldX, worldY)
      -> MapGenerationDebugWriter.write_generated_map(config, map_state)
```

开发预览流程：

```text
MapGeneratorPreview
  -> MapGenerationConfig
  -> MapGenerator.generate(config)
  -> ImageTexture preview
```

预览工具不复制生成逻辑，不进入正式游戏流程，也不影响 `MapRoot`。

## 预览工具

预览工具位于：

```text
game/scenes/dev/MapGeneratorPreview.tscn
```

首版支持：

- 输入 seed。
- 输入 width / height。
- 调整 `sub_map_size`，用于控制进入单个大地图地块后的局部地图边长。
- 调整 `ocean_ratio`，用于控制海洋生成目标比例。
- 调整 `mountain_count`。
- 调整 `river_source_count`。
- 调整 `continent_bias`。
- 打开场景时不自动生成地图，右侧预览区保持空白并提示调整参数后生成。
- 点击“生成地图”后才生成完整世界地图。
- 点击“随机 Seed”只更新 seed 输入框，不立即生成地图。
- 通过 `Stage` 下拉框切换基础地形、山脉、海洋、河流、环境和最终地貌阶段。
- 切换视图：
  - 基础地貌
  - 海拔
  - 湿度
  - 温度
  - 河流
  - 特征
  - 走向
- 显示摘要：
  - 海洋比例
  - 山脉比例
  - 森林比例
  - 河流地块数量
  - 平均海拔
- 预览视口交互：
  - 右键拖动。
  - 按住 Ctrl 后滚轮缩放。
  - 左键选择地块。
  - 黄色选中标记。
  - 左侧面板显示选中地块信息。
- 大地图走向预览：
  - 默认在大地图预览上叠加山脉脊线和河流走向。
  - “显示走向”开关可以关闭普通视图中的走向叠加。
  - “走向”视图会强制显示走向叠加，用较暗底图突出线条。
  - 河流使用蓝色线条和箭头表示路径与流向。
  - “河流”和“走向”视图会强制显示河流走向 overlay，避免只看到有河流的色块。
  - 单个河流地块优先使用 `river_flow` 绘制格内方向箭头；只有没有 `river_flow` 时才回退到 `river_path_points`。
  - 山脉使用灰棕色连续脊线表示整体走向。
  - 远景缩放低于阈值时隐藏走向细节。
  - 该功能只作用于大地图预览，小地图预览暂不显示走向 overlay。
- 小地图预览：
  - 选中地块后点击“查看小地图”。
  - 双击大地图地块进入小地图。
  - 在同一预览场景内切换大地图/小地图。
  - 小地图不走缓存，直接用当前 seed 和选中 tile 生成。
  - 小地图支持右键拖动、Ctrl + 滚轮缩放和左键选择地格。
  - 左侧面板显示 tile key、平均高度和选中地格信息。

预览视口交互由 `PreviewViewport.gui_input` 处理。预览场景整体是 UI Control 结构，不能依赖 `_unhandled_input`，否则鼠标事件可能先被 GUI 控件消费，导致右键拖动或左键选择不触发。

预览工具刻意不在 `_ready()` 中调用地图生成器。原因是当前世界生成和小地图采样成本较高，自动生成会拖慢打开工具的速度。用户需要先调整 seed、尺寸、河流数量和大陆偏置，再点击“生成地图”显式触发生成。

小地图预览复用 `LocalMapGenerator`，但不使用 `LocalMapService`，因此不会读取或写入 `user://local_maps` 缓存。这样可以让生成器预览始终反映当前 seed 和当前选中地块的即时生成结果。

## 边界

`MapGenerator` 不依赖：

- Godot 场景节点。
- `TileMapLayer`。
- overlay 绘制脚本。
- UI 面板。
- 存档系统。

生成器可以生成服务于渲染的辅助数据，例如 `river_path_points` 和 `ridge_path_points`，但不直接执行绘制。

## 当前世界生成模型

当前大地图尺寸使用正方形 `big_map_size x big_map_size`。小地图尺寸使用 `sub_map_size`，默认 `64`。所有采样必须先转换为全局坐标：

```text
worldX = tileX * subMapSize + localX
worldY = tileY * subMapSize + localY
```

高度统一使用 `-256..256` 的整数语义。大地图地块的 `elevation` 是内部采样地格高度的平均值，同时记录 `min_height` 和 `max_height`。当前默认 `summary_sample_resolution = 4`，即每个大地图地块采样 `4x4` 个点，以保证开局大地图摘要生成速度可接受。

`TileState` 当前使用 `biome` 和 `terrain_tags` 表达主体地貌与附加标签，不再使用旧版 `terrain_id`、`rainfall`、`ruggedness`、`features` 作为主数据来源。河流和山脉的渲染辅助仍保留 `river_path_points`、`ridge_path_points`，用于大地图 overlay 绘制。

## 当前生成步骤

本节描述当前代码实际执行的地图生成方法，入口是：

```text
MapGenerator.generate(config)
```

执行顺序如下：

```text
MapGenerator.generate(config)
  -> MapGenerator.generate_pipeline(config)
      -> final_map

MapGenerator.generate_pipeline(config)
  -> WorldSkeletonGenerator.generate(config)
      -> _generate_mountain_ridges()
      -> resolve sea_level from ocean_ratio after mountains
      -> _generate_rivers()
      -> _build_skeleton_tile_index()
  -> BigMapSummaryGenerator.generate(config, skeleton, stage_id)
      -> _generate_tile_summary()
          -> WorldFunctionSampler.sample_base_height()
          -> WorldFunctionSampler.sample_ocean_height()
          -> WorldFunctionSampler.sample_mountain_delta()
          -> WorldFunctionSampler.sample_temperature()
          -> WorldFunctionSampler.sample_moisture()
          -> WorldFunctionSampler.sample_river_strength()
          -> WorldFunctionSampler.sample_biome()
      -> _apply_river_summary() for river/final stages
      -> _apply_mountain_summary() for mountain/final stages
```

`generate(config)` 仍然是正式游戏入口，返回最终 `MapState`。`generate_pipeline(config)` 是调试和预览入口，返回 `MapGenerationPipelineResult`，其中包含最终地图和各阶段快照。

### 1. 读取生成配置

`MapGenerationConfig` 负责把 JSON 配置或预览工具输入转换成生成器使用的强类型字段。

当前核心字段：

| 字段 | 当前默认 | 用途 |
| --- | --- | --- |
| `seed` | `260603` | 所有确定性随机的根输入。 |
| `big_map_size` | `40` | 大地图边长，当前强制为方形。 |
| `sub_map_size` | `64` | 每个大地图地块内部对应的小地图边长。 |
| `sea_level` | `0` | 兼容字段；当前实际海平面由 `ocean_ratio` 从基础高度 + 山脉抬升后的高度中求得。 |
| `ocean_ratio` | `0.30` | 海洋生成目标比例，预览工具可调整。 |
| `mountain_count` | `6` | 生成多少条全局山脉脊线。 |
| `river_source_count` | `8` | 生成多少个河流源头候选。实际河流可能因汇流或湖泊停止而少于该值。 |
| `summary_sample_resolution` | `4` | 每个大地图地块内部摘要采样为 `4 x 4` 点。 |
| `continent_bias` | `0.26` | 控制大陆中心抬升和边缘衰减幅度。 |

配置读取后，`width` 和 `height` 会被设置为 `big_map_size`，因此大地图运行时尺寸为：

```text
width = big_map_size
height = big_map_size
```

### 2. 生成世界骨架

`WorldSkeletonGenerator` 先生成只描述大尺度结构的 `WorldSkeleton`。这个阶段不生成每个地格的完整地形，只保存会影响连续采样的结构。

`WorldSkeleton` 当前保存：

| 字段 | 含义 |
| --- | --- |
| `seed` | 当前世界种子。 |
| `big_map_size` | 大地图边长。 |
| `sub_map_size` | 小地图边长。 |
| `sea_level` | 海平面。 |
| `continent_bias` | 大陆偏置。 |
| `mountain_ridges` | 山脉折线数组。 |
| `rivers` | 河流下坡路径数组。 |
| `river_sources` | 已成功生成的河流源头地块数组，用于源头排他性。 |
| `lakes` | 河流遇到局部洼地后形成的湖泊数组。 |
| `mountains_by_tile` | 大地图地块到相关山脉 id 的索引。 |
| `rivers_by_tile` | 大地图地块到相关河流 id 的索引。 |

### 3. 阶段快照

`MapGenerationPipelineResult` 当前包含以下阶段：

| 阶段 | 含义 | 预览显示 |
| --- | --- | --- |
| `base` | 根据 seed 和大陆偏置生成基础海拔。 | 基础高度灰度/渐变。 |
| `mountains` | 生成山脉影响层。 | 山脉影响强度灰度图。 |
| `ocean` | 根据山脉后高度和 `ocean_ratio` 求海平面并浸没低地。 | 海洋 mask。 |
| `rivers` | 生成主河流路径。 | 黑底河流路径。 |
| `environment` | 采样温度和湿度。 | 当前以湿度梯度显示。 |
| `final` | 合成最终高度、地貌、河流和渲染辅助数据。 | 完整大地图。 |

正式游戏只使用 `final_map`。阶段快照主要服务于预览器和调试，不进入正式存档。

### 4. 生成山脉骨架

`_generate_mountain_ridges(config, skeleton)` 会按 `mountain_count` 创建多条全局山脉折线。

每条山脉当前包含：

| 字段 | 生成方法 |
| --- | --- |
| `id` | 山脉序号。 |
| `points` | 5 个全局坐标点组成的折线。 |
| `width` | `52..124` 之间的影响宽度。 |
| `strength` | `0.62..1.0` 之间的山脉强度。 |
| `roughness` | `0.35..0.85` 之间的崎岖度，当前已保存但尚未参与采样公式。 |

山脉折线生成方法：

1. 用 `hash01(seed, salt, x, y)` 选择起点。
2. 用另一个 hash 值选择方向角 `angle`。
3. 山脉长度为世界尺寸的 `38%..83%`。
4. 沿主方向取 5 个点。
5. 每个点沿法线方向加入随机弯曲，形成不完全笔直的山脉。

山脉不是直接写入大地图地块的固定属性，而是在后续高度采样时通过“距离山脉折线的远近”产生抬升影响。

### 5. 生成河流骨架

`_generate_rivers(config, skeleton)` 会按 `river_source_count` 创建河流源头候选。

当前河流层只生成路径、流向、强度和大地图地块标记，不再对海拔执行河床下切，也不再为湿度采样叠加河流加成。

每条河流当前包含：

| 字段 | 生成方法 |
| --- | --- |
| `id` | 河流序号。 |
| `points` | 按大地图 8 邻域下坡追踪得到的全局坐标点。 |
| `width_profile` | 每个路径点的河流宽度，单位为全局地格。 |
| `width` | 最大影响宽度，当前默认最大 `12`。 |
| `flow` | 流量强度，当前为 `1.0`。 |
| `merge_target` | 如果汇入已有河流，则记录被汇入河流 id。 |

河流折线生成方法：

1. 在全世界范围内抽取多个候选点。
2. 使用基础地形、山脉影响和山脉邻近程度，选择山脉影响范围内的高海拔陆地作为源头。
3. 源头之间存在排他性：新源头必须与已有源头保持至少 `4` 个大地图地块的直线距离。
4. 如果本轮候选都不满足源头排他性，则放弃生成这条河流，不放宽距离。
5. 湖泊溢出源头也受同样的源头距离限制。
6. 在大地图 8 邻域中逐步选择更低海拔地块前进。
7. 到达海洋地块后停止。
8. 如果进入已有河流宽度范围，则当前河流在汇入点停止，并通过宽度增长表示汇流。
9. 如果周围没有更低海拔，则记录湖泊，并让后续河流源头有机会从已有湖泊附近溢出继续。

河流宽度单位为全局地格。默认从 `3` 开始，随路径距离增长；如果发生汇流，会额外增宽，最大宽度为 `12`。

当前河流在大地图层仍是粗路径，用于地图摘要、预览和快速索引。进入小地图后，`LocalMapGenerator` 会把该粗路径转换为地格级控制点，并在当前小地图内部生成完整河段。这样大地图不提前保存完整世界级河流图层，小地图也不会只沿地块中心线画一条直线。

当前大地图/小地图分工：

1. 大地图保存粗路径，继续用于地图摘要、预览和快速索引。
2. 小地图第一次进入时，根据粗路径的入口、出口和全局地格坐标进行局部细化。
3. 小地图细化路径使用 8 邻域寻路算法逐地格生成。
4. 寻路成本包含高度下降、到海方向、切割成本和避免穿越高山脊。
5. 河流切割保存为小地图内沿线切割点、宽度和深度，而不是提前保存整张世界级 `river_carving` 图。
6. 小地图缓存保存 `river_carve_points`，用于后续调试、存档和更细的河流渲染。

河流切割目前在小地图生成时生效：平时允许轻微切割，遇到局部洼地或低矮阻挡时允许通过较低的切割成本继续前进；高海拔山体仍会产生额外成本。切割宽度使用当前河流宽度，最终会在小地图地格高度中形成一条与河流宽度接近的低海拔通道。

### 5. 建立骨架索引

`_build_skeleton_tile_index(skeleton)` 会把每条山脉和河流登记到相关大地图地块中。

索引方法：

1. 遍历折线上的每个全局点。
2. 根据 `sub_map_size` 计算该点所在的大地图坐标：

```text
tile_x = floor(point.x / sub_map_size)
tile_y = floor(point.y / sub_map_size)
```

3. 把该结构登记到目标地块及其周围 8 个邻居。

这样做的目的不是精确覆盖所有折线经过的地块，而是给大地图摘要阶段一个快速提示：某个地块附近可能有山脉或河流，需要生成 `ridge_path_points` 或 `river_path_points` 供预览和正式 overlay 使用。

### 6. 连续函数采样

`WorldFunctionSampler` 是当前生成器的核心。它不根据局部坐标或生成顺序取随机数，而是根据全局坐标采样。

全局坐标规则：

```text
world_x = tile_col * sub_map_size + local_x
world_y = tile_row * sub_map_size + local_y
```

#### 高度采样

高度范围被限制在：

```text
-256..256
```

当前最终高度公式：

```text
height = ocean_reshape(base + mountain)
```

各部分含义：

| 部分 | 方法 |
| --- | --- |
| `continent` | 中心大陆抬升，边缘衰减。 |
| `detail` | 三层坐标 hash 噪声叠加。 |
| `mountain` | 山脉折线附近增加高度，最高约 `150`。 |
| `ocean_reshape` | 根据 `ocean_ratio` 在山脉后高度上求海平面，并重塑低地深度。 |

大陆基础高度：

```text
normalized = (world_x / world_size - 0.5, world_y / world_size - 0.5)
island_falloff = 1 - clamp(length(normalized) * lerp(1.80, 1.15, continent_bias), 0, 1)
continent = lerp(-140, 130, island_falloff)
```

细节噪声：

```text
detail =
  (hash(seed, 301, world_x / 64, world_y / 64) - 0.5) * 92
+ (hash(seed, 302, world_x / 24, world_y / 24) - 0.5) * 48
+ (hash(seed, 303, world_x / 8,  world_y / 8)  - 0.5) * 20
```

山脉影响：

```text
mountain_influence = sum(ridge.strength * falloff(distance_to_ridge / ridge.width))
mountain = mountain_influence * 150
```

`falloff(t)` 当前是平方衰减：

```text
falloff(t) = (1 - t) * (1 - t), t < 1
falloff(t) = 0, t >= 1
```

#### 温度采样

温度范围为 `0..1`。

当前公式由三个因素组成：

| 因素 | 影响 |
| --- | --- |
| 纬度 | 世界中部较热，上下边缘较冷。 |
| 高度 | 高海拔降低温度。 |
| 噪声 | 小幅随机扰动。 |

简化公式：

```text
latitude_temp = 1 - abs(world_y / world_size - 0.5) * 2
altitude_penalty = max(0, height / 256) * 0.34
temperature = clamp(latitude_temp - altitude_penalty + noise, 0, 1)
```

#### 湿度采样

湿度范围为 `0..1`。

当前公式：

```text
moisture = base_noise + ocean_bonus
```

| 因素 | 影响 |
| --- | --- |
| `base_noise` | 坐标 hash 产生的基础湿度。 |
| `ocean_bonus` | 海洋区域增加 `0.16`。 |

#### 河流强度采样

河流强度通过点到所有河流折线的最短距离计算：

```text
t = distance_to_river / river.width
river_strength = max(river.flow * falloff(t))
```

只有当 `t < 1` 时，河流会对该坐标产生影响。

#### Biome 推导

`sample_biome(world_x, world_y)` 会按顺序判断：

| 条件 | biome |
| --- | --- |
| `height < sea_level` | `ocean` |
| `river_strength > 0.70` | `river` |
| `height > 210` | `snow_mountain` |
| `height > 150` | `mountain` |
| `height > 86` | `hill` |
| `temperature < 0.18` | `tundra` |
| `moisture < 0.22` 且 `temperature > 0.55` | `desert` |
| `moisture > 0.75` 且 `temperature > 0.55` | `rainforest` |
| `moisture > 0.55` | `forest` |
| `moisture > 0.35` | `grassland` |
| 其他 | `plain` |

### 7. 大地图摘要

`BigMapSummaryGenerator` 不为每个大地图地块保存完整 `sub_map_size x sub_map_size` 地格，而是只采样少量点生成摘要。

默认每个大地图地块采样：

```text
summary_sample_resolution = 4
sample_count = 4 x 4 = 16
```

对每个样本点：

1. 计算局部坐标 `local_x/local_y`。
2. 转换为全局坐标 `world_x/world_y`。
3. 调用 `WorldFunctionSampler` 采样高度、温度、湿度、河流强度和 biome。
4. 把结果累计到当前大地图地块摘要。

写入 `TileState` 的摘要字段：

| 字段 | 方法 |
| --- | --- |
| `min_height` | 16 个样本高度最小值。 |
| `max_height` | 16 个样本高度最大值。 |
| `avg_height` | 16 个样本高度平均值。 |
| `elevation` | 当前等于 `avg_height`。 |
| `temperature` | 样本温度平均值。 |
| `moisture` | 样本湿度平均值。 |
| `river_strength` | 样本河流强度平均值。 |
| `has_river` | `river_strength > 0.08` 或骨架索引中存在河流。 |
| `biome` | 样本中出现次数最多的 biome。 |
| `terrain_tags` | 根据 biome 推导出的标签。 |

`terrain_tags` 当前推导规则：

| biome | tag |
| --- | --- |
| `ocean` | `water` |
| `river` | `river` |
| `snow_mountain` / `mountain` | `mountain` |
| `hill` | `hill` |
| `forest` / `rainforest` | `forest` |
| `desert` | `desert` |
| `tundra` | `tundra` |

### 8. 生成渲染辅助路径

大地图摘要完成后，会把骨架折线转换为每个地块内部的归一化路径点。

河流：

```text
tile.river_path_points = normalized river polyline points
tile.river_flow = sign(last_point - first_point)
```

山脉：

```text
tile.ridge_path_points = normalized ridge polyline points
tile.terrain_tags append "mountain"
```

归一化路径点范围是：

```text
0.0..1.0
```

它表示路径点在单个大地图地块内部的位置。例如 `(0.5, 0.5)` 表示地块中心。正式地图 overlay 和预览工具都使用这些点绘制河流线和山脉脊线。

### 9. 标记起始城市

`BigMapSummaryGenerator.generate()` 在遍历大地图地块时检查：

```text
col == config.start_city_col
row == config.start_city_row
```

命中后写入：

```text
tile.is_city_center = true
tile.owner_city_id = "player_capital"
map_state.start_city_tile_key = tile.tile_key
```

### 10. 写出调试 JSON

正式游戏流程中，`MapLoader` 在生成 `MapState` 后调用 `MapGenerationDebugWriter`，写入：

```text
config.generated_output_path
```

默认路径：

```text
user://generated_map.json
```

调试 JSON 当前包含：

- `version`
- `seed`
- `width`
- `height`
- 每个地块的 `biome`、高度摘要、温度、湿度、河流信息、路径点和 `terrain_tags`

该文件是运行时调试输出，不进入仓库版本控制。

## 确定性方法

当前地图生成避免依赖全局随机状态，核心随机值来自坐标 hash。

骨架生成使用：

```text
hash01(seed, salt, x, y)
```

连续采样使用：

```text
hash01(skeleton.seed, salt, world_x / scale, world_y / scale)
```

这种方式的特点：

- 同一个 seed、同一组参数、同一个坐标，采样结果固定。
- 生成顺序变化不影响单点采样结果。
- 大地图摘要和未来小地图只要使用同一全局坐标规则，就能保持边界连续。

当前仍需注意：

- 山脉和河流骨架本身由固定顺序生成，改变 `mountain_count` 或 `river_source_count` 会改变结构数量。
- 当前河流按大地图地块级别下坡追踪，尚未细化到小地图地格级真实水文。
- `summary_sample_resolution` 越高，大地图摘要越接近真实局部地形，但生成耗时越高。

## 当前限制

- 相同 seed 的确定性当前通过 headless 加载和人工预览验证，尚未做自动回归测试。
- 预览工具暂不支持 PNG 导出。
- 预览工具暂不支持参数 preset。
- 预览工具暂不支持同屏对比。
- `SubMapGenerator` 目前只是接口占位，尚未接入真实小地图生成。
