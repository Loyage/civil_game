# local_map 渲染设计计划

## 目标

小地图首版渲染目标是快速、清晰地展示 `sub_map_size x sub_map_size` 地格的高度、水体、河流和基础地貌，不追求精细美术。

## 场景规划

首版新建独立场景：

```text
game/scenes/local_map/LocalMapRoot.tscn
game/scripts/local_map/local_map_root.gd
```

理由：

- 大地图和小地图职责不同
- 小地图以可配置边长的地格高度图为核心，不适合复用当前大地图 `TileMapLayer`
- 独立场景便于上层 `core_root.gd` 切换显示和管理返回逻辑
- 小地图根节点使用 `CanvasLayer`，避免被大地图 `Camera2D` 的 canvas transform 影响

## 首版渲染方式

首版已实现：

```text
每个地格 1 像素，生成 `ImageTexture` 后用 `TextureRect` 放大显示
```

渲染结果是 `sub_map_size x sub_map_size` 地貌图：

- `water_flags` 显示为水色
- 河流地格显示为更亮或更饱和的蓝色
- 陆地优先按 `terrain_flags` 显示雪地、湿地、森林、岩石、沙地、草地
- 资源地格优先按资源定义颜色显示
- 如果旧缓存缺少 `terrain_flags`，回退到高度颜色

当前已支持缩放和拖拽；如果后续需要更高保真，再考虑每地格多像素渲染。

## 渲染数据输入

- `LocalMapState.heights`
- `LocalMapState.water_flags`
- `LocalMapState.river_flags`
- `LocalMapState.terrain_flags`
- `LocalMapState.slope_values`
- `LocalMapState.resource_instances`

## 交互

当前交互：

- 从大地图双击地块进入小地图
- 小地图界面提供返回大地图按钮
- 小地图内右键拖动视图
- 小地图内按住 Ctrl 后滚轮缩放
- 小地图内左键点击地格后显示选中标记
- 鼠标悬停地格时只显示预览标记，不更新左下角信息面板
- 返回后保留大地图当前相机状态
- 再次进入同一地块时从缓存加载，不重新生成

## 性能注意

每个地格 1 像素可以直接生成 `ImageTexture`：

1. 创建 `Image`
2. 遍历高度数组写入像素
3. 创建或更新 `ImageTexture`
4. 用 `TextureRect` 或 `Sprite2D` 显示

避免首版使用 `65536` 个独立节点。

## Checklist

- [x] 设计 `LocalMapRoot.tscn`
- [x] 设计 `local_map_root.gd`
- [x] 设计高度到颜色的映射
- [x] 设计水体颜色规则
- [x] 设计河流颜色规则
- [x] 设计地貌标签颜色规则
- [x] 设计资源颜色规则
- [x] 设计 `ImageTexture` 生成流程
- [x] 设计返回大地图按钮
- [x] 设计保留大地图相机状态
- [x] 设计重复进入缓存加载流程
- [x] 设计右键拖动和 Ctrl 滚轮缩放
- [x] 设计地格点击选中和悬停预览
