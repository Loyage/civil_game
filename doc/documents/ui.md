# UI Module Design

UI 模块负责展示玩家当前需要读取的信息，并把玩家操作请求发送给上层调度节点。当前版本只实现基础 HUD 和地块信息面板，不提前实现城市、科技、保存/读档的完整业务界面。

## 架构边界

当前运行时结构是：

- `Main.tscn`：临时上层调度场景。
- `core_root.gd`：挂在 `Main` 节点上，负责连接 `MapRoot` 和 `UIRoot`。
- `MapRoot`：地图模块，继续负责加载 `MapState`、渲染地图和发出地块选择信号。
- `UIRoot`：UI 模块，只负责显示和发出 UI 请求。

`map` 和 `ui` 是同级模块，不直接互相调用。二者之间的通信由 `core_root.gd` 调度。

`UIRoot` 的全屏根 `Control` 设置为忽略鼠标输入，避免覆盖整个视口后拦截地图的右键拖拽和 Ctrl+滚轮缩放。实际按钮和面板仍保留自己的输入处理。

## 当前实现范围

首版 UI 包含：

- 顶部 HUD 横条。
- 左下角地块信息卡片。
- 保存、读档、结束回合入口。
- `Texture / Symbol` 地图调试符号切换入口。

首版暂不显示：

- 城市信息面板。
- 科技进度面板。
- 保存/读档弹窗。
- 结束回合后的业务结算。

这些模块对应的运行时代码尚未开始实现，因此 UI 不展示占位面板，避免形成错误的信息结构。

## 场景和脚本

| 文件 | 职责 |
| --- | --- |
| `game/scenes/main/Main.tscn` | 持有同级的 `MapRoot` 和 `UIRoot`。 |
| `game/scripts/core/core_root.gd` | 当前临时上层调度脚本，连接地图信号和 UI 刷新。 |
| `game/scenes/ui/UIRoot.tscn` | UI 容器场景。 |
| `game/scripts/ui/ui_root.gd` | UI 对外接口，转发 HUD 按钮信号并刷新子面板。 |
| `game/scenes/ui/HudBar.tscn` | 顶部 HUD 横条。 |
| `game/scripts/ui/hud_bar.gd` | HUD 控件绑定与按钮信号。 |
| `game/scenes/ui/TileInfoPanel.tscn` | 左下角地块信息卡片。 |
| `game/scripts/ui/tile_info_panel.gd` | 地块信息文本渲染。 |

## HUD 设计

HUD 横贯屏幕顶部，当前显示：

- `回合 1`
- `金币 0`
- 当前选中地块坐标
- `Texture / Symbol`
- `保存`
- `读档`
- `结束回合`

`保存`、`读档`、`结束回合` 当前禁用，悬停提示为“暂未实现”。它们保留入口位置，方便后续接入 `core` 和 `save_load`。

`Texture / Symbol` 按钮可用。点击后，`HudBar` 发出 `debug_symbols_toggle_requested`，`UIRoot` 转发给 `CoreRoot`，再由 `CoreRoot` 调用 `MapRoot.toggle_debug_symbols()`。

进入局部地图后，HUD 会隐藏 `Texture / Symbol`，显示“返回大地图”按钮。点击后由 `UIRoot` 发出 `return_to_world_requested`，`CoreRoot` 负责恢复大地图显示。

局部地图模式下，左下角信息面板从“地块信息”切换为“地格信息”。默认显示未选择状态；玩家左键点击小地图视口中的地格后，面板显示地格坐标、全局坐标、高度、水体、河流和坡度。鼠标悬停只用于小地图内预览标记，不更新该面板。

## 地块信息面板

地块信息面板位于左下角，尺寸约 `420 x 240`。当启动游戏时，默认展示起始城市地块；点击地图后实时刷新。

当前显示字段：

- 坐标。
- 基础地形。
- 特征。
- 河流状态和强度。
- 海拔、降水、温度、起伏，保留 2 位小数。

特征使用中文名称显示，例如 `森林`、`丘陵`、`山脉`。

## 信号流程

### 初始化流程

1. `MapRoot` 在 `_ready()` 中生成 `MapState`。
2. `CoreRoot` 在 `_ready()` 中连接 `MapRoot.tile_selected` 和 `UIRoot.debug_symbols_toggle_requested`。
3. `CoreRoot` 从 `MapRoot.map_state.start_city_tile_key` 读取起始地块。
4. `CoreRoot` 调用 `UIRoot.show_tile(tile)` 初始化 HUD 和地块信息面板。

### 选择地块流程

1. 玩家左键点击地图。
2. `MapRoot` 更新地图选中框和调试符号选中状态。
3. `MapRoot` 发出 `tile_selected(tile)`。
4. `CoreRoot` 接收信号并调用 `UIRoot.show_tile(tile)`。
5. `UIRoot` 刷新 HUD 当前坐标和地块信息面板。

### 地图调试符号切换流程

1. 玩家点击 HUD 中的 `Texture / Symbol`。
2. `HudBar` 发出 `debug_symbols_toggle_requested`。
3. `UIRoot` 转发该信号。
4. `CoreRoot` 调用 `MapRoot.toggle_debug_symbols()`。
5. `MapRoot` 切换选中地块旧符号叠加显示。

## 当前限制

- HUD 中的回合和金币是静态文本，尚未接入 `GameState`。
- 保存、读档、结束回合按钮禁用，尚未发起业务请求。
- UI 还没有 presenter 层，当前面板直接消费 `TileState`。
- 城市和科技面板尚未创建，因为对应运行时模块尚未开始实现。
- 视觉风格只是基础羊皮纸/策略面板方向的结构占位，后续需要统一主题资源。
