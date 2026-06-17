# Map Preview Visual Enhancement Design

## Goal

Improve the map generator preview so terrain, resources, and local map cells are easier to read at a glance. The preview should keep the existing color views as the primary signal, then add low-contrast textures and compact symbols where they improve recognition.

## Scope

The first implementation targets `MapGeneratorPreview`. The drawing logic should be kept in small helper methods so the same symbol and texture decisions can later be reused by the formal world map renderer.

The feature does not change map generation data, resource definitions, local map generation, or formal gameplay state.

## User-Approved Direction

The selected visual direction is "icons plus light texture":

- Colors stay dominant.
- Terrain identity is reinforced with subtle pixel textures.
- Key map states use compact symbols.
- Heatmap views stay clean and do not receive icons by default.

## Behavior

Add a visual enhancement mode with two choices:

- `自动`: the default. Enhancement is enabled for terrain-like views and disabled for pure heatmap views.
- `关闭`: disables icon and texture drawing and restores the current color-only preview.

Automatic enhancement applies to:

- World map: basic terrain, features, resources.
- Local map: basic terrain, features, resources.

Automatic enhancement does not apply to:

- Elevation.
- Rainfall.
- Temperature.
- River-only and direction views, because those already use dedicated colors or direction overlays.

## Visual Rules

Symbol priority:

1. Resource.
2. Mountain or local rock.
3. Forest.
4. Wetland or swamp.
5. Sand or snow.
6. Hill.

Rivers keep the existing blue path/color treatment and should not be replaced by symbols.

Texture treatment:

- Forest: sparse dark-green clusters.
- Mountain/rock: low-contrast diagonal strokes or peaks.
- Wetland/swamp: short wave marks.
- Sand/desert: scattered dots.
- Snow: pale speckles.
- Hill: short contour strokes.

Resource cells/tiles use a small high-contrast marker in the center, using the resource catalog color.

## UI

Add a control near the direction overlay toggle:

- Label/text: `视觉增强`
- Options: `自动`, `关闭`
- Default: `自动`

The left summary should add a compact legend only when enhancement is active for the current view, for example:

`视觉增强：● 资源  ◆ 山地/岩石  ♣ 森林  ≈ 湿地  · 沙地/雪地  ▲ 丘陵`

## Implementation Notes

The existing preview builds `Image` objects and converts them to `ImageTexture`. The first version should draw directly into those images after base colors are written.

Keep helpers focused:

- Determine whether enhancement is active for the current mode and view.
- Draw world tile texture and symbol.
- Draw local cell texture and symbol.
- Append enhancement legend text.

Avoid adding imported art assets for this version. Pixel symbols and procedural marks are enough for the dev preview and do not require Godot import metadata.

## Validation

Per repository rules, automated validation should only be run when the user explicitly requests it. Manual inspection in the Godot editor is the expected validation path unless the user asks for checks.
