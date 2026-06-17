# Map Preview Visual Enhancement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add automatic light texture and icon overlays to terrain-like map generator preview views while keeping heatmap views clean.

**Architecture:** Extend the existing `MapGeneratorPreview` image rendering path. Base colors remain unchanged; helper methods draw procedural texture marks and compact pixel symbols into the generated `Image` before it becomes an `ImageTexture`.

**Tech Stack:** Godot 4, GDScript, existing `Image` / `ImageTexture` preview rendering, existing `ResourceDefinitionCatalog`.

---

## File Structure

- Modify `game/scenes/dev/MapGeneratorPreview.tscn`: add a `VisualEnhancementButton` `OptionButton` near the current view controls.
- Modify `game/scripts/dev/map_generator_preview.gd`: wire the control, decide when enhancement is active, draw world/local textures and symbols, and append the legend text.
- Modify `doc/documents/map_generator.md`: update the visual enhancement section with implementation details.
- Modify `doc/tasks/map_generator.md`: mark the visual enhancement task complete after code is implemented.

No new imported art assets are required. No automated validation is run unless the user explicitly asks for it.

---

### Task 1: Add the Visual Enhancement UI Control

**Files:**
- Modify: `game/scenes/dev/MapGeneratorPreview.tscn`
- Modify: `game/scripts/dev/map_generator_preview.gd`

- [ ] **Step 1: Add the scene nodes**

In `game/scenes/dev/MapGeneratorPreview.tscn`, insert these nodes after `DirectionOverlayToggle` and before `GenerateButton`:

```ini
[node name="VisualEnhancementLabel" type="Label" parent="Root/Controls/Margin/Column"]
layout_mode = 2
text = "视觉增强"

[node name="VisualEnhancementButton" type="OptionButton" parent="Root/Controls/Margin/Column"]
unique_name_in_owner = true
layout_mode = 2
```

- [ ] **Step 2: Add constants and node binding**

In `game/scripts/dev/map_generator_preview.gd`, add constants near the other mode constants:

```gdscript
const ENHANCEMENT_AUTO := 0
const ENHANCEMENT_OFF := 1
```

Add the `@onready` binding after `direction_overlay_toggle`:

```gdscript
@onready var visual_enhancement_button: OptionButton = %VisualEnhancementButton
```

- [ ] **Step 3: Configure and wire the control**

In `_ready()`, call setup before connecting signals:

```gdscript
_setup_visual_enhancement_modes()
```

Connect the control after the direction overlay connection:

```gdscript
visual_enhancement_button.item_selected.connect(func(_index: int) -> void: _on_visual_enhancement_changed())
```

Add the setup method after `_setup_view_modes()`:

```gdscript
func _setup_visual_enhancement_modes() -> void:
	visual_enhancement_button.clear()
	visual_enhancement_button.add_item("自动", ENHANCEMENT_AUTO)
	visual_enhancement_button.add_item("关闭", ENHANCEMENT_OFF)
	visual_enhancement_button.select(0)
```

Add the signal handler near `_on_view_mode_changed()`:

```gdscript
func _on_visual_enhancement_changed() -> void:
	_render_preview()
	if preview_mode == MODE_LOCAL:
		_update_local_summary_after_view_change()
	elif map_state != null:
		_update_summary(_build_config_from_inputs())
```

---

### Task 2: Add Enhancement Activation and Legend Helpers

**Files:**
- Modify: `game/scripts/dev/map_generator_preview.gd`

- [ ] **Step 1: Add activation helpers**

Add these methods near `_summary_text_with_elevation_legend()`:

```gdscript
func _visual_enhancement_active() -> bool:
	if visual_enhancement_button == null:
		return false
	if visual_enhancement_button.get_selected_id() == ENHANCEMENT_OFF:
		return false
	return view_mode_button.get_selected_id() in [VIEW_TERRAIN, VIEW_FEATURES, VIEW_RESOURCES]

func _summary_text_with_visual_legend(summary_text: String) -> String:
	if not _visual_enhancement_active():
		return summary_text
	return "%s\n视觉增强：● 资源  ◆ 山地/岩石  ♣ 森林  ≈ 湿地  · 沙地/雪地  ▲ 丘陵" % summary_text
```

- [ ] **Step 2: Update summary composition**

Replace `_summary_text_with_elevation_legend()` with:

```gdscript
func _summary_text_with_elevation_legend(summary_text: String) -> String:
	var result := summary_text
	if view_mode_button.get_selected_id() == VIEW_ELEVATION:
		result = "%s\n%s" % [result, _elevation_legend_text()]
	return _summary_text_with_visual_legend(result)
```

This keeps the existing elevation legend and adds the visual legend only when the enhancement is active.

---

### Task 3: Draw World Map Texture and Symbols

**Files:**
- Modify: `game/scripts/dev/map_generator_preview.gd`

- [ ] **Step 1: Call the world enhancement pass**

In `_render_preview()`, after the nested loops that set base pixels and before `map_texture.texture = ...`, add:

```gdscript
	if _visual_enhancement_active():
		_draw_world_visual_enhancement(image)
```

- [ ] **Step 2: Add deterministic drawing helpers**

Add these helper methods near the color helpers:

```gdscript
func _draw_world_visual_enhancement(image: Image) -> void:
	for row in range(map_state.height):
		for col in range(map_state.width):
			var tile = map_state.get_tile_by_offset(col, row)
			if tile == null:
				continue
			_draw_world_tile_texture(image, col, row, tile)
			_draw_world_tile_symbol(image, col, row, tile)

func _draw_world_tile_texture(image: Image, col: int, row: int, tile) -> void:
	if tile.is_mountain():
		_draw_preview_mark(image, col, row, Color("#6d6a62"), 0)
	elif tile.is_hill():
		_draw_preview_mark(image, col, row, Color("#6f5d3f"), 1)
	elif tile.is_swamp():
		_draw_preview_mark(image, col, row, Color("#2f5f55"), 2)
	elif tile.has_feature("forest"):
		_draw_preview_mark(image, col, row, Color("#174b25"), 3)
	elif tile.biome == "desert":
		_draw_preview_mark(image, col, row, Color("#9a7b3d"), 4)
	elif tile.biome == "snow_mountain" or tile.biome == "tundra":
		_draw_preview_mark(image, col, row, Color("#ffffff"), 5)

func _draw_world_tile_symbol(image: Image, col: int, row: int, tile) -> void:
	if not tile.resource_ids.is_empty():
		_draw_resource_symbol(image, col, row, resource_catalog.color(String(tile.resource_ids[0])))
	elif tile.is_mountain():
		_draw_preview_symbol(image, col, row, Color("#f4efe4"), 0)
	elif tile.has_feature("forest"):
		_draw_preview_symbol(image, col, row, Color("#d6f0c6"), 1)
	elif tile.is_swamp():
		_draw_preview_symbol(image, col, row, Color("#d1f2e6"), 2)
	elif tile.biome == "desert" or tile.biome == "snow_mountain" or tile.biome == "tundra":
		_draw_preview_symbol(image, col, row, Color("#fff3c6"), 3)
	elif tile.is_hill():
		_draw_preview_symbol(image, col, row, Color("#f0d9a2"), 4)
```

- [ ] **Step 3: Add reusable mark and symbol primitives**

Add these methods below the world helpers:

```gdscript
func _draw_preview_mark(image: Image, x: int, y: int, color: Color, pattern: int) -> void:
	match pattern:
		0:
			_blend_preview_pixel(image, x, y, color, 0.34)
		1:
			if (x + y) % 2 == 0:
				_blend_preview_pixel(image, x, y, color, 0.22)
		2:
			if x % 2 == 0:
				_blend_preview_pixel(image, x, y, color, 0.28)
		3:
			_blend_preview_pixel(image, x, y, color, 0.26)
		4:
			if (x * 3 + y * 5) % 4 == 0:
				_blend_preview_pixel(image, x, y, color, 0.22)
		5:
			if (x * 7 + y * 11) % 5 == 0:
				_blend_preview_pixel(image, x, y, color, 0.30)

func _draw_preview_symbol(image: Image, x: int, y: int, color: Color, symbol: int) -> void:
	match symbol:
		0:
			_blend_preview_pixel(image, x, y, color, 0.72)
		1:
			_blend_preview_pixel(image, x, y, color, 0.58)
		2:
			_blend_preview_pixel(image, x, y, color, 0.52)
		3:
			_blend_preview_pixel(image, x, y, color, 0.45)
		4:
			_blend_preview_pixel(image, x, y, color, 0.48)

func _draw_resource_symbol(image: Image, x: int, y: int, color: Color) -> void:
	_blend_preview_pixel(image, x, y, color.lightened(0.25), 0.86)

func _blend_preview_pixel(image: Image, x: int, y: int, color: Color, alpha: float) -> void:
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return
	var base := image.get_pixel(x, y)
	image.set_pixel(x, y, base.lerp(color, clampf(alpha, 0.0, 1.0)))
```

These first-pass world marks operate at one generated image pixel per world tile, matching the current preview image resolution.

---

### Task 4: Draw Local Map Texture and Symbols

**Files:**
- Modify: `game/scripts/dev/map_generator_preview.gd`

- [ ] **Step 1: Call the local enhancement pass**

In `_render_local_map()`, after the nested loops that set base cell pixels and before `map_texture.texture = ...`, add:

```gdscript
	if _visual_enhancement_active():
		_draw_local_visual_enhancement(image)
```

- [ ] **Step 2: Add local enhancement helpers**

Add these methods near `_local_terrain_color()`:

```gdscript
func _draw_local_visual_enhancement(image: Image) -> void:
	for y in range(local_map_state.height):
		for x in range(local_map_state.width):
			var index: int = local_map_state.index(x, y)
			_draw_local_cell_texture(image, x, y, index)
			_draw_local_cell_symbol(image, x, y, index)

func _draw_local_cell_texture(image: Image, x: int, y: int, index: int) -> void:
	if local_map_state.water_flags[index] == 1 or local_map_state.river_flags[index] == 1:
		return
	if local_map_state.terrain_flags.size() != local_map_state.heights.size():
		return
	var flags: int = int(local_map_state.terrain_flags[index])
	if (flags & LocalMapStateScript.TERRAIN_ROCK) != 0:
		_draw_preview_mark(image, x, y, Color("#6d6a62"), 0)
	elif (flags & LocalMapStateScript.TERRAIN_WETLAND) != 0:
		_draw_preview_mark(image, x, y, Color("#2f5f55"), 2)
	elif (flags & LocalMapStateScript.TERRAIN_FOREST) != 0:
		_draw_preview_mark(image, x, y, Color("#174b25"), 3)
	elif (flags & LocalMapStateScript.TERRAIN_SAND) != 0:
		_draw_preview_mark(image, x, y, Color("#9a7b3d"), 4)
	elif (flags & LocalMapStateScript.TERRAIN_SNOW) != 0:
		_draw_preview_mark(image, x, y, Color("#ffffff"), 5)

func _draw_local_cell_symbol(image: Image, x: int, y: int, index: int) -> void:
	var resource_id: String = _local_first_resource_id_at_index(index)
	if resource_id != "":
		_draw_resource_symbol(image, x, y, resource_catalog.color(resource_id))
		return
	if local_map_state.water_flags[index] == 1 or local_map_state.river_flags[index] == 1:
		return
	if local_map_state.terrain_flags.size() != local_map_state.heights.size():
		return
	var flags: int = int(local_map_state.terrain_flags[index])
	if (flags & LocalMapStateScript.TERRAIN_ROCK) != 0:
		_draw_preview_symbol(image, x, y, Color("#f4efe4"), 0)
	elif (flags & LocalMapStateScript.TERRAIN_FOREST) != 0:
		_draw_preview_symbol(image, x, y, Color("#d6f0c6"), 1)
	elif (flags & LocalMapStateScript.TERRAIN_WETLAND) != 0:
		_draw_preview_symbol(image, x, y, Color("#d1f2e6"), 2)
	elif (flags & LocalMapStateScript.TERRAIN_SAND) != 0 or (flags & LocalMapStateScript.TERRAIN_SNOW) != 0:
		_draw_preview_symbol(image, x, y, Color("#fff3c6"), 3)
```

The local map has one generated image pixel per local cell, so these marks are intentionally subtle and rely on nearest-neighbor preview scaling.

---

### Task 5: Keep Documentation in Sync

**Files:**
- Modify: `doc/documents/map_generator.md`
- Modify: `doc/tasks/map_generator.md`

- [ ] **Step 1: Update design documentation**

In `doc/documents/map_generator.md`, extend the existing "地图预览视觉增强" bullets with implementation details:

```markdown
  - 首版不引入外部贴图资源，直接在预览 `Image` 上绘制程序化像素纹理和符号。
  - 视觉增强判定集中在预览脚本 helper 中，后续正式地图渲染可以复用同一套符号语义。
```

- [ ] **Step 2: Mark task progress complete**

In `doc/tasks/map_generator.md`, change:

```markdown
- [ ] 地图生成器预览增加自动视觉增强，在地貌类视图中叠加轻纹理和图标
```

to:

```markdown
- [x] 地图生成器预览增加自动视觉增强，在地貌类视图中叠加轻纹理和图标
```

---

### Task 6: Optional Validation if User Requests It

**Files:**
- No file changes.

- [ ] **Step 1: Skip validation by default**

Per `AGENTS.md`, do not run program verification, tests, or headless checks unless the user explicitly asks.

- [ ] **Step 2: If validation is requested, run a Godot parse/headless check**

Run:

```bash
nix develop -c godot4 --headless --path . --quit-after 1
```

Expected: Godot starts, loads the project, and exits without script parse errors.

If the command fails because dependencies or network access are blocked, request approval before rerunning with escalation.

---

## Self-Review

- Spec coverage: The plan adds the automatic/off control, applies enhancement only to terrain-like world/local views, keeps heatmap views clean, preserves river/direction overlays, adds resource and terrain symbol priority, and updates docs/tasks.
- Placeholder scan: No task uses open-ended placeholders.
- Type consistency: All new constants, node names, and helper names are defined before use.
