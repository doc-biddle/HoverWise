-- HoverWise: more useful tooltips.
--  * tooltips follow the cursor, at the size and background opacity you choose,
--  * unit tooltips: class colours, a level line coloured by difficulty, health numbers, the unit's target and its
--    target's target, who in your group targets it, guild rank, and your standing with its faction,
--  * ore veins, herbs, beasts, recipes and lockboxes show the profession level they need, coloured against your skill.
--
-- Only hooks are used (hooksecurefunc, HookScript and the tooltip data post-calls): no Blizzard function is replaced.

local ADDON = ...

local DEFAULTS = {
	anchor = true,         -- tooltips follow the cursor
	anchorUI = true,       -- interface tooltips (skills, buttons) too, not only the game world
	offsetX = 0,
	offsetY = 0,
	scale = 100,           -- tooltip size, percent
	opacity = 100,         -- background opacity, percent of Blizzard's
	classColors = true,    -- player names in class colours
	border = true,         -- border tinted by class (players) or reaction (everything else)
	levelColor = true,     -- level line coloured by difficulty, with elite and rare marked
	healthText = true,     -- health numbers on the health bar
	hideHealthBar = false, -- no health bar at all
	target = true,         -- "Target: <name>"
	targetTarget = true,   -- "Target: <name> > <its target>"
	targetedBy = true,     -- "Targeted by: <group members>"
	rank = true,           -- guild rank for members of your own guild
	rankAll = false,       -- guild rank for every guild
	faction = true,        -- your standing with an NPC's faction
	profession = true,     -- required profession level on nodes and corpses
	skinLiving = true,     -- skinning level on living beasts too
	recipes = true,        -- recipe skill coloured against yours, with known / learnable
	lockpicking = true,    -- lockpicking level on lockboxes and junkboxes
}

local function DB()
	HoverWiseDB = HoverWiseDB or {}
	local db = HoverWiseDB
	for k, v in pairs(DEFAULTS) do
		if db[k] == nil then db[k] = v end
	end
	return db
end

-- Helpers ------------------------------------------------------------------------------------------------------

-- Values the game keeps secret from addons (some health and unit values, in some situations) can be shown but not
-- compared or calculated with.
local function Secret(v)
	return issecretvalue ~= nil and issecretvalue(v) == true
end

-- Runs a feature without letting its errors reach the game; each different error is printed once per session.
local reported = {}
local function Try(fn, ...)
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	local message = tostring(a)
	if not reported[message] then
		reported[message] = true
		print("|cff40c0ffHoverWise|r error (shown once): " .. message)
	end
end

-- Whether two unit tokens are the same unit. Falls back to comparing GUIDs when the game keeps the answer secret.
local function SameUnit(a, b)
	local ok, same = pcall(UnitIsUnit, a, b)
	if ok and not Secret(same) then return same and true or false end
	local ga, gb = UnitGUID(a), UnitGUID(b)
	if ga and gb and not Secret(ga) and not Secret(gb) then return ga == gb end
	return false
end

local function Hex(r, g, b)
	return ("|cff%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function ClassColor(unit)
	if not UnitIsPlayer(unit) then return nil end
	local _, class = UnitClass(unit)
	return class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
end

local function ReactionColor(unit)
	local reaction = UnitReaction(unit, "player")
	return reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
end

-- A unit's name in its class colour (players) or reaction colour (everything else).
local function ColoredName(unit)
	if not UnitExists(unit) then return nil end
	local name = UnitName(unit)
	if not name then return nil end
	if SameUnit(unit, "player") then return "|cffff4040>> You <<|r" end
	local c = ClassColor(unit) or ReactionColor(unit)
	if c then return Hex(c.r, c.g, c.b) .. name .. "|r" end
	return name
end

local function Line(tooltip, i)
	local name = tooltip:GetName()
	return name and _G[name .. "TextLeft" .. i]
end

local function FindLine(tooltip, test, from)
	for i = from or 1, tooltip:NumLines() do
		local fs = Line(tooltip, i)
		local text = fs and fs:GetText()
		if text and not Secret(text) and test(text) then return fs, i end
	end
end

-- Your rank in a skill, by name (nil if you don't have it).
local function SkillRank(name)
	if GetNumSkillLines and GetSkillLineInfo then
		for i = 1, GetNumSkillLines() do
			local skill, isHeader, _, rank = GetSkillLineInfo(i)
			if not isHeader and skill == name then return rank end
		end
	end
	return nil
end

-- Gathering colours: red can't, orange always gives a skill-up, yellow usually, green rarely, grey never.
local function SkillColor(rank, need)
	if not rank or rank < need then return "|cffff2020" end
	if rank < need + 25 then return "|cffff8040" end
	if rank < need + 50 then return "|cffffff00" end
	if rank < need + 100 then return "|cff40bf40" end
	return "|cff808080"
end

local function SkillText(profession, need)
	return SkillColor(SkillRank(profession), need) .. profession .. " " .. need .. "|r"
end

-- Looks ---------------------------------------------------------------------------------------------------------

-- Tooltips that would go to the default corner spot follow the cursor instead.
if GameTooltip_SetDefaultAnchor then
	hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
		local db = DB()
		if not db.anchor or not tooltip or not parent then return end
		local overWorld = WorldFrame.IsMouseMotionFocus and WorldFrame:IsMouseMotionFocus()
		if not overWorld and not db.anchorUI then return end
		tooltip:SetOwner(parent, "ANCHOR_CURSOR_RIGHT", db.offsetX, db.offsetY)
	end)
end

local defaultCenter, defaultBorder

local function NineSlice(tooltip)
	local ns = tooltip.NineSlice
	if ns and ns.SetCenterColor and ns.GetCenterColor then return ns end
end

-- Size and background opacity, put back each time the tooltip shows (Blizzard restyles it then).
local function ApplyLooks(tooltip)
	local db = DB()
	tooltip:SetScale(db.scale / 100)
	local ns = NineSlice(tooltip)
	if ns then
		local r, g, b, a = ns:GetCenterColor()
		if r and not defaultCenter then defaultCenter = { r, g, b, a or 1 } end
		if defaultCenter then
			ns:SetCenterColor(defaultCenter[1], defaultCenter[2], defaultCenter[3], defaultCenter[4] * db.opacity / 100)
		end
	end
end

local function SetBorder(tooltip, c)
	local ns = NineSlice(tooltip)
	if not (ns and ns.SetBorderColor) then return end
	if not defaultBorder and ns.GetBorderColor then
		local r, g, b, a = ns:GetBorderColor()
		if r then defaultBorder = { r, g, b, a or 1 } end
	end
	if c then
		ns:SetBorderColor(c.r, c.g, c.b, 1)
	elseif defaultBorder then
		ns:SetBorderColor(unpack(defaultBorder))
	end
end

-- Units ---------------------------------------------------------------------------------------------------------

local TARGET = (TARGET or "Target") .. ": "
local TARGETED_BY = "Targeted by: "

local function StyleName(tooltip, unit)
	local db = DB()
	local c = ClassColor(unit)
	if db.classColors and c then
		local fs = Line(tooltip, 1)
		if fs then fs:SetTextColor(c.r, c.g, c.b) end
	end
	if db.border then SetBorder(tooltip, c or ReactionColor(unit)) end
end

local CLASSIFICATION = {
	elite = ELITE or "Elite",
	rareelite = "Rare " .. (ELITE or "Elite"),
	rare = "Rare",
	worldboss = BOSS or "Boss",
}

-- "Level 24" becomes a difficulty-coloured "Level 24 Elite".
local function StyleLevel(tooltip, unit)
	if not DB().levelColor then return end
	local levelWord = LEVEL or "Level"
	local fs = FindLine(tooltip, function(text) return text:find(levelWord, 1, true) == 1 end, 2)
	if not fs then return end
	local level = UnitLevel(unit)
	local c
	if level and level > 0 then
		c = (GetCreatureDifficultyColor or GetQuestDifficultyColor)(level)
	else
		c = { r = 1, g = 0.1, b = 0.1 }
	end
	local text = fs:GetText()
	local shown = level and level > 0 and tostring(level) or "??"
	text = text:gsub("^(" .. levelWord .. "%s+)(%S+)", function(word) return word .. Hex(c.r, c.g, c.b) .. shown .. "|r" end, 1)
	local class = UnitClassification and CLASSIFICATION[UnitClassification(unit)]
	if class and not text:find(class, 1, true) then
		text = text:gsub("^(" .. levelWord .. "%s+%S+)", "%1 |cffffd100" .. class .. "|r", 1)
	end
	fs:SetText(text)
end

local function AddGuildRank(tooltip, unit)
	local db = DB()
	if not db.rank or not UnitIsPlayer(unit) then return end
	local guild, rank = GetGuildInfo(unit)
	if not (guild and rank) then return end
	if not db.rankAll and guild ~= GetGuildInfo("player") then return end
	local fs = FindLine(tooltip, function(text) return text:find(guild, 1, true) ~= nil end)
	if fs and not fs:GetText():find(rank, 1, true) then
		fs:SetText(fs:GetText() .. " |cffaaaaaa- " .. rank .. "|r")
	end
end

-- Your reputation, by faction name. Rebuilt when it changes.
local standings
local function Standings()
	if standings then return standings end
	standings = {}
	if C_Reputation and C_Reputation.GetNumFactions and C_Reputation.GetFactionDataByIndex then
		for i = 1, C_Reputation.GetNumFactions() do
			local f = C_Reputation.GetFactionDataByIndex(i)
			if f and f.name and not f.isHeader then standings[f.name] = f.reaction end
		end
	elseif GetNumFactions and GetFactionInfo then
		for i = 1, GetNumFactions() do
			local name, _, standing, _, _, _, _, _, isHeader = GetFactionInfo(i)
			if name and not isHeader then standings[name] = standing end
		end
	end
	return standings
end

-- "Orgrimmar" becomes "Orgrimmar - Honored", in the standing's colour.
local function AddFaction(tooltip, unit)
	if not DB().faction or UnitIsPlayer(unit) then return end
	local list = Standings()
	local fs, _ = FindLine(tooltip, function(text) return list[text] ~= nil end, 2)
	if not fs then return end
	local standing = list[fs:GetText()]
	local label = _G["FACTION_STANDING_LABEL" .. standing]
	local c = FACTION_BAR_COLORS and FACTION_BAR_COLORS[standing]
	if label then
		fs:SetText(fs:GetText() .. " - " .. (c and Hex(c.r, c.g, c.b) or "") .. label .. "|r")
	end
end

-- "Target: Grunt > Doc": the unit's target, and that target's own target.
local function TargetText(unit)
	local db = DB()
	if not db.target then return nil end
	local name = ColoredName(unit .. "target")
	if not name then return nil end
	if db.targetTarget then
		local next = ColoredName(unit .. "targettarget")
		if next then name = name .. " |cffaaaaaa>|r " .. next end
	end
	return TARGET .. name
end

-- Members of your party or raid (and you) whose target is the unit.
local function TargetedByText(unit)
	if not DB().targetedBy then return nil end
	local names = {}
	local prefix, count = "party", 0
	if IsInRaid and IsInRaid() then
		prefix, count = "raid", GetNumGroupMembers()
	elseif IsInGroup and IsInGroup() then
		count = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
	end
	-- "playertarget" doesn't match in this client, so your own target is checked as "target".
	local function Check(member)
		if UnitExists(member) and SameUnit(member == "player" and "target" or member .. "target", unit) then names[#names + 1] = ColoredName(member) end
	end
	if prefix == "party" then Check("player") end
	for i = 1, count do Check(prefix .. i) end
	if #names == 0 then return nil end
	return TARGETED_BY .. table.concat(names, ", ")
end

-- Lines that change while the tooltip is up, kept at fixed positions so they can be rewritten in place.
local function SetDynamicLine(tooltip, key, text)
	local index = tooltip[key]
	if index then
		local fs = Line(tooltip, index)
		if not fs then return false end
		local old = fs:GetText()
		if Secret(text) or Secret(old) or old ~= (text or " ") then fs:SetText(text or " "); return not Secret(text) end
	elseif text then
		tooltip:AddLine(text, 1, 1, 1)
		tooltip[key] = tooltip:NumLines()
		return true
	end
	return false
end

local function UpdateDynamic(tooltip, unit)
	local changed = SetDynamicLine(tooltip, "hoverWiseTarget", TargetText(unit))
	changed = SetDynamicLine(tooltip, "hoverWiseTargetedBy", TargetedByText(unit)) or changed
	return changed
end

-- Health numbers on the tooltip's health bar. Creatures often only report a percentage (max 100).
local bar = GameTooltipStatusBar
local function UpdateHealth()
	if not bar or not bar.hoverWiseText then return end
	local unit = GameTooltip.hoverWiseUnit
	if not (DB().healthText and unit and UnitExists(unit)) then bar.hoverWiseText:SetText("") return end
	local hp, max = UnitHealth(unit), UnitHealthMax(unit)
	if Secret(hp) or Secret(max) then
		-- Can be shown, not worked with: plain numbers, no percentage.
		if not pcall(bar.hoverWiseText.SetFormattedText, bar.hoverWiseText, "%s / %s", hp, max) then bar.hoverWiseText:SetText("") end
		return
	end
	if not max or max <= 0 then bar.hoverWiseText:SetText("") return end
	local pct = math.floor(hp / max * 100 + 0.5)
	if max == 100 then
		bar.hoverWiseText:SetText(pct .. "%")
	else
		local fmt = AbbreviateLargeNumbers or tostring
		bar.hoverWiseText:SetText(fmt(hp) .. " / " .. fmt(max) .. " (" .. pct .. "%)")
	end
end

if bar then
	bar.hoverWiseText = bar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
	bar.hoverWiseText:SetPoint("CENTER", bar, "CENTER", 0, 0)
	bar:HookScript("OnValueChanged", function() Try(UpdateHealth) end)
	bar:HookScript("OnShow", function(self)
		if DB().hideHealthBar then self:Hide() end
	end)
end

-- Professions ---------------------------------------------------------------------------------------------------

-- Skill needed to gather each node, by its name (English client).
local NODES = {
	-- Mining
	["Copper Vein"] = { "Mining", 1 },
	["Tin Vein"] = { "Mining", 65 },
	["Incendicite Mineral Vein"] = { "Mining", 65 },
	["Silver Vein"] = { "Mining", 75 },
	["Ooze Covered Silver Vein"] = { "Mining", 75 },
	["Lesser Bloodstone Deposit"] = { "Mining", 75 },
	["Iron Deposit"] = { "Mining", 125 },
	["Indurium Mineral Vein"] = { "Mining", 150 },
	["Gold Vein"] = { "Mining", 155 },
	["Ooze Covered Gold Vein"] = { "Mining", 155 },
	["Mithril Deposit"] = { "Mining", 175 },
	["Ooze Covered Mithril Deposit"] = { "Mining", 175 },
	["Truesilver Deposit"] = { "Mining", 230 },
	["Ooze Covered Truesilver Deposit"] = { "Mining", 230 },
	["Dark Iron Deposit"] = { "Mining", 230 },
	["Small Thorium Vein"] = { "Mining", 245 },
	["Ooze Covered Thorium Vein"] = { "Mining", 245 },
	["Rich Thorium Vein"] = { "Mining", 275 },
	["Ooze Covered Rich Thorium Vein"] = { "Mining", 275 },
	["Hakkari Thorium Vein"] = { "Mining", 275 },
	["Small Obsidian Chunk"] = { "Mining", 305 },
	["Large Obsidian Chunk"] = { "Mining", 305 },
	-- Herbalism
	["Peacebloom"] = { "Herbalism", 1 },
	["Silverleaf"] = { "Herbalism", 1 },
	["Bloodthistle"] = { "Herbalism", 1 },
	["Earthroot"] = { "Herbalism", 15 },
	["Mageroyal"] = { "Herbalism", 50 },
	["Briarthorn"] = { "Herbalism", 70 },
	["Stranglekelp"] = { "Herbalism", 85 },
	["Bruiseweed"] = { "Herbalism", 100 },
	["Wild Steelbloom"] = { "Herbalism", 115 },
	["Grave Moss"] = { "Herbalism", 120 },
	["Kingsblood"] = { "Herbalism", 125 },
	["Liferoot"] = { "Herbalism", 150 },
	["Fadeleaf"] = { "Herbalism", 160 },
	["Goldthorn"] = { "Herbalism", 170 },
	["Khadgar's Whisker"] = { "Herbalism", 185 },
	["Wintersbite"] = { "Herbalism", 195 },
	["Firebloom"] = { "Herbalism", 205 },
	["Purple Lotus"] = { "Herbalism", 210 },
	["Arthas' Tears"] = { "Herbalism", 220 },
	["Sungrass"] = { "Herbalism", 230 },
	["Blindweed"] = { "Herbalism", 235 },
	["Ghost Mushroom"] = { "Herbalism", 245 },
	["Gromsblood"] = { "Herbalism", 250 },
	["Golden Sansam"] = { "Herbalism", 260 },
	["Dreamfoil"] = { "Herbalism", 270 },
	["Mountain Silversage"] = { "Herbalism", 280 },
	["Plaguebloom"] = { "Herbalism", 285 },
	["Icecap"] = { "Herbalism", 290 },
	["Black Lotus"] = { "Herbalism", 300 },
}

-- Lockpicking needed to open each lockbox or junkbox, by item name.
local LOCKBOXES = {
	["Ornate Bronze Lockbox"] = 1,
	["Battered Junkbox"] = 1,
	["Heavy Bronze Lockbox"] = 25,
	["Iron Lockbox"] = 70,
	["Worn Junkbox"] = 70,
	["Strong Iron Lockbox"] = 125,
	["Steel Lockbox"] = 175,
	["Sturdy Junkbox"] = 175,
	["Reinforced Steel Lockbox"] = 225,
	["Mithril Lockbox"] = 225,
	["Thorium Lockbox"] = 225,
	["Eternium Lockbox"] = 225,
	["Heavy Junkbox"] = 250,
}

-- Skinning needs 1 up to level 10, then 10 per level to 100 at level 20, then 5 per level.
local function SkinningNeed(level)
	if level <= 10 then return 1 end
	if level <= 20 then return (level - 10) * 10 end
	return level * 5
end

local SKINNABLE = UNIT_SKINNABLE_LEATHER or "Skinnable"
local BEAST = "Beast"

local function AddSkinning(tooltip, unit)
	local db = DB()
	if not db.profession or UnitIsPlayer(unit) then return end
	-- Hunter pets, warlock demons and other player-controlled units can't be skinned.
	if UnitPlayerControlled and UnitPlayerControlled(unit) then return end
	local level = UnitLevel(unit)
	if not level or level <= 0 then return end
	local text = SkillText("Skinning", SkinningNeed(level))
	if UnitIsDead(unit) then
		local fs = FindLine(tooltip, function(t) return t == SKINNABLE end)
		if fs then fs:SetText(text) end
	elseif db.skinLiving and UnitCreatureType and UnitCreatureType(unit) == BEAST then
		tooltip:AddLine(text)
	end
end

-- Nodes: the tooltip's first line is the node's name.
local function AddNode(tooltip)
	if not DB().profession or tooltip.hoverWiseNode then return end
	-- Only world objects: not items (Peacebloom is an item too), units or spells, and not tooltips owned by a button.
	local owner = tooltip:GetOwner()
	if owner ~= UIParent and owner ~= WorldFrame then return end
	if (tooltip.GetItem and tooltip:GetItem()) or (tooltip.GetUnit and tooltip:GetUnit()) then return end
	if tooltip.GetSpell and tooltip:GetSpell() then return end
	local first = Line(tooltip, 1)
	local node = first and NODES[first:GetText() or ""]
	if not node then return end
	tooltip.hoverWiseNode = true
	-- Replace Blizzard's "Requires Mining" or "Mining" line if there is one, otherwise add a line.
	local fs = FindLine(tooltip, function(text) return text ~= first:GetText() and text:find(node[1], 1, true) ~= nil end)
	if fs then fs:SetText(SkillText(node[1], node[2])) else tooltip:AddLine(SkillText(node[1], node[2])) end
	tooltip:Show()
end

-- Items: recipes and lockboxes.
local REQUIRES = (ITEM_MIN_SKILL or "Requires %s (%d)"):gsub("[%(%)%.%-%+%[%]]", "%%%0"):gsub("%%s", "(.-)"):gsub("%%d", "(%%d+)")
local KNOWN = ITEM_SPELL_KNOWN or "Already known"

local function AddItem(tooltip)
	if tooltip.hoverWiseItem then return end
	tooltip.hoverWiseItem = true
	local db = DB()
	local name, link = tooltip:GetItem()
	if not name then return end

	if db.lockpicking and LOCKBOXES[name] then
		tooltip:AddLine(SkillText("Lockpicking", LOCKBOXES[name]))
		tooltip:Show()
		return
	end

	if not db.recipes or not link then return end
	local classID = select(12, GetItemInfo(link))
	local recipeClass = (Enum and Enum.ItemClass and Enum.ItemClass.Recipe) or 9
	if classID ~= recipeClass then return end
	local known = FindLine(tooltip, function(text) return text == KNOWN end) ~= nil
	local fs, _ = FindLine(tooltip, function(text) return text:match("^" .. REQUIRES .. "$") ~= nil end, 2)
	if not fs then return end
	local profession, need = fs:GetText():match("^" .. REQUIRES .. "$")
	need = tonumber(need)
	if not (profession and need) then return end
	local rank = SkillRank(profession)
	local status
	if known then
		status = "|cff808080" .. profession .. " " .. need .. " - known|r"
	elseif rank and rank >= need then
		status = "|cff40ff40" .. profession .. " " .. need .. " - learnable|r"
	elseif rank then
		status = "|cffff2020" .. profession .. " " .. need .. " - you have " .. rank .. "|r"
	else
		status = "|cffff2020" .. profession .. " " .. need .. "|r"
	end
	fs:SetText(status)
	tooltip:Show()
end

-- Wiring ---------------------------------------------------------------------------------------------------------

local function OnUnit(tooltip)
	if tooltip ~= GameTooltip then return end
	local _, unit = tooltip:GetUnit()
	if not unit then return end
	tooltip.hoverWiseUnit = unit
	tooltip.hoverWiseTarget = nil
	tooltip.hoverWiseTargetedBy = nil
	Try(StyleName, tooltip, unit)
	Try(StyleLevel, tooltip, unit)
	Try(AddGuildRank, tooltip, unit)
	Try(AddFaction, tooltip, unit)
	Try(AddSkinning, tooltip, unit)
	Try(UpdateDynamic, tooltip, unit)
	Try(UpdateHealth)
end

local function OnItem(tooltip)
	if tooltip == GameTooltip or tooltip == ItemRefTooltip then Try(AddItem, tooltip) end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnUnit)
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItem)
	if Enum.TooltipDataType.Object then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Object, function(tooltip)
			if tooltip == GameTooltip then Try(AddNode, tooltip) end
		end)
	end
else
	GameTooltip:HookScript("OnTooltipSetUnit", OnUnit)
	GameTooltip:HookScript("OnTooltipSetItem", OnItem)
	if ItemRefTooltip then ItemRefTooltip:HookScript("OnTooltipSetItem", OnItem) end
end

-- World objects don't always come through the data post-calls; their name is in place once the tooltip shows.
GameTooltip:HookScript("OnShow", function(tooltip)
	Try(ApplyLooks, tooltip)
	Try(AddNode, tooltip)
end)
for _, tip in ipairs({ GameTooltip, ItemRefTooltip }) do
	if tip then
		tip:HookScript("OnTooltipCleared", function(tooltip)
			tooltip.hoverWiseNode = nil
			tooltip.hoverWiseItem = nil
			tooltip.hoverWiseUnit = nil
			tooltip.hoverWiseTarget = nil
			tooltip.hoverWiseTargetedBy = nil
			Try(SetBorder, tooltip, nil)
			if tooltip == GameTooltip and bar and bar.hoverWiseText then bar.hoverWiseText:SetText("") end
		end)
	end
end

-- Keep target lines and health current while the tooltip stays up.
local elapsed = 0
GameTooltip:HookScript("OnUpdate", function(tooltip, dt)
	elapsed = elapsed + dt
	if elapsed < 0.2 then return end
	elapsed = 0
	local unit = tooltip.hoverWiseUnit
	if not unit or not UnitExists(unit) then return end
	if Try(UpdateDynamic, tooltip, unit) then tooltip:Show() end
	Try(UpdateHealth)
end)

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("UPDATE_FACTION")

-- Settings -------------------------------------------------------------------------------------------------------

local category

local function BuildOptions()
	if category or not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterProxySetting) then return end
	local cat, layout = Settings.RegisterVerticalLayoutCategory("HoverWise")
	local VT = Settings.VarType or {}
	local Checkbox = Settings.CreateCheckbox or Settings.CreateCheckBox

	local function Section(title)
		if layout and CreateSettingsListSectionHeaderInitializer then
			layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(title))
		end
	end

	local function Toggle(key, name, tooltip)
		local setting = Settings.RegisterProxySetting(cat, "HOVERWISE_" .. key:upper(), VT.Boolean or "boolean", name, DEFAULTS[key],
			function() return DB()[key] and true or false end,
			function(value) DB()[key] = value and true or false end)
		Checkbox(cat, setting, tooltip)
	end

	local function Slider(key, name, min, max, step, suffix, tooltip)
		local setting = Settings.RegisterProxySetting(cat, "HOVERWISE_" .. key:upper(), VT.Number or "number", name, DEFAULTS[key],
			function() return DB()[key] end,
			function(value) DB()[key] = value end)
		local options = Settings.CreateSliderOptions(min, max, step)
		if MinimalSliderWithSteppersMixin then
			options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v) return tostring(v) .. (suffix or "") end)
		end
		Settings.CreateSlider(cat, setting, options, tooltip)
	end

	Section("Position and look")
	Toggle("anchor", "Tooltips follow the cursor", "Tooltips appear to the right of the cursor instead of in the corner of the screen.")
	Toggle("anchorUI", "Interface tooltips too", "Skill, button and other interface tooltips follow the cursor as well, not only tooltips for things in the game world.")
	Slider("offsetX", "Cursor offset across", -60, 60, 1, nil, "How far right of the cursor tooltips appear.")
	Slider("offsetY", "Cursor offset up", -60, 60, 1, nil, "How far above the cursor tooltips appear.")
	Slider("scale", "Tooltip size", 50, 150, 5, "%", "Size of tooltips.")
	Slider("opacity", "Background opacity", 0, 100, 5, "%", "How see-through the tooltip background is. 100% is Blizzard's.")

	Section("Units")
	Toggle("classColors", "Class-coloured player names", "Player names in their class colour.")
	Toggle("border", "Coloured border", "The tooltip border takes the player's class colour, or for creatures and NPCs how friendly they are.")
	Toggle("levelColor", "Level coloured by difficulty", "The level is coloured grey, green, yellow, orange or red against your own level, and elites, rares and bosses are marked.")
	Toggle("healthText", "Health numbers", "Shows health on the tooltip's health bar, such as \"272 / 272 (100%)\". Creatures that only report a percentage show that.")
	Toggle("hideHealthBar", "Hide the health bar", "Removes the health bar under unit tooltips.")
	Toggle("target", "Show the unit's target", "Adds a \"Target:\" line, coloured by class or reaction. It updates while the tooltip is shown.")
	Toggle("targetTarget", "Show the target's target", "Adds what the target is targeting to the same line, such as \"Target: Grunt > Doc\".")
	Toggle("targetedBy", "Show who targets it (you and your group)", "Adds a \"Targeted by:\" line listing who has the unit targeted: you, and the members of your party or raid.")
	Toggle("rank", "Show guild ranks for your guild", "Adds the guild rank after the guild name on tooltips for members of your own guild.")
	Toggle("rankAll", "Show guild ranks for all guilds", "Shows the guild rank for members of every guild, not only yours. Needs the setting above.")
	Toggle("faction", "Show your faction standing", "Adds your standing after an NPC's faction, such as \"Orgrimmar - Honored\", in the standing's colour.")

	Section("Professions")
	Toggle("profession", "Show required profession level", "Ore veins, herbs and skinnable corpses show the skill they need, such as \"Mining 175\". The colour compares it with your own skill: red means you can't gather it yet, then orange, yellow, green and grey as skill-ups get rarer.")
	Toggle("skinLiving", "Skinning level on living beasts", "Beasts show the skinning level they will need before you kill them. Needs the setting above.")
	Toggle("recipes", "Recipe skill and status", "Recipes, patterns and plans show the skill they need coloured against yours, and whether you already know them, can learn them, or what your skill is.")
	Toggle("lockpicking", "Lockpicking level on lockboxes", "Lockboxes and junkboxes show the lockpicking skill needed to open them.")

	Settings.RegisterAddOnCategory(cat)
	category = cat
end

events:SetScript("OnEvent", function(self, event, name)
	if event == "UPDATE_FACTION" then standings = nil return end
	if name ~= ADDON then return end
	self:UnregisterEvent("ADDON_LOADED")
	DB()
	local ok, err = pcall(BuildOptions)
	if not ok then print("HoverWise: the options panel could not be built (" .. tostring(err) .. ").") end
end)

SLASH_HOVERWISE1 = "/hoverwise"
SlashCmdList.HOVERWISE = function()
	if not category then BuildOptions() end
	-- Opening Blizzard's options window from addon code makes the game treat the whole window as addon-driven, and
	-- Blizzard's own checks inside it then get blocked and blamed on this addon. The client's own call avoids that;
	-- without it, say where the options are instead of opening them.
	if category and C_SettingsUtil and C_SettingsUtil.OpenSettingsPanel then
		C_SettingsUtil.OpenSettingsPanel(category.GetID and category:GetID() or category)
	else
		print("HoverWise: the options are in Options > AddOns > HoverWise (or search the options for \"HoverWise\").")
	end
end
