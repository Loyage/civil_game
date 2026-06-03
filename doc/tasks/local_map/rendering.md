# local_map 渲染设计计划

## 目标

小地图首版渲染目标是快速、清晰地展示 `256 x 256` 地格的高度、水体、河流和基础地貌，不追求精细美术。

## 场景规划

首版新建独立场景：

```text
game/scenes/local_map/LocalMapRoot.tscn
game/scripts/local_map/local_map_root.gd
```

理由：

- 大地图和小地图职责不同
- 小地图以 256x256 地格高度图为核心，不适合复用当前大地图 `TileMapLayer`
- 独立场景便于上层 `core_root.gd` 切换显示和管理返回逻辑

## 首版渲染方式

首版使用：

```text
每个地格 1 像素
```

渲染结果是 `256 x 256` 高度图：

- 高度越高颜色越亮
- `height < 0` 显示为水色
- 河流地格显示为更亮或更饱和的蓝色
- 山脉或高坡区域用灰白色表达

后续如果需要近距离查看，再增加缩放或每地格多像素渲染。

## 渲染数据输入

- `LocalMapState.heights`
- `LocalMapState.water_flags`
- `LocalMapState.river_flags`
- `LocalMapState.slope_values`

## 交互规划

首版需要规划：

- 从大地图双击地块进入小地图
- 小地图界面提供返回大地图按钮
- 返回后保留大地图当前相机状态
- 再次进入同一地块时从缓存加载，不重新生成

## 性能注意

`256 x 256` 每格 1 像素可以直接生成 `ImageTexture`：

1. 创建 `Image`
2. 遍历高度数组写入像素
3. 创建或更新 `ImageTexture`
4. 用 `TextureRect` 或 `Sprite2D` 显示

避免首版使用 `65536` 个独立节点。

## Checklist

- [ ] 设计 `LocalMapRoot.tscn`
- [ ] 设计 `local_map_root.gd`
- [ ] 设计高度到颜色的映射
- [ ] 设计水体颜色规则
- [ ] 设计河流颜色规则
- [ ] 设计山地/高坡颜色规则
- [ ] 设计 `ImageTexture` 生成流程
- [ ] 设计返回大地图按钮
- [ ] 设计保留大地图相机状态
- [ ] 设计重复进入缓存加载流程
