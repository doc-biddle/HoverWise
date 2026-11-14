-- HoverWise in a fake game: unit, item, node and spell tooltips, secret values, and error forwarding.

-- A fake game with units, a tooltip that holds lines, and HoverWise loaded. `units` describes what the game
-- reports for each unit token; `opts.secret` lists answers the game keeps secret.
local function World(units, opts)
	opts = opts or {}
	local game, h = FakeWoW.New()
	local post = {}

	-- The tooltip: lines are font strings named GameTooltipTextLeftN, as in the game.
	local tip = game.CreateFrame("GameTooltip", "GameTooltip")
	tip.lines = {}
	function tip:NumLines() return #self.lines end
	function tip:AddLine(text)
		local fs = game.CreateFrame("FontString", "GameTooltipTextLeft" .. (#self.lines + 1))
		function fs:SetText(t) self.text = t end
		function fs:GetText() return self.text end
		function fs:SetTextColor() end
		fs.text = text
		table.insert(self.lines, fs)
	end
	function tip:GetOwner() return self.owner end
	function tip:GetUnit() if self.unit then return "name", self.unit end end
	function tip:GetItem() if self.item then return self.item, "link:" .. self.item end end
	function tip:GetSpell() if self.spell then return self.spell.name, self.spell.id end end
	function tip:Text()
		local out = {}
		for _, fs in ipairs(self.lines) do out[#out + 1] = tostring(fs.text) end
		return table.concat(out, " | ")
	end
	function tip:Reset()
		for i = 1, #self.lines do h.Env()["GameTooltipTextLeft" .. i] = nil end
		self.lines, self.unit, self.item, self.spell, self.owner = {}, nil, nil, nil, nil
		FakeWoW.RunScript(self, "OnTooltipCleared")
	end
	game.GameTooltipStatusBar = game.CreateFrame("StatusBar", "GameTooltipStatusBar")
	game.TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) post[kind] = fn end }
	game.Enum = { TooltipDataType = { Item = 0, Spell = 1, Unit = 2, Object = 33 }, ItemClass = { Recipe = 9 } }

	-- Units.
	local function U(u) return units[u] or {} end
	local function Ask(u, field, value)
		if opts.secret and opts.secret[field] then return FakeWoW.Secret(field) end
		return value
	end
	game.UnitExists = function(u) assert(not FakeWoW.IsSecret(u), "UnitExists got a secret unit"); return units[u] ~= nil end
	game.UnitName = function(u) return Ask(u, "name", U(u).name) end
	game.UnitIsPlayer = function(u) assert(not FakeWoW.IsSecret(u), "UnitIsPlayer got a secret unit"); return U(u).player or false end
	game.UnitIsUnit = function(a, b) return a == b end
	game.UnitGUID = function(u) return units[u] and ("guid-" .. (U(u).name or u)) end
	game.UnitClass = function(u) return U(u).class and "Warrior", U(u).class end
	game.UnitReaction = function(u) return U(u).reaction end
	game.UnitIsDead = function(u) return U(u).dead or false end
	game.UnitLevel = function(u) return Ask(u, "level", U(u).level or 1) end
	game.UnitClassification = function(u) return Ask(u, "classification", U(u).cls or "normal") end
	game.UnitCreatureType = function(u) return Ask(u, "creatureType", U(u).ctype) end
	game.UnitCanAttack = function(_, u) return not U(u).friendly end
	game.UnitPlayerControlled = function(u) return U(u).pet or false end
	game.UnitHealth = function(u) return Ask(u, "health", 272) end
	game.UnitHealthMax = function(u) return Ask(u, "health", 300) end
	game.GetGuildInfo = function(u) return U(u).guild, U(u).rank end
	game.IsInGroup, game.IsInRaid = function() return false end, function() return false end
	game.GetNumSubgroupMembers, game.GetNumGroupMembers = function() return 0 end, function() return 0 end
	game.GetCreatureDifficultyColor = function() return { r = 1, g = 1, b = 0 } end
	game.RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
	game.FACTION_BAR_COLORS = { [2] = { r = 1, g = 0, b = 0 }, [4] = { r = 1, g = 1, b = 0 }, [5] = { r = 0, g = 0.6, b = 0.1 } }
	game.LEVEL, game.ELITE, game.BOSS, game.TARGET = "Level", "Elite", "Boss", "Target"
	game.ITEM_MIN_SKILL, game.ITEM_SPELL_KNOWN = "Requires %s (%d)", "Already known"

	-- Skills: Mining 180, Tailoring 120, Skinning 300.
	-- As the real client returns them (see /dump C_SkillInfo.GetSkillLineInfo(2)): one table per line, talent
	-- specs and headers mixed in.
	local skills = {
		{ name = "Professions", isHeader = true, rank = 0, maxRank = 0 },
		{ name = "Affliction", isHeader = false, rank = 1, maxRank = 1, skillID = 355 },
		{ name = "Mining", isHeader = false, rank = 180, maxRank = 225 },
		{ name = "Tailoring", isHeader = false, rank = 120, maxRank = 150, skillID = 197 },
		{ name = "Skinning", isHeader = false, rank = 300, maxRank = 300 },
	}
	game.C_SkillInfo = {
		GetNumSkillLines = function() return #skills end,
		GetSkillLineInfo = function(i) return skills[i] end,
	}

	-- Items: anything named "Pattern: ..." is a recipe.
	game.C_Item = { GetItemInfoInstant = function(link)
		if tostring(link):find("Pattern", 1, true) then return 1, "Recipe", "", "", "", 9, 2 end
		return 1, "Miscellaneous", "", "", "", 15, 0
	end }

	h.Load("HoverWise.lua", "HoverWise")
	h.Fire("ADDON_LOADED", "HoverWise")
	return game, h, tip, post
end

local function ShowUnit(tip, post, unit, lines)
	tip:Reset()
	tip.unit, tip.owner = unit, tip.owner
	for _, l in ipairs(lines) do tip:AddLine(l) end
	post[2](tip)
	return tip:Text()
end

local function ShowItem(tip, post, name, lines)
	tip:Reset()
	tip.item = name
	for _, l in ipairs(lines) do tip:AddLine(l) end
	post[0](tip)
	return tip:Text()
end

local cases = {}

function cases.player_in_own_guild_shows_rank_and_target()
	local units = {
		mouseover = { name = "Grunt", player = true, class = "WARRIOR", guild = "Doc Crew", rank = "Officer" },
		mouseovertarget = { name = "Plainstrider", reaction = 2 },
		player = { name = "Doc", guild = "Doc Crew", rank = "GM" },
	}
	local _, h, tip, post = World(units)
	local text = ShowUnit(tip, post, "mouseover", { "Grunt", "<Doc Crew>", "Level 20 Orc Warrior" })
	T.has(text, "Officer", "guild rank")
	T.has(text, "Plainstrider", "target line")
	T.clean(h)
end

function cases.skinning_line_on_hostile_beast_but_not_on_friendly_one()
	local units = {
		beast = { name = "Plainstrider", level = 24, ctype = "Beast" },
		spirit = { name = "Great Cat Spirit", level = 60, ctype = "Beast", friendly = true },
	}
	local _, h, tip, post = World(units)
	T.has(ShowUnit(tip, post, "beast", { "Plainstrider", "Level 24 Beast" }), "Skinning", "hostile beast")
	T.lacks(ShowUnit(tip, post, "spirit", { "Great Cat Spirit", "Level 60" }), "Skinning", "friendly beast")
	T.clean(h)
end

function cases.no_skinning_line_on_pets()
	local _, h, tip, post = World({ pet = { name = "Wolf", level = 20, ctype = "Beast", pet = true } })
	T.lacks(ShowUnit(tip, post, "pet", { "Wolf", "Level 20 Beast" }), "Skinning", "hunter pet")
	T.clean(h)
end

function cases.secret_unit_under_the_cursor_uses_mouseover_without_errors()
	-- In dungeons the tooltip's unit, and answers about it, can be secret.
	local units = { mouseover = { name = "Deviate Ravager", level = 19, ctype = "Beast" } }
	local _, h, tip, post = World(units, { secret = { level = true, creatureType = true, classification = true } })
	tip:Reset()
	tip.unit, tip.owner = FakeWoW.Secret("unit"), h.Env().UIParent
	tip:AddLine("Deviate Ravager"); tip:AddLine("Level 19 Beast")
	post[2](tip)
	T.has(tip:Text(), "Level 19", "the game's own level line is left alone")
	T.clean(h)
end

function cases.recipe_shows_skill_needed()
	local _, h, tip, post = World({})
	T.has(ShowItem(tip, post, "Pattern: Red Linen Robe", { "Pattern: Red Linen Robe", "Requires Tailoring (40)" }), "learnable", "low recipe")
	T.has(ShowItem(tip, post, "Pattern: Big", { "Pattern: Big", "Requires Tailoring (150)" }), "you have 120", "high recipe")
	T.clean(h)
end

function cases.plain_items_are_left_alone()
	local _, h, tip, post = World({})
	T.eq(ShowItem(tip, post, "Linen Cloth", { "Linen Cloth" }), "Linen Cloth", "tooltip")
	T.clean(h)
end

function cases.errors_are_printed_once_and_passed_to_the_error_handler()
	-- A unit tooltip that fails inside HoverWise must not break the tooltip, and the error must reach the game's
	-- error handler, where BugSack and Biddle Utilities collect it.
	local game, h, tip, post = World({ mouseover = { name = "Grunt" } })
	game.UnitLevel = function() error("game failure") end
	ShowUnit(tip, post, "mouseover", { "Grunt" })
	ShowUnit(tip, post, "mouseover", { "Grunt" })
	local printed = 0
	for _, line in ipairs(h.Printed()) do if line:find("error (shown once)", 1, true) then printed = printed + 1 end end
	T.eq(printed, 1, "error printed")
	T.eq(#h.Errors(), 1, "errors passed to the handler")
end

return cases
