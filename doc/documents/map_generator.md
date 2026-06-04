# Map Generator Module Design

`map_generator` 模块负责世界地图生成算法。它从原先的 `MapLoader` 中抽离出来，让配置读取、生成算法和调试输出各自承担清晰职责。

## 当前实现范围

- `MapGenerationConfig` 承载地图生成配置。
- `MapGenerationValues` 承载生成过程中的环境场和河流中间数据。
- `MapGenerator.generate(config)` 根据配置生成 `MapState`。
- `MapGenerationDebugWriter` 负责把生成结果写入调试 JSON。
- `MapLoader` 保留原有 `load_generated_map()` 入口，但内部只负责读取 JSON、构建配置、调用生成器和触发调试输出。
- 新增独立开发场景 `MapGeneratorPreview.tscn`，用于输入 seed 和参数后预览生成结果。

## 文件结构

| 文件 | 职责 |
| --- | --- |
| `game/scripts/map_generation/map_generation_config.gd` | 地图生成配置对象，保存 seed、尺寸、阈值、生成参数和起始城市。 |
| `game/scripts/map_generation/map_generation_values.gd` | 地图生成中间数据，保存环境场和河流字段。 |
| `game/scripts/map_generation/map_generator.gd` | 世界地图生成器，生成环境场、河流、地貌派生和渲染辅助路径。 |
| `game/scripts/map_generation/map_generation_debug_writer.gd` | 调试输出写入器，负责写出 `user://generated_map.json`。 |
| `game/scenes/dev/MapGeneratorPreview.tscn` | 开发期地图生成器预览场景。 |
| `game/scripts/dev/map_generator_preview.gd` | 预览场景脚本，调用正式 `MapGenerator.generate(config)` 并渲染预览图。 |

## 数据流

正式游戏流程：

```text
MapRoot
  -> MapLoader.load_generated_map()
      -> MapGenerationConfig.load_from_dictionary(raw_config)
      -> MapGenerator.generate(config)
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
- 调整 `river_count`。
- 调整 `continent_bias`。
- 点击“生成”重新生成地图。
- 点击“随机 Seed”生成随机种子并刷新。
- 切换视图：
  - 基础地貌
  - 海拔
  - 降水
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

## 中间数据

`MapGenerator` 使用 `tile_key -> MapGenerationValues` 字典保存生成过程中的环境场。`MapGenerationValues` 当前包含：

- `elevation`
- `rainfall`
- `temperature`
- `river_strength`
- `river_flow`

这样可以避免继续把单个地块的中间字段存成裸 Dictionary，同时保留通过 `tile_key` 快速查询整张地图环境场的能力。

## 当前限制

- 抽离前后同 seed 一致性当前采用人工验证说明，尚未做自动回归测试。
- 预览工具暂不支持 PNG 导出。
- 预览工具暂不支持参数 preset。
- 预览工具暂不支持同屏对比。
