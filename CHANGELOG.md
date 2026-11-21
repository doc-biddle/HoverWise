# HoverWise changelog

Versions follow semantic versioning: MAJOR.MINOR.PATCH.
MAJOR for changes that break saved settings or commands, MINOR for new features, PATCH for fixes.

## 1.3.1 (2026-11-21)
- The skinning line on living beasts no longer shows on kinds that can't be skinned. The game only says so on the corpse, so HoverWise remembers what corpses show: once you have looted one bare and it had no "Skinnable" line, the living ones of that kind stop showing a skinning level. Until a corpse has settled it either way, the level on a living beast carries a question mark, such as "Skinning 1 ?". This is shared by all your characters.

## 1.3.0 (2026-11-16)
- New option "Show vendor prices" (Options > AddOns > HoverWise > Items, or `/hoverwise vendor always|auto|never`): the game's own "Sell Price" line on item tooltips can be hidden, always or only while Auctionator or TradeSkillMaster is set to show its own vendor price, so the same price isn't listed two or three times. At a merchant the game's line stays, since it is the price for the whole stack. The default is unchanged: always shown.

## 1.2.0 (2026-11-15)
- Gathering, skinning and lockpicking levels only show on characters that have the skill: no more "Skinning 100" on every beast for a character who isn't a skinner. Recipes still show the skill they need for everyone.

## 1.1.3 (2026-11-14)
- Recipe tooltips show your skill again ("you have 126"): the skill lookup used `GetNumSkillLines`, which this client no longer has, so every recipe looked unlearnable. It now reads `C_SkillInfo`.
- If something inside HoverWise fails, the error is printed once and also passed to the game's error handler, so BugSack and similar addons collect it with a full stack.

## 1.1.2 (2026-11-13)
- No more "attempt to call a nil value" error (HoverWise.lua:514) when hovering an item: the recipe check used `GetItemInfo`, which this client no longer has.

## 1.1.1 (2026-11-13)
- Wand comparison reads the cast time from the tooltip's own cast line ("1.5 sec cast"), which always includes talents such as Improved Frostbolt.
- No more "Secret values are only allowed during untainted execution" or "attempt to compare a secret value" errors when hovering units in dungeons, where the game keeps the tooltip's unit, and some answers about it (level, creature type), secret. Units under the cursor still get the tooltip; anything the game keeps secret is left as the game shows it.
- The skinning line on living beasts only shows on beasts you can attack, not on friendly ones such as the Great Cat Spirit.

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
