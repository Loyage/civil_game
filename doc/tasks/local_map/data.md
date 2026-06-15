# local_map 数据设计计划

## 目标

小地图数据需要支持按需生成、缓存、加载和版本兼容，同时避免每个地格都用重对象导致内存和存档膨胀。

## 核心数据结构

### `LocalMapState`

建议字段：

```gdscript
class_name LocalMapState

var version: int
var world_seed: int
var tile_key: String
var tile_col: int
var tile_row: int
var width: int
var height: int
var heights: PackedInt32Array
var water_flags: PackedByteArray
var river_flags: PackedByteArray
var terrain_flags: PackedInt32Array
var slope_values: PackedInt32Array
var river_carve_points: Array
var resource_instances: Array
var average_height: int
```

说明：

- `width` 和 `height` 来自地图生成配置 `sub_map_size`
- `heights` 长度为 `width * height`
- 一维索引：`index = y * width + x`
- `water_flags`、`river_flags` 使用紧凑数组表达派生状态
- `water_flags` 只表示与大地图海洋掩码一致的水域：当前大地图地块属于 `skeleton.ocean_tiles`，且地格高度低于 `skeleton.sea_level`
- `terrain_flags` 使用 bitmask 表示多地貌标签：草地、森林、湿地、岩石、沙地、雪地
- `river_carve_points` 保存已生成河段的切割点、宽度和深度，不保存完整世界级河流切割图层
- `resource_instances` 保存由大地图 `resource_ids` 派生的小地图资源位置；当前不写入缓存，缓存命中后重新派生

### `LocalCellState`

`LocalCellState` 不建议作为所有地格常驻对象。它更适合作为查询某个地格时临时组装的视图对象。代码中由 `LocalMapState` 通过 preload 脚本引用创建，避免依赖 Godot 全局 `class_name` 注册顺序。

建议字段：

```gdscript
class_name LocalCellState

var x: int
var y: int
var global_x: int
var global_y: int
var height: int
var is_water: bool
var has_river: bool
var terrain_flags: int
var resources: Array
var slope: int
```

## 缓存策略

缓存位置已实现为：

```text
user://local_maps/{seed}/v{version}/{tile_key}.bin
```

缓存加载流程：

1. 进入大地图地块。
2. 根据世界种子和 `tile_key` 计算缓存路径。
3. 如果缓存存在并且版本兼容，加载缓存。
4. 如果缓存不存在，生成小地图并写入缓存。
5. 如果缓存版本不兼容，保留旧文件但忽略，写入新版本目录或新版本文件。

## 缓存内容

缓存当前包含：

- 版本号
- 世界种子
- `tile_key`
- 地块坐标
- 小地图尺寸
- 生成配置摘要
- 高度数组
- 水体派生结果
- 河流派生结果
- 地貌 bitmask 派生结果
- 坡度派生结果
- 河流切割点、宽度和深度
- 平均高度

资源实例当前不写入缓存。

## 存储格式

首版已采用 Godot `FileAccess` 二进制写入：

- 文件头写入 `CLM1` magic。
- 文件头后写入 `CACHE_VERSION`。
- 主体使用 `store_var()` 写入 Dictionary，包含 `PackedInt32Array` 与 `PackedByteArray`。

这样保留二进制缓存方向，同时避免手写有符号整数数组读写导致负高度歧义。

## 缓存版本

建议字段：

```text
version: int
generator_version: string
config_hash: string
```

不兼容策略：

- 不删除旧缓存
- 忽略旧缓存
- 写入新版本目录：`v{version}`

## Checklist

- [x] 设计 `LocalMapState`
- [x] 设计临时查询用 `LocalCellState`
- [x] 设计一维索引规则
- [x] 设计缓存路径规则
- [x] 设计缓存版本字段
- [ ] 设计生成配置摘要字段
- [x] 设计高度数组存储格式
- [x] 设计 water/river/slope 派生数组
- [x] 设计 terrain_flags bitmask 派生数组
- [x] 设计 resource_instances 派生数组
- [x] 设计版本不兼容处理流程
- [x] 设计缓存读写接口
