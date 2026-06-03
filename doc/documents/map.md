# Map Module Design

地图模块负责生成、保存、展示和查询世界地图。当前版本已经从类文明的单一地形格，调整为更接近 RimWorld 世界地图的多属性地块：每个地块不只拥有一种地貌，而是由海拔、降水、温度、起伏度、水系等环境字段共同推导出基础地形和附加特征。

当前地图仍是世界地图层级，不包含进入单个地块后的局部地图生成。

## 目标

地图模块当前承担以下职责：

- 生成固定尺寸的可复现样例地图。
- 用多环境字段描述每个地块，而不是只记录单一 terrain。
- 根据海拔、降水、河流等字段自然推导山脉、丘陵、湖泊、沼泽、森林等特征。
- 在 Godot 4 中用 `TileMapLayer` 和自定义 overlay 展示地图。
- 支持左键选择地块、右键拖拽视角、按住 Ctrl 后滚轮缩放。
- 提供 8 邻域查询和基础交通可达程度计算。

## 文件结构

| 文件 | 职责 |
| --- | --- |
| `game/data/maps/map_generation_config.json` | 地图生成配置，包含尺寸、种子、生成参数、起始城市位置等。 |
| `game/scripts/map/map_loader.gd` | 读取地图生成配置，调用 `MapGenerator`，并触发调试输出写入。 |
| `game/scripts/map_generation/map_generation_config.gd` | 地图生成配置对象，承载 seed、尺寸、阈值和生成参数。 |
| `game/scripts/map_generation/map_generator.gd` | 世界地图生成器，把 `MapGenerationConfig` 转换为 `MapState`。 |
| `game/scripts/map_generation/map_generation_debug_writer.gd` | 将生成结果写入 `user://generated_map.json` 等调试输出。 |
| `game/scripts/map/map_state.gd` | 地图运行时状态，保存宽高、地块字典、起始城市等。 |
| `game/scripts/map/tile_state.gd` | 单个地块的数据结构，保存基础地形、环境字段、特征和河流信息。 |
| `game/scripts/map/grid_layout.gd` | 方形格坐标与像素位置转换。 |
| `game/scripts/map/offset_coord.gd` | 地图格坐标值对象。 |
| `game/scripts/map/map_query_service.gd` | 邻接、范围、距离、交通成本查询。 |
| `game/scripts/map/map_input_controller.gd` | 鼠标屏幕坐标到地图格坐标的转换，以及选择状态维护。 |
| `game/scripts/map/map_camera_controller.gd` | 右键拖拽、Ctrl+滚轮缩放、摄像机边界限制。 |
| `game/scripts/map/river_overlay.gd` | 根据地块内部路径点绘制跨格连续河流。 |
| `game/scripts/map/terrain_detail_overlay.gd` | 绘制山脉、丘陵、森林、沼泽和湖泊的程序化纹理。 |
| `game/scripts/map/map_overlay.gd` | 绘制调试符号、选中框、边界和城市标记。 |
| `game/scripts/map/map_root.gd` | 地图场景入口，连接生成、渲染、输入、摄像机和 overlay。 |
| `game/scenes/map/MapRoot.tscn` | 地图场景结构。 |

## 核心数据结构

### MapState

`MapState` 是世界地图的运行时容器。它保存地图尺寸、地块集合和起始城市坐标。

地块通过 `col:row` 形式的 key 存储，例如 `12:8`。这样可以在 GDScript 字典中稳定索引，同时避免把坐标对象作为 key 带来的序列化问题。

### TileState

`TileState` 表示单个世界地块。当前保留两类信息：

- 原始环境字段：`elevation`、`rainfall`、`temperature`、`ruggedness`、`moisture`。
- 推导结果：`terrain_id`、`features`、`has_river`、`river_flow`、`river_strength`。
- 渲染辅助数据：`river_path_points`、`ridge_path_points`。

这种结构允许后续继续扩展，不需要把所有地貌都硬编码成互斥类型。例如一个地块可以同时是 `grassland`，带有 `forest`，并且有 `river` 穿过。

`river_path_points` 和 `ridge_path_points` 使用地块内部归一化坐标，范围为 `0.0` 到 `1.0`。这样渲染层可以根据当前 tile 像素尺寸转换为实际绘制坐标，同时不会把逻辑数据绑定到具体分辨率。

## 地图生成流程

地图生成入口仍是 `MapLoader.load_generated_map()`。`MapLoader` 读取 `map_generation_config.json` 后构建 `MapGenerationConfig`，调用 `MapGenerator.generate(config)` 生成 `MapState`，再通过 `MapGenerationDebugWriter` 写入 `user://generated_map.json`，方便调试和复现。

当前生成流程如下：

1. 读取配置中的地图尺寸、种子和生成参数。
2. 使用确定性随机数生成基础环境场。
3. 用中心大陆偏置提高地图中心区域海拔，边缘更容易形成海洋。
4. 基于海拔和扰动值生成降水、温度、起伏度和湿度。
5. 从高海拔点生成河流，让水流沿低处扩展。
6. 根据环境字段推导基础地形和附加特征。
7. 为河流生成地块内部路径点。
8. 为相邻山地生成连续脊线路径点。
9. 创建起始城市标记，并写入生成结果文件。

生成结果依赖种子，因此同一配置可以生成稳定地图。

## 地貌推导规则

基础地形和特征不是相互独立随机生成，而是从环境字段推导。

### 基础地形

`terrain_id` 当前用于渲染底色和基本通行规则：

| 地形 | 推导依据 |
| --- | --- |
| `ocean` | 海拔低于海洋阈值。 |
| `plains` | 默认陆地，温和环境。 |
| `grassland` | 降水较高、环境较湿润。 |
| `desert` | 降水低且温度较高。 |
| `tundra` | 温度较低。 |

### 附加特征

`features` 是数组，允许一个地块拥有多个特征：

| 特征 | 推导依据 |
| --- | --- |
| `mountain` | 高海拔且起伏度高，代表海拔突然拔高区域。 |
| `hill` | 陆地起伏明显但没有达到山脉程度。 |
| `lake` | 低海拔陆地且有河流汇入，代表局部蓄水。 |
| `swamp` | 高湿度、低洼或有河流影响的陆地区域。 |
| `forest` | 湿润陆地，且不在高山区域。 |

河流不是边缘属性，而是地块内部属性，由 `has_river`、`river_flow` 和 `river_path_points` 表示。这样后续进入局部地图时，可以在该地块内部生成实际河道。

湖泊地块中的河流线只进入湖泊中心，不继续穿过湖面。湖泊本身由地貌纹理层绘制为不规则水面斑块。

## 交通与邻接

当前地图使用方形格，每个地块有 8 个邻居，包括上下左右和四个对角方向。

`MapQueryService` 提供以下查询能力：

- `get_neighbors(coord)`：返回周围 8 个合法邻居。
- `get_distance(a, b)`：使用 Chebyshev distance，适配 8 方向移动。
- `get_tiles_in_radius(center, radius)`：返回指定半径内的地块。
- `get_movement_cost(from, to)`：根据两个相邻地块计算移动成本。

移动成本是动态计算的，不提前缓存。当前规则强调交通可达程度：

| 条件 | 影响 |
| --- | --- |
| 非相邻地块 | 不可达，返回 `-1`。 |
| 海洋或湖泊 | 当前不可达，返回 `-1`。 |
| 对角移动 | 成本增加。 |
| 山脉 | 成本大幅提高，但当前仍允许通行。 |
| 丘陵、森林、沼泽 | 成本提高。 |
| 河流 | 成本略微提高。 |

后续如果加入道路、桥梁、航运或区域控制，可以在 `MapQueryService` 上扩展，而不需要改动渲染层。

## 渲染设计

地图场景使用 `MapRoot.tscn` 作为入口。`MapRoot` 负责把 `MapState` 渲染到 Godot 节点上。

当前渲染分为多个层：

- `TileMapLayer`：绘制基础地形底色。
- `RiverOverlay`：绘制河流线条。
- `FeatureOverlay`：绘制山脉、丘陵、森林、沼泽、湖泊纹理。
- `DebugSymbolOverlay`：只在选中地块显示旧版符号，用于调试。
- `MapOverlay`：继续绘制选中框、城市标记和边界等简单覆盖信息。

`TileMapLayer` 的 TileSet 目前由代码在运行时创建，用简单颜色区分基础地形。这符合当前原型阶段的目标：先验证地图生成和交互逻辑，不提前投入美术资产。

`RiverOverlay` 使用 `river_path_points` 绘制地块内部曲线。路径点是归一化坐标，会在绘制时转换为 tile 本地像素位置。线宽由 `river_strength` 决定，远景缩放时只显示较强的主河流。

`FeatureOverlay` 使用程序化图形表达多种地貌：

- 山脉根据 `ridge_path_points` 绘制跨格连续脊线，并叠加浅色高光。
- 丘陵用短弧线表现起伏。
- 森林用半透明绿色斑块表现植被覆盖。
- 沼泽用蓝绿色半透明斑块表现湿地。
- 湖泊用不规则蓝色水面斑块表现。

远景缩放时，细节纹理会隐藏，只保留基础地形和主河流。当前阈值硬编码在 overlay 脚本中，后续如果需要频繁调参，再迁移到配置文件。

调试符号切换入口由 UI 模块提供。`MapRoot` 暴露 `toggle_debug_symbols()`，由上层 `core_root.gd` 在收到 UI 请求后调用。默认显示纹理和选中地块旧符号，切换后只显示新纹理。

这种拆分让基础地形和动态信息保持独立。后续替换正式 TileSet 或加入更多调试层时，不需要重写地图状态逻辑。

## 输入与摄像机

地图输入分为两个脚本：

- `MapInputController`：处理选择地块。
- `MapCameraController`：处理视角移动和缩放。

### 地块选择

左键点击时，输入控制器会把屏幕坐标转换成地图格坐标。由于摄像机可能已经平移或缩放，转换不能直接使用屏幕坐标。

当前流程是：

1. 使用 `TileMapLayer.get_canvas_transform().affine_inverse()` 把屏幕坐标转回世界坐标。
2. 使用 `TileMapLayer.to_local()` 转成 TileMapLayer 本地坐标。
3. 使用 `TileMapLayer.local_to_map()` 得到格子坐标。
4. `MapRoot` 更新选中覆盖层，并发出 `tile_selected(tile)`。

这个流程确保缩放后点击选中的仍然是鼠标下方的地块。

### 摄像机控制

`MapCameraController` 当前实现：

- 右键按住拖拽移动视角。
- 按住 Ctrl 后滚轮缩放。
- 缩放以鼠标位置为中心。
- 缩放范围限制在 `0.25x` 到 `3.0x`。
- 摄像机位置限制在地图边界附近，避免拖出地图太远。

## 与其他模块的关系

地图模块当前是原型中最先落地的运行时模块。它暂时不依赖城市、科技、UI 或存档模块。

未来关系预计如下：

- 城市模块会读取地图中的起始城市坐标，并可能影响地块产出。
- UI 模块会展示当前选中地块的环境字段、地貌、交通成本等信息。
- 数据模块会把 terrain、feature、movement rule 等配置从脚本中逐步外移。
- 存档模块会保存 `MapState` 或生成配置与玩家改动。
- 局部地图模块会根据 `TileState` 的环境字段生成 RimWorld 风格的小世界。

## 当前限制

- 还没有进入单个地块后的局部地图生成。
- 地形视觉仍是程序生成的简单色块和 overlay 标记，不是正式美术。
- 河流、山脉、森林、沼泽、湖泊纹理仍是程序化占位美术，不是正式素材。
- `user://generated_map.json` 是运行时调试输出，不进入仓库版本控制。
- movement cost 规则仍然较粗糙，还没有道路、桥梁、季节、单位类型等差异。
- 山脉当前成本很高但仍可通行，未来可以按单位类型或科技条件改成不可通行。
- terrain、feature 和渲染阈值的配置仍有一部分写在脚本中，后续应逐步迁移到数据配置。

## 后续扩展方向

地图模块后续最重要的扩展不是增加更多随机装饰，而是让生成字段服务于玩法系统。优先方向包括：

- 把地块产出从环境字段中推导出来，供城市模块使用。
- 增加选中地块的信息面板，帮助验证生成结果。
- 把 movement rule 数据化，支持道路、桥梁和不同移动单位。
- 增加局部地图生成入口，让世界地块可以展开为独立小地图。

## 局部地图入口

当前已接入基础 `local_map` 流程：玩家双击世界地图地块后，`MapRoot` 发出 `tile_enter_requested(tile)`，由 `CoreRoot` 调用 `LocalMapService.load_or_generate(tile)` 并切换到 `LocalMapRoot`。

大地图节点在进入局部地图时只隐藏不释放，因此返回后相机位置、缩放和选中地块状态会保留。局部地图详细设计见 `doc/documents/local_map.md`。
- 将当前运行时 TileSet 替换为可维护的资源文件和正式占位素材。
