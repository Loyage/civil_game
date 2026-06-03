# city 模块设计

## 目标

`city` 模块负责城市状态、人口增长、工作地块分配、生产队列和自动扩边逻辑。

首版目标：

- 游戏开局拥有一座初始城市
- 城市每回合结算粮食、生产力、金币
- 人口会增长
- 生产队列支持 `纪念碑`、`粮仓`
- 城市边界自动扩张
- 结构上支持未来扩展到多城市

## 职责边界

### 负责

- 城市运行时状态
- 工作地块选择规则
- 城市产出汇总
- 粮食增长结算
- 生产队列结算
- 边界扩张规则
- 建筑效果应用

### 不负责

- 地图加载
- 科技定义管理
- 存档持久化
- 顶层回合顺序调度
- 面板 UI 渲染

## 核心数据结构

### `CityState`

```gdscript
class_name CityState

var city_id: String
var city_name: String
var owner_id: String
var center_tile_key: String
var population: int
var stored_food: int
var food_to_next_pop: int
var border_points: int
var border_threshold: int
var owned_tile_keys: PackedStringArray
var worked_tile_keys: PackedStringArray
var building_ids: PackedStringArray
var production_queue: Array[ProductionQueueItem]
var current_production: int
```

### `ProductionQueueItem`

```gdscript
class_name ProductionQueueItem

var item_id: String
var item_type: String # building
var production_cost: int
```

### `CityYieldBreakdown`

```gdscript
class_name CityYieldBreakdown

var food: int
var production: int
var gold: int
var science: int
```

## 主要流程

### 初始城市创建流程

1. `core` 提供起始城市中心地块。
2. `CityService` 创建 `CityState`。
3. 默认人口为 `1`。
4. 默认拥有城市中心及首圈初始边界。
5. 默认生产队列为空。
6. UI 刷新城市面板。

设计决策：

- 虽然 V1 只有一座城市，但不将城市写死在单例变量中
- 初始边界建议为城市中心 + 六个相邻格，便于尽快进入经营循环

### 工作地块分配流程

V1 不做手动市民管理，采用自动分配。

规则建议：

- 城市中心地块始终生效
- 可工作的附加地块数量为 `population`
- 只从 `owned_tile_keys` 中选择非中心地块
- 每回合自动重算

优先级建议：

1. 若当前粮食盈余不足，优先高粮食地块
2. 否则按 `food + production + gold` 综合值排序
3. 同分时优先生产力更高的地块

说明：

- 这是首版简化方案，后续可扩展为手动锁定地块

### 城市产出结算流程

1. 读取城市中心地块产出。
2. 读取自动分配的工作地块产出。
3. 叠加建筑修正。
4. 生成 `CityYieldBreakdown`。
5. 将金币汇总到 `PlayerState.gold`。
6. 将固定科研值提交给 `tech` 模块。

### 人口增长流程

推荐规则：

- 人口消耗：`2 * population`
- 粮食盈余：`total_food - consumption`
- 只有正盈余可积累到 `stored_food`
- 升级阈值：`10 + (population - 1) * 5`

增长完成时：

- `population += 1`
- `stored_food` 扣除阈值
- 重算下一级阈值
- 触发城市 UI 刷新

### 生产队列流程

1. 队列头部作为当前生产目标。
2. 每回合将城市总生产力加入 `current_production`。
3. 若达到 `production_cost`，完成当前建筑。
4. 应用建筑效果。
5. 从队列移除当前项，继续下一项。

首版建筑建议规则：

- `纪念碑`
  - 提供边界扩张加成
- `粮仓`
  - 提供粮食增长加成

推荐初始效果：

- `纪念碑`：`border_points_per_turn +1`
- `粮仓`：城市总粮食 `+1`

说明：

- 具体数值应数据化，不应硬编码在场景脚本里

### 自动扩边流程

由于首版没有独立文化值系统，采用简化的“边界点数”机制。

推荐规则：

- 每回合基础获得 `1` 点边界点数
- 若已建 `纪念碑`，额外 `+1`
- 初始扩边阈值 `8`
- 每次扩张后阈值增加 `+4`

候选地块选择规则：

1. 必须与当前已拥有地块相邻
2. 不能是海洋和山脉
3. 不能已被其他城市拥有
4. 优先综合产出更高的地块
5. 同分时优先离城市中心更近

扩边成功时：

- 将目标地块加入 `owned_tile_keys`
- 更新 `MapState` 的 `owner_city_id`
- 通知地图边界覆盖层刷新

## 场景/脚本拆分

建议文件：

```text
game/scripts/city/city_state.gd
game/scripts/city/city_service.gd
game/scripts/city/city_factory.gd
game/scripts/city/city_yield_calculator.gd
game/scripts/city/city_growth_service.gd
game/scripts/city/city_production_service.gd
game/scripts/city/city_border_service.gd
game/scripts/city/production_queue_item.gd
game/scripts/city/city_yield_breakdown.gd
```

建议职责：

- `city_service.gd`
  - 城市模块总入口
  - 回合处理协调
- `city_factory.gd`
  - 创建初始城市
- `city_yield_calculator.gd`
  - 汇总地块与建筑产出
- `city_growth_service.gd`
  - 处理人口增长
- `city_production_service.gd`
  - 处理生产队列
- `city_border_service.gd`
  - 处理自动扩边

## 输入输出

### 输入

- `MapState`
- 建筑定义
- 来自 `core` 的结束回合调用
- 科技状态中的建筑可用性

### 输出

- 更新后的 `CityState`
- 汇总后的金币和科研贡献
- 边界变化结果
- 建筑完成事件

## 依赖关系

### 依赖

- `map`
- `data`
- `tech`

### 被依赖

- `core`
- `ui`
- `save_load`

## 风险

- 如果工作地块规则定义不清，人口和地块系统会彼此牵制，后续很难平衡
- `Masonry` 在首版没有明显城市效果时，科技体验会偏空
- 自动扩边如果与地图所有权更新不同步，UI 和存档会出现不一致

## 子任务 checklist

- [ ] 定义 `CityState`
- [ ] 定义 `ProductionQueueItem`
- [ ] 定义 `CityYieldBreakdown`
- [ ] 实现 `CityFactory`
- [ ] 实现 `CityService`
- [ ] 实现自动工作地块分配
- [ ] 实现城市总产出计算
- [ ] 实现人口增长规则
- [ ] 实现生产队列推进
- [ ] 实现纪念碑效果
- [ ] 实现粮仓效果
- [ ] 实现自动扩边规则
- [ ] 实现边界变更后的地图同步
- [ ] 增加城市模块调试输出
