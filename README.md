# HoverWise

<img src="media/logo.png" alt="HoverWise logo" width="128" align="right">

A small WoW Forever addon that makes tooltips more useful. Every feature below can be turned on or off in its options.

## Features

### Position and look
- **Tooltips follow the cursor:** tooltips appear to the right of the cursor instead of in the corner of the screen.
- **Interface tooltips too:** skill, button and other interface tooltips follow the cursor as well, not only things in the game world.
- **Cursor offset:** how far across and up from the cursor tooltips appear.
- **Tooltip size:** 50% to 150%.
- **Background opacity:** how see-through the tooltip background is.

### Units (players, creatures and NPCs)
- **Class-coloured player names.**
- **Coloured border:** the player's class colour, or how friendly a creature or NPC is.
- **Level coloured by difficulty:** grey, green, yellow, orange or red against your level, with elites, rares and bosses marked ("Level 24 Elite").
- **Health numbers** on the tooltip's health bar ("272 / 300 (91%)"), or the health bar hidden.
- **The unit's target:** "Target: Grunt", coloured by class or reaction, kept up to date while the tooltip is shown.
- **The target's target:** "Target: Grunt > Doc".
- **Who targets it:** "Targeted by:" lists you and the members of your party or raid who have the unit targeted.
- **Guild rank** after the guild name, for your own guild or for every guild.
- **Faction standing** after an NPC's faction ("Orgrimmar - Honored"), in the standing's colour.

### Professions
- **Gathering level** on ore veins and herbs ("Mining 175", "Herbalism 205").
- **Skinning level** on skinnable corpses, and optionally on living beasts before you kill them (not on hunter pets or other player-controlled creatures).
- **Recipe status** on recipes, patterns and plans: the skill they need, and whether you know them, can learn them, or what your skill is now.
- **Lockpicking level** on lockboxes and junkboxes.
- Required levels are coloured against your own skill: red means you can't yet, then orange, yellow, green and grey as skill-ups get rarer.

### Spells
- **Wand comparison** on damage spells, when you have a wand equipped: whether the spell's up-front hit beats your wand per second of casting ("Beats your wand: 25.0 vs 14.8 damage per second"). Damage over time isn't counted, and spells that only do damage over time get no comparison. Talents such as Wand Specialization are included. `/hoverwise wand` shows the wand's numbers.

## Settings

Options > AddOns > HoverWise, or type `/hoverwise`. Every setting can also be found with the options search box.

## Installing

Install it from the WowUp Hub, Wago or CurseForge, or download the zip from Releases and extract the `HoverWise` folder into `_forever_\Interface\AddOns`.

## License

GPL-3.0. See [LICENSE](LICENSE).
