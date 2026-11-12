# HoverWise changelog

Versions follow semantic versioning: MAJOR.MINOR.PATCH.
MAJOR for changes that break saved settings or commands, MINOR for new features, PATCH for fixes.

## 1.1.0 (2026-11-12)
- Damage spells show whether they beat your equipped wand, per second of casting (at least the global cooldown): "Beats your wand: 25.0 vs 14.8 damage per second" or "Your wand does more". Only the up-front hit counts, not damage over time (Immolate is compared on its initial burn); spells that only do damage over time, and heals, get no comparison. Channelled spells count over the channel. Only shown with a wand equipped; can be turned off in the options.
- `/hoverwise wand` shows your wand's damage per second and the numbers behind it. Talents such as Wand Specialization are already part of the wand's damage range.

## 1.0.1 (2026-11-12)
- `/hoverwise` opens the options without a "tried to call the protected function" error from Blizzard's options window. Without the client call that allows that, it says where to find the options instead.

## 1.0.0 (2026-11-12)
- Tooltips follow the cursor (to its right), for the game world and, optionally, the interface. Offsets can be set.
- Unit tooltips show the unit's target, coloured by class or reaction, kept up to date while the tooltip is shown.
- Tooltips for members of your guild show their guild rank (optionally for every guild).
- Ore veins, herbs and skinnable corpses show the profession level they need, such as "Mining 175", coloured against your own skill.
- Unit tooltips also show the target's own target ("Target: Grunt > Doc") and which of your party or raid targets the unit.
- Player names in class colours, and the border tinted by class or reaction.
- Level coloured by difficulty, with elites, rares and bosses marked.
- Health numbers on the tooltip's health bar, or the bar hidden.
- Your standing with an NPC's faction, such as "Orgrimmar - Honored".
- Skinning level on living beasts, not only corpses.
- Recipes show the skill they need coloured against yours, and whether they're known or learnable.
- Lockboxes and junkboxes show the lockpicking level they need.
- Tooltip size and background opacity.
- Options panel in Options > AddOns > HoverWise, with searchable settings. `/hoverwise` opens it.
