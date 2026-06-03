# map 模块设计

## 目标

`map` 模块负责随机地图生成、正方形网格坐标转换、地块运行时状态维护，以及地图的 2D 俯视渲染。

首版目标：

- 默认生成 `40 x 20` 地图，尺寸可配置
- 使用正方形地块紧密排列
- 使用 seed 生成可复现地图
- 使用海拔、降水、温度和起伏派生草地、平原、荒漠、苔原、森林、丘陵、河流、海洋、山脉、湖泊、沼泽
- 支持地块选中与信息查询
- 支持城市边界高亮
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

- `40 x 20` 的地图文件更适合按行列组织
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
var terrain_id: String
var elevation: float
var rainfall: float
var temperature: float
var ruggedness: float
var moisture: float
var has_river: bool
var river_flow: Vector2i
var river_strength: float
var features: PackedStringArray
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
2. 使用配置中的 `seed` 生成海拔、降水和温度数值场。
3. 从高海拔区域生成河流，让河流沿低海拔方向流向海洋或低地。
4. 根据海拔阈值派生海洋。
5. 根据局部海拔落差派生山脉和丘陵。
6. 根据低海拔和河流汇入派生湖泊。
7. 根据降水、温度和低洼程度派生荒漠、森林和沼泽。
8. 创建 `MapState` 和 `TileState` 集合。
9. 将完整生成结果写入 `generated_output_path`。
10. 将 `MapState` 交给渲染层显示。

### 地图渲染流程

设计决策：

- 地形底图采用 `TileMapLayer`
- 选中框、边界、城市标记采用独立覆盖层

理由：

- `TileMapLayer` 适合规则性正方形地形绘制
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
  - 鼠标点击和选中逻辑

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
- [x] 实现海拔/降水/温度数值场
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
- [x] 实现 `MapQueryService`
- [x] 实现 `MapInputController`
