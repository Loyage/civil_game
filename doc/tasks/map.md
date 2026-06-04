# map 模块设计

## 目标

`map` 模块负责随机地图生成、正方形网格坐标转换、地块运行时状态维护，以及地图的 2D 俯视渲染。

首版目标：

- 默认生成 `40 x 40` 方形大地图，尺寸由 `big_map_size` 配置
- 使用正方形地块紧密排列
- 使用 seed 生成可复现地图
- 使用 `-256..256` 高度、温度、湿度、河流和山脉骨架派生草地、平原、荒漠、苔原、森林、丘陵、河流、海洋和山脉
- 支持地块选中与信息查询
- 支持城市边界高亮
- 支持右键拖拽平移地图视图
- 支持按住 Ctrl 后使用滚轮缩放地图视图
- 支持程序化河流、山脉、丘陵、森林、沼泽、湖泊纹理渲染
- 支持纹理渲染与选中地块调试符号叠加显示
- 支持周围 8 格邻接和动态交通成本计算
- 为未来扩展迷雾、单位、随机地图保留结构

## 职责边界

### 负责

- 地图生成配置解析
- 可复现随机地图生成
- 地块运行时状态构建
- 正方形网格邻接关系查询
- 相邻地块交通成本计算
- 渲染地形与覆盖层
- 地图查看相机的平移与缩放
- 对外提供地块查询接口

### 不负责

- 城市增长
- 科技结算
- 存档文件写入
- 产出公式本身
- UI 面板排版

## 核心数据结构

### 坐标设计决策

当前实现使用正方形紧密排列地图，运行时查询与渲染以 `offset(col, row)` 为准。

- 地图配置存储：`width / height / seed / thresholds`
- 运行时逻辑：`offset(col, row)`
- 地块 key：`col:row`

说明：

- 方形 `big_map_size x big_map_size` 配置便于后续按全局坐标展开小地图
- 邻居查询采用周围 8 个方向
- 对角移动允许，但交通成本更高

### `OffsetCoord`

```gdscript
class_name OffsetCoord

var col: int
var row: int
```

### `TileStaticData`

来自 `data` 模块的静态定义。

```gdscript
class_name TileStaticData

var terrain_id: String
var base_food: int
var base_production: int
var base_gold: int
var tags: PackedStringArray
```

### `TileState`

```gdscript
class_name TileState

var tile_key: String
var offset: OffsetCoord
var biome: String
var elevation: int
var avg_height: int
var min_height: int
var max_height: int
var temperature: float
var moisture: float
var has_river: bool
var river_flow: Vector2i
var river_strength: float
var river_path_points: PackedVector2Array
var ridge_path_points: PackedVector2Array
var terrain_tags: PackedStringArray
var owner_city_id: String
var is_city_center: bool
```

### `MapState`

```gdscript
class_name MapState

var width: int
var height: int
var tiles_by_key: Dictionary
```

建议：

- `tile_key` 使用稳定字符串，例如 `q:r`
- 所有模块使用同一个 `tile_key`，避免频繁传对象引用

## 主要流程

### 地图生成流程

1. `MapLoader` 从 `game/data/maps/map_generation_config.json` 读取生成配置。
2. `MapGenerator` 调用 `WorldSkeletonGenerator` 生成全局山脉折线和主河流折线。
3. `BigMapSummaryGenerator` 对每个大地图地块内部执行摘要采样。
4. `WorldFunctionSampler` 基于全局坐标采样高度、温度、湿度、河流强度和 biome。
5. 根据采样结果创建 `MapState` 和 `TileState` 集合。
6. 为河流生成地块内部归一化路径点。
7. 为山脉生成地块内部归一化脊线路径点。
8. 将完整生成结果写入 `generated_output_path`。
9. 将 `MapState` 交给渲染层显示。

### 地图渲染流程

设计决策：

- 地形底图采用 `TileMapLayer`
- 河流、地貌细节、调试符号、选中框、边界、城市标记采用独立覆盖层

理由：

- `TileMapLayer` 适合规则性正方形地形绘制
- 覆盖层独立后，后续边界、路径、选中效果不需要反复改底图
- 河流、山脉等程序化纹理需要独立于 TileSet 的运行时绘制能力

渲染层建议：

- `TerrainLayer`
- `RiverOverlay`
- `FeatureOverlay`
- `DebugSymbolOverlay`
- `BorderOverlay`
- `SelectionOverlay`
- `CityMarkerLayer`

细节层规则：

- `RiverOverlay` 根据 `river_path_points` 绘制跨格连续河流线条，线宽由 `river_strength` 决定
- `FeatureOverlay` 根据 `ridge_path_points` 绘制山脉脊线，并绘制丘陵、森林、沼泽、湖泊纹理
- 远景缩放时只显示基础地形和主河流，近景显示全部细节纹理
- `DebugSymbolOverlay` 只在选中地块半透明叠加旧符号，用于验证生成结果
- `Texture / Symbol` 按钮由 `ui` 模块提供，`core_root.gd` 调用 `MapRoot.toggle_debug_symbols()` 执行切换

### 选中地块流程

1. 玩家点击地图。
2. `MapInputController` 通过当前画布变换将屏幕坐标转换为 `Camera2D` 缩放/平移后的世界坐标。
3. `MapInputController` 再将世界坐标转换为 `TileMapLayer` 局部坐标和地图格坐标。
4. 更新当前 `selected_tile_key`。
5. `MapRoot` 发出 `tile_selected(tile)`。
6. 上层 `core_root.gd` 接收信号并调度 `ui` 刷新地块信息面板。

### 地图查看交互流程

1. `MapCameraController` 作为 `Camera2D` 管理地图视图。
2. 玩家按住鼠标右键拖拽时，地图内容跟随鼠标拖拽方向移动。
3. 相机位置被限制在地图像素范围内，不允许拖出地图边界。
4. 玩家按住 Ctrl 并滚动鼠标滚轮时，以鼠标当前位置为中心缩放。
5. 缩放范围为 `0.25x ~ 3.0x`。
6. 单次滚轮缩放倍率约为 `10%`。
7. 未按 Ctrl 时滚轮输入不触发地图交互。

### 邻居查询流程

`MapQueryService` 提供：

- `get_tile(tile_key)`
- `get_neighbors(tile_key)`
- `get_distance(a, b)`
- `get_tiles_in_radius(center, radius)`
- `get_movement_cost(a, b)`

这些查询能力是边界扩张、工作地块筛选、交通可达性和未来单位系统的基础。

## 场景/脚本拆分

建议文件：

```text
game/scenes/map/MapRoot.tscn
game/scripts/map/map_root.gd
game/scripts/map/map_loader.gd
game/scripts/map/map_state.gd
game/scripts/map/tile_state.gd
game/scripts/map/offset_coord.gd
game/scripts/map/grid_layout.gd
game/scripts/map/map_query_service.gd
game/scripts/map/map_input_controller.gd
game/scripts/map/map_camera_controller.gd
game/scripts/map/river_overlay.gd
game/scripts/map/terrain_detail_overlay.gd
```

建议职责：

- `MapRoot.tscn`
  - 地图容器场景
  - 内含 `TileMapLayer` 和覆盖层
- `grid_layout.gd`
  - 负责正方形网格尺寸、像素定位和边线绘制辅助
- `map_loader.gd`
  - 地图生成配置解析和随机地图生成
- `map_query_service.gd`
  - 8 邻域、范围查询和动态交通成本计算
- `map_input_controller.gd`
  - 基于当前相机视图的鼠标点击和选中逻辑
- `map_camera_controller.gd`
  - 右键拖拽平移
  - Ctrl + 滚轮缩放
  - 地图边界限制
- `river_overlay.gd`
  - 根据地块内部归一化路径点绘制河流
  - 根据缩放级别隐藏弱河流
- `terrain_detail_overlay.gd`
  - 绘制山脉脊线、丘陵线、森林斑块、沼泽斑块和湖泊水面
  - 根据缩放级别隐藏细节纹理

## 输入输出

### 输入

- 来自 `data` 的地形定义
- 地图生成配置 JSON
- 来自 `core` 的新游戏/读档指令
- 来自 `city` 的边界归属更新

### 输出

- `MapState`
- 当前选中的 `tile_key`
- 可供 `city` 使用的邻居/范围查询接口
- 可供 `ui` 读取的地块显示数据
- 平移/缩放后的地图查看视图

## 依赖关系

### 依赖

- `data`
- `core` 的运行时信号

### 被依赖

- `city`
- `ui`
- `save_load`

## 风险

- 如果坐标体系不统一，后续边界和存档会频繁出错
- 河流、山脉、森林、丘陵的渲染表达如果全都耦合在一个图层，维护成本会迅速上升
- 派生地貌规则如果没有清晰阈值，地图会难以调试
- 交通成本是动态计算的，未来如果加入道路/桥梁，可能需要引入边缓存或边覆盖数据

## 子任务 checklist

- [x] 定义 `OffsetCoord`
- [x] 定义组合式 `TileState`
- [x] 实现 seed 可复现地图生成
- [x] 实现高度/温度/湿度连续采样
- [x] 实现河流按地块内部方向延展
- [x] 实现 `offset -> tile_key` 转换
- [x] 实现正方形地块像素定位
- [x] 定义 `MapState`
- [x] 实现 `MapLoader`
- [x] 设计地图生成配置 JSON 格式
- [x] 创建 `MapRoot.tscn`
- [x] 接入 `TileMapLayer` 地形渲染
- [x] 实现派生地貌覆盖层
- [x] 实现边界覆盖层
- [x] 实现选中覆盖层
- [x] 实现城市标记层
- [x] 实现河流程序化线条渲染
- [x] 实现山脉连续脊线渲染
- [x] 实现丘陵线条纹理
- [x] 实现森林半透明斑块纹理
- [x] 实现沼泽半透明斑块纹理
- [x] 实现湖泊不规则水面斑块
- [x] 实现远景隐藏细节纹理
- [x] 实现选中地块调试符号层
- [x] 提供 `MapRoot.toggle_debug_symbols()` 供 UI 调用
- [x] 实现 `MapQueryService`
- [x] 实现 `MapInputController`
- [x] 实现 `Camera2D` 地图查看控制器
- [x] 实现右键拖拽平移
- [x] 实现 Ctrl + 滚轮缩放
- [x] 实现地图视图边界限制
