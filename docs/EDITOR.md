# Developer Table Editor v1

An **internal development tool** for authoring greybox pinball tables fast. Not a
production player-facing creator, but built so a future safe restricted player
editor could reuse the same registry + table-definition format. Dev-only.

Design target: Mario-Maker-simple, Unreal-style inspector, Paradigm table tools —
**left** Asset Library, **center** 3D viewport, **right** Inspector, **top** toolbar.

## Opening / modes
- Launch the game, press **F2** to enter/exit the editor (or run with `-- editor`).
- **EDIT MODE**: gameplay physics suspended (ball frozen/hidden), full editor UI,
  mouse manipulation active.
- **PLAY TEST** (toolbar ▶ or F2): the in-memory layout becomes playable
  immediately — no save required — physics resumes, ball respawns, editing off.
  Returning to Edit preserves the edited layout exactly.
- Edit Mode and **F4 Live Tuning** are mutually exclusive.

## Architecture (controller / view split)
- `scripts/editor/table_editor.gd` (**TableEditor**, controller): pure logic —
  selection, snap, transform/add/delete/duplicate ops, inspector `set_property`,
  bounded undo/redo, save/load/new/duplicate, Edit/Play mode. Emits signals;
  **headless-testable** (`tools/editor_probe.gd`). In group `table_editor`;
  flippers query `is_active()`.
- `scripts/editor/editor_shell.gd` (**EditorShell**, view): the CanvasLayer UI
  (toolbar, Asset Library, Inspector), viewport mouse pick/hover/drag, the 3D
  transform gizmo, and drag-to-place ghost. All state changes go through the
  controller.
- The live `Table` node is the source of truth; it serializes to/from the JSON
  table-definition (`TableLoader` / `TableDefinition`) on save/load.

## Viewport controls
- **Hover** a component → subtle highlight. **Left-click** → select (persistent
  yellow highlight + gizmo). **Click empty** → clear selection. **Tab / Shift+Tab**
  → keyboard fallback cycle.
- **Drag body** → move on the X/Z plane. **Gizmo handles**: red X, blue Z, green Y
  (move), yellow knob (yaw). Snapping applies to drags.
- Keyboard fallback: arrows move X/Z, PgUp/PgDn move Y, `,`/`.` rotate yaw,
  `-`/`=` scale, **Shift** = coarse, **Del** delete, **Ins** duplicate, **Esc**
  clear/cancel.

## Snapping (toolbar)
- Position: Off / 0.25 / 0.5 / 1.0 units. Rotation: Off / 5° / 15° / 30°.
- Respected by dragging and numeric inspector edits.

## Asset Library (left)
Populated entirely from `TableRegistry.META` — categories (Flippers, Bumpers,
Slingshots, Ramps, Walls / Guides, Targets, Lanes / Spawns, Utility), search
filter, category dropdown. **Drag** an asset onto the table: a translucent ghost
follows the snapped cursor; release places a component with a stable unique ID,
adds it to the table state and selects it — no save/reload cycle.

## Inspector (right)
Universal fields (ID, Type, Pos X/Y/Z, Yaw°, Scale) plus component-specific
editable properties from `META.editable_properties` (explicit metadata — **no**
arbitrary script reflection). Editing a field applies immediately, updates table
state, and clamps invalid values to the metadata range.

## Undo / Redo
Bounded history (64 ops, session-only): move, rotate, scale, add, delete,
duplicate, property change. **Ctrl+Z** undo, **Ctrl+Y** / **Ctrl+Shift+Z** redo,
toolbar buttons.

## Save / Load (PAR-43)
- **New** (minimal floor + spawn), **Save**, **Save As** (id + name), **Load**
  (picks from a list), duplicate via Save As. Dirty state shown as `● unsaved`.
- Files: `res://data/pinball/tables/` when writable (running from source), else
  `user://tables/`. Never overwrites packed resources from an exported build.
- Format = the versioned, human-readable JSON table-definition
  (`docs/TABLE_DEFINITION.md`) — safe, no executable state.

## Adding a new component type (future-proofing)
Add one entry to `TableRegistry.META` (type → scene, category, display name,
description, icon, default + editable properties, placement tags) and a
`type_of()` branch. It then appears in the Asset Library and Inspector with **no
editor UI changes** — e.g. Tesla Bumper, Portal, Spinner, Drop-Target Bank.

## Automated tests
- `godot --headless -- editortest` — controller smoke test (pick/move/rotate/snap/
  add/delete/duplicate/undo/redo/inspector-apply+serialize/save-load round-trip/
  Play↔Edit preserve/flipper-operational-after-move/serialize-safety).
- `godot --headless -- selftest` — physics self-test (unchanged, still passes).

## Manual QA checklist
Run the game, press **F2**:
1. **Library**: type "bump" in Search → only Pop Bumper shows; clear; pick a
   category → list filters.
2. **Place**: drag "Pop Bumper" onto the table → ghost follows + snaps → release →
   a new bumper appears, selected, inspector populated.
3. **Select**: click the flippers, ramp, a wall, the drain, the ball spawn → each
   selects with highlight + gizmo; click empty → clears.
4. **Move**: drag the selected component on the table → it follows; toggle Pos snap
   0.5 → movement snaps to the grid.
5. **Gizmo**: drag the green handle → height changes; drag the yellow knob → it
   rotates; red/blue arrows constrain to X/Z.
6. **Rotate**: set Rot snap 15°, rotate → snaps to 15° increments.
7. **Inspector**: change Radius / Impulse (-1=global) → the bumper updates live;
   enter an out-of-range value → it clamps.
8. **Undo/Redo**: move, add, delete, edit a property → Ctrl+Z reverts each; Ctrl+Y
   re-applies.
9. **Save**: Save As → id `qa_test` → check `data/pinball/tables/qa_test.json`
   (or `user://tables/`); the dirty dot clears.
10. **Play Test**: click ▶ Play Test → the ball spawns and the edited table is
    playable; flippers (A/D) work even if you moved them.
11. **Back to Edit**: F2 → layout is exactly as you left it.
12. **Reload**: Load → `qa_test` → same layout returns.
13. **Tuning exclusivity**: press F4 while editing → tuning does not open.
