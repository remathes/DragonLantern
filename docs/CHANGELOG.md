Version 1.3

- Fixed: removing the mod could wipe merchants' stock (for example the Crow's Perch quartermaster) and gear you'd bought. The game cuts off a saved inventory at the first item it doesn't recognise, and earlier versions left the lantern and oil in shops' stock permanently. Shops now only show them while you're trading; unsold ones are removed when you close the shop, and old lantern stock from 1.0-1.2 is cleared too.
- New: ddluninstall console command. Run it before removing the mod: it takes every Belt Lantern and Lantern Oil out of Geralt's inventory and from nearby merchants. Then save, and remove the mod.

Already removed the mod and lost gear? Reinstall it and load a save from before you removed it: the gear is still in that save.

Version 1.2

- New: "Hide lantern" option, replacing "Hide in cutscenes". Hide it in dialogue and cutscenes (as before), in cutscenes only, or never. "In cutscenes only" keeps the lantern lit while Geralt examines bodies in quest scenes.
- Improved: Shadows (experimental). With shadows on, the light now sits a little out from Geralt's body, so he casts a natural silhouette instead of huge shadows across the room. The lantern's own glass and frame no longer cast shadows, and the shadows no longer lag behind as the lantern moves.
- New: Light forward / Light up / Light out sliders (experimental) to fine-tune where the light sits when Shadows is on. Default: 30 / 30 / 30 cm.
- Fixed: settings you had never changed showed as Off or 0 in the menu (the mod still used its defaults). They now show the real defaults.
- Fixed: the preset row at the top of the menu showed "##preset" text.

Updating: replace the settings menu file (bin\config\r4game\user_config_matrix\pc\modDragonsLantern.xml) with the new one, or the new options won't appear.

Version 1.1

- New: riding position. While Geralt is on horseback the lantern moves to the back of his belt, clear of the saddle and his leg, and returns to his hip when he dismounts.
- New: light or douse the lantern while riding with the use-item button (middle mouse / R1 / RB). The game normally blocks usable items in the saddle.
- Fixed: shops sometimes didn't stock the Belt Lantern and Lantern Oil after restocking.

Version 1.0 - First release

- Belt Lantern: equip it in a Pockets slot and it hangs from Geralt's left hip with both hands free, like the Arisen's lantern in Dragon's Dogma. Also offers right hip, front-left and small of the back, and an option to keep it on the belt even when not equipped.
- Auto light: lights when placed in a Pockets slot and goes out when removed. Can also light only at night, or be manual only. Use it from the quick slot to light or douse it by hand.
- Lantern Oil: a lit lantern burns oil (8 game hours per flask by default) and refills itself from carried flasks.
- Swimming or diving puts the flame out.
- Hidden in cutscenes and dialogue. Swings as Geralt moves.
- Innkeepers and shopkeepers sell the Belt Lantern and Lantern Oil, each with its own inventory icon.
- Settings under Options > Mods > Dragon's Lantern: position, brightness, light radius, oil use, auto light and more.
- Text in all 17 languages the game supports.
- Built for The Witcher 3 Remastered (5.0).

Report bugs on GitHub: https://github.com/remathes/DragonLantern/issues
