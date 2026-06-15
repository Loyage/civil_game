# map_generator 模块工作计划

## 目标

`map_generator` 模块负责世界地图生成算法本身。当前生成逻辑已经从旧版 `MapLoader` 抽离，并进一步接入 `world_generation` 分层：世界骨架、连续函数采样、大地图摘要和小地图生成接口。

首版抽离目标：

- `MapLoader` 只负责读取生成配置、调用生成器、触发调试输出。
- `MapGenerator` 只负责把 `MapGenerationConfig` 转换为 `MapState`。
- `WorldSkeletonGenerator` 负责世界骨架生成编排。
- `WorldMountainGenerator`、`WorldOceanResolver`、`WorldRiverGenerator` 和 `WorldSkeletonTileIndexer` 分别负责山脉、海平面、河流和索引步骤。
- `WorldGenerationMath` 负责骨架生成阶段共用的确定性 hash、全局高度采样、几何距离和方向工具。
- `WorldFunctionSampler` 负责基于全局坐标采样高度、温度、湿度、河流强度和 biome。
- `BigMapSummaryGenerator` 负责把连续世界函数汇总为大地图地块摘要。
- 生成器不依赖 Godot 场景节点、`TileMapLayer`、overlay 或 UI。
- 地图生成配置使用专门的 `MapGenerationConfig` 对象承载，不长期依赖裸 `Dictionary`。
- 调试输出从 `MapLoader` 中进一步拆到 `MapGenerationDebugWriter`。
- 保持相同 seed 和相同配置下生成结果可复现。

## 职责边界

### 负责

- 解析后的生成配置建模。
- 可复现随机数和噪声采样。
- 世界骨架生成：全局山脉折线、河流下坡路径、湖泊和大地图地块索引。
- 连续函数采样：高度、温度、湿度、河流强度和 biome。
- 大地图摘要：平均高度、最低/最高高度、主体 biome、地貌标签和渲染辅助路径。
- 生成渲染辅助数据：河流路径点、山脉脊线路径点。
- 构建 `MapState` 与 `TileState`。

### 不负责

- 地图场景节点管理。
- `TileMapLayer` 绘制。
- overlay 绘制。
- UI 面板刷新。
- 存档系统。
- 大地图/小地图切换。

## 规划文件结构

```text
game/scripts/map_generation/map_generation_config.gd
game/scripts/map_generation/map_generator.gd
game/scripts/map_generation/map_generation_preview_task.gd
game/scripts/map_generation/map_generation_debug_writer.gd
game/scripts/map_generation/map_generation_values.gd
game/scripts/world_generation/world_skeleton.gd
game/scripts/world_generation/world_skeleton_generator.gd
game/scripts/world_generation/world_mountain_generator.gd
game/scripts/world_generation/world_ocean_resolver.gd
game/scripts/world_generation/world_river_generator.gd
game/scripts/world_generation/world_skeleton_tile_indexer.gd
game/scripts/world_generation/world_generation_math.gd
game/scripts/world_generation/world_function_sampler.gd
game/scripts/world_generation/big_map_summary_generator.gd
game/scripts/world_generation/sub_map_generator.gd
game/scenes/dev/MapGeneratorPreview.tscn
game/scripts/dev/map_generator_preview.gd
```

说明：

- `map_generation_config.gd`：强类型配置对象，承载 width、height、seed、thresholds、generation 参数和 start_city。
- `map_generator.gd`：主生成器入口，提供 `generate(config) -> MapState`，委托 `world_generation` 分层执行实际生成。
- `map_generation_preview_task.gd`：预览工具专用分帧生成任务，负责进度信号和取消检查。
- `map_generation_debug_writer.gd`：把生成结果写入 `user://generated_map.json` 等调试输出。
- `map_generation_values.gd`：中间数据结构，承载环境场与派生字段，避免生成流程继续依赖裸 `Dictionary`。
- `world_skeleton_generator.gd`：骨架生成编排器，只保留步骤调用顺序。
- `world_mountain_generator.gd`：山脉骨架生成步骤。
- `world_ocean_resolver.gd`：海洋/海平面解析步骤。
- `world_river_generator.gd`：河流源头、路径、汇流和湖泊生成步骤。
- `world_skeleton_tile_indexer.gd`：山脉和河流到大地图地块的索引步骤。
- `world_generation_math.gd`：骨架生成共用工具。
- `world_function_sampler.gd`：连续函数采样，服务大地图摘要和后续小地图懒加载。
- `MapGeneratorPreview.tscn`：开发期地图生成预览场景，用于输入 seed 和参数后直观看到生成结果。
- `map_generator_preview.gd`：预览场景脚本，只调用正式 `MapGenerator.generate(config)`，不实现独立生成逻辑。

## 与现有模块关系

当前 `map_loader.gd` 同时承担：

1. 读取 JSON 配置。
2. 生成 `MapState`。
3. 写出调试 JSON。

抽离后关系规划为：

```text
MapRoot
  -> MapLoader
       -> MapGenerationConfig.load_from_dictionary(raw_config)
       -> MapGenerator.generate(config)
       -> MapGenerationDebugWriter.write_generated_map(config, map_state)
```

`MapRoot` 仍通过 `MapLoader.load_generated_map()` 获取 `MapState`，这样抽离不会影响渲染层和 UI 调用入口。

## 生成流程拆分

### 阶段 1：配置建模

把 `game/data/maps/map_generation_config.json` 解析出的 Dictionary 转换为 `MapGenerationConfig`。

配置对象至少包含：

- `version`
- `width`
- `height`
- `seed`
- `ocean_ratio`
- `mountain_count`
- `river_source_count`
- `generated_output_path`
- `start_city_col`
- `start_city_row`
- `start_city_name`
- `terrain_thresholds`
- `generation_params`

首版允许 `terrain_thresholds` 和 `generation_params` 继续以 Dictionary 保存，但对象需要提供默认值和读取接口。

### 阶段 2：世界骨架生成

`WorldSkeletonGenerator` 只负责生成顺序编排，实际步骤拆分为：

```text
WorldSkeletonGenerator.generate(config)
  -> WorldMountainGenerator.generate(config, skeleton)
  -> WorldOceanResolver.resolve_sea_level(config, skeleton)
  -> WorldRiverGenerator.generate(config, skeleton)
  -> WorldSkeletonTileIndexer.build(skeleton)
```

拆分后的骨架数据仍由 `WorldSkeleton` 承载：

- `mountain_ridges`
- `rivers`
- `river_sources`
- `lakes`
- `ocean_tiles`
- `ocean_distance_by_tile`
- `mountains_by_tile`
- `rivers_by_tile`
- 河流骨架字段包含 `points`、`width_profile`、`merge_target` 和 `reached_ocean`

骨架不保存每个小地图地格的完整地形，只保存能影响连续函数采样的大尺度结构。

海洋解析在山脉之后运行。`WorldOceanResolver` 会按大地图地块中心采样山脉后高度，再搜索接近 `ocean_ratio` 的海平面阈值。候选海洋使用大地图 8 邻域做连通区过滤，连通面积必须不小于 `max(8, 总地块数 * 1%)`；小于底线的低洼区不算海洋，最终高度会抬升到 `sea_level + 4`。合格海洋写入 `skeleton.ocean_tiles`，并计算 `skeleton.ocean_distance_by_tile`，后续采样会让离海岸越远的海洋越深，最大额外下沉 `64`。

大地图摘要必须和小地图采样保持一致。海洋阶段之后，如果一个大地图地块内部摘要样本中水域超过半数，则该地块主体 `biome` 强制为 `ocean`；小地图内部 `water_flags` 也只能由 `skeleton.ocean_tiles` 和 `skeleton.sea_level` 共同决定，不能只看高度是否小于 `0`。

河流从山脉影响范围内的高海拔陆地源头出发。河流源头之间存在排他性，新源头必须与已有源头保持至少 `4` 个大地图地块的直线距离；候选不足时放弃该河流，不放宽距离；湖泊溢出源头也受同样限制。确定源头后，河流按大地图 8 邻域执行成本寻路，优先寻找入海路径。成本包含移动距离、上坡切割、高地、山脉、下坡奖励和入海奖励；允许切开短距离局部高地，单步上坡超过 `72` 高度且不是海洋时视为不可通行。到达海洋后停止；进入已有河流宽度范围后停止并视为汇流；找不到可行入海路径时记录湖泊。河流宽度单位为全局地格，默认从 `3` 随距离和汇流低速增长到最大 `12`；当前距离增长系数为 `0.42`，汇流增宽系数为 `0.16`。

大地图河流显示必须只使用河流中心路径索引。山脉索引可以扩展到周围 8 个邻居，但河流不允许这样扩展；否则一个河流路径点会把周围多个地块都标成河流，形成并排箭头。`TileState.has_river` 只由 `skeleton.rivers_by_tile` 决定，`river_strength` 只保留为连续强度数据。

河流不只停留在大地图路径。大地图路径保留为粗路径，负责预览、摘要和索引；小地图第一次进入时根据粗路径进行地格级细化。细化后的河流会保存沿线切割点、宽度和深度，使河流能通过切割低成本地形继续前进，更容易入海。

### 阶段 2.1：骨架生成源码定位

- `game/scripts/world_generation/world_skeleton_generator.gd`：入口和步骤顺序。
- `game/scripts/world_generation/world_mountain_generator.gd`：山脉折线生成。
- `game/scripts/world_generation/world_ocean_resolver.gd`：按 `ocean_ratio` 解析海平面、连通海洋和离岸距离。
- `game/scripts/world_generation/world_river_generator.gd`：河流源头选择、入海寻路、汇流和湖泊记录。
- `game/scripts/world_generation/world_skeleton_tile_indexer.gd`：山脉/河流索引。
- `game/scripts/resources/world_resource_generator.gd`：最终资源类型生成。
- `game/scripts/world_generation/world_generation_math.gd`：hash、高度、距离、方向等共用函数。

### 阶段 3：阶段化累计快照

新增 `MapGenerationPipelineResult`：

- `final_map`
- `stage_maps`
- `stage_labels`

预览器点击“生成地图”时一次性生成以下阶段。每个阶段表示“地图生成到这一步之后的整体样貌”，不是单独图层：

- 基础地形
- 山脉：基础地形 + 山脉
- 海洋：基础地形 + 山脉 + 海洋
- 河流：基础地形 + 山脉 + 海洋 + 河流
- 环境：基础地形 + 山脉 + 海洋 + 河流 + 环境
- 资源：基础地形 + 山脉 + 海洋 + 河流 + 环境 + 资源
- 最终地貌

正式游戏继续调用 `MapGenerator.generate(config)`，只取得最终 `MapState`。

### 阶段 4：连续函数采样

`WorldFunctionSampler` 只接受全局坐标采样：

```text
worldX = tileX * subMapSize + localX
worldY = tileY * subMapSize + localY
```

当前采样字段：

- `height`
- `temperature`
- `moisture`
- `river_strength`
- `biome`

### 阶段 4：大地图摘要

`BigMapSummaryGenerator` 对每个大地图地块内部采样，汇总为 `TileState`：

- `elevation` / `avg_height`
- `min_height`
- `max_height`
- `temperature`
- `moisture`
- `river_strength`
- `biome`
- `terrain_tags`
- `resource_ids`

### 阶段 5：渲染辅助路径

生成仍属于地图数据的路径点：

- `river_path_points`
- `ridge_path_points`

这些数据可以被 overlay 使用，但生成器本身不绘制 overlay。

### 阶段 6：调试输出

`MapGenerationDebugWriter` 负责写出 `generated_output_path`。

理由：

- 生成器输出应是 `MapState`，不直接承担文件副作用。
- 调试输出格式后续可能变成二进制、压缩或多文件。
- 测试生成器时可以跳过调试写入。

## 预览工具

地图生成器后续会成为复杂且重要的模块，因此需要提供开发期预览工具，帮助直观看到“某个 seed + 参数”生成出来的地图样式。

预览工具原则：

- 只调用正式生成器入口。正式游戏使用 `MapGenerator.generate(config)`，预览工具使用同一生成器的 `generate_pipeline(config)` 调试入口。
- 不复制、不分叉地图生成逻辑。
- 不进入正式游戏流程。
- 不影响 `MapRoot`、存档、UI 主流程。
- 可以作为 Godot 独立 dev 场景运行。

首版预览场景：

```text
game/scenes/dev/MapGeneratorPreview.tscn
game/scripts/dev/map_generator_preview.gd
```

首版功能：

- 输入 seed。
- 输入 width / height。
- 输入 `ocean_ratio`。
- 输入 `mountain_count`。
- 输入 `river_source_count`。
- 打开预览工具时不自动生成地图。
- 点击“生成地图”后显示完整世界地图。
- 点击“生成地图”后一次性生成所有阶段累计快照。
- 点击“生成地图”后在地图显示区域叠加进度层，保留旧地图。
- 生成期间显示骨架步骤和阶段摘要逐行进度。
- 河流骨架按河流源头逐个生成并刷新进度。
- 生成期间禁用“生成地图”和“随机 Seed”。
- 生成期间显示“取消生成”按钮，取消后保留旧地图，不写入部分结果。
- 支持通过 `Stage` 下拉框切换基础地形、山脉、海洋、河流、环境和最终地貌；选中阶段显示生成到该步骤为止的整体样貌。
- 支持随机 seed，但随机按钮只更新 seed 输入框，不立即生成地图。
- 支持重新生成。
- 显示当前 seed 和主要生成参数。
- 支持基础视图切换：
  - 基础地貌
  - 海拔
  - 湿度
  - 温度
  - 河流
  - 特征
  - 走向
- 海拔视图使用热力图：
  - 低海拔为蓝色，高海拔逐步过渡到红色和白色。
  - 海平面以下保持蓝色系，和陆地热力颜色区分。
  - 大地图按固定 `-256..256` 显示。
  - 小地图按当前小地图高度动态范围显示，并继续以 `0` 作为海平面。
  - 摘要区显示简要海拔图例。
- 支持大地图走向显示：
  - 默认开启山脉脊线和河流走向叠加。
  - 提供“显示走向”开关。
  - 提供独立“走向”视图。
  - 河流使用线条和箭头显示流向。
  - 河流视图和走向视图强制显示河流走向 overlay，不依赖“显示走向”开关，也不受远景缩放隐藏条件影响。
  - 河流走向优先使用每个地块附近的局部河段方向写入 `river_flow` 并绘制格内方向箭头，避免整条河所有地块显示同向箭头，也避免单格 `river_path_points` 不足时退化为不可见零长度线段。
  - 山脉使用连续脊线显示走向。
  - 缩放过远时隐藏走向细节。
  - 当前只作用于大地图预览。

后续功能：

- 调整 `continent_bias`、海洋阈值、山脉高度阈值、丘陵高度阈值、荒漠湿度阈值、沼泽湿度阈值和河流源头数量。
- 保存 seed + 参数为 preset。
- 导出当前地图 PNG。
- 显示地图摘要：海洋比例、山脉比例、森林比例、河流地块数量、平均海拔。
- 同屏对比两个 seed。
- 同屏对比同一 seed 在两组参数或两版算法下的差异。

预览工具和正式游戏的关系：

```text
MapGeneratorPreview
  -> MapGenerationConfig
  -> MapGenerator.generate(config)
  -> PreviewRenderer
```

`PreviewRenderer` 只负责把 `MapState` 渲染成预览图，不参与正式地图渲染，也不影响 `MapRoot`。

## 里程碑

### M0 - 文档和边界确认

- 明确 `map_generator` 职责。
- 明确 `MapLoader`、`MapGenerator`、`MapGenerationDebugWriter` 的边界。
- 明确生成器不依赖场景节点和渲染。

### M1 - 配置对象

- 新建 `MapGenerationConfig`。
- 从 JSON Dictionary 构建配置对象。
- 提供默认值读取。
- 保持当前配置文件格式不变。

### M2 - 主生成器抽离

- 新建 `MapGenerator`。
- 将 `_generate_map_state()` 及其纯生成辅助函数迁移到生成器。
- `MapLoader.load_generated_map()` 改为调用 `MapGenerator.generate(config)`。
- 保持现有地图生成结果稳定。

### M3 - 调试输出抽离

- 新建 `MapGenerationDebugWriter`。
- 将 `_write_generated_map()` 和序列化辅助函数迁移到 debug writer。
- `MapLoader` 只负责决定是否写调试输出和调用 writer。

### M4 - 中间数据结构

- 新建 `MapGenerationValues`。
- 用 `MapGenerationValues` 替代旧版临时 Dictionary value。
- 明确环境场、河流字段和派生字段的生命周期。
- 为后续测试和算法扩展提供稳定结构。

### M5 - 验证

- 验证相同 seed 生成一致。
- 抽离前后关键地图摘要一致性当前采用人工验证说明，不新增自动测试代码。
- 验证 `generated_output_path` 仍能写出。
- 验证 `MapRoot`、UI、local_map 的调用入口不受影响。

### M6 - 生成器预览工具

- 新建 `MapGeneratorPreview.tscn`。
- 新建 `map_generator_preview.gd`。
- 支持输入 seed、width、height。
- 支持点击生成并显示地图。
- 支持随机 seed 和重新生成。
- 支持基础地貌、海拔、湿度、温度、河流、特征视图切换。
- 确保预览工具调用正式 `MapGenerator.generate(config)`。

### M7 - 预览工具调参和对比

- 支持核心生成参数调节。
- 支持显示地图摘要数据。
- 支持保存 seed + 参数 preset。
- 支持导出 PNG。
- 支持同屏对比 seed 或参数差异。
- 当前不纳入首版完成范围，后续作为增强功能处理。

## 当前 checklist

- [x] M0 明确 `map_generator` 职责边界
- [x] M1 新建 `MapGenerationConfig`
- [x] M2 新建 `MapGenerator` 并抽离主生成逻辑
- [x] M3 新建 `MapGenerationDebugWriter` 并抽离调试输出
- [x] M4 新建并接入 `MapGenerationValues`
- [x] M5 采用人工验证说明，不新增自动测试代码
- [x] M6 新建地图生成器预览场景
- [ ] M7 预览工具 preset、PNG 导出和同屏对比

### M8 - 预览交互

- 预览视口支持右键拖动。
- 预览视口支持按住 Ctrl 后滚轮缩放。
- 预览视口支持左键选择地块。
- 显示选中地块标记。
- 显示选中地块信息。
- 交互习惯和正式地图保持一致，但预览工具不复用 `MapRoot`。

### M9 - 预览小地图

- 支持左键选中大地图地块后点击“查看小地图”。
- 支持双击大地图地块进入小地图。
- 在同一个预览场景内切换大地图/小地图视图。
- 小地图预览不走缓存，每次直接使用当前 seed 和选中 tile 生成。
- 小地图预览支持右键拖动、Ctrl + 滚轮缩放。
- 小地图预览支持左键选择地格。
- 小地图预览支持复用 `View` 下拉框；当前已接入“海拔”和“特征”视图。
- 左侧面板显示小地图 tile key、平均高度和选中地格信息。

### M10 - 连续世界生成改造

- 使用 `WorldSkeletonGenerator` 编排世界骨架生成。
- 使用 `WorldMountainGenerator` 生成全局山脉折线。
- 使用 `WorldOceanResolver` 在山脉生成之后解析海平面。
- 使用 `WorldRiverGenerator` 生成河流源头、下坡路径、汇流和湖泊。
- 使用 `WorldSkeletonTileIndexer` 建立山脉/河流地块索引。
- 使用 `WorldGenerationMath` 复用骨架生成阶段的 hash、高度采样、距离和方向工具。
- 使用 `WorldFunctionSampler` 按全局坐标采样连续高度、温度、湿度、河流强度和 biome。
- 使用 `BigMapSummaryGenerator` 将小地图地格采样汇总为大地图地块摘要。
- 大地图高度语义改为 `-256..256` 整数，`TileState.elevation` 表示内部高度平均值。
- 大地图尺寸改为 `big_map_size x big_map_size` 方形语义。
- `summary_sample_resolution` 当前默认 `4`，用于控制开局摘要生成成本。
- `SubMapGenerator` 先作为接口占位，暂不接入旧版 `LocalMapGenerator`。
- 更新正式 `MapRoot`、UI 信息面板和预览场景以读取 `biome`、`terrain_tags`、平均/最低/最高高度。

### M11 - 预览走向显示

- 在大地图预览上默认叠加山脉脊线和河流走向。
- 新增“显示走向”开关。
- 新增“走向”视图。
- 河流显示路径线和方向箭头。
- 河流视图和走向视图强制显示河流走向 overlay。
- 单个河流地块优先使用 `river_flow` 绘制方向箭头。
- 山脉显示连续脊线。
- 缩放过远时隐藏走向细节。
- 小地图预览暂不显示走向 overlay。

## Checklist

- [x] 创建 `map_generator` 任务文档
- [x] 定义 `MapGenerationConfig`
- [x] 定义 `MapGenerator.generate(config)` 接口
- [x] 定义 `MapGenerationDebugWriter`
- [x] 设计并接入 `MapGenerationValues`
- [x] 从 `MapLoader` 抽离环境场生成
- [x] 从 `MapLoader` 抽离河流生成
- [x] 从 `MapLoader` 抽离地貌派生
- [x] 从 `MapLoader` 抽离渲染辅助路径生成
- [x] 从 `MapLoader` 抽离调试输出写入
- [x] 保持 `MapRoot` 调用入口不变
- [x] 记录抽离前后同 seed 生成一致的人工验证策略
- [ ] 验证调试输出仍可写入
- [x] 创建 `MapGeneratorPreview.tscn`
- [x] 创建 `map_generator_preview.gd`
- [x] 实现 seed / width / height 输入
- [x] 实现预览场景点击“生成地图”后生成
- [x] 实现打开预览工具时不自动生成地图
- [x] 实现随机 seed 只更新输入框
- [x] 实现重新生成
- [x] 实现基础地貌 / 海拔 / 湿度 / 温度 / 河流 / 特征视图切换
- [x] 实现大地图预览山脉/河流走向叠加
- [x] 实现预览工具“显示走向”开关
- [x] 实现预览工具“走向”独立视图
- [x] 实现河流方向箭头
- [x] 实现河流视图和走向视图强制显示河流走向 overlay
- [x] 实现按 `river_flow` 绘制河流地块内方向箭头
- [x] 实现阶段化地图生成结果 `MapGenerationPipelineResult`
- [x] 实现基础地形 / 山脉 / 海洋 / 河流 / 环境 / 资源 / 最终地貌阶段快照
- [x] 将阶段快照改为显示生成到该步骤为止的累计地图状态
- [x] 实现预览工具分帧生成任务
- [x] 实现地图显示区域进度覆盖层
- [x] 实现生成期间禁用生成/随机 Seed 按钮
- [x] 实现生成取消按钮
- [x] 实现阶段摘要逐行进度显示
- [x] 实现河流骨架按源头分帧生成进度
- [x] 调整海洋生成到山脉生成之后
- [x] 实现海洋连通区过滤
- [x] 实现小低洼区抬升为陆地
- [x] 实现海洋离岸距离下沉
- [x] 修正大地图陆地与小地图水域判定不一致
- [x] 实现预览工具阶段下拉框
- [x] 实现 `ocean_ratio` 预览参数
- [x] 实现山脉源头下坡河流生成
- [x] 实现河流源头 4 格排他性
- [x] 实现大地图河流成本寻路入海
- [x] 实现按地块局部河段计算 `river_flow`
- [x] 修正河流索引只标记中心路径地块
- [x] 移除 `major_river_count`，改用 `river_source_count`
- [x] 设计大地图粗路径指导小地图地格级河流细化
- [x] 设计河流切割层数据结构
- [x] 设计河流切割对小地图缓存版本的影响
- [x] 实现远景缩放隐藏走向细节
- [x] 确保预览工具复用正式 `MapGenerator.generate(config)`
- [x] 设计生成参数调节面板
- [x] 设计地图摘要数据显示
- [ ] 设计 PNG 导出和 seed/参数 preset
- [ ] 设计同屏对比功能
- [x] 预览视口支持右键拖动
- [x] 预览视口支持 Ctrl + 滚轮缩放
- [x] 预览视口支持左键选择地块
- [x] 显示选中地块标记
- [x] 显示选中地块信息
- [x] 预览工具支持查看选中地块小地图
- [x] 预览工具支持双击地块进入小地图
- [x] 小地图预览不走缓存直接生成
- [x] 小地图预览支持右键拖动和 Ctrl + 滚轮缩放
- [x] 小地图预览支持左键选择地格
- [x] 小地图预览支持海拔视图
- [x] 小地图预览支持 terrain_flags 特征视图
- [x] 大地图和小地图预览支持资源视图
- [x] 海拔视图使用蓝到红白的热力图
- [x] 海拔视图显示简要热力图图例
- [x] 左侧面板显示小地图地格信息
- [x] 创建 `world_generation` 目录
- [x] 实现 `WorldSkeleton` 数据结构
- [x] 实现 `WorldSkeletonGenerator`
- [x] 将 `WorldSkeletonGenerator` 拆为步骤编排器
- [x] 实现 `WorldMountainGenerator`
- [x] 实现 `WorldOceanResolver`
- [x] 实现 `WorldRiverGenerator`
- [x] 实现 `WorldSkeletonTileIndexer`
- [x] 实现 `WorldGenerationMath` 共用工具
- [x] 实现 `WorldFunctionSampler`
- [x] 实现 `BigMapSummaryGenerator`
- [x] 新增 `SubMapGenerator` 接口占位
- [x] 将 `MapGenerator.generate(config)` 改为调用新世界生成分层
- [x] 将大地图高度改为 `-256..256` 整数语义
- [x] 将 `TileState` 主地貌字段改为 `biome` 和 `terrain_tags`
- [x] 更新正式地图渲染读取 `biome`
- [x] 更新 UI 地块信息面板显示平均/最低/最高高度、温度、湿度、biome
- [x] 更新生成器预览场景读取新字段
- [ ] 将真实小地图生成接入 `SubMapGenerator`
- [ ] 实现玩家改动增量保存与原始地形分离
- [ ] 为相同 seed 的大地图摘要增加自动回归测试

## 风险

- 抽离过程中如果改变随机数调用顺序，会导致同 seed 地图变化。
- 如果配置对象默认值和当前 Dictionary 默认值不一致，会引入难以定位的生成差异。
- 渲染辅助路径虽然服务于 overlay，但仍依赖地图生成数据；迁移时需要避免把 overlay 绘制逻辑带入生成器。
- 调试输出如果继续和生成器耦合，会影响后续测试和缓存策略。
- 预览工具如果复制生成逻辑，会和正式游戏生成结果分叉；必须强制复用正式生成器入口。
- 本次世界骨架生成拆分只移动代码边界，不应改变同 seed 输出；如果后续发现生成结果变化，优先检查 `WorldGenerationMath` 中 hash 和高度采样是否与拆分前一致。
