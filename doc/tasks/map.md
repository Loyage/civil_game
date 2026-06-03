# map 模块设计

## 目标

`map` 模块负责固定地图的加载、六边形坐标转换、地块运行时状态维护，以及地图的 2D 俯视渲染。

首版目标：

- 加载 `40 x 20` 固定地图
- 支持草地、平原、森林、丘陵、河流、海洋、山脉
- 支持地块选中与信息查询
- 支持城市边界高亮
- 为未来扩展迷雾、单位、随机地图保留结构

## 职责边界

### 负责

- 地图文件解析
- 地块运行时状态构建
- 六边形邻接关系查询
- 渲染地形与覆盖层
- 对外提供地块查询接口

### 不负责

- 城市增长
- 科技结算
- 存档文件写入
- 产出公式本身
- UI 面板排版

## 核心数据结构

### 坐标设计决策

为了兼顾“固定矩形地图编辑体验”和“六边形邻接计算简洁性”，采用双坐标方案：

- 地图文件存储：`offset(col, row)`
- 运行时逻辑：`axial(q, r)`

说明：

- `40 x 20` 的地图文件更适合按行列组织
- 六边形邻居、距离、范围计算用 `axial` 更直接

### `OffsetCoord`

```gdscript
class_name OffsetCoord

var col: int
var row: int
```

### `HexCoord`

```gdscript
class_name HexCoord

var q: int
var r: int
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
var coord: HexCoord
var terrain_id: String
var has_forest: bool
var has_hill: bool
var has_river: bool
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

### 地图加载流程

1. `MapLoader` 从 `game/data/maps/` 读取固定地图 JSON。
2. 按 `offset` 行列遍历原始数据。
3. 转换为运行时 `HexCoord`。
4. 生成 `TileState` 集合。
5. 创建 `MapState`。
6. 将 `MapState` 交给渲染层显示。

### 地图渲染流程

设计决策：

- 地形底图采用 `TileMapLayer`
- 选中框、边界、城市标记采用独立覆盖层

理由：

- `TileMapLayer` 适合规则性六边形地形绘制
- 覆盖层独立后，后续边界、路径、选中效果不需要反复改底图

渲染层建议：

- `TerrainLayer`
- `BorderOverlay`
- `SelectionOverlay`
- `CityMarkerLayer`

### 选中地块流程

1. 玩家点击地图。
2. `MapInputController` 计算点击位置对应的地块。
3. 更新当前 `selected_tile_key`。
4. 发出 `selected_tile_changed`。
5. `ui` 刷新地块信息面板。

### 邻居查询流程

`MapQueryService` 提供：

- `get_tile(tile_key)`
- `get_neighbors(tile_key)`
- `get_distance(a, b)`
- `get_tiles_in_radius(center, radius)`

这些查询能力是边界扩张、工作地块筛选和未来单位系统的基础。

## 场景/脚本拆分

建议文件：

```text
game/scenes/map/MapRoot.tscn
game/scenes/map/HexSelectionOverlay.tscn
game/scripts/map/map_root.gd
game/scripts/map/map_loader.gd
game/scripts/map/map_state.gd
game/scripts/map/tile_state.gd
game/scripts/map/hex_coord.gd
game/scripts/map/offset_coord.gd
game/scripts/map/hex_layout.gd
game/scripts/map/map_query_service.gd
game/scripts/map/map_input_controller.gd
```

建议职责：

- `MapRoot.tscn`
  - 地图容器场景
  - 内含 `TileMapLayer` 和覆盖层
- `hex_layout.gd`
  - 坐标转换和像素定位
- `map_loader.gd`
  - 固定地图文件解析
- `map_query_service.gd`
  - 邻居和范围查询
- `map_input_controller.gd`
  - 鼠标点击和选中逻辑

## 输入输出

### 输入

- 来自 `data` 的地形定义
- 固定地图 JSON
- 来自 `core` 的新游戏/读档指令
- 来自 `city` 的边界归属更新

### 输出

- `MapState`
- 当前选中的 `tile_key`
- 可供 `city` 使用的邻居/范围查询接口
- 可供 `ui` 读取的地块显示数据

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
- 现在是固定地图，但如果地图文件格式写死，未来切换随机地图会很痛苦

## 子任务 checklist

- [x] 定义 `OffsetCoord`
- [x] 定义 `HexCoord`
- [x] 实现 `offset -> axial` 转换
- [x] 实现 `axial -> 像素坐标` 转换
- [x] 定义 `TileState`
- [x] 定义 `MapState`
- [x] 实现 `MapLoader`
- [x] 设计固定地图 JSON 格式
- [x] 创建 `MapRoot.tscn`
- [x] 接入 `TileMapLayer` 地形渲染
- [x] 实现边界覆盖层
- [x] 实现选中覆盖层
- [x] 实现城市标记层
- [x] 实现 `MapQueryService`
- [x] 实现 `MapInputController`
