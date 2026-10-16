# Provenance

Dragon's Lantern is original work. Its code and data come only from the game's
own 5.0 sources, as shipped with REDkit (`r4data\scripts`, `r4data\gameplay`),
and from in-game testing. It contains no files, code or assets from other mods.

| Part | Based on |
|---|---|
| Lantern model | Vanilla entity `items\work\lantern_dwarf_01\lantern_dwarf_01.w2ent` (spot light removed, point light attached to the base) |
| Lantern item | Vanilla "Oil Lamp" usable in `gameplay\items\def_item_misc.xml` and its `oil_lamp` type in `def_item_usable_types.xml` |
| Oil item | Vanilla stackable `misc` items in `def_item_misc.xml`; icon is the vanilla `oil_64x64.png` with a flame added (`src\icons\lantern_oil_64x64.png`) |
| Lantern icon | Made for this mod from REDkit's own preview render of the vanilla lantern model (`src\icons\belt_lantern_64x64.png`) |
| Workshop thumbnail | The author's own in-game screenshots |
| Quick-slot use | Vanilla flow: `CPlayerInput.OnCbtThrowItem` and the radial menu call `CR4Player.OnUseSelectedItem()` |
| Pockets slots | Vanilla `EEquipmentSlots` (`EES_Quickslot1/2`) and `W3PlayerWitcher.GetItemEquippedOnSlot` |
| Shop stocking | Vanilla `CR4InventoryMenu.OnConfigUI`: an NPC tagged `Merchant` is a shop, and `W3MerchantComponent.GetMapPinType` gives its type |
| Menu text keys | Vanilla string keys (`panel_`, `option_`, `preset_value_` prefixes) |
| Placement, glow, swing, oil, water, auto light | Written for this mod and tuned in game |
