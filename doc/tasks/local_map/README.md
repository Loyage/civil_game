# local_map 模块工作计划

## 目标

`local_map` 模块负责生成和展示大地图单个地块内部的局部地图。大地图中的每个地块 `tile`，进入后对应一个 `sub_map_size x sub_map_size` 的小地图；小地图中的每个单位称为地格 `cell`。

首版目标：

- 每个大地图地块都可以按需生成一个 `sub_map_size x sub_map_size` 小地图
- 小地图在第一次进入地块前不生成、不缓存、不渲染
- 第一次进入时先查缓存，有缓存则加载，无缓存则按种子生成并写入缓存
- 相同世界种子和相同地块坐标必须生成完全一致的小地图
- 相邻地块的小地图边缘视觉连续，河流入口/出口位置和宽度连续
- 河流入口/出口由大地图指定，小地图内部路径独立寻路生成
- 大地图和小地图都使用 `-256..256` 高度语义
- 小地图地格高度使用 `-256..256` 整数范围
- 小地图平均高度可用于校验大地图摘要，但当前不反向改写大地图地块

## 命名约定

- 大地图单位：地块 `tile`
- 小地图单位：地格 `cell`
- 大地图状态：`MapState`
- 小地图状态：`LocalMapState`
- 大地图坐标：`tile offset(col, row)`
- 小地图内部坐标：`cell(x, y)`，范围 `0..sub_map_size - 1`

## 目录规划

```text
doc/tasks/local_map/README.md
doc/tasks/local_map/generation.md
doc/tasks/local_map/data.md
doc/tasks/local_map/rendering.md
doc/tasks/local_map/integration.md
doc/tasks/local_map/testing.md
doc/tasks/local_map/progress.md
```

## 首版里程碑

### M0 - 数据结构和缓存协议

- 定义 `LocalMapState`
- 定义 `LocalCellState`
- 定义缓存文件版本格式
- 定义世界种子和地块坐标推导小地图种子的规则

### M1 - 生成算法

- 实现基于全局坐标噪声的高度采样
- 保证小地图严格归属于对应大地图地块，并保持相邻地块边界视觉连续
- 接入大地图河流入口/出口
- 生成水、河流、坡度等基础派生数据

### M2 - 场景与渲染

- 新建 `LocalMapRoot.tscn`
- 使用 `sub_map_size x sub_map_size` 像素高度图进行首版渲染
- 实现进入和返回大地图的 UI/上层调度接口

### M3 - 验证和回归

- 验证同种子同地块生成一致
- 验证相邻地块边界视觉连续和河流入口/出口连续
- 验证缓存版本不兼容时不会读取错误数据

## 风险

- 如果直接以小地图平均高度反写大地图，会让摘要生成和显示链路耦合过深；当前保持“小地图校验大地图摘要”，不做反向覆盖。
- 小地图地格数量为 `sub_map_size * sub_map_size`。如果每个地格都存完整对象，内存和存档体积会快速膨胀；首版需要优先考虑紧凑数组结构。
- JSON 对完整高度数组不适合长期使用，当前缓存已落为 Godot 二进制 Variant。
- 河流跨地块连续不仅需要边界位置一致，还需要水流方向、坡度和河床高度合理，否则会出现视觉连续但逻辑不通的情况。

## Checklist

- [x] 创建 `LocalMapState` 设计
- [x] 创建 `LocalCellState` 设计
- [x] 设计小地图缓存协议
- [x] 设计小地图种子推导规则
- [x] 设计全局高度采样算法
- [x] 设计河流入口/出口约束
- [x] 设计 `LocalMapRoot.tscn`
- [x] 设计大地图进入小地图流程
- [x] 设计返回大地图流程
- [ ] 设计验证方案
