# Local Map Module Design

`local_map` 模块负责在玩家进入世界地图单个地块时，按需生成并展示该地块内部的 `256 x 256` 局部地图。当前版本实现基础可用流程，不提前生成所有地块的小地图。

## 当前实现范围

- 双击大地图地块进入小地图。
- 小地图第一次进入时通过 `LocalMapService.load_or_generate(tile)` 读取缓存或生成。
- 缓存使用 Godot 二进制文件，路径为 `user://local_maps/{seed}/v{version}/{tile_key}.bin`。
- 小地图高度范围为 `-256..256` 整数。
- 水体规则为 `height < 0`。
- 河流地块会根据入口/出口生成基础寻路河道，并压低河床。
- `LocalMapRoot` 用 `ImageTexture` 渲染 `256 x 256` 高度图，避免为每个地格创建节点。
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

小地图内部坐标为 `cell(x, y)`，范围 `0..255`。为了让相邻地块共享边界高度完全一致，全局采样坐标使用：

```text
global_cell_x = tile_col * 255 + cell_x
global_cell_y = tile_row * 255 + cell_y
```

因此右侧相邻地块的 `cell(0, y)` 与当前地块的 `cell(255, y)` 会采样同一个全局坐标。

边界高度只使用全局高度场。地块海拔、山脉、水体等宏观约束从边界向内部渐入，最外圈权重为 0，避免相邻地块因为属性不同而出现高度缝。河流可以标记边界地格，但河床下切不会改写最外圈高度。

## 集成流程

`MapRoot` 在左键双击地块时发出 `tile_enter_requested(tile)`。`CoreRoot` 接收信号后调用 `LocalMapService`，隐藏大地图，显示 `LocalMapRoot`，并让 UI 进入小地图模式。

返回时，`UIRoot` 发出 `return_to_world_requested`，`CoreRoot` 隐藏小地图并恢复大地图显示。大地图节点只是隐藏，不释放，因此相机位置和缩放保留。

小地图内部交互复用大地图的操作习惯：右键拖动移动视图，按住 Ctrl 后滚轮缩放。缩放会以鼠标所在位置为焦点，拖动偏移会被限制在当前小地图纹理范围内。

左下角 UI 在小地图模式切换为“地格信息”。进入小地图后默认未选择地格；玩家在小地图视口内左键点击地格后，`LocalMapRoot` 发出 `local_cell_selected(cell_info)`，`CoreRoot` 转发给 `UIRoot`，面板显示地格坐标、全局坐标、高度、水体、河流和坡度。悬停只更新预览标记，不改变面板内容。

`MapGeneratorPreview` 也可以查看小地图。该开发工具入口直接调用 `LocalMapGenerator`，不使用 `LocalMapService`，因此不会读取或写入缓存，适合快速查看当前 seed 和选中大地图地块对应的小地图样式。

## 当前限制

- 小地图地格信息面板尚未实现。
- 河流寻路是基础成本寻路，还没有完整水文约束。
- 山脉目前只整体抬高山地地块，尚未沿大地图 `ridge_path_points` 生成局部山脊。
- 缓存主体使用 `store_var()` 写入 Dictionary，后续如果需要更小体积，可以改成手写压缩二进制格式。
