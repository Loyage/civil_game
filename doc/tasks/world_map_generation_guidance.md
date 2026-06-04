# 文明建设类游戏地图生成系统实现指导

> 目标：指导 Codex 实现一个“文明 6 大地图 + RimWorld 式小地图”的确定性、连续、可懒加载的地图生成系统。

---

## 1. 项目背景

游戏地图采用两级结构：

```text
BigMap: n * n
SubMap: m * m
```

每个大地图地块 `BigTile(tileX, tileY)` 对应一个小地图区域。玩家一开始可以看到完整大地图，但不会立即生成所有小地图的完整细节。玩家进入某个大地图地块时，才按需生成该地块对应的小地图。

核心设计原则：

```text
世界不是由一个个小地图拼出来的；
世界是一套由 seed 驱动的连续函数；
大地图是低分辨率摘要；
小地图是高分辨率采样；
玩家修改作为增量数据保存。
```

---

## 2. 必须满足的需求

地图生成系统必须满足以下条件：

1. 地形、地貌比较符合现实，有海洋、平原、丘陵、山脉、森林、沙漠、冻原、湿地等。
2. 地图中存在有整体走向的山脉，而不是零散随机高地。
3. 地图中存在跨越多个大地图地块的河流，河流方向与高度变化大体一致。
4. 相邻大地图地块的小地图边缘必须连续，包括高度、地貌、河流、山脉等。
5. 相同 seed 必须生成完全一致的地图。
6. 小地图必须支持懒加载：只有玩家进入或需要查看时才生成。
7. 无论什么时候生成同一个小地图，原始结果都必须一致。
8. 游戏开局需要较短时间内生成完整大地图摘要。
9. 大地图每个地块需要有大致属性，包括主体地形、平均海拔、温度、湿度、山脉走向、河流流向等。
10. 玩家对地图造成的修改需要保存，但原始地形不需要完整保存。

---

## 3. 核心架构

请按以下架构实现：

```text
WorldGenerator
├── WorldSkeletonGenerator
│   ├── generateContinents()
│   ├── generateMountainRidges()
│   ├── generateMajorRivers()
│   └── buildSkeletonTileIndex()
│
├── WorldFunctionSampler
│   ├── sampleHeight(worldX, worldY)
│   ├── sampleTemperature(worldX, worldY)
│   ├── sampleMoisture(worldX, worldY)
│   ├── sampleRiverStrength(worldX, worldY)
│   └── sampleBiome(worldX, worldY)
│
├── BigMapSummaryGenerator
│   ├── generateBigMapSummary()
│   ├── generateBigTileSummary(tileX, tileY)
│   ├── summarizeHeight()
│   ├── summarizeBiome()
│   ├── summarizeMountains()
│   └── summarizeRivers()
│
└── SubMapGenerator
    ├── generateSubMap(tileX, tileY)
    ├── generateBaseTerrain()
    ├── applyMountainInfluence()
    ├── applyRiverPaths()
    ├── generateVegetation()
    ├── generateResources()
    └── applyPlayerModifications()
```

---

## 4. 最重要的坐标规则

所有地图生成必须基于全局坐标。

给定：

```text
大地图坐标: tileX, tileY
小地图局部坐标: localX, localY
小地图尺寸: subMapSize = m
```

必须转换为：

```text
worldX = tileX * subMapSize + localX
worldY = tileY * subMapSize + localY
```

禁止使用以下方式作为核心生成依据：

```text
noise(localX, localY, seed + tileX + tileY)
```

因为这会导致相邻小地图边缘不连续。

正确方式：

```text
noise(worldX, worldY, seed)
```

只要所有高度、湿度、温度、植被、资源等都基于全局坐标采样，相邻小地图天然连续。

---

## 5. 确定性随机规则

不要依赖全局随机状态。

避免：

```ts
random.seed(seed)
random.next()
random.next()
```

原因是生成顺序一旦变化，结果就会变化。

应该使用坐标哈希随机：

```ts
hash01(seed, namespace, x, y) -> 0.0 ~ 1.0
```

示例：

```ts
const hasTree = hash01(seed, "tree", worldX, worldY) < treeDensity;
const hasIron = hash01(seed, "iron", chunkX, chunkY) < ironProbability;
```

`namespace` 用于区分不同系统，避免树木、矿物、动物共用同一随机序列。

推荐 namespace：

```text
height_detail
vegetation
tree
stone
iron
copper
animal
ruin
village
loot
```

---

## 6. 核心数据结构

### 6.1 WorldConfig

```ts
export interface WorldConfig {
  seed: number;
  bigMapSize: number;      // n
  subMapSize: number;      // m
  seaLevel: number;
  mountainCount: number;
  majorRiverCount: number;
  summarySampleResolution: number; // 推荐 4、8 或 16
}
```

---

### 6.2 WorldSkeleton

`WorldSkeleton` 是世界的大结构源数据。

```ts
export interface WorldSkeleton {
  seed: number;
  config: WorldConfig;
  continentParams: ContinentParams;
  climateParams: ClimateParams;
  mountainRidges: MountainRidge[];
  rivers: RiverPath[];
  tileIndex: SkeletonTileIndex;
}
```

注意：

```text
WorldSkeleton 不保存每个小格子的地形。
WorldSkeleton 只保存大陆、山脉、河流、气候等大尺度结构。
```

---

### 6.3 MountainRidge

```ts
export interface MountainRidge {
  id: number;
  points: Vec2[];      // 全局坐标折线
  width: number;       // 影响宽度，单位为小地图格子
  strength: number;    // 0 ~ 1
  roughness: number;   // 崎岖程度
}
```

山脉是无向结构，只记录“走向”，不记录“流向”。

---

### 6.4 RiverPath

```ts
export interface RiverPath {
  id: number;
  points: Vec2[];      // 全局坐标折线，按从源头到下游排序
  width: number;
  flow: number;        // 流量
}
```

河流是有向结构，`points[0]` 是源头，最后一个点是下游。

---

### 6.5 SkeletonTileIndex

用于快速查询某个大地图地块中穿过了哪些山脉、河流。

```ts
export interface SkeletonTileIndex {
  mountainsByTile: Map<string, number[]>;
  riversByTile: Map<string, number[]>;
}
```

key 推荐格式：

```ts
function tileKey(tileX: number, tileY: number): string {
  return `${tileX},${tileY}`;
}
```

---

### 6.6 BigTileSummary

这是开局生成并展示给玩家的大地图摘要。

```ts
export interface BigTileSummary {
  tileX: number;
  tileY: number;

  avgHeight: number;
  minHeight: number;
  maxHeight: number;

  avgTemperature: number;
  avgMoisture: number;

  mainBiome: BiomeType;
  biomeWeights: Partial<Record<BiomeType, number>>;

  hasMountain: boolean;
  mountains: MountainSummary[];

  hasRiver: boolean;
  rivers: RiverSummary[];

  terrainTags: string[];
}
```

---

### 6.7 MountainSummary

```ts
export interface MountainSummary {
  ridgeId: number;
  directionAxis: Vec2;   // 无向轴线
  strength: number;
  width: number;
  entryEdges: Edge[];
}
```

---

### 6.8 RiverSummary

```ts
export interface RiverSummary {
  riverId: number;
  flowDirection: Vec2;  // 有向流向
  entryEdge?: Edge;
  exitEdge?: Edge;
  width: number;
  flow: number;
}
```

---

### 6.9 SubMapCell

```ts
export interface SubMapCell {
  worldX: number;
  worldY: number;
  localX: number;
  localY: number;

  height: number;
  temperature: number;
  moisture: number;
  riverStrength: number;
  biome: BiomeType;

  hasTree: boolean;
  resource?: ResourceType;
}
```

---

### 6.10 PlayerModification

原始地形不需要存盘，玩家造成的变化需要存盘。

```ts
export interface PlayerModification {
  tileX: number;
  tileY: number;
  localX: number;
  localY: number;
  type: ModificationType;
  payload?: unknown;
}
```

最终显示逻辑：

```text
最终小地图 = seed 生成的原始小地图 + 玩家修改
```

---

## 7. 地形生成函数

### 7.1 高度函数

高度由三部分组成：

```text
height = continentBase + noiseDetail + mountainInfluence - riverCarving
```

推荐实现：

```ts
function sampleHeight(seed: number, skeleton: WorldSkeleton, worldX: number, worldY: number): number {
  const continent = sampleContinentHeight(seed, skeleton, worldX, worldY);
  const detail = sampleHeightNoise(seed, worldX, worldY);
  const mountain = sampleMountainInfluence(skeleton, worldX, worldY);
  const riverCarving = sampleRiverCarving(skeleton, worldX, worldY);

  return continent + detail + mountain - riverCarving;
}
```

多层噪声示例：

```ts
function sampleHeightNoise(seed: number, worldX: number, worldY: number): number {
  return 
    0.50 * noise2D(seed, worldX / 2048, worldY / 2048) +
    0.25 * noise2D(seed, worldX / 512,  worldY / 512) +
    0.15 * noise2D(seed, worldX / 128,  worldY / 128) +
    0.10 * noise2D(seed, worldX / 32,   worldY / 32);
}
```

---

### 7.2 山脉影响

每条山脉是一条全局折线。某个点受山脉影响的强度取决于它到山脉折线的距离。

```ts
function sampleMountainInfluence(skeleton: WorldSkeleton, worldX: number, worldY: number): number {
  let result = 0;

  for (const ridge of nearbyMountainRidges(skeleton, worldX, worldY)) {
    const d = distanceToPolyline({ x: worldX, y: worldY }, ridge.points);
    const t = d / ridge.width;
    const influence = ridge.strength * falloff(t);
    result += influence;
  }

  return result;
}

function falloff(t: number): number {
  if (t >= 1) return 0;
  return (1 - t) * (1 - t);
}
```

---

### 7.3 河流强度与河谷雕刻

河流也由全局折线表示。

```ts
function sampleRiverStrength(skeleton: WorldSkeleton, worldX: number, worldY: number): number {
  let result = 0;

  for (const river of nearbyRivers(skeleton, worldX, worldY)) {
    const d = distanceToPolyline({ x: worldX, y: worldY }, river.points);
    const t = d / river.width;
    const influence = river.flow * falloff(t);
    result = Math.max(result, influence);
  }

  return result;
}
```

河流位置应降低高度，形成河谷：

```ts
function sampleRiverCarving(skeleton: WorldSkeleton, worldX: number, worldY: number): number {
  const riverStrength = sampleRiverStrength(skeleton, worldX, worldY);
  return riverStrength * 0.2;
}
```

---

### 7.4 温度函数

温度主要由纬度和海拔决定：

```ts
function sampleTemperature(seed: number, skeleton: WorldSkeleton, worldX: number, worldY: number): number {
  const latitude = worldY / (skeleton.config.bigMapSize * skeleton.config.subMapSize);
  const latitudeTemp = 1.0 - Math.abs(latitude - 0.5) * 2.0;
  const height = sampleHeight(seed, skeleton, worldX, worldY);
  const altitudePenalty = Math.max(0, height - 0.5) * 0.5;
  const noise = 0.1 * noise2D(seed + 101, worldX / 1024, worldY / 1024);

  return clamp01(latitudeTemp - altitudePenalty + noise);
}
```

---

### 7.5 湿度函数

湿度可以由基础噪声、海岸距离、河流距离共同决定：

```ts
function sampleMoisture(seed: number, skeleton: WorldSkeleton, worldX: number, worldY: number): number {
  const base = 0.5 + 0.4 * noise2D(seed + 202, worldX / 1024, worldY / 1024);
  const riverBonus = 0.3 * sampleRiverStrength(skeleton, worldX, worldY);
  return clamp01(base + riverBonus);
}
```

后续可以扩展雨影、季风、海岸湿度等。

---

## 8. 生物群系判定

根据高度、温度、湿度、河流强度判定地貌。

```ts
function decideBiome(input: {
  height: number;
  temperature: number;
  moisture: number;
  riverStrength: number;
  seaLevel: number;
}): BiomeType {
  const { height, temperature, moisture, riverStrength, seaLevel } = input;

  if (height < seaLevel) return "ocean";
  if (riverStrength > 0.7) return "river";
  if (height > 0.85) return "snow_mountain";
  if (height > 0.72) return "mountain";
  if (height > 0.58) return "hill";

  if (temperature < 0.18) return "tundra";
  if (moisture < 0.22 && temperature > 0.55) return "desert";
  if (moisture > 0.75 && temperature > 0.55) return "rainforest";
  if (moisture > 0.55) return "forest";
  if (moisture > 0.35) return "grassland";

  return "plain";
}
```

---

## 9. 开局大地图摘要生成

开局必须快速生成 `BigMapSummary[n][n]`。

不要生成所有小地图的 `m * m` 细节。

每个大地图地块使用低分辨率采样，例如：

```text
summarySampleResolution = 8
每个大地图地块采样 8 * 8 = 64 个点
```

实现：

```ts
function generateBigTileSummary(
  seed: number,
  skeleton: WorldSkeleton,
  tileX: number,
  tileY: number
): BigTileSummary {
  const samples: SampledCell[] = [];
  const r = skeleton.config.summarySampleResolution;
  const m = skeleton.config.subMapSize;

  for (let iy = 0; iy < r; iy++) {
    for (let ix = 0; ix < r; ix++) {
      const localX = Math.floor((ix + 0.5) * m / r);
      const localY = Math.floor((iy + 0.5) * m / r);
      const worldX = tileX * m + localX;
      const worldY = tileY * m + localY;
      samples.push(sampleWorldCell(seed, skeleton, worldX, worldY));
    }
  }

  return {
    tileX,
    tileY,
    ...summarizeHeight(samples),
    ...summarizeClimate(samples),
    ...summarizeBiome(samples),
    ...summarizeMountains(skeleton, tileX, tileY),
    ...summarizeRivers(skeleton, tileX, tileY),
    terrainTags: buildTerrainTags(samples, skeleton, tileX, tileY),
  };
}
```

---

## 10. 大地图摘要与小地图的一致性

必须遵守：

```text
BigTileSummary 不是 SubMap 的生成源。
SubMap 也不是 BigTileSummary 的展开结果。

它们都来自：
WorldSkeleton + WorldFunctionSampler + seed
```

正确关系：

```text
WorldSkeleton + WorldFunctions
        ├── BigTileSummary
        └── SubMap
```

错误关系：

```text
BigTileSummary -> SubMap
```

原因：

大地图摘要是低精度统计结果，小地图是高精度采样结果。如果用摘要反向生成小地图，会导致边缘断裂、地貌不一致、河流断流等问题。

---

## 11. 小地图懒加载生成

小地图生成函数：

```ts
function generateSubMap(
  seed: number,
  skeleton: WorldSkeleton,
  tileX: number,
  tileY: number,
  modifications: PlayerModification[]
): SubMap {
  const m = skeleton.config.subMapSize;
  const cells: SubMapCell[][] = [];

  for (let localY = 0; localY < m; localY++) {
    const row: SubMapCell[] = [];

    for (let localX = 0; localX < m; localX++) {
      const worldX = tileX * m + localX;
      const worldY = tileY * m + localY;
      row.push(sampleWorldCell(seed, skeleton, worldX, worldY, localX, localY));
    }

    cells.push(row);
  }

  applyPlayerModifications(cells, modifications);

  return {
    tileX,
    tileY,
    cells,
  };
}
```

---

## 12. 山脉与河流的地块索引

在生成 `WorldSkeleton` 后，需要构建空间索引。

目标：快速查询某个大地图地块被哪些山脉、河流穿过。

```ts
function buildSkeletonTileIndex(skeleton: WorldSkeleton): SkeletonTileIndex {
  const index: SkeletonTileIndex = {
    mountainsByTile: new Map(),
    riversByTile: new Map(),
  };

  for (const ridge of skeleton.mountainRidges) {
    const tiles = rasterizePolylineToBigTiles(ridge.points, skeleton.config.subMapSize);
    for (const tile of tiles) {
      addToMapList(index.mountainsByTile, tileKey(tile.x, tile.y), ridge.id);
    }
  }

  for (const river of skeleton.rivers) {
    const tiles = rasterizePolylineToBigTiles(river.points, skeleton.config.subMapSize);
    for (const tile of tiles) {
      addToMapList(index.riversByTile, tileKey(tile.x, tile.y), river.id);
    }
  }

  return index;
}
```

---

## 13. 山脉摘要生成

对于一个大地图地块，查询 `mountainsByTile`。

```ts
function summarizeMountains(
  skeleton: WorldSkeleton,
  tileX: number,
  tileY: number
): { hasMountain: boolean; mountains: MountainSummary[] } {
  const ids = skeleton.tileIndex.mountainsByTile.get(tileKey(tileX, tileY)) ?? [];
  const mountains = ids.map(id => {
    const ridge = getMountainById(skeleton, id);
    return summarizeMountainInTile(ridge, tileX, tileY, skeleton.config.subMapSize);
  });

  return {
    hasMountain: mountains.length > 0,
    mountains,
  };
}
```

山脉走向是无向轴线：

```text
东北—西南 和 西南—东北 视为同一种走向。
```

---

## 14. 河流摘要生成

对于一个大地图地块，查询 `riversByTile`。

```ts
function summarizeRivers(
  skeleton: WorldSkeleton,
  tileX: number,
  tileY: number
): { hasRiver: boolean; rivers: RiverSummary[] } {
  const ids = skeleton.tileIndex.riversByTile.get(tileKey(tileX, tileY)) ?? [];
  const rivers = ids.map(id => {
    const river = getRiverById(skeleton, id);
    return summarizeRiverInTile(river, tileX, tileY, skeleton.config.subMapSize);
  });

  return {
    hasRiver: rivers.length > 0,
    rivers,
  };
}
```

河流方向是有向的：

```text
从源头流向下游。
```

因此 `flowDirection` 必须保留方向。

---

## 15. 生成顺序

开局流程：

```text
1. 读取 WorldConfig
2. 根据 seed 生成 WorldSkeleton
3. 构建 SkeletonTileIndex
4. 遍历 n * n 个大地图地块
5. 对每个地块生成 BigTileSummary
6. 把 BigMapSummary 提供给 UI 显示
```

进入小地图流程：

```text
1. 输入 tileX, tileY
2. 读取 WorldSkeleton
3. 读取该 tile 的玩家修改
4. 调用 generateSubMap(seed, skeleton, tileX, tileY, modifications)
5. 显示小地图
```

保存流程：

```text
1. 保存 WorldConfig
2. 保存 seed
3. 保存 WorldSkeleton，或保存足够重建 WorldSkeleton 的参数
4. 保存 BigMapSummary，可选
5. 保存 PlayerModification[]
```

---

## 16. 性能要求与优化建议

### 16.1 开局大地图性能

大地图生成不能采样所有小地图格子。

推荐：

```text
summarySampleResolution = 4 或 8
```

当 `n = 100`，`summarySampleResolution = 8` 时：

```text
100 * 100 * 8 * 8 = 640000 次采样
```

这是可接受的目标量级。

---

### 16.2 自适应采样

普通地块使用低采样：

```text
4 * 4 或 8 * 8
```

复杂地块可以提高采样：

```text
16 * 16
```

复杂地块包括：

```text
海岸线附近
山脉穿过
河流穿过
多种 biome 交界处
```

---

### 16.3 缓存策略

可以缓存：

```text
BigMapSummary
最近进入过的 SubMap
WorldSkeleton
SkeletonTileIndex
```

不需要长期保存：

```text
每个小地图的原始地形
每棵树的位置
每块石头的位置
```

这些可以用 seed + world coordinate 重新生成。

---

## 17. 测试与验收标准

Codex 实现后，请添加以下测试。

### 17.1 确定性测试

同一个 seed，同一个 tile，多次生成结果完全一致。

```ts
const a = generateSubMap(seed, skeleton, 3, 5, []);
const b = generateSubMap(seed, skeleton, 3, 5, []);
expect(a).toEqual(b);
```

---

### 17.2 顺序无关测试

先生成 A 再生成 B，和先生成 B 再生成 A，结果不变。

```ts
const a1 = generateSubMap(seed, skeleton, 1, 1, []);
const b1 = generateSubMap(seed, skeleton, 2, 1, []);

const b2 = generateSubMap(seed, skeleton, 2, 1, []);
const a2 = generateSubMap(seed, skeleton, 1, 1, []);

expect(a1).toEqual(a2);
expect(b1).toEqual(b2);
```

---

### 17.3 边缘连续测试

右邻地块的左边界应该与当前地块右边界自然相邻。

```ts
const left = generateSubMap(seed, skeleton, 3, 4, []);
const right = generateSubMap(seed, skeleton, 4, 4, []);

for (let y = 0; y < m; y++) {
  const a = left.cells[y][m - 1];
  const b = right.cells[y][0];

  expect(Math.abs(a.height - b.height)).toBeLessThan(MAX_ALLOWED_HEIGHT_DELTA);
  expect(areBiomesCompatible(a.biome, b.biome)).toBe(true);
}
```

注意：高度不要求完全相等，因为它们是相邻两个格子，不是同一个格子；但差异应平滑。

---

### 17.4 大地图摘要一致性测试

大地图摘要的主地貌应该大致符合高分辨率小地图统计。

```ts
const summary = generateBigTileSummary(seed, skeleton, tileX, tileY);
const submap = generateSubMap(seed, skeleton, tileX, tileY, []);
const actualMainBiome = computeMainBiomeFromSubMap(submap);

expect(areBiomesCompatible(summary.mainBiome, actualMainBiome)).toBe(true);
```

---

### 17.5 河流连续测试

如果河流从一个大地图地块流出到相邻地块，相邻地块必须能查询到同一条河流。

```ts
const summaryA = bigMap[tileY][tileX];
const summaryB = bigMap[tileY][tileX + 1];

// 如果 A 中某条河从 east 边离开，则 B 中应该有同 riverId 从 west 附近进入。
```

---

### 17.6 玩家修改测试

玩家修改不应改变原始生成结果，只应作为增量覆盖。

```ts
const original = generateSubMap(seed, skeleton, tileX, tileY, []);
const modified = generateSubMap(seed, skeleton, tileX, tileY, [mod]);
const originalAgain = generateSubMap(seed, skeleton, tileX, tileY, []);

expect(original).toEqual(originalAgain);
expect(modified).not.toEqual(original);
```

---

## 18. 建议的实现里程碑

### Milestone 1：确定性基础地形

完成：

```text
WorldConfig
hash01
noise2D
sampleHeight
sampleTemperature
sampleMoisture
decideBiome
generateSubMap
```

验收：

```text
相同 seed 生成相同小地图
相邻小地图高度连续
```

---

### Milestone 2：大地图摘要

完成：

```text
generateBigTileSummary
generateBigMapSummary
biomeWeights
avgHeight / minHeight / maxHeight
```

验收：

```text
开局可以快速显示完整大地图
大地图主体地貌和小地图基本一致
```

---

### Milestone 3：山脉骨架

完成：

```text
MountainRidge
generateMountainRidges
sampleMountainInfluence
summarizeMountains
```

验收：

```text
山脉能跨越多个大地图地块
大地图能显示山脉走向
小地图中山脉边缘连续
```

---

### Milestone 4：河流骨架

完成：

```text
RiverPath
generateMajorRivers
sampleRiverStrength
sampleRiverCarving
summarizeRivers
```

验收：

```text
河流能跨越多个大地图地块
河流在相邻小地图边缘连续
大地图能显示河流流向
```

---

### Milestone 5：玩家修改与存档

完成：

```text
PlayerModification
applyPlayerModifications
save/load modifications
```

验收：

```text
原始地图可由 seed 重建
玩家修改能正确恢复
无需保存所有小地图原始数据
```

---

## 19. 给 Codex 的实现要求

实现时请遵守以下要求：

1. 不要把所有小地图在开局全部生成。
2. 不要让小地图使用局部坐标作为噪声采样坐标。
3. 不要使用依赖调用顺序的全局随机数。
4. 所有随机结果必须能由 `seed + namespace + world coordinate` 重建。
5. 大地图摘要和小地图必须来自同一套世界函数。
6. 山脉和河流必须作为 `WorldSkeleton` 的一部分生成。
7. 河流和山脉要建立 tile 索引，避免每次遍历全部结构。
8. 玩家修改必须作为增量保存，不要覆盖原始生成逻辑。
9. 每个模块应保持纯函数倾向，便于测试。
10. 请优先实现简单、稳定、可测试的 MVP，再逐步增加真实感。

---

## 20. 关键结论

本系统的核心不是“生成很多张小地图”，而是：

```text
用 seed 生成一个确定性的连续世界，
用 WorldSkeleton 表达大尺度结构，
用 BigTileSummary 快速展示大地图，
用 SubMapGenerator 按需展开局部细节，
用 PlayerModification 保存玩家造成的变化。
```

只要坚持这个架构，就可以同时满足：

```text
现实感
整体山脉
连续河流
边缘连续
相同 seed 一致
小地图懒加载
开局快速显示完整大地图
```
