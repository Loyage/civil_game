# local_map 生成设计计划

## 目标

小地图生成器需要在不提前生成所有地块内部结构的前提下，保证任意地块第一次进入时都能生成稳定、可复现、与邻居衔接合理的 `sub_map_size x sub_map_size` 小地图。

## 生成输入

- 世界种子 `world_seed`
- 大地图地块坐标 `tile_col/tile_row`
- 大地图地块状态 `TileState`
- 大地图相邻地块信息
- 大地图河流方向 `river_flow`
- 大地图河流路径点 `river_path_points`
- 大地图山脉脊线路径点 `ridge_path_points`

## 种子策略

当前实现使用：

```text
local_seed = hash(world_seed, tile_col, tile_row)
```

用途划分：

- 全局高度连续性：主要依赖全局地格坐标采样，不能只依赖单地块 seed
- 局部细节扰动：使用 `local_seed`
- 地貌派生随机性：使用 `local_seed` 加不同 salt

## 坐标策略

小地图内部坐标：

```text
cell_x: 0..sub_map_size - 1
cell_y: 0..sub_map_size - 1
```

全局地格坐标实际实现为共享边界步长：

```text
global_cell_x = tile_col * (sub_map_size - 1) + cell_x
global_cell_y = tile_row * (sub_map_size - 1) + cell_y
```

原因是小地图的边界地格需要被相邻地块复用：A 地块 `cell(sub_map_size - 1, y)` 与右侧 B 地块 `cell(0, y)` 必须采样同一个全局坐标。使用 `sub_map_size - 1` 步长可以保证共享边界高度逐格相等。

实现上，共享边界只使用全局高度场。大地图地块海拔、山脉、水体等宏观约束通过 `edge_weight` 从边界向内部渐入，避免相邻地块因为各自宏观属性不同而破坏边界高度一致性。河流可以在边界设置 `river_flags`，但不会改写最外圈高度。

## 高度范围

小地图每个地格高度是整数：

```text
-256..256
```

大地图地块与小地图地格当前都使用同一套 `-256..256` 高度语义，阈值、渲染和 UI 已按这一语义工作。

## 高度生成思路

当前实现分层：

1. 使用 `WorldSkeletonGenerator` 按当前地图配置和 seed 重建世界骨架。
2. 使用 `WorldFunctionSampler.sample_height(global_x, global_y)` 逐地格采样高度。
3. 全局坐标采用 `tile_col * (sub_map_size - 1) + cell_x` / `tile_row * (sub_map_size - 1) + cell_y`，保证共享边界高度一致。
4. 山脉通过 `WorldFunctionSampler` 的山脉影响自然抬高，不额外沿 `ridge_path_points` 强化。
5. 河流约束根据大地图粗路径生成小地图地格级细化路径，并按动态宽度/深度压低河床高度。
6. 水体按 `height < 0` 派生。
7. 坡度按周围 8 邻域最大高度差派生。

## 河流生成

大地图指定河流粗路径，小地图内部路径按地格级重新细化：

- 入口和出口由大地图 `river_path_points`、`river_flow` 和邻接关系决定。
- 大地图 `river_path_points` 会被转换为小地图内的控制点。
- 小地图内部按相邻控制点分段执行 8 邻域寻路，最终拼接成完整河段。
- 寻路成本优先选择低处、缓坡和接近目标方向的地格。
- 寻路允许低成本上坡，用后续河流切割模拟河道切开局部洼地或低矮阻挡。
- 高海拔山体仍有额外成本，避免河流无代价穿越山脊。
- 河流宽度默认从 `3` 逐渐增长到最大 `12`，并受大地图 `river_strength` 轻微影响。
- 河床切割深度随河流宽度和下游距离增长，切割数据保存为 `river_carve_points`。
- 最外圈边界地格只标记河流，不改写高度，保留相邻小地图共享边界高度一致。
- 湖泊地块允许河流进入低洼水体后停止。

## 河流切割数据

`LocalMapState.river_carve_points` 保存细化后的河流切割轨迹。每个切割点记录：

- `cell_x`
- `cell_y`
- `global_x`
- `global_y`
- `width`
- `depth`

该数据不是完整世界级图层，只保存当前已生成小地图内的河流切割轨迹，后续可以用于调试、局部存档和更细的河流渲染。

## 水体规则

首版采用：

```text
height < 0 => water
```

后续可以引入 `sea_level` 配置，但首版默认海平面为 `0`。

## 大地图海拔关系

当前不立即强制大地图海拔等于小地图平均值。首版策略：

- 大地图按 `WorldFunctionSampler` 生成低分辨率摘要
- 小地图按同一 `WorldFunctionSampler` 对更密集的全局坐标采样
- 生成后计算 `average_height`
- 后续可以用小地图平均值校验大地图摘要，但当前不反向改写大地图地块

## Checklist

- [x] 设计 `world_seed + tile_col/tile_row` hash 规则
- [x] 设计全局地格坐标采样函数
- [x] 接入 `WorldFunctionSampler` 逐地格采样高度
- [x] 将小地图边长改为 `sub_map_size` 可调参数
- [x] 设计小地图高度生成层级
- [x] 明确山脉只通过全局高度采样自然体现
- [x] 设计河流入口/出口映射规则
- [x] 设计小地图河流寻路成本
- [x] 设计河床压低规则
- [x] 设计水体派生规则
- [x] 设计平均高度统计规则
- [x] 升级小地图缓存版本
- [x] 设计大地图粗路径到小地图细化路径的输入输出
- [x] 设计地格级河流寻路成本
- [x] 设计河流切割点、宽度和深度数据结构
- [x] 设计河流切割后的缓存版本升级
