# Map Generator Module Design

`map_generator` 模块负责世界地图生成算法。当前实现已经从旧的“按大地图地块直接随机派生地貌”改为“世界骨架 + 连续函数采样 + 大地图摘要”的结构，为后续 RimWorld 式局部地图懒加载提供连续的全局坐标基础。

## 当前实现范围

- `MapGenerationConfig` 承载地图生成配置。
- `MapGenerator.generate(config)` 根据配置生成 `MapState`，内部委托 `world_generation` 模块完成骨架生成和大地图摘要。
- `WorldSkeletonGenerator` 生成全局山脉折线和主河流折线。
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
- 调整 `major_river_count`。
- 调整 `continent_bias`。
- 点击“生成”重新生成地图。
- 点击“随机 Seed”生成随机种子并刷新。
- 切换视图：
  - 基础地貌
  - 海拔
  - 湿度
  - 温度
  - 河流
  - 特征
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
- 小地图预览：
  - 选中地块后点击“查看小地图”。
  - 双击大地图地块进入小地图。
  - 在同一预览场景内切换大地图/小地图。
  - 小地图不走缓存，直接用当前 seed 和选中 tile 生成。
  - 小地图支持右键拖动、Ctrl + 滚轮缩放和左键选择地格。
  - 左侧面板显示 tile key、平均高度和选中地格信息。

预览视口交互由 `PreviewViewport.gui_input` 处理。预览场景整体是 UI Control 结构，不能依赖 `_unhandled_input`，否则鼠标事件可能先被 GUI 控件消费，导致右键拖动或左键选择不触发。

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

当前大地图尺寸使用正方形 `big_map_size x big_map_size`。小地图尺寸使用 `sub_map_size`，默认 `256`。所有采样必须先转换为全局坐标：

```text
worldX = tileX * subMapSize + localX
worldY = tileY * subMapSize + localY
```

高度统一使用 `-256..256` 的整数语义。大地图地块的 `elevation` 是内部采样地格高度的平均值，同时记录 `min_height` 和 `max_height`。当前默认 `summary_sample_resolution = 4`，即每个大地图地块采样 `4x4` 个点，以保证开局大地图摘要生成速度可接受。

`TileState` 当前使用 `biome` 和 `terrain_tags` 表达主体地貌与附加标签，不再使用旧版 `terrain_id`、`rainfall`、`ruggedness`、`features` 作为主数据来源。河流和山脉的渲染辅助仍保留 `river_path_points`、`ridge_path_points`，用于大地图 overlay 绘制。

## 当前限制

- 相同 seed 的确定性当前通过 headless 加载和人工预览验证，尚未做自动回归测试。
- 预览工具暂不支持 PNG 导出。
- 预览工具暂不支持参数 preset。
- 预览工具暂不支持同屏对比。
- `SubMapGenerator` 目前只是接口占位，尚未接入真实小地图生成。
