# local_map 集成设计计划

## 目标

`local_map` 需要和当前大地图、UI、上层调度集成，但不让 `map` 和 `local_map` 直接互相控制。首版继续使用上层 `core_root.gd` 负责调度。

## 模块关系

```text
CoreRoot
  ├── MapRoot
  ├── UIRoot
  └── LocalMapRoot
```

规划职责：

- `MapRoot`：显示大地图，发出地块选择和进入请求
- `UIRoot`：显示 HUD、地块信息、进入/返回按钮
- `LocalMapRoot`：显示某个地块内部的小地图
- `CoreRoot`：调度大地图和小地图的显示切换

## 进入流程

已确认首版进入方式：

```text
双击大地图地块进入小地图
```

流程：

1. 玩家双击大地图地块。
2. `MapRoot` 发出 `tile_enter_requested(tile)`。
3. `CoreRoot` 接收请求。
4. `CoreRoot` 隐藏或暂停 `MapRoot`。
5. `CoreRoot` 调用 `LocalMapService.load_or_generate(tile)`。
6. 如果缓存存在，加载缓存。
7. 如果缓存不存在，生成并写入缓存。
8. `CoreRoot` 将 `LocalMapState` 传给 `LocalMapRoot`。
9. `LocalMapRoot` 渲染小地图。

## 返回流程

首版返回按钮已放在 HUD：

1. 玩家点击 HUD 的返回大地图按钮。
2. `UIRoot` 发出返回请求。
3. `CoreRoot` 隐藏小地图。
4. `CoreRoot` 恢复大地图显示。
5. 大地图保留进入前的相机位置、缩放和选中地块。

## 与大地图数据关系

小地图生成依赖大地图提供：

- `tile_key`
- `tile_col/tile_row`
- `terrain_id`
- `elevation`
- `features`
- `river_flow`
- `river_strength`
- `river_path_points`
- `ridge_path_points`

其中大地图 `elevation` 后续需要从 `0..1` 改为 `-256..256` 整数范围。

## 与 UI 关系

UI 当前已接入：

- 小地图返回按钮
- 当前视图模式显示：大地图 / 小地图
- 小地图地格信息面板

UI 后续仍可新增：

- 进入地块提示或按钮状态
- 小地图地格更多派生字段

但首版确认进入方式是双击，因此进入小地图不依赖按钮。

## Checklist

- [x] 设计 `tile_enter_requested(tile)` 信号
- [x] 设计双击检测流程
- [x] 设计 `CoreRoot` 大地图/小地图切换流程
- [x] 设计 `LocalMapService.load_or_generate(tile)` 接口
- [x] 设计缓存存在时的加载流程
- [x] 设计缓存不存在时的生成流程
- [x] 设计 `LocalMapRoot` 接收 `LocalMapState` 的接口
- [x] 设计返回大地图按钮和信号
- [x] 设计保留大地图相机状态
- [x] 设计小地图地格信息 UI 后续入口
