# data 模块设计

## 目标

`data` 模块负责维护所有静态配置，包括地形、建筑、科技和固定地图源数据，并向运行时模块提供统一读取入口。

首版目标：

- 数据驱动地定义地形、建筑、科技
- 支持固定地图文件
- 为后续扩展更多时代、更多建筑、更多地图规则预留结构

## 职责边界

### 负责

- 静态数据文件组织
- 数据读取与校验
- 向运行时模块返回标准化定义对象
- 数据版本管理基础约束

### 不负责

- 回合结算
- 地块渲染
- 城市增长
- 科技推进
- 存档持久化

## 核心数据结构

设计决策：

- 首版静态数据统一使用 `JSON`
- 理由是便于人工阅读、调试和版本管理
- 后续若需要更强的编辑器集成，再考虑迁移部分定义到 `Resource`

### 地形定义

建议路径：

```text
game/data/terrain/terrains.json
```

建议结构：

```json
{
  "version": 1,
  "terrains": [
    {
      "terrain_id": "grassland",
      "display_name": "草地",
      "base_food": 2,
      "base_production": 0,
      "base_gold": 0,
      "tags": ["land"]
    }
  ]
}
```

### 建筑定义

建议路径：

```text
game/data/buildings/buildings.json
```

建议结构：

```json
{
  "version": 1,
  "buildings": [
    {
      "building_id": "monument",
      "display_name": "纪念碑",
      "production_cost": 20,
      "required_tech_id": "",
      "effects": {
        "border_points_per_turn": 1
      }
    }
  ]
}
```

### 科技定义

建议路径：

```text
game/data/tech/techs.json
```

建议结构：

```json
{
  "version": 1,
  "techs": [
    {
      "tech_id": "pottery",
      "display_name": "制陶术",
      "science_cost": 10,
      "prerequisite_ids": [],
      "unlock_building_ids": ["granary"]
    }
  ]
}
```

### 固定地图定义

建议路径：

```text
game/data/maps/start_map.json
```

建议结构：

```json
{
  "version": 1,
  "width": 40,
  "height": 20,
  "rows": [
    [
      {
        "terrain_id": "grassland",
        "has_forest": false,
        "has_hill": false,
        "has_river": false,
        "is_start_city": false
      }
    ]
  ]
}
```

说明：

- `rows` 使用 `offset(col, row)` 语义
- 起始城市位置可先在地图里用 `is_start_city` 标记
- 未来若扩展脚本化地图生成，可将该字段替换为独立 scenario 文件

## 主要流程

### 数据加载流程

1. `DataRepository` 在新游戏启动时一次性读取 JSON。
2. 调用 `DataValidator` 检查字段完整性。
3. 转为内存定义对象。
4. 缓存在仓库对象中，供其他模块查询。

### 数据校验流程

最少需要校验：

- `terrain_id` 是否唯一
- `building_id` 是否唯一
- `tech_id` 是否唯一
- 建筑前置科技是否存在
- 地图宽高是否匹配 `40 x 20`
- 地图中的 `terrain_id` 是否都能在地形定义中找到
- 起始城市标记是否存在且仅有一个

## 场景/脚本拆分

建议文件：

```text
game/scripts/data/data_repository.gd
game/scripts/data/data_validator.gd
game/scripts/data/terrain_definition.gd
game/scripts/data/building_definition.gd
game/scripts/data/tech_definition.gd
game/scripts/data/map_definition.gd
```

建议职责：

- `data_repository.gd`
  - 统一读取所有静态数据
- `data_validator.gd`
  - 启动时校验并输出错误
- 各 `*_definition.gd`
  - 约束运行时使用的数据形状

## 输入输出

### 输入

- `game/data/**` 下的 JSON 文件

### 输出

- 标准化地形定义
- 标准化建筑定义
- 标准化科技定义
- 标准化地图定义

## 依赖关系

### 依赖

- 无运行时业务依赖

### 被依赖

- `core`
- `map`
- `city`
- `tech`
- `save_load`

## 风险

- 如果没有严格的数据校验，错误会在运行时才暴露，定位成本很高
- JSON 虽然简单，但如果 schema 没有版本字段，后续迁移会困难
- 静态数据和运行时状态命名不一致时，问题会蔓延到多个模块

## 子任务 checklist

- [ ] 创建 `game/data/terrain/terrains.json`
- [ ] 创建 `game/data/buildings/buildings.json`
- [ ] 创建 `game/data/tech/techs.json`
- [ ] 创建 `game/data/maps/start_map.json`
- [ ] 定义地形数据 schema
- [ ] 定义建筑数据 schema
- [ ] 定义科技数据 schema
- [ ] 定义地图数据 schema
- [ ] 实现 `DataRepository`
- [ ] 实现 `DataValidator`
- [ ] 实现启动时数据完整性校验
