# Civilization-like Mini Game Proposal

## 1. Project Summary / 项目概述

This project aims to build a simplified, expandable turn-based strategy game inspired by Civilization VI.

本项目目标是开发一个受《文明6》启发、但范围受控且长期可扩展的简易回合制策略游戏。

Core constraints:

- Engine: Godot 4
- Language: GDScript
- Primary dev platforms: NixOS, macOS
- Target runtime platforms: Windows, macOS, Linux
- Document style: personal-development-oriented TODO + milestone proposal

## 2. Confirmed Scope / 已确认范围

### 2.1 Core Gameplay

- Turn-based
- Hex grid map
- 2D top-down presentation
- Single-player only
- Fixed map
- One playable civilization/faction
- No AI factions
- No neutral city-states
- No barbarians
- No diplomacy
- No combat system in first version
- No formal victory conditions in first version
- Continue-play only after progression

### 2.2 First Version Player Experience

- Game starts with one owned city already placed on the map
- Entire map is visible from the beginning
- Player manages one city
- Player grows population
- Player runs a production queue
- Player researches a minimal tech tree
- Player develops territory through automatic border expansion

### 2.3 Map Definition

- Grid type: hex
- Map size: `40 x 20`
- Map type: fixed handcrafted map
- Terrain to include:
  - Grassland
  - Plains
  - Forest
  - Hills
  - River
  - Ocean/Sea
  - Mountain

### 2.4 Economy and Progression

- Basic yields:
  - Food
  - Production
  - Gold
- Science is fixed-output for now
- Initial tech scope:
  - Pottery / 制陶术
  - Masonry / 采石术

### 2.5 City System

- Founding new cities is not in current first-version scope
- Existing starting city is mandatory
- Population growth is required
- Production queue is required
- Border expansion is automatic
- Initial production options:
  - Monument / 纪念碑
  - Granary / 粮仓

### 2.6 Save System

- Save is required
- Load is required

## 3. Non-Goals for V1 / V1 明确不做

- Warfare
- Units and tactical movement
- Diplomacy
- Multiple civilizations
- AI opponents
- Fog of war
- Random map generation
- Complex resource classes
- Expanded eras beyond the initial primitive-era subset
- Formal victory rules

## 4. Product Goal / 产品目标

The first meaningful milestone is not a content-rich clone of Civilization VI. It is a stable, extensible strategy-game foundation with a playable city loop.

首要目标不是复刻《文明6》，而是建立一个稳定、可扩展、可持续迭代的策略游戏基础框架，并跑通“城市经营”核心循环。

Success criteria for the first playable version:

- Player can start a game and enter a turn loop
- A fixed hex map renders correctly
- One city exists and displays core data
- Tiles provide yields
- Population grows over turns
- Production queue completes buildings over turns
- Simple technology progression works
- Save/load preserves game state

## 5. Core Gameplay Loop / 核心循环

1. Start game on a fixed visible hex map.
2. Enter turn-based loop.
3. City collects yields from worked tiles and fixed science output.
4. Food contributes to population growth.
5. Production contributes to current build queue item.
6. Gold accumulates as a basic economic output.
7. Research progresses toward one selected technology.
8. Borders expand automatically according to designed rules.
9. Player ends turn and repeats.

## 6. Functional Requirements / 功能需求

### 6.1 Game Flow

- Main menu is recommended, but lightweight implementation is acceptable
- New game
- Save game
- Load game
- End turn

### 6.2 Map System

- Support hex tile coordinate system
- Load fixed map data from a reusable format
- Render terrain and tile state in 2D top-down view
- Mark river, mountain, forest, hill, and water relationships cleanly enough for future rules expansion

### 6.3 Tile and Yield System

- Each tile has terrain data
- Tile may include modifiers such as forest, hill, river adjacency, or mountain blocking
- Tile yields must be data-driven where possible
- First version only needs food, production, and gold outputs

### 6.4 City System

- One initial city exists at game start
- City stores:
  - name
  - owner
  - population
  - worked tiles or equivalent simplified assignment model
  - border ownership
  - production queue
  - stored food / growth progress
- Automatic border expansion must be rule-based and extensible

### 6.5 Production System

- Queue supports at least one active item
- Queue items for V1:
  - Monument
  - Granary
- Production progress carries over across turns
- Completed item applies its effect to city state

### 6.6 Technology System

- Minimal tech tree
- Initial nodes:
  - Pottery
  - Masonry
- Research uses fixed science output for now
- Tech definitions should be data-driven for future expansion

### 6.7 UI

- Show turn information
- Show city panel
- Show current yields
- Show current production
- Show current research
- Show tile info on selection/hover
- Keep UI structure simple and readable

### 6.8 Save/Load

- Persist full game state
- Save format should be human-debuggable if practical, such as JSON-based serialization
- Versioning strategy should be considered early to support future schema changes

## 7. Technical Direction / 技术方向

### 7.1 Engine and Language

- Godot 4
- GDScript

Reasoning:

- Fast iteration for solo development
- Strong 2D workflow
- Easy scene-based decomposition
- Good cross-platform export support

### 7.2 Architectural Principles

- Data-driven definitions for tiles, buildings, and technologies
- Separate game rules from UI scenes
- Keep turn simulation deterministic where possible
- Prefer clear domain models over scene-coupled logic
- Plan for future addition of units, AI, diplomacy, and procedural content without rewriting core systems

### 7.3 Suggested High-Level Modules

- `core`
  - turn manager
  - game state
  - save/load
- `map`
  - hex coordinates
  - tile data
  - map loader
  - map renderer
- `city`
  - city model
  - growth
  - borders
  - production
- `tech`
  - tech definitions
  - research progress
- `ui`
  - HUD
  - city panel
  - tech panel
  - tile info panel
- `data`
  - terrain
  - buildings
  - technologies
  - fixed map data

## 8. Suggested Repository Structure / 建议目录结构

```text
civilization/
├─ doc/
│  └─ proposal.md
├─ flake.nix
├─ flake.lock
├─ project.godot
├─ game/
│  ├─ scenes/
│  │  ├─ main/
│  │  ├─ map/
│  │  ├─ city/
│  │  └─ ui/
│  ├─ scripts/
│  │  ├─ core/
│  │  ├─ map/
│  │  ├─ city/
│  │  ├─ tech/
│  │  └─ save/
│  ├─ data/
│  │  ├─ terrain/
│  │  ├─ buildings/
│  │  ├─ tech/
│  │  └─ maps/
│  └─ assets/
│     ├─ art/
│     └─ ui/
└─ tools/
```

Notes:

- Keep rules code under `scripts`, not scattered inside scene trees
- Keep content definitions under `data`
- Keep fixed map data independent from rendering logic

## 9. Development Environment / 开发环境

### 9.1 NixOS Development

Preferred approach:

- Use `flake.nix`
- Pin toolchain versions
- Make Godot editor and export templates reproducible where practical

Recommended environment goals:

- Godot 4 editor available from `nix develop`
- Common CLI helpers available
- Consistent formatting/lint workflow when later introduced

Suggested responsibilities for `flake.nix`:

- Provide Godot 4 package
- Provide git and common development tools
- Provide shell environment variables if the project later needs export/template paths

Initial Nix TODO:

- Create `flake.nix`
- Define `devShell`
- Verify Godot launches from shell
- Verify project opens successfully
- Document exact startup command

### 9.2 macOS Development

Recommended baseline:

- Install Godot 4 officially or via package manager if the team accepts that workflow
- Use the same repository structure and data layout as on NixOS
- Keep all runtime-sensitive paths relative to project root

macOS TODO:

- Install matching Godot 4 version
- Open project and verify scene/script compatibility
- Verify fonts, input, and file paths behave consistently

### 9.3 Cross-Platform Runtime Targets

Required runtime targets:

- Windows
- macOS
- Linux

Cross-platform constraints:

- Avoid platform-specific filesystem assumptions
- Avoid case-sensitive-path mistakes
- Keep save path abstraction centralized
- Use Godot-supported export presets early, not at the very end

## 10. Data Design Recommendations / 数据设计建议

### 10.1 Terrain Data

Each terrain/tile definition should ideally include:

- id
- display_name
- base_yields
- movement_cost_reserved_for_future
- tags
- render_key

### 10.2 Building Data

Each building definition should ideally include:

- id
- display_name
- production_cost
- prerequisites
- yield_modifiers
- unique_effects

### 10.3 Technology Data

Each technology definition should ideally include:

- id
- display_name
- science_cost
- prerequisites
- unlocks

## 11. Milestones / 里程碑

### M0 - Environment and Project Bootstrap

- Create Godot 4 project
- Add `flake.nix`
- Confirm project opens on NixOS
- Confirm project opens on macOS
- Establish repo structure

### M1 - Hex Map Foundation

- Implement hex coordinate system
- Load fixed `40 x 20` map data
- Render terrain in 2D top-down view
- Support tile selection and inspection

### M2 - Turn Loop and Core State

- Implement game state container
- Implement end-turn flow
- Advance yields by turn
- Keep map fully visible

### M3 - City Loop

- Spawn one initial city
- Display city panel
- Implement population growth
- Implement automatic border expansion
- Implement production queue with Monument and Granary

### M4 - Tech and Save/Load

- Implement Pottery and Masonry
- Add fixed science progression
- Implement save/load
- Validate game state restoration

### M5 - Stabilization

- Clean up data definitions
- Test on Windows/macOS/Linux export targets
- Refine UI readability
- Remove hard-coded assumptions where possible

## 12. Personal TODO List / 个人推进清单

- [ ] Create `flake.nix` for Godot 4 development
- [ ] Initialize Godot 4 project
- [ ] Define hex coordinate representation
- [ ] Define map data format for fixed `40 x 20` layout
- [ ] Create terrain data entries
- [ ] Build 2D map renderer
- [ ] Add tile inspection UI
- [ ] Implement turn manager
- [ ] Implement city state model
- [ ] Implement population growth
- [ ] Implement border expansion rules
- [ ] Implement production queue
- [ ] Add Monument effects
- [ ] Add Granary effects
- [ ] Implement tech data and research progress
- [ ] Implement save/load serialization
- [ ] Verify project on NixOS
- [ ] Verify project on macOS
- [ ] Export test for Windows/macOS/Linux

## 13. Risks / 风险

- Hex system complexity can leak into many subsystems if coordinates are not standardized early
- Mixing scene logic and gameplay rules too early will slow later expansion
- Save format changes can become painful if versioning is ignored
- Cross-platform export issues are easier to catch early than late
- Even a “simple” Civ-like loop grows quickly; scope discipline is essential

## 14. Future Expansion After V1 / V1 后续扩展方向

- More technologies
- More buildings
- Tile improvements
- Settlers and additional cities
- Units and non-combat movement
- Combat
- AI factions
- Diplomacy
- Fog of war
- Random map generation
- Formal victory conditions

## 15. Current Decision Summary / 当前结论

The project should begin as a data-driven Godot 4 + GDScript city-management prototype on a fixed visible hex map, optimized for long-term expansion rather than short-term feature volume.

项目应从一个数据驱动的 Godot 4 + GDScript 原型开始：固定地图、全图可见、单城市经营、简化科技树、支持存档读档，并优先保证未来可扩展性。
