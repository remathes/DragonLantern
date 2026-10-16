# Building the lantern entity in REDkit

The script uses one entity, `mods\dragons_lantern\ddl_lantern.w2ent`: a copy of
the vanilla dwarven lantern with its component names kept. Position, swing,
light and oil are all handled in `dragonsLantern.ws`.

REDkit only sees files inside the project's **`workspace\`** folder, which it
shows as **virtualdepot**. Here that's
`workspace\mods\dragons_lantern\ddl_lantern.w2ent` in the project folder.

## 1. Copy the vanilla lantern

In the Asset Browser, right-click `items\work\lantern_dwarf_01\lantern_dwarf_01.w2ent`,
choose **Save as...**, and save it into `virtualdepot\mods\dragons_lantern\` as
`ddl_lantern.w2ent`. Never use **Checkout**: it unlocks the vanilla file itself.

## 2. Components

The vanilla entity has five components. The script finds them by these names:

| Component | What it is | What to do |
|---|---|---|
| `lantern_dwarf_base` | Rig, the "carrier" | Keep. The script positions and swings this. |
| `lantern_dwarf` | Body mesh | Keep. It must move when the base moves (see the test below). |
| `hinge_lantern_dwarf` | Vanilla dangle | Keep. The script disables it at runtime. |
| `CPointLightComponent0` | Light | Keep. **Attach it to `lantern_dwarf_base`**: drag from the base node's orange dot onto the light node. |
| `CSpotLightComponent0` | Spot light | Delete it (select it, then press Delete). The lantern is omnidirectional, like in Dragon's Dogma. |

**Test in the editor:** select `lantern_dwarf_base` and turn it with **Rotate** in
the preview. The body and the light should both follow. If the body doesn't,
attach `lantern_dwarf` to the base the same way. Then press Ctrl+Z to undo the
test rotation, and save.

Optional: add an effect called `ddl_fire` (for example a small candle flame
particle from the vanilla `fx` folder). The script plays it when lit and stops
it when doused. If there's no such effect, nothing breaks.

## 3. Pack the bundle

Pack into the mod's `content\blob0.bundle`:

- `mods\dragons_lantern\ddl_lantern.w2ent` (the vanilla meshes it uses are already in the game)
- `gameplay\items\def_item_dragons_lantern.xml` (from `src\items\`)
- `gameplay\items_plus\def_item_dragons_lantern.xml` (the same file)

## 4. First in-game check

1. Install (see the README), load a save, open the console, and run `ddlgive`.
2. Equip the Belt Lantern in a quick slot and run `ddlstatus`. You want
   `owned=yes entity=yes`.
3. If it's floating, sideways or inside Geralt:
   - **Small offsets:** use the three offset sliders in Options > Mods > Dragon's Lantern.
   - **Wrong orientation:** try each **Model orientation** option (Upright A-D) in the mod menu.
   - **Swings on the wrong axis:** swap or negate the two `rotation.` lines at the end of
     `DDL_SwingTick`.
4. Script errors show up when the game compiles scripts at startup. The log
   channel is `DDLantern`.
