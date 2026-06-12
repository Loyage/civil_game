# Local Map Module Design

`local_map` 模块负责在玩家进入世界地图单个地块时，按需生成并展示该地块内部的局部地图。小地图边长由地图生成配置 `sub_map_size` 控制，默认值为 `64`。当前版本实现基础可用流程，不提前生成所有地块的小地图。

## 当前实现范围

- 双击大地图地块进入小地图。
- 小地图第一次进入时通过 `LocalMapService.load_or_generate(tile)` 读取缓存或生成。
- 缓存使用 Godot 二进制文件，路径为 `user://local_maps/{seed}/v{version}/{tile_key}.bin`。
- 小地图边长由 `sub_map_size` 配置控制；预览工具中可以通过 `Sub Map Size` 调整。
- 小地图高度范围为 `-256..256` 整数。
- 小地图高度逐地格复用世界生成器的 `WorldSkeletonGenerator + WorldFunctionSampler`，不再使用旧版本地噪声高度场。
- 水体规则由大地图海洋掩码和海平面共同决定。
- 河流地块会根据大地图粗路径生成地格级细化河道，并按全局 `width_profile` 采样宽度后压低河床。
- `LocalMapRoot` 用 `ImageTexture` 渲染高度图，避免为每个地格创建节点。
- `LocalMapRoot` 使用 `CanvasLayer` 固定在屏幕坐标渲染，不受大地图相机平移和缩放影响。
- 小地图视口支持右键拖动，以及按住 Ctrl 后滚轮缩放。
- 小地图视口支持左键点击地格选中，悬停只显示预览标记，不更新左下角信息面板。
- HUD 在小地图模式显示“返回大地图”按钮。

## 文件结构

| 文件 | 职责 |
| --- | --- |
| `game/scripts/local_map/local_map_state.gd` | 小地图运行时状态，保存高度、水体、河流和坡度数组。 |
| `game/scripts/local_map/local_map_generator.gd` | 根据世界种子和大地图地块生成小地图。 |
| `game/scripts/local_map/local_map_service.gd` | 负责缓存读取、生成和写入。 |
| `game/scripts/local_map/local_map_root.gd` | 小地图场景脚本，接收 `LocalMapState` 并渲染纹理。 |
| `game/scenes/local_map/LocalMapRoot.tscn` | 小地图显示场景。 |

## 边界连续性

小地图内部坐标为 `cell(x, y)`，范围 `0..sub_map_size - 1`。为了让小地图严格归属于对应的大地图地块，并与大地图海洋掩码保持一致，全局采样坐标使用：

```text
global_cell_x = tile_col * sub_map_size + cell_x
global_cell_y = tile_row * sub_map_size + cell_y
```

这样每个大地图地块覆盖一个独立的 `sub_map_size x sub_map_size` 全局采样区间，避免小地图因为 `sub_map_size - 1` 的累计偏移采样到相邻大地图地块，导致大地图显示陆地但小地图内部大面积为水。

基础高度只使用全局高度场。当前全局高度场来自 `WorldFunctionSampler.sample_height(global_cell_x, global_cell_y)`，因此同一种子和同一配置下生成结果稳定；相邻小地图边界追求视觉连续，但不再要求完全复用同一个边界采样坐标。

河流是例外：为了保证跨地块入口/出口真正连通，河流可以在边界地格标记 `river_flags` 并下切河床。相邻小地图会从同一条全局河流折线裁剪出各自的入口/出口，因此共享边界上的河流位置由全局路径决定，而不是由单个地块独立猜测。

## 当前生成算法

`LocalMapGenerator.generate(tile)` 当前执行顺序：

```text
LocalMapGenerator.generate(tile)
  -> _generate_heights()
      -> WorldSkeletonGenerator.generate(config)
      -> WorldFunctionSampler.sample_height(global_x, global_y)
  -> _apply_river()
      -> _find_refined_river_path()
      -> _find_river_path_segment()
      -> _record_river_carve()
      -> _carve_river_at()
  -> _derive_flags_and_slopes()
```

### 高度生成

小地图每个地格先转换为全局地格坐标：

```text
global_x = tile_col * sub_map_size + cell_x
global_y = tile_row * sub_map_size + cell_y
```

然后调用：

```text
WorldFunctionSampler.sample_height(global_x, global_y)
```

`water_flags` 不再只根据 `height < 0` 推导。当前规则是：当前大地图地块必须属于 `skeleton.ocean_tiles`，且地格高度低于 `skeleton.sea_level`，才标记为水域。非海洋大地图地块内部的低洼地会在世界采样阶段被抬升到海平面以上，避免大地图陆地进入后显示为大面积水域。

高度值被限制在：

```text
-256..256
```

这样小地图和大地图使用同一套世界骨架和连续函数：大陆衰减、山脉抬升、河流下切和多层高度噪声都来自 `world_generation` 模块。大地图是低分辨率摘要，小地图是同一世界函数的高分辨率采样。

生成单个小地图前，`LocalMapGenerator` 会从完整 `WorldSkeleton` 中筛选当前地块附近可能产生影响的山脉和河流线段，构造局部骨架副本再交给 `WorldFunctionSampler`。这样仍然使用同一套采样方法，但避免每个地格都遍历全世界所有山脉和河流。

运行时 `LocalMapService` 会读取 `game/data/maps/map_generation_config.json` 构造配置，并覆盖当前 `world_seed`；开发期 `MapGeneratorPreview` 会把当前预览控件中的配置传给 `LocalMapGenerator`，其中 `Sub Map Size` 会写入 `config.sub_map_size`，避免预览参数和小地图生成参数分叉。

### 河流生成

河流使用“大地图粗路径 + 小地图细化路径”的两层结构：

1. 优先从 `WorldSkeleton.rivers` 读取完整全局河流折线。
2. 用当前大地图地块在世界坐标中的矩形裁剪全局折线，得到该地块内的入口、控制点和出口。
3. 对相邻控制点分段执行 8 邻域 A* 风格寻路。
4. 寻路成本偏好低处、缓坡、下坡和接近目标方向。
5. 对低矮上坡设置较低切割成本，让河流能切开局部洼地边缘或低矮阻挡。
6. 对高海拔山体增加额外成本，避免河流无代价穿越山脊。
7. 拼接所有分段路径，得到当前小地图内的完整河段。
8. 沿路径记录 `river_carve_points`，宽度通过当前地格投影到全局河流折线后从 `width_profile` 插值获得。
9. 边界地格也允许执行河床下切，以保证当前小地图的出口和相邻小地图的入口在高度与河流标记上连续。

如果当前地块找不到对应的全局河流折线，生成器才会回退到旧版 `river_path_points`、`river_flow` 和湖泊标记推导入口/出口。这个回退只用于兼容异常数据，不是主路径。

河流宽度默认从 `3` 逐渐增长到最大 `12`，具体宽度由世界河流骨架里的 `width_profile` 决定。小地图只负责把细化后的河道地格投影回全局河流折线并读取对应宽度，因此相邻地块入口/出口处会继承同一条全局河流上的连续宽度，不会因为每个小地图局部重新从起点增长而变窄。切割深度从 `10` 增长到最大 `42`，同时参考当前宽度和小地图内下游距离。中心河床会被压低到海平面以下，外围按距离衰减，形成与河宽接近的低海拔通道。

`LocalMapState.river_carve_points` 保存当前小地图内已生成河段的切割点，每个点包含：

- `cell_x`
- `cell_y`
- `global_x`
- `global_y`
- `width`
- `depth`

当前没有直接使用 `WorldFunctionSampler.sample_river_strength()` 标记整片河流范围。这样可以保证大地图指定的入口/出口连通，并让小地图内部河段具备基本地形切割能力，但水文真实性仍是原型级。

### 水体和坡度

水体规则与大地图海洋掩码保持一致：

```text
tile in skeleton.ocean_tiles and height < skeleton.sea_level => water
```

坡度使用当前地格与周围 8 个邻居的最大高度差：

```text
slope = max(abs(center_height - neighbor_height))
```

`average_height` 在生成高度后统计一次，并在河流下切和水体/坡度派生后重新统计。

## 缓存版本

本次小地图河流改为按完整全局河流折线裁剪入口/出口，边界河床允许下切，河宽按全局 `width_profile` 采样。缓存版本升级为：

```text
CACHE_VERSION = 7
LocalMapState.version = 7
```

旧版缓存路径不会被读取，新生成的小地图会写入 `v7` 目录。

同一个缓存版本下，缓存读取还会校验 `width` 和 `height` 是否等于当前配置的 `sub_map_size`。如果玩家调整小地图边长，旧尺寸缓存不会被复用，会重新生成对应尺寸的小地图。

## 集成流程

`MapRoot` 在左键双击地块时发出 `tile_enter_requested(tile)`。`CoreRoot` 接收信号后调用 `LocalMapService`，隐藏大地图，显示 `LocalMapRoot`，并让 UI 进入小地图模式。

返回时，`UIRoot` 发出 `return_to_world_requested`，`CoreRoot` 隐藏小地图并恢复大地图显示。大地图节点只是隐藏，不释放，因此相机位置和缩放保留。

小地图内部交互复用大地图的操作习惯：右键拖动移动视图，按住 Ctrl 后滚轮缩放。缩放会以鼠标所在位置为焦点，拖动偏移会被限制在当前小地图纹理范围内。

左下角 UI 在小地图模式切换为“地格信息”。进入小地图后默认未选择地格；玩家在小地图视口内左键点击地格后，`LocalMapRoot` 发出 `local_cell_selected(cell_info)`，`CoreRoot` 转发给 `UIRoot`，面板显示地格坐标、全局坐标、高度、水体、河流和坡度。悬停只更新预览标记，不改变面板内容。

`MapGeneratorPreview` 也可以查看小地图。该开发工具入口直接调用 `LocalMapGenerator`，不使用 `LocalMapService`，因此不会读取或写入缓存，适合快速查看当前 seed 和选中大地图地块对应的小地图样式。

## 当前限制

- 小地图地格信息面板尚未实现。
- 小地图当前仍直接使用最终世界骨架和 `WorldFunctionSampler` 采样，没有迁移到 `MapGenerationPipelineResult` 的阶段快照系统。后续应复用同一套“基础地形、山脉、海洋、河流、环境、最终地貌”的图层合成思路，避免大地图和小地图生成语义分叉。
- 河流已经具备全局折线约束、地格级寻路和基础切割能力，但还没有完整流量守恒、侵蚀迭代和跨小地图缓存联动。
- 山脉目前通过全局高度采样自然体现，尚未沿大地图 `ridge_path_points` 额外强化局部山脊。
- 湖泊、湿地、植被和资源暂未在小地图数据结构中细化。
- 缓存主体使用 `store_var()` 写入 Dictionary，后续如果需要更小体积，可以改成手写压缩二进制格式。
