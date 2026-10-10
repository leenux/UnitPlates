UnitPlatesAddonIsLoaded = false
UnitPlatesPlayerEnteredWorld = false
UnitPlatesElapsedTimeSinceFullyLoaded = 0
UnitPlatesLoadDelay = 0
UnitPlatesConstantsInitialized = false

-- local UnitPlatesMouselookCatcher = CreateFrame("Button", "UnitPlatesMouselookCatcher", UIParent)
-- UnitPlatesMouselookCatcher:SetAllPoints(UIParent)
-- UnitPlatesMouselookCatcher:SetFrameStrata("TOOLTIP") -- Ensures it sits above all other UI elements
-- UnitPlatesMouselookCatcher:EnableMouse(true)
-- UnitPlatesMouselookCatcher:Hide()

-- UnitPlatesMouselookCatcher:SetScript("OnMouseDown", function()
	-- print("UnitPlatesMouselookCatcher:SetScript(OnMouseDown, function()")
    -- -- if IsMouselooking() then
        -- -- MouselookStop()
    -- -- end
    -- -- UnitPlatesMouselookCatcher:Hide() -- Hide the catcher immediately to restore normal UI interaction
-- end)

-- UnitPlatesMouselookCatcher:SetScript("OnMouseUp", function()
	-- print("UnitPlatesMouselookCatcher:SetScript(OnMouseUp, function()")
    -- -- if IsMouselooking() then
        -- -- MouselookStop()
    -- -- end
    -- -- UnitPlatesMouselookCatcher:Hide() -- Hide the catcher immediately to restore normal UI interaction
-- end)

---------------------------CONSTANTS

local spellSchoolColors = {
	[1] = {a = 1.00, r = 1.00, g = 1.00, b = 0.00}, -- Physical
	[2] = {a = 1.00, r = 1.00, g = 0.90, b = 0.50}, -- Holy
	[4] = {a = 1.00, r = 1.00, g = 0.50, b = 0.00}, -- Fire
	[8] = {a = 1.00, r = 0.30, g = 1.00, b = 0.30}, -- Nature
	[16] = {a = 1.00, r = 0.50, g = 1.00, b = 1.00}, -- Frost
	[20] = {a = 1.00, r = 0.50, g = 1.00, b = 1.00}, -- Frostfire
	[32] = {a = 1.00, r = 0.50, g = 0.50, b = 1.00}, -- Shadow
	[64] = {a = 1.00, r = 1.00, g = 0.50, b = 1.00} -- Arcane
}

local function getClassPos(class)
	if(class=="WARRIOR") then return 0,    0.25,    0,	0.25;	end
	if(class=="MAGE")    then return 0.25, 0.5,     0,	0.25;	end
	if(class=="ROGUE")   then return 0.5,  0.75,    0,	0.25;	end
	if(class=="DRUID")   then return 0.75, 1,       0,	0.25;	end
	if(class=="HUNTER")  then return 0,    0.25,    0.25,	0.5;	end
	if(class=="SHAMAN")  then return 0.25, 0.5,     0.25,	0.5;	end
	if(class=="PRIEST")  then return 0.5,  0.75,    0.25,	0.5;	end
	if(class=="WARLOCK") then return 0.75, 1,       0.25,	0.5;	end
	if(class=="PALADIN") then return 0,    0.25,    0.5,	0.75;	end
	return 0.25, 0.5, 0.5, 0.75	-- Returns empty next one, so blank
end

local slowUpdateTime, critUpdateTime, aurasUnitUpdateTime = 0.1, 0.01, 0.2
-- Fallback aura poll when UNIT_AURA is wired (event path is primary).
local aurasUnitUpdateTimeEventDriven = 1.0

-- Throttle profile inspired by pfUI ClassicAPI nameplates:
-- target plates stay smooth; mass packs drop to a few FPS.
local UP_THROTTLE_CENTRAL = 0.01   -- ~100 Hz central loop gate
local UP_THROTTLE_TARGET = 0.02    -- ~50 Hz
local UP_THROTTLE_NORMAL = 0.1     -- ~10 Hz
local UP_THROTTLE_MASS = 0.2       -- ~5 Hz when many plates
local UP_THROTTLE_CAST = 0.05      -- active castbar on non-target
local UP_THROTTLE_MIN = 0.02
local UP_SORT_INTERVAL = 0.05
local UP_BUBBLE_INTERVAL = 0.1
local UP_MASS_PLATE_THRESHOLD = 20

local rightClickSimulationDelay = 0.15

-- Event-driven plate registry (ClassicAPI NAME_PLATE_*). Fallback WorldFrame
-- discovery still fills these when ClassicAPI is absent.
local UPVisiblePlates = {}
local UPVisiblePlateCount = 0
local UPPlateByGuid = {}
local UPHasClassicNamePlates = type(C_NamePlate) == "table"
	and type(C_NamePlate.GetNamePlateForUnit) == "function"
local UPHasUnitGUID = type(UnitGUID) == "function"

--SIZES
--make all sizes relative to UPConstants.nameplateHealthBarHeight
local UPConstants = {}

local function InitUPConstants()
	UPConstants.nameplateHealthBarHeight = 14 * UnitPlatesSettings.scale --all other sizes are based upon nameplateHealthBarHeight
	UPConstants.minimalOnePixel = UPConstants.nameplateHealthBarHeight / 16

	UPConstants.nameplateHealthBarWidth = (UPConstants.nameplateHealthBarHeight * (UnitPlatesSettings.nameplateWidthPercent / 10)) --6.5
	UPConstants.nameplateWidthGrayLevel = (UPConstants.nameplateHealthBarHeight * (UnitPlatesSettings.nameplateWidthPercentTrivial / 10)) --4.5
	
	UPConstants.nameplatePowerBarHeight = (UPConstants.nameplateHealthBarHeight / 2)

	UPConstants.nameFontSize = UPConstants.nameplateHealthBarHeight * 0.6875
	UPConstants.healthPercentageFontSize = UPConstants.nameplateHealthBarHeight * 0.625
	UPConstants.healthBigFontSize = UPConstants.nameplateHealthBarHeight * 0.625
	UPConstants.powerFontSize = UPConstants.nameplateHealthBarHeight * 0.5
	UPConstants.levelFontSize = UPConstants.nameplateHealthBarHeight * 0.625
	UPConstants.castWarningNameFontSize = UPConstants.nameplateHealthBarHeight * 0.6875
	UPConstants.castWarningDurationFontSize = UPConstants.nameplateHealthBarHeight * 0.5

	UPConstants.nameplateArrowSize = UPConstants.nameplateHealthBarHeight * 1.875
	UPConstants.nameplateRarityH = UPConstants.nameplateHealthBarHeight * 2.75
	UPConstants.nameplateRarityW = UPConstants.nameplateHealthBarHeight * 2.625

	UPConstants.questIconSize = UPConstants.nameplateHealthBarHeight * 1.1

	UPConstants.petHappinessIconSize = UPConstants.nameplateHealthBarHeight * 1.1

	UPConstants.combatIconSize = UPConstants.nameplateHealthBarHeight * 1.4

	UPConstants.shootingIconSize = UPConstants.nameplateHealthBarHeight * 0.9
	
	UPConstants.pvpIconSize = UPConstants.nameplateHealthBarHeight * 1.8
	
	UPConstants.pvpRankIconSize = UPConstants.nameplateHealthBarHeight * 0.75

	UPConstants.nameplateTypeIconSize = UPConstants.nameplateHealthBarHeight
	UPConstants.nameplateClassIconSize = UPConstants.nameplateHealthBarHeight * 1.25

	UPConstants.totemIconSize = UPConstants.nameplateHealthBarHeight * 2

	UPConstants.raidIconSize = UPConstants.nameplateHealthBarHeight * 2

	UPConstants.threatFrameSize = UPConstants.nameplateHealthBarHeight
	UPConstants.threatFontSize = UPConstants.nameplateHealthBarHeight * 0.5

	UPConstants.maxAuras = 80
	-- UPConstants.maxAurasInRowSetting = 5
	UPConstants.maxAurasInRow = UnitPlatesSettings.aurasInRow --6
	UPConstants.maxAurasInRowGrayLevel = UnitPlatesSettings.aurasInRowTrivial --4
	
	UPConstants.auraIconOffset = 0.1 * UPConstants.minimalOnePixel
	
	--glow
	UPConstants.selectionGlowScale = UnitPlatesSettings.selectionGlowScale / 100.0
	
	UPConstants.selectionGlowAlpha = UnitPlatesSettings.selectionGlowAlpha / 100.0
	
	UPConstants.glowHeight = (UPConstants.nameplateHealthBarHeight * 4.5) * UPConstants.selectionGlowScale
	UPConstants.glowWidth = (UPConstants.nameplateHealthBarWidth * 2.6) * UPConstants.selectionGlowScale
	UPConstants.glowWidthGrayLevel = (UPConstants.nameplateWidthGrayLevel * 3.0) * UPConstants.selectionGlowScale
	UPConstants.glowWidthTotem = (UPConstants.totemIconSize * 3.5) * UPConstants.selectionGlowScale

	--OFFSETS
	UPConstants.nameplateRarityXOffset = UPConstants.nameplateRarityW * 0.619

	UPConstants.castBarSizes = {
		cbheight = UPConstants.nameplateHealthBarHeight * 0.3125,
		shield = UPConstants.nameplateHealthBarHeight,
		icon = UPConstants.nameplateHealthBarHeight
	 }

	UPConstants.combopointsSizes = {
		combopoints = UPConstants.nameplateHealthBarHeight * 0.5625,
		spacing = UPConstants.minimalOnePixel
	}
	
	UnitPlatesConstantsInitialized = true
end

--COLORS
--local glowColor = {.3, 0.7, 1, 1}
local glowColor = {.3, 0.7, 1, 1}
local backgroundGlowColor = {.3, 0.7, 1, 1}
local hatedColor = {.7, 0.2, 0.1}
local neutralColor = {1, 0.8, 0}
local friendlyColor = {.2, 0.6, 0.1}
local tappedColor = {0.2352941176470588, 0.2274509803921569, 0.2352941176470588}
local playerColor = {.2, 0.5, 0.9}

local castBarColor = {.43, 0.47, 0.55, 1}
local castBarShieldColor = {.8, 0.1, 0.1, 1}

local combopointsColors = {
	full = {1, 0.224, 0.027},
	--full = {0, 0.9, 1}, --Electric Cyan
	empty = {0.3, 0.3, 0.3}
}

local powerBarColors = {
	mana = {0, 0, 0.9, 0.99999779462814},
	energy = {1, 1, 0, 0.99999779462814},
	rage = {1, 0, 0, 0.99999779462814},
	rageDim = {0.5, 0, 0, 0.99999779462814}
}

-- local chatTextColors = {
    -- ["CHAT_MSG_SAY"] = {1.0, 1.0, 1.0, 0.99}, -- White
    -- ["CHAT_MSG_PARTY"] = {0.67, 0.67, 1.0, 0.99}, -- Light Blue
    -- ["CHAT_MSG_YELL"] = {1.0, 0.25, 0.25, 0.99}, -- Bright Red
    -- ["CHAT_MSG_MONSTER_SAY"] = {1.0, 1.0, 0.6, 0.99}, -- Pale Yellow
    -- ["CHAT_MSG_MONSTER_YELL"] = {1.0, 0.48, 0.0, 0.99}, -- Orange-Gold (Distinct from Say)
-- }

--FONT
--local mainFontPath = "Interface\\AddOns\\UnitPlates\\fonts\\francois.ttf"
local mainFontPath = "Interface\\AddOns\\UnitPlates\\fonts\\INTERNATIONAL_FRIZQT__.ttf"

---------------------------CONSTANTS END

-- Hot-path locals: the per-plate and per-frame updaters call these dozens of
-- times per frame; resolving them as upvalues avoids repeated global lookups.
local GetTime = GetTime
local UnitExists = UnitExists
local UnitName = UnitName
local UnitLevel = UnitLevel
local IsMouselooking = IsMouselooking
local MouseIsOver = MouseIsOver
local math_floor = math.floor
local math_mod = math.mod
local string_find = string.find
local string_gfind = string.gfind
local string_upper = string.upper
local table_insert = table.insert
local table_sort = table.sort
local table_getn = table.getn

-- Ignore-lists for aura polling: re-parsed only when the setting text changes
-- instead of on every plate's every aura poll.
local UPCachedIgnoredBuffNames = {}
local UPCachedIgnoredDebuffNames = {}
local UPCachedIgnoredBuffNamesRaw = nil
local UPCachedIgnoredDebuffNamesRaw = nil

-- Player state used by every plate update (own guild, pet UI, pet happiness,
-- own name). Refreshed at most once a second instead of per plate per tick.
local UPCachedPlayerState = {
	myGuildName = nil,
	myPlayerHasPetUI = nil,
	myPlayerPetIsHunterPet = nil,
	playerName = nil,
	petHappiness = nil,
}
local UPCachedPlayerStateAt = 0

local function UPGetCachedPlayerState()
	local now = GetTime()
	if (now - UPCachedPlayerStateAt) > 1 then
		UPCachedPlayerStateAt = now
		UPCachedPlayerState.myGuildName = GetGuildInfo("player")
		UPCachedPlayerState.myPlayerHasPetUI, UPCachedPlayerState.myPlayerPetIsHunterPet = HasPetUI()
		UPCachedPlayerState.playerName = UnitName("player")
		UPCachedPlayerState.petHappiness = GetPetHappiness()
	end
	return UPCachedPlayerState
end

local function UPGetIgnoredAuraNames()
	if UnitPlatesSettings.ignoredBuffNames ~= UPCachedIgnoredBuffNamesRaw then
		UPCachedIgnoredBuffNamesRaw = UnitPlatesSettings.ignoredBuffNames
		UPCachedIgnoredBuffNames = {}
		for word in string_gfind(UPCachedIgnoredBuffNamesRaw, '([^,]+)') do
			-- stored uppercase so the aura lookup needs no per-aura string.upper
			table_insert(UPCachedIgnoredBuffNames, string_upper(UPCoreTrimString(word)))
		end
	end
	if UnitPlatesSettings.ignoredDebuffNames ~= UPCachedIgnoredDebuffNamesRaw then
		UPCachedIgnoredDebuffNamesRaw = UnitPlatesSettings.ignoredDebuffNames
		UPCachedIgnoredDebuffNames = {}
		for word in string_gfind(UPCachedIgnoredDebuffNamesRaw, '([^,]+)') do
			table_insert(UPCachedIgnoredDebuffNames, string_upper(UPCoreTrimString(word)))
		end
	end
	return UPCachedIgnoredBuffNames, UPCachedIgnoredDebuffNames
end

--aura
local function HideAllAuras(kuiPlateFrame)
	kuiPlateFrame.unitAuras = {}
	for i = 1, UPConstants.maxAuras do
        kuiPlateFrame.aurasContainer.auraIcons[i]:Hide()
    end
end

local function GetHighestVisibleAuraFrame(kuiPlateFrame)
	local latestVisibleFrame = kuiPlateFrame.name

	for i = 1, UPConstants.maxAuras do
		if kuiPlateFrame.aurasContainer.auraIcons[i] then
			if kuiPlateFrame.aurasContainer.auraIcons[i]:IsShown() then
				latestVisibleFrame = kuiPlateFrame.aurasContainer.auraIcons[i]
			end
		else
			break
		end
	end

	return latestVisibleFrame
end

------------------------------------------------------------- Frame functions --
--required to set frame positions
local function SetFrameCenter(kuiPlateFrame)
	-- using CENTER breaks pixel-perfectness with oddly sized frames
	-- .. so we have to align frames manually.
	
	--overlap
	if UnitPlatesSettings.overlapping then
		kuiPlateFrame.originalPlateFrame:SetWidth(1)
		kuiPlateFrame.originalPlateFrame:SetHeight(1)
	else
		if kuiPlateFrame:GetHeight() and kuiPlateFrame:GetHeight() > 0 then
			kuiPlateFrame.originalPlateFrame:SetWidth(kuiPlateFrame:GetWidth())
			kuiPlateFrame.originalPlateFrame:SetHeight(kuiPlateFrame:GetHeight())
		end
	end
	
	local w = kuiPlateFrame:GetWidth()
	local h = kuiPlateFrame:GetHeight()

	if kuiPlateFrame.isTrivial then
		kuiPlateFrame.x = math.floor((w / 2) - (UPConstants.nameplateWidthGrayLevel / 2))
		kuiPlateFrame.y = math.floor((h / 2) - (UPConstants.nameplateHealthBarHeight / 2))
	else
		kuiPlateFrame.x = math.floor((w / 2) - (UPConstants.nameplateHealthBarWidth / 2))
		kuiPlateFrame.y = math.floor((h / 2) - (UPConstants.nameplateHealthBarHeight / 2))
	end
end

local function ResetFrame(kuiPlateFrame, originalPlateFrame)
	kuiPlateFrame:SetWidth(originalPlateFrame:GetWidth())
	kuiPlateFrame:SetHeight(originalPlateFrame:GetHeight())
	SetFrameCenter(kuiPlateFrame)
	
	kuiPlateFrame.elapsed = 0
	kuiPlateFrame.critElap = 0
	kuiPlateFrame.aurasUpdateElapsed = 0
	kuiPlateFrame.clickElapsed = 0
	-- a freshly (re)shown plate needs the full static rebuild on its next tick
	kuiPlateFrame.doFullUpdate = true
	
	--kuiPlateFrame:SetFrameLevel(0)
	kuiPlateFrame.glow:Hide() 
	kuiPlateFrame.glow2:Hide()
	-- kuiPlateFrame.visglow:Hide()
	-- kuiPlateFrame.visglow2:Hide()
	if originalPlateFrame.totem then
		originalPlateFrame.totem:Hide()
	end
	kuiPlateFrame.isTarget = nil
	UPCoreFrameFadeRemoveFrame(kuiPlateFrame.castWarning)
	kuiPlateFrame.castWarning:Hide()
	HideAllAuras(kuiPlateFrame)
	kuiPlateFrame.guid = nil
	kuiPlateFrame.cachedGuid = nil
	kuiPlateFrame.unit = nil
	kuiPlateFrame.eventcache = nil
	kuiPlateFrame.auraUpdate = nil
	kuiPlateFrame.castUpdate = nil
	kuiPlateFrame.lasttick = nil
	kuiPlateFrame.lastFullTick = nil
	-- isBoss is only ever set (never cleared) when the skull region is visible;
	-- reset it here so a recycled plate doesn't inherit it from a previous unit
	kuiPlateFrame.isBoss = false
	-- clear the identity markers so the next UpdatePlate treats this as a new unit
	kuiPlateFrame.lastFullGuid = nil
	kuiPlateFrame.lastFullName = nil
	kuiPlateFrame.lastFullLevel = nil
end

local function UPRegisterPlateUnitEvents(kuiPlateFrame, unit)
	if not kuiPlateFrame or not unit then return end
	if kuiPlateFrame.RegisterUnitEvent then
		kuiPlateFrame:RegisterUnitEvent("UNIT_AURA", unit)
		kuiPlateFrame:RegisterUnitEvent("UNIT_FLAGS", unit)
		if UPApiHasClassicCast and UPApiHasClassicCast() then
			kuiPlateFrame:RegisterUnitEvent("UNIT_SPELLCAST_START", unit)
			kuiPlateFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", unit)
			kuiPlateFrame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", unit)
			kuiPlateFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", unit)
		end
	end
end

local function UPUnregisterPlateUnitEvents(kuiPlateFrame)
	if not kuiPlateFrame then return end
	if kuiPlateFrame.UnregisterAllEvents then
		kuiPlateFrame:UnregisterAllEvents()
	end
end

local function UPBindPlateUnit(originalPlateFrame, unit)
	local kuiPlateFrame = originalPlateFrame.kui
	if not kuiPlateFrame then return end

	kuiPlateFrame.unit = unit
	local guid = nil
	if unit and UPHasUnitGUID then
		guid = UnitGUID(unit)
	end
	if not guid and originalPlateFrame.GetName then
		guid = originalPlateFrame:GetName(1)
	end
	kuiPlateFrame.cachedGuid = guid
	kuiPlateFrame.guid = guid

	if guid then
		UPPlateByGuid[guid] = originalPlateFrame
	end

	UPRegisterPlateUnitEvents(kuiPlateFrame, unit)

	-- Unit may already be mid-cast when the plate appears.
	if unit and UPApiHasClassicCast and UPApiHasClassicCast() then
		if UPApiPollCastFromUnit(unit) then
			kuiPlateFrame.castUpdate = true
		end
	end

	kuiPlateFrame.auraUpdate = true
	kuiPlateFrame.eventcache = true
	kuiPlateFrame.doFullUpdate = true
end

local function UPUnbindPlateUnit(originalPlateFrame)
	local kuiPlateFrame = originalPlateFrame and originalPlateFrame.kui
	if not kuiPlateFrame then return end

	local guid = kuiPlateFrame.cachedGuid
	if guid and UPPlateByGuid[guid] == originalPlateFrame then
		UPPlateByGuid[guid] = nil
	end
	if guid then
		UPApiClearCastForGuid(guid)
	end
	UPUnregisterPlateUnitEvents(kuiPlateFrame)
	kuiPlateFrame.unit = nil
	kuiPlateFrame.cachedGuid = nil
	kuiPlateFrame.guid = nil
end

local function OnFrameShow(originalPlateFrame)
	--print("OnFrameShow")
	local kuiPlateFrame = originalPlateFrame.kui
	ResetFrame(kuiPlateFrame, originalPlateFrame)
end

-------------------------------------------------------

local function UpdatePlate(kuiPlateFrame)
	-- The 10ms tick passes doFullUpdate=false and only refreshes fast-changing
	-- state (health, cast bar, target/glow, power). The 100ms tick passes true
	-- and additionally rebuilds the expensive mostly-static content (tooltip
	-- guild/pet scans, texts, icons, colors, trivial sizing).
	local doFullUpdate = kuiPlateFrame.doFullUpdate
	kuiPlateFrame.doFullUpdate = false

	-- Prefer the GUID cached on NAME_PLATE_UNIT_ADDED (or last resolve).
	-- Falling back to SuperWoW GetName(1) only when the cache is empty avoids
	-- a per-tick C call on every visible plate.
	if kuiPlateFrame.cachedGuid then
		kuiPlateFrame.guid = kuiPlateFrame.cachedGuid
	elseif kuiPlateFrame.unit and UPHasUnitGUID then
		kuiPlateFrame.guid = UnitGUID(kuiPlateFrame.unit)
		kuiPlateFrame.cachedGuid = kuiPlateFrame.guid
	else
		kuiPlateFrame.guid = kuiPlateFrame.originalPlateFrame:GetName(1)
		kuiPlateFrame.cachedGuid = kuiPlateFrame.guid
	end

	-- Prefer the stable nameplateN token for Unit* reads when ClassicAPI bound it.
	local unitRef = kuiPlateFrame.unit or kuiPlateFrame.guid
	if not unitRef then
		return
	end

	-- Player-side state is shared across full + fast paths (party colors, pet
	-- happiness). Hoist so locals stay in scope for the whole UpdatePlate call.
	local playerState = UPGetCachedPlayerState()
	local myGuildName = playerState.myGuildName
	local myPlayerHasPetUI = playerState.myPlayerHasPetUI
	local myPlayerPetIsHunterPet = playerState.myPlayerPetIsHunterPet

	-- The engine recycles nameplate frames between units while they stay
	-- visible. If the guid changed since the last full rebuild, force one now
	-- so no stale content from the previous unit is shown. (Only the guid is
	-- compared: UnitName/UnitLevel can transiently return nil for a valid guid
	-- and would make this check fire spuriously, flashing the plate.)
	if not doFullUpdate and kuiPlateFrame.guid
		and kuiPlateFrame.lastFullGuid
		and (kuiPlateFrame.guid ~= kuiPlateFrame.lastFullGuid) then
		doFullUpdate = true
	end

	if doFullUpdate then
		-- NOTE: no totem:Hide()/kuiPlateFrame:Show() resets here -- totem and
		-- plate visibility are owned by the TOTEM section in the fast path
		-- (below), which runs every tick. Resetting them here would flash the
		-- normal plate over totems once per slow tick.
		kuiPlateFrame.isTrivial = false

		if not kuiPlateFrame.originalPlateFrame.name then return nil end
		kuiPlateFrame.oldName = kuiPlateFrame.originalPlateFrame.name
		kuiPlateFrame.originalPlateFrame.name:Hide()

		if not kuiPlateFrame.originalPlateFrame.level then return nil end
		kuiPlateFrame.oldLevel = kuiPlateFrame.originalPlateFrame.level
		kuiPlateFrame.originalPlateFrame.level:Hide()

		--raid icon
		--adjust aurasContainer position
		if kuiPlateFrame.classIcon:IsShown() then
			kuiPlateFrame.aurasContainer:SetPoint("BOTTOM", kuiPlateFrame.name, "TOP", 0, UPConstants.nameplateClassIconSize / 2)
		else
			kuiPlateFrame.aurasContainer:SetPoint("BOTTOM", kuiPlateFrame.name, "TOP", 0, 2 * UPConstants.minimalOnePixel)
		end

		if kuiPlateFrame.originalPlateFrame.raidIconRegion then
			kuiPlateFrame.originalPlateFrame.raidIconRegion:SetParent(kuiPlateFrame.originalPlateFrame)
			kuiPlateFrame.originalPlateFrame.raidIconRegion:SetWidth(UPConstants.raidIconSize)
			kuiPlateFrame.originalPlateFrame.raidIconRegion:SetHeight(UPConstants.raidIconSize)
			kuiPlateFrame.originalPlateFrame.raidIconRegion:ClearAllPoints()

			local auraFrame = GetHighestVisibleAuraFrame(kuiPlateFrame)

			local auraTopY = auraFrame:GetTop()
			if not auraTopY then
				auraTopY = 0
			end
			kuiPlateFrame.originalPlateFrame.raidIconRegion:SetPoint("CENTER", kuiPlateFrame.name, "CENTER", 0, 0)
			kuiPlateFrame.originalPlateFrame.raidIconRegion:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, auraTopY + (2 * UPConstants.minimalOnePixel))
		end
		--raid icon end

		if kuiPlateFrame.originalPlateFrame.bossIconRegion and kuiPlateFrame.originalPlateFrame.bossIconRegion:IsVisible() then
			-- This unit is a Boss (it has the skull icon active)
			kuiPlateFrame.originalPlateFrame.bossIconRegion:SetTexture(nil)
			kuiPlateFrame.isBoss = true
		end

		kuiPlateFrame.nameTextVariable = UnitName(unitRef)

		kuiPlateFrame.originalPlateFrame.isTotem = UPApiIsTotem(kuiPlateFrame.nameTextVariable)

		kuiPlateFrame.guildTextVariable = UPApiGetGuildText(unitRef)
		kuiPlateFrame.levelNumber = UnitLevel(unitRef)
		kuiPlateFrame.isPlayer = UnitIsPlayer(unitRef)
		-- remember the identity this static rebuild was based on (see the
		-- frame-recycling guard at the top of UpdatePlate). These markers are
		-- only written when the reads actually succeeded, so a transient nil
		-- can never poison the guard into re-firing every tick.
		if kuiPlateFrame.guid and kuiPlateFrame.nameTextVariable then
			kuiPlateFrame.lastFullGuid = kuiPlateFrame.guid
			kuiPlateFrame.lastFullName = kuiPlateFrame.nameTextVariable
			kuiPlateFrame.lastFullLevel = kuiPlateFrame.levelNumber
		end
		if kuiPlateFrame.isPlayer then
			local titleName = ""
			kuiPlateFrame.titleName = titleName

			local playerrankname, playerrank = GetPVPRankInfo(UnitPVPRank(unitRef), unitRef)
			kuiPlateFrame.pvpRank = playerrank
		else
			kuiPlateFrame.pvpRank = 0
			kuiPlateFrame.titleName = ""
		end
		kuiPlateFrame.class, kuiPlateFrame.race, kuiPlateFrame.gender = UPApiGetClassRaceGender(unitRef)
		kuiPlateFrame.classification = UnitClassification(unitRef)
		kuiPlateFrame.isPlusMob = UnitIsPlusMob(unitRef)
		kuiPlateFrame.creatureType = UPApiGetCreatureType(unitRef)
		kuiPlateFrame.levelDifficultyColor = UPApiGetLevelDifficultyColor(kuiPlateFrame.levelNumber)
		kuiPlateFrame.isGrayLevel = UPApiIsGrayLevel(kuiPlateFrame.levelNumber)
		kuiPlateFrame.isPet = UPApiIsPet(unitRef)
		if kuiPlateFrame.isPet and kuiPlateFrame.guildTextVariable ~= "" then
			kuiPlateFrame.isMyPet = false
			if string_find(kuiPlateFrame.guildTextVariable, playerState.playerName.."'s Pet") then
				kuiPlateFrame.isMyPet = true
			end
			if not kuiPlateFrame.isMyPet then
				if string_find(kuiPlateFrame.guildTextVariable, playerState.playerName.."'s Minion") then
					kuiPlateFrame.isMyPet = true
				end
			end
		end

		if kuiPlateFrame.isGrayLevel or kuiPlateFrame.isPet or kuiPlateFrame.creatureType == "CRITTER" then
			kuiPlateFrame.isTrivial = true
		end
		--static data end
	end

	-- fast-path state, refreshed every tick ------------------------------
	kuiPlateFrame.isInCombat = UnitAffectingCombat(unitRef)
	kuiPlateFrame.unitMaxPower = UnitManaMax(unitRef)
	if kuiPlateFrame.unitMaxPower > 0 then
		kuiPlateFrame.unitPower = UnitMana(unitRef)
		kuiPlateFrame.unitPowerType = UnitPowerType(unitRef)
	else
		kuiPlateFrame.unitPower = 0
		kuiPlateFrame.unitPowerType = 0
	end
	kuiPlateFrame.isTarget = UPApiIsTarget(kuiPlateFrame.guid)
	kuiPlateFrame.isTapped = (UnitIsTapped(unitRef) and not (UnitIsTappedByPlayer(unitRef)))

	--hide plate early to avoid calculations (every tick: on the full tick the
	--fresh static data decides, and on fast ticks we must keep re-hiding so the
	--TOTEM section's kuiPlateFrame:Show() below can't resurrect a hidden plate)
	if (not kuiPlateFrame.isTarget) and kuiPlateFrame.isPet and (kuiPlateFrame.levelNumber == 1 or (kuiPlateFrame.creatureType == "NOT SPECIFIED")) then
		--unknown creature type is NOT SPECIFIED
		--hide entirely
		kuiPlateFrame.originalPlateFrame.selectionGlow:Hide()
		kuiPlateFrame.originalPlateFrame.selectionGlow2:Hide()
		kuiPlateFrame.originalPlateFrame.totem:Hide()
		kuiPlateFrame:Hide()
		return
	end

	--combo points update
	if kuiPlateFrame.isTarget then
		kuiPlateFrame.combopoints.points = GetComboPoints("player", "target")
		if not kuiPlateFrame.combopoints.points or kuiPlateFrame.combopoints.points < 1 then
			kuiPlateFrame.combopoints:Hide()
		else
			for i = 1, 5 do
				if i <= kuiPlateFrame.combopoints.points then
					kuiPlateFrame.combopoints[i]:SetAlpha(1)
					kuiPlateFrame.combopoints[i]:SetVertexColor(unpack(combopointsColors.full))
				else
					kuiPlateFrame.combopoints[i]:SetAlpha(1)
					kuiPlateFrame.combopoints[i]:SetVertexColor(unpack(combopointsColors.empty))
				end
			end
			kuiPlateFrame.combopoints:Show()
		end
	else
		kuiPlateFrame.combopoints.points = nil
		kuiPlateFrame.combopoints:Hide()
	end
	--combo points update end

	if doFullUpdate then
		--setGuild
		if kuiPlateFrame.guildTextVariable then
			local guildTranslation = UPCompatWoWTranslateGetCachedGuildTranslation(kuiPlateFrame.guildTextVariable)
			if guildTranslation and (guildTranslation ~= '') then
				kuiPlateFrame.guild:SetText("<"..guildTranslation.."*"..">")
			else
				kuiPlateFrame.guild:SetText("<"..kuiPlateFrame.guildTextVariable..">")
			end
		else
			-- no guild/subtitle on this unit: clear the text so a recycled
			-- plate doesn't keep showing the previous unit's guild
			kuiPlateFrame.guild:SetText("")
		end
		--coloring
		if (kuiPlateFrame.isPlayer and myGuildName and (kuiPlateFrame.guildTextVariable == myGuildName)) then
			kuiPlateFrame.guild:SetTextColor(0,0.999,0,1)
		else
			kuiPlateFrame.guild:SetTextColor(1,1,1,1)
		end
		--setGuild end

		--setName
		local nameTranslation = UPCompatWoWTranslateGetCachedNameTranslation(kuiPlateFrame.nameTextVariable)
		if nameTranslation and (nameTranslation ~= '') then
			kuiPlateFrame.name:SetText(kuiPlateFrame.titleName.." "..nameTranslation.."*")
		else
			kuiPlateFrame.name:SetText(kuiPlateFrame.titleName.." "..kuiPlateFrame.nameTextVariable)
		end
		kuiPlateFrame.name:SetTextColor(1,1,1,1)
		--setName end

		--set name and guild positions
		kuiPlateFrame.name:SetPoint("BOTTOM", kuiPlateFrame.health, "TOP", 0, 2 * UPConstants.minimalOnePixel)
		kuiPlateFrame.guild:SetPoint("BOTTOM", kuiPlateFrame.health, "TOP", 0, 2 * UPConstants.minimalOnePixel)
		if (kuiPlateFrame.guild:GetText() == nil or kuiPlateFrame.guild:GetText() == '') then
			if kuiPlateFrame.combopoints:IsShown() then
				kuiPlateFrame.name:SetPoint("BOTTOM", kuiPlateFrame.combopoints[3], "TOP", 0, 2 * UPConstants.minimalOnePixel * 2)
			else
				kuiPlateFrame.name:SetPoint("BOTTOM", kuiPlateFrame.health, "TOP", 0, 2 * UPConstants.minimalOnePixel)
			end
		else
			if kuiPlateFrame.combopoints:IsShown() then
				kuiPlateFrame.guild:SetPoint("BOTTOM", kuiPlateFrame.combopoints[3], "TOP", 0, 2 * UPConstants.minimalOnePixel * 2)
			else
				kuiPlateFrame.guild:SetPoint("BOTTOM", kuiPlateFrame.health, "TOP", 0, 2 * UPConstants.minimalOnePixel)
			end
			kuiPlateFrame.name:SetPoint("BOTTOM", kuiPlateFrame.guild, "TOP", 0, 2 * UPConstants.minimalOnePixel)
		end
		--set name and guild positions end

		--level
		if kuiPlateFrame.levelNumber > 0 then
			kuiPlateFrame.level:SetText(kuiPlateFrame.oldLevel:GetText())
			kuiPlateFrame.level:SetTextColor(kuiPlateFrame.oldLevel:GetTextColor())
		else
			kuiPlateFrame.level:SetText("??")
			kuiPlateFrame.level:SetTextColor(kuiPlateFrame.levelDifficultyColor.r, kuiPlateFrame.levelDifficultyColor.g, kuiPlateFrame.levelDifficultyColor.b)
		end
		kuiPlateFrame.level:Show()
		--level end

		--RARITY
		if (kuiPlateFrame.isPlayer) then
			kuiPlateFrame.rarityIcon:Hide()
			kuiPlateFrame.rarityIconR:Hide()
		else
			kuiPlateFrame.rarityIcon.icon:SetTexture("Interface\\AddOns\\UnitPlates\\img\\frame_elite")
			kuiPlateFrame.rarityIconR.icon:SetTexture("Interface\\AddOns\\UnitPlates\\img\\frame_elite")
			if kuiPlateFrame.classification == "elite" then
				kuiPlateFrame.rarityIcon.icon:SetVertexColor(1, 1, 0, 1)
				kuiPlateFrame.rarityIcon:Show()
				kuiPlateFrame.rarityIconR.icon:SetVertexColor(1, 1, 0, 1)
				kuiPlateFrame.rarityIconR:Show()
			elseif kuiPlateFrame.classification == "rareelite" then
				kuiPlateFrame.rarityIcon.icon:SetVertexColor(1, 1, 1, 1)
				kuiPlateFrame.rarityIcon:Show()
				kuiPlateFrame.rarityIconR.icon:SetVertexColor(1, 1, 1, 1)
				kuiPlateFrame.rarityIconR:Show()
			elseif kuiPlateFrame.classification == "rare" then
				kuiPlateFrame.rarityIcon.icon:SetTexture("Interface\\AddOns\\UnitPlates\\img\\frame_rare")
				kuiPlateFrame.rarityIconR.icon:SetTexture("Interface\\AddOns\\UnitPlates\\img\\frame_rare")
				kuiPlateFrame.rarityIcon.icon:SetVertexColor(1, 1, 1, 1)
				kuiPlateFrame.rarityIcon:Show()
				kuiPlateFrame.rarityIconR.icon:SetVertexColor(1, 1, 1, 1)
				kuiPlateFrame.rarityIconR:Show()
			elseif (kuiPlateFrame.classification == "boss") or kuiPlateFrame.isBoss then
				if kuiPlateFrame.isPlusMob then
					kuiPlateFrame.rarityIcon.icon:SetVertexColor(0.5, 0, 0, 1)
					kuiPlateFrame.rarityIcon:Show()
					kuiPlateFrame.rarityIconR.icon:SetVertexColor(0.5, 0, 0, 1)
					kuiPlateFrame.rarityIconR:Show()
				else
					kuiPlateFrame.rarityIcon:Hide()
					kuiPlateFrame.rarityIconR:Hide()
				end
			else
				kuiPlateFrame.rarityIcon:Hide()
				kuiPlateFrame.rarityIconR:Hide()
			end
		end
		--RARITY END

		if UnitIsPVP(kuiPlateFrame.guid) then
			local factionGroup = UnitFactionGroup(kuiPlateFrame.guid)
			if factionGroup then
				kuiPlateFrame.pvpIcon.icon:SetTexture("Interface\\TargetingFrame\\UI-PVP-"..factionGroup)
				kuiPlateFrame.pvpIcon:Show()
			else
				kuiPlateFrame.pvpIcon:Hide()
			end
		else
			kuiPlateFrame.pvpIcon:Hide()
		end

		--hide pvp icon for your own pet/minion
		if kuiPlateFrame.isPet
			and kuiPlateFrame.guildTextVariable
			and kuiPlateFrame.isMyPet then
			kuiPlateFrame.pvpIcon:Hide()
		end

		--pet happiness
		if (myPlayerHasPetUI and myPlayerPetIsHunterPet and kuiPlateFrame.guildTextVariable and kuiPlateFrame.isMyPet) then
			local petHappiness = playerState.petHappiness
			if (petHappiness == 1) then
				kuiPlateFrame.petHappiness.icon:SetTexCoord(0.375, 0.5625, 0, 0.359375)
				kuiPlateFrame.petHappiness:Show()
			elseif (petHappiness == 2) then
				kuiPlateFrame.petHappiness.icon:SetTexCoord(0.1875, 0.375, 0, 0.359375)
				kuiPlateFrame.petHappiness:Show()
			elseif (petHappiness == 3) then
				kuiPlateFrame.petHappiness:Hide()
			end
		else
			kuiPlateFrame.petHappiness:Hide()
		end
		--pet happiness end

		kuiPlateFrame.pvpRankIcon:SetPoint("LEFT", kuiPlateFrame.name, "RIGHT", UPConstants.minimalOnePixel*1, 0)

		if kuiPlateFrame.pvpRank > 0 then
			kuiPlateFrame.pvpRankIcon:Show()
			kuiPlateFrame.pvpRankIcon.icon:SetTexture(string.format("Interface\\PVPRankBadges\\PVPRank%02d", kuiPlateFrame.pvpRank))
			kuiPlateFrame.pvpIcon:SetPoint("LEFT", kuiPlateFrame.pvpRankIcon, "RIGHT", -UPConstants.pvpIconSize * 0.0, -UPConstants.pvpIconSize/4.5)
		else
			kuiPlateFrame.pvpRankIcon:Hide()
			kuiPlateFrame.pvpIcon:SetPoint("LEFT", kuiPlateFrame.name, "RIGHT", -UPConstants.pvpIconSize * 0.0, -UPConstants.pvpIconSize/4.5)
		end

		--icon positions
		if kuiPlateFrame.pvpIcon:IsShown() then
			if kuiPlateFrame.petHappiness:IsShown() then
				kuiPlateFrame.petHappiness:SetPoint("LEFT", kuiPlateFrame.name, "RIGHT", ((2 * UPConstants.minimalOnePixel)+(UPConstants.pvpIconSize/1.8)), 0)
				kuiPlateFrame.combatIcon:SetPoint("LEFT", kuiPlateFrame.petHappiness, "RIGHT", -0, -0)
			else
				if kuiPlateFrame.pvpRankIcon:IsShown() then
					kuiPlateFrame.combatIcon:SetPoint("LEFT", kuiPlateFrame.name, "RIGHT", ((2 * UPConstants.minimalOnePixel)+(UPConstants.pvpIconSize/1.8))+(2 * UPConstants.minimalOnePixel)+(UPConstants.pvpRankIconSize/1.8), -0)
				else
					kuiPlateFrame.combatIcon:SetPoint("LEFT", kuiPlateFrame.name, "RIGHT", ((-2 * UPConstants.minimalOnePixel)+(UPConstants.pvpIconSize/1.8)), -0)
				end
			end
		else
			if kuiPlateFrame.petHappiness:IsShown() then
				kuiPlateFrame.petHappiness:SetPoint("LEFT", kuiPlateFrame.name, "RIGHT", -0, 0)
				kuiPlateFrame.combatIcon:SetPoint("LEFT", kuiPlateFrame.petHappiness, "RIGHT", -0, -0)
			else
				if kuiPlateFrame.pvpRankIcon:IsShown() then
					kuiPlateFrame.combatIcon:SetPoint("LEFT", kuiPlateFrame.name, "RIGHT", (5 * UPConstants.minimalOnePixel)+(UPConstants.pvpRankIconSize/1.8), -0)
				else
					kuiPlateFrame.combatIcon:SetPoint("LEFT", kuiPlateFrame.name, "RIGHT", -2 * UPConstants.minimalOnePixel, -0)
				end
			end
		end
		--icon positions end

		--healthbar width (trivial vs normal sizing)
		if kuiPlateFrame.isTrivial then
			kuiPlateFrame.originalPlateFrame.selectionGlow:SetWidth(UPConstants.glowWidthGrayLevel)
			kuiPlateFrame.originalPlateFrame.selectionGlow:SetHeight(UPConstants.glowHeight)
			kuiPlateFrame.originalPlateFrame.selectionGlow:SetPoint("CENTER", kuiPlateFrame.health, "CENTER", -UPConstants.nameplateTypeIconSize/2, 0)
			kuiPlateFrame.originalPlateFrame.selectionGlow2:SetWidth(UPConstants.glowWidthGrayLevel)
			kuiPlateFrame.originalPlateFrame.selectionGlow2:SetHeight(UPConstants.glowHeight)
			kuiPlateFrame.originalPlateFrame.selectionGlow2:SetPoint("CENTER", kuiPlateFrame.health, "CENTER", -UPConstants.nameplateTypeIconSize/2, 0)
			kuiPlateFrame.originalPlateFrame:SetWidth(UPConstants.nameplateWidthGrayLevel)
			kuiPlateFrame.originalPlateFrame:SetHeight(UPConstants.nameplateHealthBarHeight)
			SetFrameCenter(kuiPlateFrame)
			kuiPlateFrame.health:SetWidth(UPConstants.nameplateWidthGrayLevel)
			kuiPlateFrame.health:SetHeight(UPConstants.nameplateHealthBarHeight)
			kuiPlateFrame.health:SetPoint("BOTTOMLEFT", kuiPlateFrame.x, kuiPlateFrame.y)
			kuiPlateFrame.power:SetWidth(UPConstants.nameplateWidthGrayLevel)
			kuiPlateFrame.castWarning.bar:SetWidth(UPConstants.nameplateWidthGrayLevel)
			kuiPlateFrame.aurasContainer:SetWidth(UPConstants.nameplateWidthGrayLevel)
		else
			kuiPlateFrame.originalPlateFrame.selectionGlow:SetWidth(UPConstants.glowWidth)
			kuiPlateFrame.originalPlateFrame.selectionGlow:SetHeight(UPConstants.glowHeight)
			kuiPlateFrame.originalPlateFrame.selectionGlow:SetPoint("CENTER", kuiPlateFrame.health, "CENTER", -UPConstants.nameplateTypeIconSize/2, 0)
			kuiPlateFrame.originalPlateFrame.selectionGlow2:SetWidth(UPConstants.glowWidth)
			kuiPlateFrame.originalPlateFrame.selectionGlow2:SetHeight(UPConstants.glowHeight)
			kuiPlateFrame.originalPlateFrame.selectionGlow2:SetPoint("CENTER", kuiPlateFrame.health, "CENTER", -UPConstants.nameplateTypeIconSize/2, 0)
			kuiPlateFrame.originalPlateFrame:SetWidth(UPConstants.nameplateHealthBarWidth)
			kuiPlateFrame.originalPlateFrame:SetHeight(UPConstants.nameplateHealthBarHeight)
			SetFrameCenter(kuiPlateFrame)
			kuiPlateFrame.health:SetWidth(UPConstants.nameplateHealthBarWidth)
			kuiPlateFrame.health:SetHeight(UPConstants.nameplateHealthBarHeight)
			kuiPlateFrame.health:SetPoint("BOTTOMLEFT", kuiPlateFrame.x, kuiPlateFrame.y)
			kuiPlateFrame.power:SetWidth(UPConstants.nameplateHealthBarWidth)
			kuiPlateFrame.castWarning.bar:SetWidth(UPConstants.nameplateHealthBarWidth)
			kuiPlateFrame.aurasContainer:SetWidth(UPConstants.nameplateHealthBarWidth)
		end
		--healthbar width end

		--class, race, gender icons
		if kuiPlateFrame.isPlayer then
			if kuiPlateFrame.class then
				local classr, classl, classt, classb = getClassPos(string.upper(kuiPlateFrame.class))
				kuiPlateFrame.classIcon.icon:SetTexCoord(classr, classl, classt, classb)
				kuiPlateFrame.classIcon:Show()
			else
				kuiPlateFrame.classIcon:Hide()
			end

			if kuiPlateFrame.gender and kuiPlateFrame.race then
				if kuiPlateFrame.gender == 3 then
					kuiPlateFrame.typeIcon.icon:SetTexture("Interface\\AddOns\\UnitPlates\\img\\races\\"..kuiPlateFrame.race.."_female.tga")
				else
					kuiPlateFrame.typeIcon.icon:SetTexture("Interface\\AddOns\\UnitPlates\\img\\races\\"..kuiPlateFrame.race.."_male.tga")
				end
			else
				kuiPlateFrame.typeIcon.icon:SetTexture("Interface\\AddOns\\UnitPlates\\img\\loading.tga")
			end
		else
			kuiPlateFrame.classIcon:Hide()
		end
		--class, race, gender end

		--set creature type
		if not kuiPlateFrame.isPlayer then
			if kuiPlateFrame.creatureType then
				local success = kuiPlateFrame.typeIcon.icon:SetTexture("Interface\\AddOns\\UnitPlates\\img\\creaturetypes\\"..kuiPlateFrame.creatureType..".tga")
				if not success then
					local success = kuiPlateFrame.typeIcon.icon:SetTexture("Interface\\AddOns\\UnitPlates\\img\\creaturetypes\\UNKNOWN.tga")
				end
			else
				kuiPlateFrame.typeIcon.icon:SetTexture("Interface\\AddOns\\UnitPlates\\img\\loading.tga")
			end
		end
		--set creature type end
	end

	--combat icon (dynamic)
	if kuiPlateFrame.isInCombat then
		kuiPlateFrame.combatIcon:Show()
	else
		kuiPlateFrame.combatIcon:Hide()
	end

	--health color
	local r, g, b = kuiPlateFrame.oldHealth:GetStatusBarColor()
	kuiPlateFrame.health.r, kuiPlateFrame.health.g, kuiPlateFrame.health.b = r, g, b
	if g > 0.9 and r == 0 and b == 0 then
		-- friendly NPC
		r, g, b = unpack(friendlyColor)
	elseif b > 0.9 and r == 0 and g == 0 then
		-- friendly player
		r, g, b = unpack(playerColor)
	elseif r > 0.9 and g == 0 and b == 0 then
		-- enemy NPC
		r, g, b = unpack(hatedColor)
	elseif (r + g) > 1.8 and b == 0 then
		-- neutral NPC
		r, g, b = unpack(neutralColor)
	elseif r < 0.6 and (r + g) == (r + b) then
		-- tapped NPC
		r, g, b = unpack(tappedColor)
	else
		-- enemy player, use default UI colour
	end
	kuiPlateFrame.health:SetStatusBarColor(r, g, b)
	--health color end
	
	--health percentage
	local hpPercent = math.floor(kuiPlateFrame.health.percent)
	if (hpPercent < 100) or (kuiPlateFrame.isInCombat) then
		kuiPlateFrame.health.percentage:SetText(math.floor(kuiPlateFrame.health.percent).."%")
	else
		kuiPlateFrame.health.percentage:SetText("")
	end
	--health percentage
	
	--update health
	kuiPlateFrame.health.min, kuiPlateFrame.health.max = kuiPlateFrame.oldHealth:GetMinMaxValues()
	kuiPlateFrame.health.curr = kuiPlateFrame.oldHealth:GetValue()
	kuiPlateFrame.health.percent = 100 * kuiPlateFrame.health.curr / kuiPlateFrame.health.max
	kuiPlateFrame.health:SetMinMaxValues(kuiPlateFrame.health.min, kuiPlateFrame.health.max)
	kuiPlateFrame.health:SetValue(kuiPlateFrame.health.curr)
	if UPCoreNum(kuiPlateFrame.health.max) == 100 then
		--most likely it is unknown hp
		--try to get from shaguTweaks
		local current, max = UPCompatGetHealthFromShaguTweaks(kuiPlateFrame.guid)

		if not current then
			--try MobHealth fallback
			current, max = UPCompatGetHealthFromMobHealth(kuiPlateFrame.guid)
		end

		if current then
			kuiPlateFrame.health.p:SetText(UPCoreNum(math_floor(current + 0.5)))
		else
			--most likely it is unknown hp
			kuiPlateFrame.health.p:SetText(UPCoreNum(kuiPlateFrame.health.curr).."%")
		end
	else
		--most likely has real hp
		kuiPlateFrame.health.p:SetText(UPCoreNum(kuiPlateFrame.health.curr))
	end
	--update health end
	
	--power
	if kuiPlateFrame.unitMaxPower > 0 then		
		-- print("----------unitPowerType: "..kuiPlateFrame.unitPowerType)
		-- print("----------unitMaxPower: "..kuiPlateFrame.unitMaxPower)
		-- print("----------unitPower: "..unitPower)
		kuiPlateFrame.power.text:SetText(string.format("%s", UPCoreAbbreviate(kuiPlateFrame.unitPower)))
	
		if kuiPlateFrame.unitPowerType == 0 then
			kuiPlateFrame.power:SetStatusBarColor(unpack(powerBarColors.mana))
		elseif kuiPlateFrame.unitPowerType == 1 then
			kuiPlateFrame.power:SetStatusBarColor(unpack(powerBarColors.rage))
		elseif kuiPlateFrame.unitPowerType == 2 or kuiPlateFrame.unitPowerType == 3 then
			kuiPlateFrame.power:SetStatusBarColor(unpack(powerBarColors.energy))
		else
			kuiPlateFrame.power:SetStatusBarColor(unpack(powerBarColors.energy))
		end
		
		kuiPlateFrame.power:SetMinMaxValues(0, kuiPlateFrame.unitMaxPower)
		
		if kuiPlateFrame.unitPowerType == 1 and kuiPlateFrame.unitPower < 1 then
			kuiPlateFrame.power:SetValue(kuiPlateFrame.unitMaxPower)
			kuiPlateFrame.power:SetStatusBarColor(unpack(powerBarColors.rageDim))
		else
			kuiPlateFrame.power:SetValue(kuiPlateFrame.unitPower)
		end
		kuiPlateFrame.power:Show()
	else
		kuiPlateFrame.power:Hide()
	end
	--power end

	--tapped
	if kuiPlateFrame.isTapped then
		--print("----------name3: "..kuiPlateFrame.guid)
		-- tapped NPC
		local rt, gt, bt = unpack(tappedColor)
		kuiPlateFrame.health:SetStatusBarColor(tr, gt, bt)
	else
		--not tapped
		--gotta set normal color?
	end
	--tapped end
	
	-- --mouseover
	-- if kuiPlateFrame.originalPlateFrame.isInMouseOver then
		-- kuiPlateFrame.originalPlateFrame:SetFrameStrata("LOW")
		-- -- kuiPlateFrame.name:SetTextColor(1,1,0,1)
		-- -- kuiPlateFrame.guild:SetTextColor(1,1,0,1)
	-- else
		-- kuiPlateFrame.originalPlateFrame:SetFrameStrata("BACKGROUND")
		-- -- kuiPlateFrame.name:SetTextColor(1,1,0,1)
		-- -- kuiPlateFrame.guild:SetTextColor(1,1,0,1)
	-- end
	-- --mouseover end
	
	--target
	if kuiPlateFrame.isTarget then
		kuiPlateFrame.originalPlateFrame:SetFrameStrata("MEDIUM")
		kuiPlateFrame.glow:Show() 
		kuiPlateFrame.glow2:Show()
		-- kuiPlateFrame.visglow:Show()
		-- kuiPlateFrame.visglow2:Show()
		kuiPlateFrame.originalPlateFrame.totem.glow:Show()
		kuiPlateFrame.originalPlateFrame.totem.glow2:Show()
		
		-- kuiPlateFrame.health:SetBackdropColor(unpack(glowColor))
		-- kuiPlateFrame.power:SetBackdropColor(unpack(glowColor))
		-- kuiPlateFrame.typeIcon:SetBackdropColor(unpack(glowColor))
		kuiPlateFrame.health:SetBackdropBorderColor(unpack(glowColor))
		kuiPlateFrame.power:SetBackdropBorderColor(unpack(glowColor))
		kuiPlateFrame.typeIcon:SetBackdropBorderColor(unpack(glowColor))
		
		-- kuiPlateFrame.health.bgOffsetFrame:SetBackdropBorderColor(unpack(glowColor)) -- Very dark grey subtle border
		-- kuiPlateFrame.health.overlayMask:SetBackdropBorderColor(unpack(glowColor)) -- Black masking border
		
		--kuiPlateFrame:SetFrameLevel(3)
		
		
		kuiPlateFrame.originalPlateFrame.selectionGlow:Show()
		kuiPlateFrame.originalPlateFrame.selectionGlow2:Show()
	else
		--mouseover
		if kuiPlateFrame.originalPlateFrame.isInMouseOver then
			kuiPlateFrame.originalPlateFrame:SetFrameStrata("LOW")
			-- kuiPlateFrame.name:SetTextColor(1,1,0,1)
			-- kuiPlateFrame.guild:SetTextColor(1,1,0,1)
		else
			kuiPlateFrame.originalPlateFrame:SetFrameStrata("BACKGROUND")
			-- kuiPlateFrame.name:SetTextColor(1,1,0,1)
			-- kuiPlateFrame.guild:SetTextColor(1,1,0,1)
		end
		--mouseover end
	
	
		kuiPlateFrame.glow:Hide() 
		kuiPlateFrame.glow2:Hide()
		-- kuiPlateFrame.visglow:Hide()
		-- kuiPlateFrame.visglow2:Hide()
		kuiPlateFrame.originalPlateFrame.totem.glow:Hide()
		kuiPlateFrame.originalPlateFrame.totem.glow2:Hide()
		
		-- kuiPlateFrame.health:SetBackdropColor(0, 0, 0, 1)
		-- kuiPlateFrame.power:SetBackdropColor(0, 0, 0, 1)
		-- kuiPlateFrame.typeIcon:SetBackdropColor(0, 0, 0, 1)
		kuiPlateFrame.health:SetBackdropBorderColor(0, 0, 0, 1)
		kuiPlateFrame.power:SetBackdropBorderColor(0, 0, 0, 1)
		kuiPlateFrame.typeIcon:SetBackdropBorderColor(0, 0, 0, 1)
		
		-- kuiPlateFrame.health.bgOffsetFrame:SetBackdropBorderColor(0.1, 0.1, 0.1, 1) -- Very dark grey subtle border
		-- kuiPlateFrame.health.overlayMask:SetBackdropBorderColor(0, 0, 0, 1) -- Black masking border
		
		--kuiPlateFrame:SetFrameLevel(0)
		kuiPlateFrame.originalPlateFrame.selectionGlow:Hide()
		kuiPlateFrame.originalPlateFrame.selectionGlow2:Hide()
	end
	--target end
	
	--shooting range icon
	if kuiPlateFrame.isTarget and UnitCanAttack("player", "target") then
		if UPApiIsTargetInShootingDistance() then
			kuiPlateFrame.shootingIcon:Show()
		else
			kuiPlateFrame.shootingIcon:Hide()
		end
	else
		kuiPlateFrame.shootingIcon:Hide()
	end
	--shooting range icon end
	
	--TOTEM
	-- Re-evaluate totem-ness every tick from the current name instead of
	-- trusting the 100ms-cached originalPlateFrame.isTotem: when a plate is
	-- recycled between units (or a totem expires) the stale flag would keep
	-- the totem icon visible on a unit that is no longer a totem. This is a
	-- handful of string.find calls on one short name -- cheap.
	-- guid is refreshed at the top of UpdatePlate; the name is read here when
	-- needed (UnitName on a valid guid is one API call).
	local liveIsTotem = false
	if kuiPlateFrame.guid then
		local liveName = UnitName(unitRef)
		if liveName then
			liveIsTotem = UPApiIsTotem(liveName)
		end
	end
	kuiPlateFrame.originalPlateFrame.isTotem = liveIsTotem
	if liveIsTotem then
		kuiPlateFrame.originalPlateFrame.totem.icon:SetTexture(UpApiGetTotemIconForName(kuiPlateFrame.nameTextVariable))
		local totemR,totemG,totemB,totemA = kuiPlateFrame.health:GetStatusBarColor()
		kuiPlateFrame.originalPlateFrame.totem:SetBackdropColor(totemR,totemG,totemB,totemA)
		kuiPlateFrame.originalPlateFrame.totem:SetBackdropBorderColor(totemR,totemG,totemB,totemA)
		
		kuiPlateFrame.originalPlateFrame.totem.bgOffsetFrame:SetBackdropColor(totemR,totemG,totemB,totemA) -- Dark backdrop fill
		kuiPlateFrame.originalPlateFrame.totem.bgOffsetFrame:SetBackdropBorderColor(totemR,totemG,totemB,totemA) -- Matte grey border rim
		kuiPlateFrame.originalPlateFrame.totem.overlayMask:SetBackdropBorderColor(0, 0, 0, 1) -- Pure black mask to match layouts
		
		kuiPlateFrame.originalPlateFrame.selectionGlow:SetWidth(UPConstants.glowWidthTotem)
		kuiPlateFrame.originalPlateFrame.selectionGlow:SetHeight(UPConstants.glowWidthTotem)
		kuiPlateFrame.originalPlateFrame.selectionGlow:SetPoint("CENTER", kuiPlateFrame.originalPlateFrame.totem, "CENTER", 0, 0)
		kuiPlateFrame.originalPlateFrame.selectionGlow2:SetWidth(UPConstants.glowWidthTotem)
		kuiPlateFrame.originalPlateFrame.selectionGlow2:SetHeight(UPConstants.glowWidthTotem)
		kuiPlateFrame.originalPlateFrame.selectionGlow2:SetPoint("CENTER", kuiPlateFrame.originalPlateFrame.totem, "CENTER", 0, 0)
		
		kuiPlateFrame.originalPlateFrame.totem:Show()
		kuiPlateFrame:Hide()
	else
		kuiPlateFrame.originalPlateFrame.totem:Hide()
		kuiPlateFrame:Show()
	end
	--if totemIcon then return nil end
	--TOTEM end
	
	--cast warning bar simulation
	local currTimeMillis = GetTime()*1000
	local spellName, spellNameSecondary, spellDisplayName, spellIcon, spellStartTimeMillis, spellEndTimeMillis, spellIsTradeSkill, isChannel = UPApiUnitCastingInfo(kuiPlateFrame.guid)
	-- local spellName = nil
	if kuiPlateFrame.guid then
		if (spellName and ((spellEndTimeMillis - currTimeMillis) > 0)) then
			-- print("spellName: "..spellName)
			-- print("spellNameSecondary: "..spellNameSecondary)
			-- print("spellDisplayName: "..spellDisplayName)
			-- print("spellIcon: "..spellIcon)
			-- print("spellStartTimeMillis: "..spellStartTimeMillis)
			-- print("spellEndTimeMillis: "..spellEndTimeMillis)
			-- print("spellIsTradeSkill: ".."boolean")
			-- print("spellCastID: "..spellCastID)
			-- print("spellInterrupt: ".."boolean")
			
			--something is being cast
			kuiPlateFrame.castWarning.currentValue = spellEndTimeMillis - currTimeMillis
			kuiPlateFrame.castWarning.startTime = spellStartTimeMillis
			kuiPlateFrame.castWarning.endTime = spellEndTimeMillis
			kuiPlateFrame.castWarning.castTime = kuiPlateFrame.castWarning.endTime-kuiPlateFrame.castWarning.startTime
			
			-- print("guid startTime raw: "..spellStartTimeMillis)
			-- print("guid endTime raw: "..spellEndTimeMillis)
			
			local col = {r = 1, g = 1, b = 1}
			kuiPlateFrame.castWarning.text:SetTextColor(col.r, col.g, col.b)
			kuiPlateFrame.castWarning.text:SetText("["..spellName.."]")
			kuiPlateFrame.castWarning.icon.tex:SetTexture(spellIcon)
			
			kuiPlateFrame.castWarning.curr:SetText(string.format("%.1f", kuiPlateFrame.castWarning.currentValue/1000))
			kuiPlateFrame.castWarning.bar:SetMinMaxValues(0, kuiPlateFrame.castWarning.castTime)
			local progress = kuiPlateFrame.castWarning.castTime - kuiPlateFrame.castWarning.currentValue -- Fills (e.g., 0 -> 3000)
			if isChannel then
				progress = kuiPlateFrame.castWarning.currentValue -- Drains (e.g., 3000 -> 0)
			end
			kuiPlateFrame.castWarning.bar:SetValue(progress)
			
			-- Move the Spark
			local barWidth = kuiPlateFrame.castWarning.bar:GetWidth()
			if barWidth > 0 and kuiPlateFrame.castWarning.castTime > 0 then
				-- 2. Calculate the progress ratio (0 to 1)
				-- For a standard cast (filling up):
				local ratio = progress / kuiPlateFrame.castWarning.castTime
				
				-- 3. Calculate the pixel offset
				local sparkOffset = ratio * barWidth
				
				-- 4. APPLY THE MOVEMENT
				kuiPlateFrame.castWarning.spark:ClearAllPoints() -- CRITICAL for 1.12
				kuiPlateFrame.castWarning.spark:SetPoint("CENTER", kuiPlateFrame.castWarning.bar, "LEFT", sparkOffset, 0)
				
				--print("Ratio: "..ratio.." Offset: "..sparkOffset)
				
				-- 5. Optional: Hide spark if it's at the very beginning or end
				if ratio <= 0.01 or ratio >= 0.99 then
					kuiPlateFrame.castWarning.spark:Hide()
				else
					kuiPlateFrame.castWarning.spark:Show()
				end
			end
			
			if not spellInterrupt then
				kuiPlateFrame.castWarning.bar:SetStatusBarColor(unpack(castBarColor))	
				kuiPlateFrame.castWarning.shield:Hide()
			else
				kuiPlateFrame.castWarning.bar:SetStatusBarColor(unpack(castBarShieldColor))
				kuiPlateFrame.castWarning.shield:Show()
			end
			
			kuiPlateFrame.castWarning:Show()
			-- print("guid castTime: "..kuiPlateFrame.castWarning.castTime.." / ".."current: "..kuiPlateFrame.castWarning.castTime-kuiPlateFrame.castWarning.currentValue)
		else
			--assume nothing is being cast
			kuiPlateFrame.castWarning.startTime = 0
			kuiPlateFrame.castWarning.endTime = 0
			
			if kuiPlateFrame.castWarning.endTime > currTimeMillis then
				kuiPlateFrame.castWarning.currentValue = kuiPlateFrame.castWarning.endTime - currTimeMillis
				
				kuiPlateFrame.castWarning.curr:SetText(string.format("%.1f", kuiPlateFrame.castWarning.currentValue/1000))
				kuiPlateFrame.castWarning.bar:SetMinMaxValues(0, kuiPlateFrame.castWarning.castTime)
				kuiPlateFrame.castWarning.bar:SetValue(kuiPlateFrame.castWarning.castTime - kuiPlateFrame.castWarning.currentValue)
				
				kuiPlateFrame.castWarning.bar:SetStatusBarColor(unpack(castBarColor))	
				kuiPlateFrame.castWarning.shield:Hide()
				
			end
			if (kuiPlateFrame.castWarning:IsShown() and (kuiPlateFrame.castWarning.castTime > 0) and (currTimeMillis > kuiPlateFrame.castWarning.endTime)) then
				kuiPlateFrame.castWarning.castTime = 0
				kuiPlateFrame.castWarning:Hide()
				kuiPlateFrame.castWarning.spark:ClearAllPoints() -- CRITICAL for 1.12
				kuiPlateFrame.castWarning.spark:SetPoint("CENTER", kuiPlateFrame.castWarning.bar, "LEFT", 0, 0)
			end
		end
	else
		if kuiPlateFrame.castWarning.endTime > currTimeMillis then
			kuiPlateFrame.castWarning.currentValue = kuiPlateFrame.castWarning.endTime - currTimeMillis
			
			kuiPlateFrame.castWarning.curr:SetText(string.format("%.1f", kuiPlateFrame.castWarning.currentValue/1000))
			kuiPlateFrame.castWarning.bar:SetMinMaxValues(0, kuiPlateFrame.castWarning.castTime)
			kuiPlateFrame.castWarning.bar:SetValue(kuiPlateFrame.castWarning.castTime-kuiPlateFrame.castWarning.currentValue)
			
			kuiPlateFrame.castWarning.bar:SetStatusBarColor(unpack(castBarColor))	
			kuiPlateFrame.castWarning.shield:Hide()
			
			-- print("normal castTime: "..kuiPlateFrame.castWarning.castTime.." / ".."current: "..kuiPlateFrame.castWarning.castTime-kuiPlateFrame.castWarning.currentValue)
		end
		if (kuiPlateFrame.castWarning:IsShown() and (kuiPlateFrame.castWarning.castTime > 0) and (currTimeMillis > kuiPlateFrame.castWarning.endTime)) then
			kuiPlateFrame.castWarning.castTime = 0
			kuiPlateFrame.castWarning:Hide()
			kuiPlateFrame.castWarning.spark:ClearAllPoints() -- CRITICAL for 1.12
			kuiPlateFrame.castWarning.spark:SetPoint("CENTER", kuiPlateFrame.castWarning.bar, "LEFT", 0, 0)
		end
	end
	--cast warning bar simulation end
	
	--THREAT
	--if (guid and (not kuiPlateFrame.friend)) then
	-- if (kuiPlateFrame.guid) then
		-- -- local isTanking, status, threatpct, rawthreatpct, threatvalue = UnitDetailedThreatSituation("player", guid)
		-- -- if threatpct then
			-- -- local p = threatpct / 100
        
			-- -- -- Interpolate: StartValue + (EndValue - StartValue) * Ratio
			-- -- local r = 0.2 + (0.7 - 0.2) * p
			-- -- local g = 0.6 + (0.2 - 0.6) * p
			-- -- local b = 0.1 -- Both start and end at 0.1		
		
			-- -- kuiPlateFrame.threat.text:SetTextColor(r, g, b, 1)
			-- -- kuiPlateFrame.threat.text:SetText(string.format("%d", threatpct).."%")
			-- -- kuiPlateFrame.threat.text:Show()
		-- -- else
			-- -- kuiPlateFrame.threat.text:Hide()
		-- -- end
		-- local threatPercentage = UPThreatLibGetMyThreatPercentage(kuiPlateFrame.guid)
		-- kuiPlateFrame.threat:SetText(string.format("%d", threatPercentage).."%")
		-- kuiPlateFrame.threat:Show()
	-- else
		-- kuiPlateFrame.threat:Hide()
	-- end
	
	if (not kuiPlateFrame.isPlayer) and kuiPlateFrame.isInCombat and (not UnitIsFriend("player", unitRef)) and UPApiIsUnitTargetingMe(kuiPlateFrame.guid) then
		kuiPlateFrame.name:SetTextColor(0.9,0,0,1)
		kuiPlateFrame.guild:SetTextColor(0.9,0,0,1)
		kuiPlateFrame.health:SetStatusBarColor(0.85,0,0,1)
		kuiPlateFrame.health:SetStatusBarTexture("Interface\\AddOns\\UnitPlates\\img\\statusbar\\XPerl_StatusBar")
	else
		kuiPlateFrame.health:SetStatusBarTexture("Interface\\AddOns\\UnitPlates\\img\\statusbar\\XPerl_StatusBar4")
	end
	
	--THREAT END
	
	--PARTY/RAID
	if kuiPlateFrame.isPlayer then
		if UnitInParty(unitRef) then
		--if true then
			--is in party
			kuiPlateFrame.name:SetTextColor(0.4, 0.6, 1, 0.99999779462814)
			if not (kuiPlateFrame.guildTextVariable == myGuildName) then
				kuiPlateFrame.guild:SetTextColor(0.4, 0.6, 1, 0.99999779462814)
			end
			kuiPlateFrame.health:SetStatusBarColor(0.4, 0.6, 1, 0.99999779462814)
			--kuiPlateFrame.health:SetStatusBarTexture("Interface\\AddOns\\UnitPlates\\img\\statusbar\\XPerl_StatusBar8")
			
			--UPApiIsPartyLeader(guid)
		elseif UnitInRaid(unitRef) then
		--elseif true then
			--not in party but in raid
			--0.85, 0.55, 0.25 --another option
			kuiPlateFrame.name:SetTextColor(0.85, 0.45, 0.15, 0.99999779462814)
			if not (kuiPlateFrame.guildTextVariable == myGuildName) then
				kuiPlateFrame.guild:SetTextColor(0.85, 0.45, 0.15, 0.99999779462814)
			end
			kuiPlateFrame.health:SetStatusBarColor(0.85, 0.45, 0.15, 0.99999779462814)
			
			--UPApiIsRaidLeader(guid)
			--UPApiIsRaidAssistant(guid)
		else
			--defaults
		end
	end
	--PARTY/RAID END
	
	--PVP SITUATION
		--add faction icon
	--PVP SITUATION END
	
	--AURA POLLING (event-driven via UNIT_AURA when ClassicAPI is present;
	-- aurasUpdateElapsed is only a slow safety net / SuperWoW fallback).
	local pollAuras = kuiPlateFrame.auraUpdate or (kuiPlateFrame.aurasUpdateElapsed <= 0)
	if pollAuras then
		kuiPlateFrame.auraUpdate = nil
		if kuiPlateFrame.unit and UPApiHasClassicAuras and UPApiHasClassicAuras() then
			kuiPlateFrame.aurasUpdateElapsed = aurasUnitUpdateTimeEventDriven
		else
			kuiPlateFrame.aurasUpdateElapsed = aurasUnitUpdateTime
		end

		-- ignore-lists are re-parsed only when the setting text changes
		local ignoredBuffNames, ignoredDebuffNames = UPGetIgnoredAuraNames()

		local polledUnitAuras = UpApiGetUnitAuras(
			kuiPlateFrame.guid,
			UnitPlatesSettings.showBuffs,
			UnitPlatesSettings.onlyYourBuffs,
			UnitPlatesSettings.showDebuffs,
			UnitPlatesSettings.onlyYourDebuffs,
			ignoredBuffNames,
			ignoredDebuffNames,
			kuiPlateFrame.unit
		)
		if polledUnitAuras then
			kuiPlateFrame.unitAuras = polledUnitAuras
		end
	end
	--AURA POLLING END
end

local function UPApplyPlateAlpha(kuiPlateFrame, state)
	-- The engine fades the original plate for non-targets and that alpha
	-- propagates to this child frame; force it back to full alpha so plates
	-- never go transparent unless the config option re-enables it.
	if UnitPlatesSettings.keepOriginalNameplateAlpha then
		local plateGuid = kuiPlateFrame.cachedGuid or kuiPlateFrame.guid
		if not state.targetGuid or (plateGuid and plateGuid == state.targetGuid) then
			kuiPlateFrame:SetAlpha(1)
		else
			kuiPlateFrame:SetAlpha(UPApiGetNonTargetAlpha())
		end
	else
		kuiPlateFrame:SetAlpha(1)
	end
end

local function UPProcessPlateMouse(originalPlateFrame, kuiPlateFrame)
	local unitExists, unitExistsGuid = UnitExists("mouseover")
	if unitExists and unitExistsGuid and (unitExistsGuid == kuiPlateFrame.guid) then
		originalPlateFrame.isMouseover3dModel = true
		originalPlateFrame.isInMouseOver = true
	else
		originalPlateFrame.isMouseover3dModel = false
	end

	if (not IsMouselooking()) and (MouseIsOver(kuiPlateFrame.health) or MouseIsOver(kuiPlateFrame.typeIcon) or MouseIsOver(kuiPlateFrame.power) or MouseIsOver(originalPlateFrame.totem)) then
		originalPlateFrame.isInMouseOver = true
		if kuiPlateFrame.guid and UnitCanAttack("player", kuiPlateFrame.guid) then
			SetCursor("ATTACK_CURSOR")
		end
		if kuiPlateFrame.isTarget and UnitCanAttack("player", "target") then
			SetCursor("ATTACK_CURSOR")
		end
	else
		if not originalPlateFrame.isMouseover3dModel then
			originalPlateFrame.isInMouseOver = false
		end
	end

	if (GetTime() - originalPlateFrame.rightClickStartTime <= rightClickSimulationDelay)
		and (not IsMouselooking())
		and (MouseIsOver(kuiPlateFrame.health) or MouseIsOver(kuiPlateFrame.typeIcon) or MouseIsOver(kuiPlateFrame.power) or MouseIsOver(originalPlateFrame.totem)) then
		originalPlateFrame:Click("RightButton")
	end
end

-- Central per-plate updater (pfUI-style): cheap work every central tick,
-- expensive UpdatePlate only past the category throttle (or on event flags).
local function ProcessVisiblePlate(originalPlateFrame, state)
	local kuiPlateFrame = originalPlateFrame.kui
	if not kuiPlateFrame then return end

	local elapsed = state.elapsed or UP_THROTTLE_CENTRAL
	kuiPlateFrame.aurasUpdateElapsed = (kuiPlateFrame.aurasUpdateElapsed or 0) - elapsed

	UPApplyPlateAlpha(kuiPlateFrame, state)
	UPProcessPlateMouse(originalPlateFrame, kuiPlateFrame)

	local now = state.now
	-- Keep ProcessVisiblePlate throttle classification aligned with the
	-- PLAYER_TARGET_CHANGED-maintained cache (also feeds UPApiIsTarget).
	local isTarget = state.targetGuid and kuiPlateFrame.cachedGuid
		and (state.targetGuid == kuiPlateFrame.cachedGuid)
	local casting = kuiPlateFrame.castWarning and kuiPlateFrame.castWarning:IsShown()
	local hasEvent = kuiPlateFrame.eventcache or kuiPlateFrame.auraUpdate
		or kuiPlateFrame.castUpdate or kuiPlateFrame.doFullUpdate

	-- Cheap gate using the floor throttle before classifying further.
	if not hasEvent and (kuiPlateFrame.lasttick or 0) + UP_THROTTLE_MIN > now then
		return
	end

	local throttle = UP_THROTTLE_NORMAL
	if isTarget then
		throttle = UP_THROTTLE_TARGET
	elseif state.visibleCount > UP_MASS_PLATE_THRESHOLD then
		throttle = UP_THROTTLE_MASS
	end
	if casting and not isTarget and UP_THROTTLE_CAST < throttle then
		throttle = UP_THROTTLE_CAST
	end

	if not hasEvent and (kuiPlateFrame.lasttick or 0) + throttle > now then
		return
	end
	kuiPlateFrame.lasttick = now
	kuiPlateFrame.eventcache = nil
	kuiPlateFrame.castUpdate = nil

	-- Periodic full rebuild for mostly-static content (guild/icons/colors).
	local ranFull = kuiPlateFrame.doFullUpdate
	if (kuiPlateFrame.lastFullTick or 0) + slowUpdateTime <= now then
		ranFull = true
		kuiPlateFrame.doFullUpdate = true
		kuiPlateFrame.lastFullTick = now
	end

	UpdatePlate(kuiPlateFrame)

	-- pfquest icon refresh rides the full-rebuild cadence.
	if ranFull then
		if not kuiPlateFrame.isPlayer then
			local icon = UPCompatPfQuestQuestObjectives[kuiPlateFrame.nameTextVariable]
			if icon then
				kuiPlateFrame.questIcon.icon:SetTexture(icon)
				kuiPlateFrame.questIcon:Show()
			else
				kuiPlateFrame.questIcon:Hide()
			end
		else
			kuiPlateFrame.questIcon:Hide()
		end
	end
end

-----------PLATE CREATION
local function InitFrame(originalPlateFrame)
	-- originalPlateFrame.variables = {
		-- guid = nil,
		-- name = nil,
		-- level = nil,
		-- isTotem = nil,
		-- isPlayer = nil,
		-- isBoss = nil,
		-- isTrivial = nil,
	-- }


	-- container for kui objects!
	originalPlateFrame.kui = CreateFrame("Frame", nil, originalPlateFrame)
	local kuiPlateFrame = originalPlateFrame.kui
	
	originalPlateFrame.rightClickStartTime = 0

	kuiPlateFrame.fontObjects = {}

	-- fetch default ui's objects
	--local healthBar, castBar = originalPlateFrame:GetChildren()
	--local glowRegion, overlayRegion, castbarOverlay, shieldedRegion, spellIconRegion, highlightRegion, nameTextRegion, levelTextRegion, bossIconRegion, raidIconRegion, stateIconRegion = originalPlateFrame:GetRegions()
	
	--local healthBar = originalPlateFrame.healthbar
	--local castBar = originalPlateFrame.castBar
	local healthBar, castBar = originalPlateFrame:GetChildren()
	
	--local nameTextRegion = originalPlateFrame.name
	--local levelTextRegion = originalPlateFrame.level
	-- local nameTextRegion = originalPlateFrame.name
	-- local nameTextRegion = originalPlateFrame.name
	
	--local threatGlow, border, highlight, levelIcon, bossIcon, raidIcon, nameTextRegion, levelTextRegion, stateIcon, eliteBorder = originalPlateFrame:GetRegions()
	
	local borderRegion, glowRegion, highlightRegion, levelIconRegion, bossIconRegion, raidIconRegion1, nameTextRegion, levelTextRegion, stateIcon, eliteBorder = originalPlateFrame:GetRegions()
	
	-- originalPlateFrame.name = nameTextRegion	
	-- originalPlateFrame.level = levelTextRegion
	
	--ureg2:SetTexture(nil)
	
	local raidIconRegion = nil
	--raid icon
	-- GetRegions returns a list of all textures and fontstrings on the frame
    local regions = {originalPlateFrame:GetRegions()}
	local fontStrings = {}
	-- Loop through all graphical components on the engine plate
	for i = 1, table.getn(regions) do
		if regions[i] and regions[i]:GetObjectType() == "FontString" then
			table.insert(fontStrings, regions[i])
		end
	end	
	-- The 1.12 engine always creates Name first, then Level second
	if table.getn(fontStrings) >= 2 then
		originalPlateFrame.name = fontStrings[1]
		originalPlateFrame.level = fontStrings[2]
	end
	
	
    for _, region in ipairs(regions) do
        -- Check if the region is a texture and has the raid icons path
        if region:IsObjectType("Texture") then
            local texturePath = region:GetTexture()
            if texturePath and string.find(texturePath, "UI%-RaidTargetingIcons") then
				raidIconRegion = region
            end
        end
    end
	originalPlateFrame.raidIconRegion = raidIconRegion
	--raid icon end	
	
	bossIconRegion:SetTexture(nil)
	if bossIconRegion and bossIconRegion:IsVisible() then
		-- -- This unit is a Boss (it has the skull icon active)
		-- --print("Boss detected!")
		-- bossIconRegion:SetTexture(nil)
		-- kuiPlateFrame.isBoss = true
	end
	originalPlateFrame.bossIconRegion = bossIconRegion
	
	-- print(tostring(borderRegion:GetTexture()))
	-- print(tostring(glowRegion:GetTexture()))
	--print(tostring(highlightRegion:GetTexture()))

	--overlayRegion:SetTexture(nil)
	--highlightRegion:SetTexture(nil)
	--bossIconRegion:SetTexture(nil)
	--shieldedRegion:SetTexture(nil)
	--castbarOverlay:SetTexture(nil)
	glowRegion:SetTexture(nil)
	--spellIconRegion:SetSize(0.01, 0.01)
	
	if not UnitPlatesSettings.overlapping then
		borderRegion:SetTexture(nil)
	end

	--overlayRegion:Hide()
	--castbarOverlay:Hide()

	-- healthBar:Hide()
	--nameTextRegion:Hide()

	-- re-hidden OnFrameShow
	--bossIconRegion:Hide()
	--bossIconRegion:SetSize(0.01, 0.01)
	--stateIconRegion:Hide()
	--stateIconRegion:SetSize(0.01, 0.01)

	-- make default healthbar & castbar transparent
	--castBar:SetStatusBarTexture("Interface\\AddOns\\UnitPlates\\Media\\t\\empty")
	
	healthBar:Hide()
	healthBar:SetStatusBarTexture("Interface\\AddOns\\UnitPlates\\Media\\t\\empty")

	kuiPlateFrame.oldGlow = glowRegion
	kuiPlateFrame.oldHealth = healthBar
	kuiPlateFrame.oldCastbar = castBar
	kuiPlateFrame.originalPlateFrame = originalPlateFrame
	kuiPlateFrame.oldHighlight = highlightRegion
	--------------------------------------------------------- Frame functions --
	--kuiPlateFrame.SetFrameCenter = SetFrameCenter
	------------------------------------------------------------------ Layout --	
	kuiPlateFrame:SetPoint("CENTER", originalPlateFrame, "CENTER")
	kuiPlateFrame.originalPlateFrame:SetFrameStrata("BACKGROUND")
	--kuiPlateFrame:SetFrameLevel(0)
	SetFrameCenter(kuiPlateFrame)
	
	
	
	
	
	
	-- -- self:CreateHealthBar(originalPlateFrame, kuiPlateFrame)
	-- kuiPlateFrame.health = CreateFrame("StatusBar", nil, kuiPlateFrame)
	-- kuiPlateFrame.health:SetFrameLevel(1)
	-- kuiPlateFrame.health:SetStatusBarTexture("Interface\\AddOns\\UnitPlates\\img\\statusbar\\XPerl_StatusBar4")
	-- kuiPlateFrame.health.percent = 100
	-- kuiPlateFrame.health:GetStatusBarTexture():SetDrawLayer("ARTWORK", -8)
	-- -- if self.SetValueSmooth then
		-- -- kuiPlateFrame.health.OrigSetValue = kuiPlateFrame.health.SetValue
		-- -- kuiPlateFrame.health.SetValue = self.SetValueSmooth
	-- -- elseif self.CutawayBar then
		-- -- self.CutawayBar(kuiPlateFrame.health)
	-- -- end
	-- kuiPlateFrame.health:SetBackdrop({
		-- bgFile = "Interface\\AddOns\\UnitPlates\\img\\WHITE", -- A solid texture
		-- edgeFile = "Interface\\AddOns\\UnitPlates\\img\\WHITE", 
		-- edgeSize = 1, 
		-- insets = { left = -UPConstants.minimalOnePixel, right = -UPConstants.minimalOnePixel, top = -UPConstants.minimalOnePixel, bottom = -UPConstants.minimalOnePixel }
	-- })
	-- kuiPlateFrame.health:SetBackdropColor(0, 0, 0, 1) -- Black Background
	-- kuiPlateFrame.health:SetBackdropBorderColor(0, 0, 0, 1) -- Black Border
	-- kuiPlateFrame.health:ClearAllPoints()
	-- kuiPlateFrame.health:SetWidth(UPConstants.nameplateHealthBarWidth)
	-- kuiPlateFrame.health:SetHeight(UPConstants.nameplateHealthBarHeight)
	-- kuiPlateFrame.health:SetPoint("BOTTOMLEFT", kuiPlateFrame.x, kuiPlateFrame.y)
	

	
	kuiPlateFrame.health = CreateFrame("StatusBar", nil, kuiPlateFrame)
	kuiPlateFrame.health:SetFrameLevel(2) -- Bumped up slightly so it layers nicely
	kuiPlateFrame.health:SetStatusBarTexture("Interface\\AddOns\\UnitPlates\\img\\statusbar\\XPerl_StatusBar4")
	kuiPlateFrame.health.percent = 100
	kuiPlateFrame.health:GetStatusBarTexture():SetDrawLayer("ARTWORK", -8)
	
	-- 1. CLEAN BACKDROP HANDLING: Create a distinct frame *behind* the health bar
	-- This ensures your dark background background has nicely padded rounded edges.
	if not kuiPlateFrame.health.bgOffsetFrame then
		kuiPlateFrame.health.bgOffsetFrame = CreateFrame("Frame", nil, kuiPlateFrame)
		kuiPlateFrame.health.bgOffsetFrame:SetFrameLevel(1) -- Below health bar
		kuiPlateFrame.health.bgOffsetFrame:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8", -- Crisp solid engine texture
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", -- Built-in 2px rounded edge
			tile = false, tileSize = 0, edgeSize = 10,
			insets = { left = 2, right = 2, top = 2, bottom = 2 }
		})
		kuiPlateFrame.health.bgOffsetFrame:SetBackdropColor(0, 0, 0, 0.8) -- Dark backdrop fill
		kuiPlateFrame.health.bgOffsetFrame:SetBackdropBorderColor(0.1, 0.1, 0.1, 1) -- Very dark grey subtle border
	end

	-- 2. THE CORNER MASKING OVERLAY: Create a frame *above* the health bar
	-- This chops off the sharp moving edges of the status bar as health updates.
	if not kuiPlateFrame.health.overlayMask then
		kuiPlateFrame.health.overlayMask = CreateFrame("Frame", nil, kuiPlateFrame)
		kuiPlateFrame.health.overlayMask:SetFrameLevel(3) -- Directly above the health bar
		kuiPlateFrame.health.overlayMask:SetBackdrop({
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", -- Slices off the 4 square corners
			tile = false, tileSize = 0, edgeSize = 10,
			insets = { left = 2, right = 2, top = 2, bottom = 2 }
		})
		kuiPlateFrame.health.overlayMask:SetBackdropBorderColor(0, 0, 0, 1) -- Black masking border
	end

	-- 3. POSITIONING LOGIC
	kuiPlateFrame.health:ClearAllPoints()
	kuiPlateFrame.health:SetWidth(UPConstants.nameplateHealthBarWidth)
	kuiPlateFrame.health:SetHeight(UPConstants.nameplateHealthBarHeight)
	kuiPlateFrame.health:SetPoint("BOTTOMLEFT", kuiPlateFrame.x, kuiPlateFrame.y)

	-- Lock the background and foreground rounded layers tight to the bar dimensions plus padding
	local padding = 2.5
	kuiPlateFrame.health.bgOffsetFrame:ClearAllPoints()
	kuiPlateFrame.health.bgOffsetFrame:SetPoint("TOPLEFT", kuiPlateFrame.health, "TOPLEFT", -padding, padding)
	kuiPlateFrame.health.bgOffsetFrame:SetPoint("BOTTOMRIGHT", kuiPlateFrame.health, "BOTTOMRIGHT", padding, -padding)

	kuiPlateFrame.health.overlayMask:ClearAllPoints()
	kuiPlateFrame.health.overlayMask:SetPoint("TOPLEFT", kuiPlateFrame.health, "TOPLEFT", -padding, padding)
	kuiPlateFrame.health.overlayMask:SetPoint("BOTTOMRIGHT", kuiPlateFrame.health, "BOTTOMRIGHT", padding, -padding)
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	-- 1. Create a dedicated High-Strata Frame to host all texts
	if not kuiPlateFrame.textLayerHost then
		kuiPlateFrame.textLayerHost = CreateFrame("Frame", nil, kuiPlateFrame)
		-- Force this frame off the nameplate strata layer entirely
		--kuiPlateFrame.textLayerHost:SetFrameStrata("LOW") 
	end
	-- Update the host frame level dynamically relative to your health bar
	local currentHealthLevel = kuiPlateFrame.health:GetFrameLevel()
	kuiPlateFrame.textLayerHost:SetFrameLevel(currentHealthLevel + 5)
	
	
	
	-- self:CreateHealthText(originalPlateFrame, kuiPlateFrame)
	-- kuiPlateFrame.health.p = kuiPlateFrame:CreateFontString(kuiPlateFrame.overlay, {
		-- font = self.font,
		-- size = "health",
		-- alpha = 1,
		-- outline = "OUTLINE"
	-- })
	-- kuiPlateFrame.health.p:SetHeight(10)
	-- kuiPlateFrame.health.p:SetJustifyH("RIGHT")
	-- kuiPlateFrame.health.p:SetJustifyV("MIDDLE")
	-- kuiPlateFrame.health.p.osize = "health" -- original font size used to update/restore
	--nameplate.health.text:SetAllPoints()
	
	kuiPlateFrame.health.p = kuiPlateFrame.textLayerHost:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	kuiPlateFrame.health.p:SetFont(mainFontPath, UPConstants.healthBigFontSize, "OUTLINE")
	kuiPlateFrame.health.p:SetJustifyH("RIGHT")
	kuiPlateFrame.health.p:SetTextColor(1,1,1,1)
	kuiPlateFrame.health.p:ClearAllPoints()
	kuiPlateFrame.health.p:SetPoint("BOTTOMRIGHT", kuiPlateFrame.health, "BOTTOMRIGHT", -1 * UPConstants.minimalOnePixel, -(UPConstants.healthBigFontSize * 0.4))
	kuiPlateFrame.health.p:Show()
	
	kuiPlateFrame.health.percentage = kuiPlateFrame.health:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	kuiPlateFrame.health.percentage:SetFont(mainFontPath, UPConstants.healthPercentageFontSize)
	kuiPlateFrame.health.percentage:SetJustifyH("CENTER")
	kuiPlateFrame.health.percentage:SetPoint("CENTER", kuiPlateFrame.health, "CENTER", 0, 0)
	kuiPlateFrame.health.percentage:SetTextColor(1,1,1,1)
	kuiPlateFrame.health.percentage:SetText("69%")

	-- overlay - originalPlateFrame level above health bar, used for text -------------------
	kuiPlateFrame.overlay = CreateFrame("Frame", nil, kuiPlateFrame)
	kuiPlateFrame.overlay:SetAllPoints(kuiPlateFrame.health)
	kuiPlateFrame.overlay:SetFrameLevel(2)
	
	-- originalPlateFrame.selectionGlow = originalPlateFrame:CreateTexture(nil, "BACKGROUND")
	-- originalPlateFrame.selectionGlow:SetPoint("CENTER", kuiPlateFrame.health, "CENTER", 0, 0)
	-- originalPlateFrame.selectionGlow:SetTexture("Interface\\AddOns\\UnitPlates\\img\\dot")
	-- originalPlateFrame.selectionGlow:SetDrawLayer("BACKGROUND")
	-- originalPlateFrame.selectionGlow:SetVertexColor(unpack(backgroundGlowColor))
	-- originalPlateFrame.selectionGlow:SetAlpha(UPConstants.selectionGlowAlpha)
	-- originalPlateFrame.selectionGlow:SetWidth((UPConstants.nameplateHealthBarWidth + 60))
	-- originalPlateFrame.selectionGlow:SetHeight((UPConstants.nameplateHealthBarHeight + 60))
	-- originalPlateFrame.selectionGlow:Hide()
	
	-- originalPlateFrame.selectionGlow2 = originalPlateFrame:CreateTexture(nil, "BACKGROUND")
	-- originalPlateFrame.selectionGlow2:SetPoint("CENTER", kuiPlateFrame.health, "CENTER", 0, 0)
	-- originalPlateFrame.selectionGlow2:SetTexture("Interface\\AddOns\\UnitPlates\\img\\dot")
	-- originalPlateFrame.selectionGlow2:SetDrawLayer("BACKGROUND")
	-- originalPlateFrame.selectionGlow2:SetVertexColor(unpack(backgroundGlowColor))
	-- originalPlateFrame.selectionGlow2:SetAlpha(UPConstants.selectionGlowAlpha)
	-- originalPlateFrame.selectionGlow2:SetWidth((UPConstants.nameplateHealthBarWidth + 60))
	-- originalPlateFrame.selectionGlow2:SetHeight((UPConstants.nameplateHealthBarHeight + 60))
	-- originalPlateFrame.selectionGlow2:Hide()

	-- self:CreateHighlight(originalPlateFrame, kuiPlateFrame)
	-- kuiPlateFrame.highlight = kuiPlateFrame.overlay:CreateTexture(nil, "ARTWORK")
	-- kuiPlateFrame.highlight:SetTexture(addon.bartexture)
	-- kuiPlateFrame.highlight:SetAllPoints(kuiPlateFrame.health)
	-- kuiPlateFrame.highlight:SetVertexColor(1, 1, 1)
	-- kuiPlateFrame.highlight:SetBlendMode("ADD")
	-- kuiPlateFrame.highlight:SetAlpha(.05)
	-- kuiPlateFrame.highlight:Hide()
	
	-- kuiPlateFrame.typeIcon = CreateFrame("Frame", nil, kuiPlateFrame)
	-- kuiPlateFrame.typeIcon:SetFrameLevel(1)
	-- kuiPlateFrame.typeIcon:SetPoint("RIGHT", kuiPlateFrame.health, "LEFT", -1 * UPConstants.minimalOnePixel, 0)
	-- kuiPlateFrame.typeIcon:SetHeight(UPConstants.nameplateTypeIconSize)
	-- kuiPlateFrame.typeIcon:SetWidth(UPConstants.nameplateTypeIconSize)
	-- kuiPlateFrame.typeIcon.icon = kuiPlateFrame.typeIcon:CreateTexture(nil, "OVERLAY")
	-- kuiPlateFrame.typeIcon.icon:SetAllPoints()
	-- --kuiPlateFrame.typeIcon.icon:SetTexture("Interface\\AddOns\\UnitPlates\\img\\creaturetypes\\UNKNOWN.tga")
	-- kuiPlateFrame.typeIcon.icon:SetTexture("Interface\\AddOns\\UnitPlates\\img\\loading.tga")
	-- --CreateBackdrop(nameplate.typeIcon, 1)
	-- kuiPlateFrame.typeIcon:SetBackdrop({
		-- bgFile = "Interface\\AddOns\\UnitPlates\\img\\WHITE", -- A solid texture
		-- edgeFile = "Interface\\AddOns\\UnitPlates\\img\\WHITE", 
		-- edgeSize = 1, 
		-- insets = { left = -UPConstants.minimalOnePixel, right = -UPConstants.minimalOnePixel, top = -UPConstants.minimalOnePixel, bottom = -UPConstants.minimalOnePixel }
	-- })
	-- kuiPlateFrame.typeIcon:SetBackdropColor(0, 0, 0, 1) -- Black Background
	-- kuiPlateFrame.typeIcon:SetBackdropBorderColor(0, 0, 0, 1) -- Black Border
	-- kuiPlateFrame.typeIcon:Show()
	
	kuiPlateFrame.typeIcon = CreateFrame("Frame", nil, kuiPlateFrame)
	kuiPlateFrame.typeIcon:SetFrameLevel(2) -- Bumped to match health bar level logic
	kuiPlateFrame.typeIcon:SetPoint("RIGHT", kuiPlateFrame.health, "LEFT", -1 * UPConstants.minimalOnePixel, 0)
	kuiPlateFrame.typeIcon:SetHeight(UPConstants.nameplateTypeIconSize)
	kuiPlateFrame.typeIcon:SetWidth(UPConstants.nameplateTypeIconSize)
	
	kuiPlateFrame.typeIcon.icon = kuiPlateFrame.typeIcon:CreateTexture(nil, "ARTWORK") -- Changed to ARTWORK layer to stay under mask
	kuiPlateFrame.typeIcon.icon:SetAllPoints()
	kuiPlateFrame.typeIcon.icon:SetTexture("Interface\\AddOns\\UnitPlates\\img\\loading.tga")

	-- 1. CLEAN BACKDROP HANDLING: Create a distinct frame *behind* the type icon
	if not kuiPlateFrame.typeIcon.bgOffsetFrame then
		kuiPlateFrame.typeIcon.bgOffsetFrame = CreateFrame("Frame", nil, kuiPlateFrame)
		kuiPlateFrame.typeIcon.bgOffsetFrame:SetFrameLevel(1) -- Below icon frame
		kuiPlateFrame.typeIcon.bgOffsetFrame:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8", 
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", -- Built-in rounded edge
			tile = false, tileSize = 0, edgeSize = 10,
			insets = { left = 2, right = 2, top = 2, bottom = 2 }
		})
		kuiPlateFrame.typeIcon.bgOffsetFrame:SetBackdropColor(0, 0, 0, 0.8) 
		kuiPlateFrame.typeIcon.bgOffsetFrame:SetBackdropBorderColor(0.1, 0.1, 0.1, 1) 
	end

	-- 2. THE CORNER MASKING OVERLAY: Create a frame *above* the type icon
	if not kuiPlateFrame.typeIcon.overlayMask then
		kuiPlateFrame.typeIcon.overlayMask = CreateFrame("Frame", nil, kuiPlateFrame)
		kuiPlateFrame.typeIcon.overlayMask:SetFrameLevel(3) -- Directly above the icon texture
		kuiPlateFrame.typeIcon.overlayMask:SetBackdrop({
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", -- Slices off the 4 square corners
			tile = false, tileSize = 0, edgeSize = 10,
			insets = { left = 2, right = 2, top = 2, bottom = 2 }
		})
		kuiPlateFrame.typeIcon.overlayMask:SetBackdropBorderColor(0, 0, 0, 1) -- Black masking border
	end

	-- Lock the background and foreground rounded layers tight to the icon dimensions plus padding
	local padding = 2.5
	kuiPlateFrame.typeIcon.bgOffsetFrame:ClearAllPoints()
	kuiPlateFrame.typeIcon.bgOffsetFrame:SetPoint("TOPLEFT", kuiPlateFrame.typeIcon, "TOPLEFT", -padding, padding)
	kuiPlateFrame.typeIcon.bgOffsetFrame:SetPoint("BOTTOMRIGHT", kuiPlateFrame.typeIcon, "BOTTOMRIGHT", padding, -padding)

	kuiPlateFrame.typeIcon.overlayMask:ClearAllPoints()
	kuiPlateFrame.typeIcon.overlayMask:SetPoint("TOPLEFT", kuiPlateFrame.typeIcon, "TOPLEFT", -padding, padding)
	kuiPlateFrame.typeIcon.overlayMask:SetPoint("BOTTOMRIGHT", kuiPlateFrame.typeIcon, "BOTTOMRIGHT", padding, -padding)

	kuiPlateFrame.typeIcon:Show()
	
	
	
	
	
	-- kuiPlateFrame.levelFrame = CreateFrame("Frame", nil, kuiPlateFrame)
	-- kuiPlateFrame.levelFrame:SetFrameLevel(2) -- Bumped to match health bar level logic
	-- -- kuiPlateFrame.levelFrame:SetPoint("TOPRIGHT", kuiPlateFrame.typeIcon, "TOPLEFT", 0, 0)
	-- kuiPlateFrame.levelFrame:SetPoint("BOTTOMLEFT", kuiPlateFrame.health, "BOTTOMLEFT", 2 * UPConstants.minimalOnePixel, -(UPConstants.levelFontSize * 0.4))
	-- kuiPlateFrame.levelFrame:SetHeight(UPConstants.nameplateTypeIconSize/1)
	-- kuiPlateFrame.levelFrame:SetWidth(UPConstants.nameplateTypeIconSize)
	
	-- -- kuiPlateFrame.typeIcon.icon = kuiPlateFrame.typeIcon:CreateTexture(nil, "ARTWORK") -- Changed to ARTWORK layer to stay under mask
	-- -- kuiPlateFrame.typeIcon.icon:SetAllPoints()
	-- -- kuiPlateFrame.typeIcon.icon:SetTexture("Interface\\AddOns\\UnitPlates\\img\\loading.tga")

	-- -- 1. CLEAN BACKDROP HANDLING: Create a distinct frame *behind* the type icon
	-- if not kuiPlateFrame.levelFrame.bgOffsetFrame then
		-- kuiPlateFrame.levelFrame.bgOffsetFrame = CreateFrame("Frame", nil, kuiPlateFrame)
		-- kuiPlateFrame.levelFrame.bgOffsetFrame:SetFrameLevel(1) -- Below icon frame
		-- kuiPlateFrame.levelFrame.bgOffsetFrame:SetBackdrop({
			-- bgFile = "Interface\\Buttons\\WHITE8X8", 
			-- edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", -- Built-in rounded edge
			-- tile = false, tileSize = 0, edgeSize = 10,
			-- insets = { left = 2, right = 2, top = 2, bottom = 2 }
		-- })
		-- kuiPlateFrame.levelFrame.bgOffsetFrame:SetBackdropColor(0.1, 0.1, 0.1, 1) 
		-- kuiPlateFrame.levelFrame.bgOffsetFrame:SetBackdropBorderColor(0.1, 0.1, 0.1, 1) 
	-- end

	-- -- 2. THE CORNER MASKING OVERLAY: Create a frame *above* the type icon
	-- if not kuiPlateFrame.levelFrame.overlayMask then
		-- kuiPlateFrame.levelFrame.overlayMask = CreateFrame("Frame", nil, kuiPlateFrame)
		-- kuiPlateFrame.levelFrame.overlayMask:SetFrameLevel(3) -- Directly above the icon texture
		-- kuiPlateFrame.levelFrame.overlayMask:SetBackdrop({
			-- edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", -- Slices off the 4 square corners
			-- tile = false, tileSize = 0, edgeSize = 10,
			-- insets = { left = 2, right = 2, top = 2, bottom = 2 }
		-- })
		-- kuiPlateFrame.levelFrame.overlayMask:SetBackdropBorderColor(0, 0, 0, 1) -- Black masking border
	-- end

	-- -- Lock the background and foreground rounded layers tight to the icon dimensions plus padding
	-- local padding = 2.5
	-- kuiPlateFrame.levelFrame.bgOffsetFrame:ClearAllPoints()
	-- kuiPlateFrame.levelFrame.bgOffsetFrame:SetPoint("TOPLEFT", kuiPlateFrame.levelFrame, "TOPLEFT", -padding, padding)
	-- kuiPlateFrame.levelFrame.bgOffsetFrame:SetPoint("BOTTOMRIGHT", kuiPlateFrame.levelFrame, "BOTTOMRIGHT", padding, -padding)

	-- kuiPlateFrame.levelFrame.overlayMask:ClearAllPoints()
	-- kuiPlateFrame.levelFrame.overlayMask:SetPoint("TOPLEFT", kuiPlateFrame.levelFrame, "TOPLEFT", -padding, padding)
	-- kuiPlateFrame.levelFrame.overlayMask:SetPoint("BOTTOMRIGHT", kuiPlateFrame.levelFrame, "BOTTOMRIGHT", padding, -padding)

	-- kuiPlateFrame.levelFrame:Show()
	
	
	
	
	-- kuiPlateFrame.threat = CreateFrame("Frame", nil, kuiPlateFrame)
	-- kuiPlateFrame.threat:SetFrameLevel(1)
	-- kuiPlateFrame.threat:SetPoint("TOP", kuiPlateFrame.typeIcon, "BOTTOM", 0, -1 * UPConstants.minimalOnePixel)
	-- kuiPlateFrame.threat:SetHeight(UPConstants.threatFrameSize)
	-- kuiPlateFrame.threat:SetWidth(UPConstants.threatFrameSize)
	
	kuiPlateFrame.threat = kuiPlateFrame.textLayerHost:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	kuiPlateFrame.threat:SetFont(mainFontPath, UPConstants.threatFontSize, "OUTLINE")
	kuiPlateFrame.threat:SetJustifyH("RIGHT")
	kuiPlateFrame.threat:SetTextColor(1,1,1,1)
	kuiPlateFrame.threat:ClearAllPoints()
	kuiPlateFrame.threat:SetPoint("TOPRIGHT", kuiPlateFrame.typeIcon, "BOTTOMRIGHT", 0, -1 * UPConstants.minimalOnePixel)
	kuiPlateFrame.threat:SetText("100%")
	kuiPlateFrame.threat:Hide()

	-- self:CreateLevel(originalPlateFrame, kuiPlateFrame)
	-- kuiPlateFrame.level = kuiPlateFrame:CreateFontString(kuiPlateFrame.level, {
		-- reset = true,
		-- font = self.font,
		-- size = "level",
		-- alpha = 1,
		-- outline = "OUTLINE"
	-- })
	-- kuiPlateFrame.level:SetParent(kuiPlateFrame.overlay)
	-- kuiPlateFrame.level:SetJustifyH("LEFT")
	-- kuiPlateFrame.level:SetJustifyV("MIDDLE")
	-- kuiPlateFrame.level:SetHeight(10)
	-- kuiPlateFrame.level:ClearAllPoints()
	-- kuiPlateFrame.level.osize = "level" -- original font size used to update/restore
	
	-- kuiPlateFrame.level:ClearAllPoints()
	kuiPlateFrame.level = kuiPlateFrame.textLayerHost:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	kuiPlateFrame.level:SetFont(mainFontPath, UPConstants.levelFontSize, "OUTLINE")
	--kuiPlateFrame.level:SetParent(kuiPlateFrame.health.overlayMask)
	kuiPlateFrame.level:SetJustifyH("CENTER")
	-- kuiPlateFrame.level:SetPoint("RIGHT", kuiPlateFrame.typeIcon, "RIGHT", -2, -4)
	kuiPlateFrame.level:ClearAllPoints()
	kuiPlateFrame.level:SetPoint("BOTTOMLEFT", kuiPlateFrame.health, "BOTTOMLEFT", 2 * UPConstants.minimalOnePixel, -(UPConstants.levelFontSize * 0.4))
	-- kuiPlateFrame.level:SetPoint("CENTER", kuiPlateFrame.levelFrame, "CENTER", 0, 0)
	-- kuiPlateFrame.oldLevel.enabled = true
	-- kuiPlateFrame.oldLevel:Hide()
	
	
	-- kuiPlateFrame.guild = kuiPlateFrame:CreateFontString(kuiPlateFrame.overlay, {
		-- font = self.font,
		-- size = "name",
		-- outline = "OUTLINE"
	-- })
	-- kuiPlateFrame.guild.osize = "name" -- original font size used to update/restore
	-- kuiPlateFrame.guild:SetHeight(10)
	kuiPlateFrame.guild = kuiPlateFrame.textLayerHost:CreateFontString(nil, "OVERLAY")
	kuiPlateFrame.guild:SetFont(mainFontPath, UPConstants.nameFontSize, "OUTLINE")
	kuiPlateFrame.guild:ClearAllPoints()
	kuiPlateFrame.guild:SetWidth(0)
	kuiPlateFrame.guild:SetPoint("BOTTOM", kuiPlateFrame.health, "TOP", 0, 2 * UPConstants.minimalOnePixel)
	
	-- kuiPlateFrame.name = kuiPlateFrame:CreateFontString(kuiPlateFrame.overlay, {
		-- font = self.font,
		-- size = "name",
		-- outline = "OUTLINE"
	-- })
	-- kuiPlateFrame.name.osize = "name" -- original font size used to update/restore
	
	kuiPlateFrame.name = kuiPlateFrame.textLayerHost:CreateFontString(nil, "OVERLAY")
	kuiPlateFrame.name:SetFont(mainFontPath, UPConstants.nameFontSize, "OUTLINE")
	--kuiPlateFrame.name:SetHeight(10)
	kuiPlateFrame.name:ClearAllPoints()
	kuiPlateFrame.name:SetWidth(0)
	if (kuiPlateFrame.guild:GetText() == nil or kuiPlateFrame.guild:GetText() == '') then
		kuiPlateFrame.name:SetPoint("BOTTOM", kuiPlateFrame.health, "TOP", 0, 2 * UPConstants.minimalOnePixel)
	else
		kuiPlateFrame.name:SetPoint("BOTTOM", kuiPlateFrame.guild, "TOP", 0, 2 * UPConstants.minimalOnePixel)
	end
	
	kuiPlateFrame.questIcon = CreateFrame("Frame", nil, kuiPlateFrame)
	kuiPlateFrame.questIcon:SetFrameLevel(0)
	kuiPlateFrame.questIcon:SetPoint("RIGHT", kuiPlateFrame.name, "LEFT", -0, -0)
	kuiPlateFrame.questIcon:SetHeight(UPConstants.questIconSize)
	kuiPlateFrame.questIcon:SetWidth(UPConstants.questIconSize)
	kuiPlateFrame.questIcon.icon = kuiPlateFrame.questIcon:CreateTexture(nil, "OVERLAY")
	kuiPlateFrame.questIcon.icon:SetAllPoints()
	kuiPlateFrame.questIcon.icon:SetTexture("Interface\\AddOns\\UnitPlates\\img\\combat\\swords_combat_2")
	kuiPlateFrame.questIcon:Hide()	
	
	kuiPlateFrame.petHappiness = CreateFrame("Frame", nil, kuiPlateFrame)
	kuiPlateFrame.petHappiness:SetFrameLevel(0)
	kuiPlateFrame.petHappiness:SetPoint("LEFT", kuiPlateFrame.name, "RIGHT", -0, 0)
	kuiPlateFrame.petHappiness:SetHeight(UPConstants.petHappinessIconSize)
	kuiPlateFrame.petHappiness:SetWidth(UPConstants.petHappinessIconSize)
	kuiPlateFrame.petHappiness.icon = kuiPlateFrame.petHappiness:CreateTexture(nil, "OVERLAY")
	--kuiPlateFrame.rarityIconR.icon:SetTexCoord(1, 0, 0, 1)
	--kuiPlateFrame.combatIcon.icon:SetVertexColor(1, 1, 0, 1)
	kuiPlateFrame.petHappiness.icon:SetAllPoints()
	kuiPlateFrame.petHappiness.icon:SetTexture("Interface\\PetPaperDollFrame\\UI-PetHappiness")
	kuiPlateFrame.petHappiness:Hide()
	
	kuiPlateFrame.combatIcon = CreateFrame("Frame", nil, kuiPlateFrame)
	kuiPlateFrame.combatIcon:SetFrameLevel(0)
	kuiPlateFrame.combatIcon:SetPoint("LEFT", kuiPlateFrame.name, "RIGHT", -0, -0)
	kuiPlateFrame.combatIcon:SetHeight(UPConstants.combatIconSize)
	kuiPlateFrame.combatIcon:SetWidth(UPConstants.combatIconSize)
	kuiPlateFrame.combatIcon.icon = kuiPlateFrame.combatIcon:CreateTexture(nil, "OVERLAY")
	kuiPlateFrame.combatIcon.icon:SetAllPoints()
	-- kuiPlateFrame.combatIcon.icon:SetTexture("Interface\\AddOns\\UnitPlates\\img\\combat\\swords_combat_2")
	kuiPlateFrame.combatIcon.icon:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
	kuiPlateFrame.combatIcon.icon:SetTexCoord(0.5, 1.0, 0.0, 0.5)
	kuiPlateFrame.combatIcon:Hide()	
	
	kuiPlateFrame.shootingIcon = CreateFrame("Frame", nil, kuiPlateFrame)
	kuiPlateFrame.shootingIcon:SetFrameLevel(3)
	kuiPlateFrame.shootingIcon:SetPoint("LEFT", kuiPlateFrame.health.p, "RIGHT", -0, -0)
	--kuiPlateFrame.shootingIcon:SetPoint("LEFT", kuiPlateFrame.health, "RIGHT", -0, -0)
	kuiPlateFrame.shootingIcon:SetHeight(UPConstants.shootingIconSize)
	kuiPlateFrame.shootingIcon:SetWidth(UPConstants.shootingIconSize)
	kuiPlateFrame.shootingIcon.icon = kuiPlateFrame.shootingIcon:CreateTexture(nil, "ARTWORK")
	kuiPlateFrame.shootingIcon.icon:SetAllPoints()
	kuiPlateFrame.shootingIcon.icon:SetTexture("Interface\\AddOns\\UnitPlates\\img\\combat\\arrow_target_1_32")
	kuiPlateFrame.shootingIcon.icon:SetDrawLayer("ARTWORK", 2)
	kuiPlateFrame.shootingIcon:Hide()
	
	kuiPlateFrame.pvpIcon = CreateFrame("Frame", nil, kuiPlateFrame)
	kuiPlateFrame.pvpIcon:SetFrameLevel(3)
	kuiPlateFrame.pvpIcon:SetPoint("LEFT", kuiPlateFrame.name, "RIGHT", -UPConstants.pvpIconSize/15, -UPConstants.pvpIconSize/4.5)
	--kuiPlateFrame.shootingIcon:SetPoint("LEFT", kuiPlateFrame.health, "RIGHT", -0, -0)
	kuiPlateFrame.pvpIcon:SetHeight(UPConstants.pvpIconSize)
	kuiPlateFrame.pvpIcon:SetWidth(UPConstants.pvpIconSize)
	kuiPlateFrame.pvpIcon.icon = kuiPlateFrame.pvpIcon:CreateTexture(nil, "ARTWORK")
	kuiPlateFrame.pvpIcon.icon:SetAllPoints()
	kuiPlateFrame.pvpIcon.icon:SetTexture("Interface\\TargetingFrame\\UI-PVP-"..UnitFactionGroup("player"))
	kuiPlateFrame.pvpIcon.icon:SetDrawLayer("ARTWORK", 2)
	kuiPlateFrame.pvpIcon:Show()
	
	kuiPlateFrame.pvpRankIcon = CreateFrame("Frame", nil, kuiPlateFrame)
	kuiPlateFrame.pvpRankIcon:SetFrameLevel(3)
	kuiPlateFrame.pvpRankIcon:SetPoint("LEFT", kuiPlateFrame.pvpIcon, "RIGHT", -(0), (0))
	-- kuiPlateFrame.pvpRankIcon:SetPoint("LEFT", kuiPlateFrame.health, "RIGHT", -(UPConstants.nameplateTypeIconSize*0.75)/2, -(UPConstants.nameplateTypeIconSize*0.75)/2)
	--kuiPlateFrame.shootingIcon:SetPoint("LEFT", kuiPlateFrame.health, "RIGHT", -0, -0)
	kuiPlateFrame.pvpRankIcon:SetHeight(UPConstants.pvpRankIconSize)
	kuiPlateFrame.pvpRankIcon:SetWidth(UPConstants.pvpRankIconSize)
	--kuiPlateFrame.pvpRankIcon:SetAlpha(0.5)
	kuiPlateFrame.pvpRankIcon.icon = kuiPlateFrame.pvpRankIcon:CreateTexture(nil, "ARTWORK")
	kuiPlateFrame.pvpRankIcon.icon:SetAllPoints()
	kuiPlateFrame.pvpRankIcon.icon:SetTexture(string.format("Interface\\PVPRankBadges\\PVPRank%02d", 1))
	kuiPlateFrame.pvpRankIcon.icon:SetDrawLayer("ARTWORK", 2)
	kuiPlateFrame.pvpRankIcon:Show()
	
	kuiPlateFrame.power = CreateFrame("StatusBar", nil, kuiPlateFrame)
	kuiPlateFrame.power:SetFrameLevel(1) -- keep above glow
	kuiPlateFrame.power:SetOrientation("HORIZONTAL")
	kuiPlateFrame.power:SetPoint("TOP", kuiPlateFrame.health, "BOTTOM", 0, 0)
	kuiPlateFrame.power:SetStatusBarTexture("Interface\\AddOns\\UnitPlates\\img\\statusbar\\XPerl_StatusBar7")
	kuiPlateFrame.power.hlr, kuiPlateFrame.power.hlg, kuiPlateFrame.power.hlb, kuiPlateFrame.power.hla = glowr, glowg, glowb, 1
	kuiPlateFrame.power:SetWidth(UPConstants.nameplateHealthBarWidth)
	kuiPlateFrame.power:SetHeight(UPConstants.nameplatePowerBarHeight)
	kuiPlateFrame.power:SetBackdrop({
		bgFile = "Interface\\AddOns\\UnitPlates\\img\\WHITE", -- A solid texture
		edgeFile = "Interface\\AddOns\\UnitPlates\\img\\WHITE", 
		edgeSize = 1, 
		insets = { left = -UPConstants.minimalOnePixel, right = -UPConstants.minimalOnePixel, top = -UPConstants.minimalOnePixel, bottom = -UPConstants.minimalOnePixel }
	})
	kuiPlateFrame.power:SetBackdropColor(0, 0, 0, 1) -- Black Background
	kuiPlateFrame.power:SetBackdropBorderColor(0, 0, 0, 1) -- Black Border
	kuiPlateFrame.power:Hide()
	
	kuiPlateFrame.power.text = kuiPlateFrame.power:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	kuiPlateFrame.power.text:SetFont(mainFontPath, UPConstants.powerFontSize, "OUTLINE")
	kuiPlateFrame.power.text:SetJustifyH("RIGHT")
	kuiPlateFrame.power.text:SetPoint("BOTTOMRIGHT", kuiPlateFrame.power, "BOTTOMRIGHT", -1 * UPConstants.minimalOnePixel, -(UPConstants.powerFontSize * 0.6))
	kuiPlateFrame.power.text:SetText("69")
	kuiPlateFrame.power.text:SetTextColor(1,1,1,1)
	
	kuiPlateFrame.classIcon = CreateFrame("Frame", nil, kuiPlateFrame)
	kuiPlateFrame.classIcon:SetPoint("RIGHT", kuiPlateFrame.name, "LEFT", -2 * UPConstants.minimalOnePixel, 4 * UPConstants.minimalOnePixel)
	kuiPlateFrame.classIcon:SetHeight(UPConstants.nameplateClassIconSize)
	kuiPlateFrame.classIcon:SetWidth(UPConstants.nameplateClassIconSize)
	kuiPlateFrame.classIcon.icon = kuiPlateFrame.classIcon:CreateTexture(nil, "ARTWORK")
	kuiPlateFrame.classIcon.icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
	kuiPlateFrame.classIcon.icon:SetAllPoints()
	kuiPlateFrame.classIcon:Hide()
	
	kuiPlateFrame.rarityIcon = CreateFrame("Frame", nil, kuiPlateFrame)
	kuiPlateFrame.rarityIcon:SetFrameLevel(2)
	kuiPlateFrame.rarityIcon:SetPoint("RIGHT", kuiPlateFrame.typeIcon, "LEFT", UPConstants.nameplateRarityXOffset, -1 * UPConstants.minimalOnePixel)
	kuiPlateFrame.rarityIcon:SetHeight(UPConstants.nameplateRarityH)
	kuiPlateFrame.rarityIcon:SetWidth(UPConstants.nameplateRarityW)
	kuiPlateFrame.rarityIcon.icon = kuiPlateFrame.rarityIcon:CreateTexture(nil, "ARTWORK") --BORDER
	kuiPlateFrame.rarityIcon.icon:SetTexCoord(1, 0, 0, 1)
	kuiPlateFrame.rarityIcon.icon:SetVertexColor(1, 1, 0, 1)
	kuiPlateFrame.rarityIcon.icon:SetAllPoints()
	kuiPlateFrame.rarityIcon.icon:SetTexture("Interface\\AddOns\\UnitPlates\\img\\frame_elite")
	kuiPlateFrame.rarityIcon:Hide()

	kuiPlateFrame.rarityIconR = CreateFrame("Frame", nil, kuiPlateFrame)
	kuiPlateFrame.rarityIconR:SetFrameLevel(2)
	kuiPlateFrame.rarityIconR:SetPoint("LEFT", kuiPlateFrame.health, "RIGHT", -UPConstants.nameplateRarityXOffset, -1 * UPConstants.minimalOnePixel)
	kuiPlateFrame.rarityIconR:SetHeight(UPConstants.nameplateRarityH)
	kuiPlateFrame.rarityIconR:SetWidth(UPConstants.nameplateRarityW)
	kuiPlateFrame.rarityIconR.icon = kuiPlateFrame.rarityIconR:CreateTexture(nil, "ARTWORK") --BORDER
	--nameplate.rarityIconR.icon:SetTexCoord(1, 0, 0, 1)
	kuiPlateFrame.rarityIconR.icon:SetVertexColor(1, 1, 0, 1)
	kuiPlateFrame.rarityIconR.icon:SetAllPoints()
	kuiPlateFrame.rarityIconR.icon:SetTexture("Interface\\AddOns\\UnitPlates\\img\\frame_elite")
	kuiPlateFrame.rarityIconR:Hide()
	
	
	
	originalPlateFrame.selectionGlow = originalPlateFrame:CreateTexture(nil, "BACKGROUND")
	--originalPlateFrame.selectionGlow:SetFrameLevel(0)
	originalPlateFrame.selectionGlow:SetPoint("CENTER", kuiPlateFrame.health, "CENTER", 0, 0)
	originalPlateFrame.selectionGlow:SetTexture("Interface\\AddOns\\UnitPlates\\img\\dot")
	originalPlateFrame.selectionGlow:SetDrawLayer("BACKGROUND")
	originalPlateFrame.selectionGlow:SetVertexColor(unpack(backgroundGlowColor))
	originalPlateFrame.selectionGlow:SetAlpha(UPConstants.selectionGlowAlpha)
	originalPlateFrame.selectionGlow:SetWidth((UPConstants.nameplateHealthBarWidth + 60))
	originalPlateFrame.selectionGlow:SetHeight((UPConstants.nameplateHealthBarHeight + 60))
	originalPlateFrame.selectionGlow:Hide()
	
	originalPlateFrame.selectionGlow2 = originalPlateFrame:CreateTexture(nil, "BACKGROUND")
	--originalPlateFrame.selectionGlow2:SetFrameLevel(0)
	originalPlateFrame.selectionGlow2:SetPoint("CENTER", kuiPlateFrame.health, "CENTER", 0, 0)
	originalPlateFrame.selectionGlow2:SetTexture("Interface\\AddOns\\UnitPlates\\img\\dot")
	originalPlateFrame.selectionGlow2:SetDrawLayer("BACKGROUND")
	originalPlateFrame.selectionGlow2:SetVertexColor(unpack(backgroundGlowColor))
	originalPlateFrame.selectionGlow2:SetAlpha(UPConstants.selectionGlowAlpha)
	originalPlateFrame.selectionGlow2:SetWidth((UPConstants.nameplateHealthBarWidth + 60))
	originalPlateFrame.selectionGlow2:SetHeight((UPConstants.nameplateHealthBarHeight + 60))
	originalPlateFrame.selectionGlow2:Hide()

	-- castbar #################################################################
	-- if self.Castbar then
		-- self.Castbar:CreateCastbar(kuiPlateFrame)
	-- end
	-- self.Castbar:CreateCastbar(kuiPlateFrame)

	-- target highlight --------------------------------------------------------
	kuiPlateFrame.glow = CreateFrame("Frame", nil, kuiPlateFrame)
	kuiPlateFrame.glow:SetPoint("LEFT", kuiPlateFrame.typeIcon, "LEFT", -UPConstants.nameplateArrowSize, 0)
	kuiPlateFrame.glow:SetWidth(UPConstants.nameplateArrowSize)
	kuiPlateFrame.glow:SetHeight(UPConstants.nameplateArrowSize)
	kuiPlateFrame.glow.icon = kuiPlateFrame.glow:CreateTexture(nil, "ARTWORK") --BORDER
	kuiPlateFrame.glow.icon:SetVertexColor(unpack(glowColor))
	kuiPlateFrame.glow.icon:SetAllPoints()
	kuiPlateFrame.glow.icon:SetTexture("Interface\\AddOns\\UnitPlates\\img\\arrow_left")
	kuiPlateFrame.glow:Hide()

	kuiPlateFrame.glow2 = CreateFrame("Frame", nil, kuiPlateFrame)
	kuiPlateFrame.glow2:SetPoint("RIGHT", kuiPlateFrame.health, "RIGHT", UPConstants.nameplateArrowSize, 0)
	kuiPlateFrame.glow2:SetWidth(UPConstants.nameplateArrowSize)
	kuiPlateFrame.glow2:SetHeight(UPConstants.nameplateArrowSize)
	kuiPlateFrame.glow2.icon = kuiPlateFrame.glow2:CreateTexture(nil, "ARTWORK") --BORDER
	kuiPlateFrame.glow2.icon:SetVertexColor(unpack(glowColor))
	kuiPlateFrame.glow2.icon:SetAllPoints()
	kuiPlateFrame.glow2.icon:SetTexture("Interface\\AddOns\\UnitPlates\\img\\arrow_right")
	kuiPlateFrame.glow2:Hide()
	
	
	-- kuiPlateFrame.glow = kuiPlateFrame:CreateTexture(nil, "BACKGROUND")
	-- kuiPlateFrame.glow:SetPoint("LEFT", kuiPlateFrame.typeIcon, "LEFT", -UPConstants.nameplateArrowSize, 0)
	-- kuiPlateFrame.glow:SetTexture("Interface\\AddOns\\UnitPlates\\img\\arrow_left")
	-- --nameplate.glow:SetFrameLevel(1)
	-- kuiPlateFrame.glow:SetDrawLayer("BORDER")
	-- kuiPlateFrame.glow:SetWidth(UPConstants.nameplateArrowSize)
	-- kuiPlateFrame.glow:SetHeight(UPConstants.nameplateArrowSize)
	-- kuiPlateFrame.glow:SetVertexColor(unpack(glowColor))
	-- kuiPlateFrame.glow:Hide()

	-- kuiPlateFrame.glow2 = kuiPlateFrame:CreateTexture(nil, "BACKGROUND")
	-- kuiPlateFrame.glow2:SetPoint("RIGHT", kuiPlateFrame.health, "RIGHT", UPConstants.nameplateArrowSize, 0)
	-- kuiPlateFrame.glow2:SetTexture("Interface\\AddOns\\UnitPlates\\img\\arrow_right")
	-- --nameplate.glow:SetFrameLevel(1)
	-- kuiPlateFrame.glow2:SetDrawLayer("BORDER")
	-- --nameplate.glow2.texture:SetRotation(2)
	-- kuiPlateFrame.glow2:SetWidth(UPConstants.nameplateArrowSize)
	-- kuiPlateFrame.glow2:SetHeight(UPConstants.nameplateArrowSize)
	-- kuiPlateFrame.glow2:SetVertexColor(unpack(glowColor))
	-- kuiPlateFrame.glow2:Hide()
	
	
	--
	-- kuiPlateFrame.visglow = kuiPlateFrame:CreateTexture(nil, "BACKGROUND")
	-- kuiPlateFrame.visglow:SetPoint("LEFT", kuiPlateFrame.typeIcon, "LEFT", -UPConstants.nameplateArrowSize * 0.7, 0)
	-- kuiPlateFrame.visglow:SetTexture("Interface\\AddOns\\UnitPlates\\img\\arrow_double_left_64")
	-- --nameplate.glow:SetFrameLevel(1)
	-- kuiPlateFrame.visglow:SetDrawLayer("BACKGROUND")
	-- kuiPlateFrame.visglow:SetWidth(UPConstants.nameplateArrowSize*3)
	-- kuiPlateFrame.visglow:SetHeight(UPConstants.nameplateArrowSize*3)
	-- kuiPlateFrame.visglow:SetVertexColor(unpack({.9, 0.1, 0.1, 1}))
	-- kuiPlateFrame.visglow:Hide()

	-- kuiPlateFrame.visglow2 = kuiPlateFrame:CreateTexture(nil, "BACKGROUND")
	-- kuiPlateFrame.visglow2:SetPoint("RIGHT", kuiPlateFrame.health, "RIGHT", UPConstants.nameplateArrowSize * 0.7, 0)
	-- kuiPlateFrame.visglow2:SetTexture("Interface\\AddOns\\UnitPlates\\img\\arrow_double_right_64")
	-- kuiPlateFrame.visglow2:SetDrawLayer("BACKGROUND")
	-- kuiPlateFrame.visglow2:SetWidth(UPConstants.nameplateArrowSize*3)
	-- kuiPlateFrame.visglow2:SetHeight(UPConstants.nameplateArrowSize*3)
	-- kuiPlateFrame.visglow2:SetVertexColor(unpack({.9, 0.1, 0.1, 1}))
	-- kuiPlateFrame.visglow2:Hide()
	
	-- kuiPlateFrame.targetGlow = kuiPlateFrame.overlay:CreateTexture(nil, "ARTWORK")
	-- kuiPlateFrame.targetGlow:SetTexture("Interface\\AddOns\\UnitPlates\\Media\\target-glow")
	-- kuiPlateFrame.targetGlow:SetTexCoord(0, .593, 0, .875)
	-- kuiPlateFrame.targetGlow:SetPoint("CENTER", kuiPlateFrame.health, "CENTER", 0, -10)
	-- kuiPlateFrame.targetGlow:SetVertexColor(unpack(self.db.profile.general.targetglowcolour))
	-- kuiPlateFrame.targetGlow:Hide()
	-- kuiPlateFrame.targetGlow:SetSize(UPConstants.nameplateHealthBarWidth, UPConstants.nameplateHealthBarHeight*4)

	-- raid icon ---------------------------------------------------------------
	-- kuiPlateFrame.icon:SetParent(kuiPlateFrame.overlay)
	-- kuiPlateFrame.icon:SetWidth(UPConstants.raidIconSize)
	-- kuiPlateFrame.icon:SetHeight(UPConstants.raidIconSize)
	-- kuiPlateFrame.icon:ClearAllPoints()
	-- kuiPlateFrame.icon:SetPoint("TOP", kuiPlateFrame.overlay, "BOTTOM", 0, -8 * UPConstants.minimalOnePixel)
	
	----------------------------------------------------------------------------
	
	kuiPlateFrame.castWarning = CreateFrame("Frame", nil, kuiPlateFrame)
	kuiPlateFrame.castWarning:SetFrameLevel(0)
	kuiPlateFrame.castWarning:SetPoint("TOP", kuiPlateFrame.power, "BOTTOM", 0, -5 * UPConstants.minimalOnePixel)
	kuiPlateFrame.castWarning:SetWidth(1)
	kuiPlateFrame.castWarning:SetHeight(1)
	kuiPlateFrame.castWarning:Hide()
	
	kuiPlateFrame.castWarning.bar = CreateFrame("StatusBar", nil, kuiPlateFrame.castWarning)
	kuiPlateFrame.castWarning.bar:SetStatusBarTexture("Interface\\AddOns\\UnitPlates\\img\\statusbar\\XPerl_StatusBar7")
	kuiPlateFrame.castWarning.bar:GetStatusBarTexture():SetDrawLayer("ARTWORK", 2)
	kuiPlateFrame.castWarning.bar:SetStatusBarColor(unpack(castBarColor))
	kuiPlateFrame.castWarning.bar:SetHeight(4)
	kuiPlateFrame.castWarning.bar:SetWidth(UPConstants.nameplateHealthBarWidth)
	kuiPlateFrame.castWarning.bar:SetPoint("TOP", kuiPlateFrame.castWarning, "TOP", 0, 0)
	kuiPlateFrame.castWarning.bar:SetMinMaxValues(0, 1)
	
	kuiPlateFrame.castWarning.bar:SetBackdrop({
		bgFile = "Interface\\AddOns\\UnitPlates\\img\\WHITE", -- A solid texture
		edgeFile = "Interface\\AddOns\\UnitPlates\\img\\WHITE", 
		edgeSize = 1, 
		insets = { left = -UPConstants.minimalOnePixel, right = -UPConstants.minimalOnePixel, top = -UPConstants.minimalOnePixel, bottom = -UPConstants.minimalOnePixel }
	})
	kuiPlateFrame.castWarning.bar:SetBackdropColor(0, 0, 0, 1) -- Black Background
	kuiPlateFrame.castWarning.bar:SetBackdropBorderColor(0, 0, 0, 1) -- Black Border
	
	-- uninterruptible cast shield -----------------------------------------
	kuiPlateFrame.castWarning.shield = kuiPlateFrame.castWarning.bar:CreateTexture(nil, "ARTWORK")
	kuiPlateFrame.castWarning.shield:SetTexture("Interface\\AddOns\\UnitPlates\\Media\\Shield")
	kuiPlateFrame.castWarning.shield:SetTexCoord(0, 0.84375, 0, 1)
	kuiPlateFrame.castWarning.shield:SetVertexColor(0.5, 0.5, 0.7)

	kuiPlateFrame.castWarning.shield:SetWidth(UPConstants.castBarSizes.shield * .84375)
	kuiPlateFrame.castWarning.shield:SetHeight(UPConstants.castBarSizes.shield)
	kuiPlateFrame.castWarning.shield:SetPoint("LEFT", kuiPlateFrame.castWarning.bar, -7 * UPConstants.minimalOnePixel, 0)

	kuiPlateFrame.castWarning.shield:SetBlendMode("BLEND")
	kuiPlateFrame.castWarning.shield:SetDrawLayer("ARTWORK", 7)
	
	--
	-- kuiPlateFrame.castWarning.spark = kuiPlateFrame.castWarning.bar:CreateTexture(nil, "ARTWORK")
	-- kuiPlateFrame.castWarning.spark:SetDrawLayer("ARTWORK", 6)
	-- kuiPlateFrame.castWarning.spark:SetVertexColor(1, 1, 0.8)
	-- kuiPlateFrame.castWarning.spark:SetTexture("Interface\\AddOns\\UnitPlates\\Media\\t\\spark")
	-- kuiPlateFrame.castWarning.spark:SetPoint("TOP", kuiPlateFrame.castWarning.bar:GetRegions(), "TOPRIGHT", 0, 3 * UPConstants.minimalOnePixel)
	-- kuiPlateFrame.castWarning.spark:SetPoint("BOTTOM", kuiPlateFrame.castWarning.bar:GetRegions(), "BOTTOMRIGHT", 0, -3 * UPConstants.minimalOnePixel)
	-- kuiPlateFrame.castWarning.spark:SetWidth(6)
	
	kuiPlateFrame.castWarning.spark = kuiPlateFrame.castWarning.bar:CreateTexture(nil, "OVERLAY") -- Use OVERLAY to be on top
	kuiPlateFrame.castWarning.spark:SetDrawLayer("ARTWORK", 6)
	kuiPlateFrame.castWarning.spark:SetVertexColor(1, 1, 0.8)
	kuiPlateFrame.castWarning.spark:SetTexture("Interface\\AddOns\\UnitPlates\\Media\\t\\spark")
	kuiPlateFrame.castWarning.spark:SetHeight(kuiPlateFrame.castWarning.bar:GetHeight() + 6) -- Make it slightly taller than the bar
	kuiPlateFrame.castWarning.spark:SetBlendMode("ADD") -- Makes it look like a "glow"
	kuiPlateFrame.castWarning.spark:SetPoint("CENTER", kuiPlateFrame.castWarning.bar, "LEFT", 0, 0)
	kuiPlateFrame.castWarning.spark:SetWidth(6)
	
	kuiPlateFrame.castWarning.curr = kuiPlateFrame.castWarning.bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	kuiPlateFrame.castWarning.curr:SetFont(mainFontPath, UPConstants.castWarningDurationFontSize, "OUTLINE")
	--kuiPlateFrame.castWarning.curr:SetPoint("LEFT", kuiPlateFrame.castWarning.bar, "RIGHT", 2, 0)
	kuiPlateFrame.castWarning.curr:SetPoint("BOTTOMRIGHT", kuiPlateFrame.castWarning.bar, "BOTTOMRIGHT", -1 * UPConstants.minimalOnePixel, -(UPConstants.castWarningDurationFontSize * 0.65))
	kuiPlateFrame.castWarning.curr:SetText("0")
	
	kuiPlateFrame.castWarning.text = kuiPlateFrame.castWarning:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	kuiPlateFrame.castWarning.text:SetFont(mainFontPath, UPConstants.castWarningNameFontSize, "OUTLINE")
	kuiPlateFrame.castWarning.text:SetPoint("TOP", kuiPlateFrame.castWarning.bar, "BOTTOM", 0, -5)
	-- kuiPlateFrame.castWarning.text:SetText("69")
	-- kuiPlateFrame.castWarning.text:SetTextColor(1,1,1,1)
	
	kuiPlateFrame.castWarning.icon = CreateFrame("Frame", nil, kuiPlateFrame.castWarning)
	kuiPlateFrame.castWarning.icon:SetFrameLevel(0)
	kuiPlateFrame.castWarning.icon:SetPoint("RIGHT", kuiPlateFrame.castWarning.text, "LEFT", -2 * UPConstants.minimalOnePixel, 0)
	kuiPlateFrame.castWarning.icon:SetHeight(UPConstants.castBarSizes.icon)
	kuiPlateFrame.castWarning.icon:SetWidth(UPConstants.castBarSizes.icon)
	kuiPlateFrame.castWarning.icon.tex = kuiPlateFrame.castWarning.icon:CreateTexture(nil, "ARTWORK")
	kuiPlateFrame.castWarning.icon.tex:SetAllPoints()
	-- kuiPlateFrame.castWarning.icon.tex:SetTexture("Interface\\AddOns\\UnitPlates\\img\\loading.tga")
	
	kuiPlateFrame.castWarning.currentValue = 0
	kuiPlateFrame.castWarning.startTime = 0
	kuiPlateFrame.castWarning.endTime = 0
	kuiPlateFrame.castWarning.castTime = 0
	
	---------------------------------------------------------------------------------

	-- scripts -------------------------------------------------------------
	-- kuiPlateFrame.castbar:RegisterEvent("UNIT_SPELLCAST_START")
	-- kuiPlateFrame.castbar:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
	--cast bar end
	
	-- create combo points
	kuiPlateFrame.combopoints = CreateFrame("Frame", nil, kuiPlateFrame.overlay)
	kuiPlateFrame.combopoints:Hide()

	local pcp
	for i = 0, 4 do
		-- create individual combo point icons
		-- size and position of first icon is set in ScaleComboPoints
		local cp = kuiPlateFrame.combopoints:CreateTexture(nil, "ARTWORK")
		cp:SetDrawLayer("ARTWORK", 2)
		cp:SetTexture("Interface\\AddOns\\UnitPlates\\Media\\combopoint-round")
		
		-- cp:SetTexture("Interface\\ComboFrame\\ComboPoint")
		-- -- Crop out just the red orb from Blizzard's combo point sprite sheet
		-- -- (Left, Right, Top, Bottom)
		-- cp:SetTexCoord(0, 0.375, 0, 0.75)

		if i > 0 then
			cp:SetPoint("LEFT", pcp, "RIGHT", UPConstants.combopointsSizes.spacing, 0)
		end

		tinsert(kuiPlateFrame.combopoints, i + 1, cp)
		pcp = cp
	end

	for i, cp in ipairs(kuiPlateFrame.combopoints) do
		cp:SetWidth(UPConstants.combopointsSizes.combopoints)
		cp:SetHeight(UPConstants.combopointsSizes.combopoints)

		if i == 1 then
			-- place first icon to offset others to center
			cp:SetPoint("TOP", kuiPlateFrame.health, "TOP", -(UPConstants.combopointsSizes.combopoints + UPConstants.combopointsSizes.spacing) * 2, (UPConstants.combopointsSizes.combopoints * 1.15))
		end
	end
	
	
	
	-- 1. CLEAN BACKDROP HANDLING: Create a distinct frame *behind* the type icon
	kuiPlateFrame.combopoints.bgOffsetFrame = CreateFrame("Frame", nil, kuiPlateFrame.combopoints)
	kuiPlateFrame.combopoints.bgOffsetFrame:SetFrameLevel(1) -- Below icon frame
	kuiPlateFrame.combopoints.bgOffsetFrame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8", 
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", -- Built-in rounded edge
		tile = false, tileSize = 0, edgeSize = 10,
		insets = { left = 2, right = 2, top = 2, bottom = 2 }
	})
	kuiPlateFrame.combopoints.bgOffsetFrame:SetBackdropColor(0, 0, 0, 0.8) 
	kuiPlateFrame.combopoints.bgOffsetFrame:SetBackdropBorderColor(0.1, 0.1, 0.1, 1) 

	-- 2. THE CORNER MASKING OVERLAY: Create a frame *above* the type icon
	kuiPlateFrame.combopoints.overlayMask = CreateFrame("Frame", nil, kuiPlateFrame.combopoints)
	kuiPlateFrame.combopoints.overlayMask:SetFrameLevel(3) -- Directly above the icon texture
	kuiPlateFrame.combopoints.overlayMask:SetBackdrop({
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", -- Slices off the 4 square corners
		tile = false, tileSize = 0, edgeSize = 10,
		insets = { left = 2, right = 2, top = 2, bottom = 2 }
	})
	kuiPlateFrame.combopoints.overlayMask:SetBackdropBorderColor(0, 0, 0, 1) -- Black masking border

	-- Lock the background and foreground rounded layers tight to the icon dimensions plus padding
	local combopointsPadding = 2.5
	local combopointsPaddingHorizontalMod = 1.5
	kuiPlateFrame.combopoints.bgOffsetFrame:ClearAllPoints()
	kuiPlateFrame.combopoints.bgOffsetFrame:SetPoint("TOPLEFT", kuiPlateFrame.combopoints[1], "TOPLEFT", -combopointsPadding * combopointsPaddingHorizontalMod, combopointsPadding)
	kuiPlateFrame.combopoints.bgOffsetFrame:SetPoint("BOTTOMRIGHT", kuiPlateFrame.combopoints[5], "BOTTOMRIGHT", combopointsPadding * combopointsPaddingHorizontalMod, -combopointsPadding)

	kuiPlateFrame.combopoints.overlayMask:ClearAllPoints()
	kuiPlateFrame.combopoints.overlayMask:SetPoint("TOPLEFT", kuiPlateFrame.combopoints[1], "TOPLEFT", -combopointsPadding * combopointsPaddingHorizontalMod, combopointsPadding)
	kuiPlateFrame.combopoints.overlayMask:SetPoint("BOTTOMRIGHT", kuiPlateFrame.combopoints[5], "BOTTOMRIGHT", combopointsPadding * combopointsPaddingHorizontalMod, -combopointsPadding)
	
	
	-- create combo points end
	
	--totem
	-- originalPlateFrame.totem = CreateFrame("Frame", nil, originalPlateFrame)
	-- originalPlateFrame.totem:SetPoint("TOP", originalPlateFrame, "TOP", 0, 0)
	-- originalPlateFrame.totem:SetHeight(UPConstants.totemIconSize)
	-- originalPlateFrame.totem:SetWidth(UPConstants.totemIconSize)
	-- --originalPlateFrame.totem:SetFrameLevel(5)
	-- originalPlateFrame.totem.icon = originalPlateFrame.totem:CreateTexture(nil, "OVERLAY")
	-- originalPlateFrame.totem.icon:SetTexCoord(.078, .92, .079, .937)
	-- originalPlateFrame.totem.icon:SetAllPoints()
	-- originalPlateFrame.totem:SetBackdrop({
		-- bgFile = "Interface\\AddOns\\UnitPlates\\img\\WHITE", -- A solid texture
		-- edgeFile = "Interface\\AddOns\\UnitPlates\\img\\WHITE", 
		-- edgeSize = 1, 
		-- insets = { left = -(3 * UPConstants.minimalOnePixel), right = -(3 * UPConstants.minimalOnePixel), top = -(3 * UPConstants.minimalOnePixel), bottom = -(3 * UPConstants.minimalOnePixel) }
	-- })
	-- originalPlateFrame.totem:SetBackdropColor(0, 0, 0, 1) -- Black Background
	-- originalPlateFrame.totem:SetBackdropBorderColor(0, 0, 0, 1) -- Black Border
	-- --originalPlateFrame.totem:SetVertexColor(1, 1, 1, 1)
	-- originalPlateFrame.totem:Hide()
	
	-- Initialize the Totem container frame
	kuiPlateFrame.originalPlateFrame.totem = CreateFrame("Frame", nil, originalPlateFrame)
	kuiPlateFrame.originalPlateFrame.totem:SetFrameLevel(3) -- Middle layer for the icon
	-- Anchor to the engine plate itself, NOT to kuiPlateFrame.health: in totem
	-- mode the kui frame is hidden, and a hidden frame stops tracking its
	-- anchor on camera moves, which would leave the totem glued to a stale
	-- screen position (ghost totems). The engine plate always tracks the unit.
	-- The health bar is vertically centered on the plate, so health's TOP is
	-- plate CENTER + half the bar height -- reproduce that offset here.
	kuiPlateFrame.originalPlateFrame.totem:SetPoint("TOP", originalPlateFrame, "CENTER", 0, UPConstants.nameplateHealthBarHeight / 2)
	kuiPlateFrame.originalPlateFrame.totem:SetHeight(UPConstants.totemIconSize)
	kuiPlateFrame.originalPlateFrame.totem:SetWidth(UPConstants.totemIconSize)
	
	-- Create the icon texture asset inside the frame
	kuiPlateFrame.originalPlateFrame.totem.icon = originalPlateFrame.totem:CreateTexture(nil, "ARTWORK") -- Changed to ARTWORK layer to stay under the mask frame
	kuiPlateFrame.originalPlateFrame.totem.icon:SetAllPoints()
	kuiPlateFrame.originalPlateFrame.totem.icon:SetTexture("Interface\\Icons\\Spell_Nature_ thereIsNoIcon")
	
	-- 1. CLEAN BACKDROP HANDLING: Create a distinct background frame *behind* the totem icon
	if not kuiPlateFrame.originalPlateFrame.totem.bgOffsetFrame then
		kuiPlateFrame.originalPlateFrame.totem.bgOffsetFrame = CreateFrame("Frame", nil, originalPlateFrame.totem)
		kuiPlateFrame.originalPlateFrame.totem.bgOffsetFrame:SetFrameLevel(2) -- Safely layers behind the texture
		kuiPlateFrame.originalPlateFrame.totem.bgOffsetFrame:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8", -- Crisp solid engine texture
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", -- Built-in rounded edge asset
			tile = false, tileSize = 0, edgeSize = 10,
			insets = { left = 2, right = 2, top = 2, bottom = 2 }
		})
		kuiPlateFrame.originalPlateFrame.totem.bgOffsetFrame:SetBackdropColor(0, 0, 0, 0.8) -- Dark backdrop fill
		kuiPlateFrame.originalPlateFrame.totem.bgOffsetFrame:SetBackdropBorderColor(0.1, 0.1, 0.1, 1) -- Matte grey border rim
	end

	-- 2. THE CORNER MASKING OVERLAY: Create a matte-black masking frame *above* the totem icon
	if not kuiPlateFrame.originalPlateFrame.totem.overlayMask then
		kuiPlateFrame.originalPlateFrame.totem.overlayMask = CreateFrame("Frame", nil, originalPlateFrame.totem)
		kuiPlateFrame.originalPlateFrame.totem.overlayMask:SetFrameLevel(4) -- Directly above the icon texture to clip it
		kuiPlateFrame.originalPlateFrame.totem.overlayMask:SetBackdrop({
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", -- Slices off the 4 square corners
			tile = false, tileSize = 0, edgeSize = 10,
			insets = { left = 2, right = 2, top = 2, bottom = 2 }
		})
		kuiPlateFrame.originalPlateFrame.totem.overlayMask:SetBackdropBorderColor(0, 0, 0, 1) -- Pure black mask to match layouts
	end

	-- 3. POSITIONING LOGIC
	-- Anchor the background and foreground overlay frames perfectly to the main icon frame
	local padding = 4
	kuiPlateFrame.originalPlateFrame.totem.bgOffsetFrame:ClearAllPoints()
	kuiPlateFrame.originalPlateFrame.totem.bgOffsetFrame:SetPoint("TOPLEFT", kuiPlateFrame.originalPlateFrame.totem, "TOPLEFT", -padding, padding)
	kuiPlateFrame.originalPlateFrame.totem.bgOffsetFrame:SetPoint("BOTTOMRIGHT", kuiPlateFrame.originalPlateFrame.totem, "BOTTOMRIGHT", padding, -padding)

	kuiPlateFrame.originalPlateFrame.totem.overlayMask:ClearAllPoints()
	kuiPlateFrame.originalPlateFrame.totem.overlayMask:SetPoint("TOPLEFT", kuiPlateFrame.originalPlateFrame.totem, "TOPLEFT", -padding, padding)
	kuiPlateFrame.originalPlateFrame.totem.overlayMask:SetPoint("BOTTOMRIGHT", kuiPlateFrame.originalPlateFrame.totem, "BOTTOMRIGHT", padding, -padding)

	kuiPlateFrame.originalPlateFrame.totem:Hide()
	
	
	
	
	
	
	originalPlateFrame.totem.glow = originalPlateFrame.totem:CreateTexture(nil, "BACKGROUND")
	originalPlateFrame.totem.glow:SetPoint("LEFT", originalPlateFrame.totem, "LEFT", -UPConstants.nameplateArrowSize * 1.1, 0)
	originalPlateFrame.totem.glow:SetTexture("Interface\\AddOns\\UnitPlates\\img\\arrow_left")
	--nameplate.glow:SetFrameLevel(1)
	originalPlateFrame.totem.glow:SetDrawLayer("BACKGROUND")
	originalPlateFrame.totem.glow:SetWidth(UPConstants.nameplateArrowSize)
	originalPlateFrame.totem.glow:SetHeight(UPConstants.nameplateArrowSize)
	originalPlateFrame.totem.glow:SetVertexColor(unpack(glowColor))
	originalPlateFrame.totem.glow:Hide()

	originalPlateFrame.totem.glow2 = originalPlateFrame.totem:CreateTexture(nil, "BACKGROUND")
	originalPlateFrame.totem.glow2:SetPoint("RIGHT", originalPlateFrame.totem, "RIGHT", UPConstants.nameplateArrowSize * 1.1, 0)
	originalPlateFrame.totem.glow2:SetTexture("Interface\\AddOns\\UnitPlates\\img\\arrow_right")
	--nameplate.glow:SetFrameLevel(1)
	originalPlateFrame.totem.glow2:SetDrawLayer("BACKGROUND")
	--nameplate.glow2.texture:SetRotation(2)
	originalPlateFrame.totem.glow2:SetWidth(UPConstants.nameplateArrowSize)
	originalPlateFrame.totem.glow2:SetHeight(UPConstants.nameplateArrowSize)
	originalPlateFrame.totem.glow2:SetVertexColor(unpack(glowColor))
	originalPlateFrame.totem.glow2:Hide()
	--totem END
	
	--auras
	kuiPlateFrame.unitAuras = {}
	
	kuiPlateFrame.aurasContainer = CreateFrame("Frame", nil, kuiPlateFrame)
	kuiPlateFrame.aurasContainer:SetPoint("BOTTOM", kuiPlateFrame.name, "TOP", 0, UPConstants.nameplateClassIconSize / 2)
	kuiPlateFrame.aurasContainer:SetHeight(UPConstants.nameplateHealthBarHeight)
	kuiPlateFrame.aurasContainer:SetWidth(UPConstants.nameplateHealthBarWidth)
	--create icons
	kuiPlateFrame.aurasContainer.auraIcons = {} -- Table to hold our icon frames
	--auras onupdate
	kuiPlateFrame.aurasContainer:SetScript("OnUpdate", function()
		local self = kuiPlateFrame.aurasContainer
		if not self then return nil end
		local elapsed = arg1

		self.nextUpdate = (self.nextUpdate or 0) - elapsed
		if self.nextUpdate > 0 then return end
		self.nextUpdate = 0.1

		--THIS IS AURAS FRAMES UPDATE
		local currentTime = GetTime()

		-- layout values are identical for every icon on this plate, so compute
		-- them once instead of per icon.
		local maxAuras = UPConstants.maxAurasInRow
		if kuiPlateFrame.isTrivial then
			maxAuras = UPConstants.maxAurasInRowGrayLevel
		end
		local iconSize = (UPConstants.nameplateHealthBarWidth / maxAuras) - UPConstants.auraIconOffset
		if kuiPlateFrame.isGrayLevel or kuiPlateFrame.isPet then
			iconSize = (UPConstants.nameplateWidthGrayLevel / maxAuras) - UPConstants.auraIconOffset
		end
		local cdFontSizeLong = iconSize / 2.6
		local cdFontSizeShort = iconSize / 2
		local countFontSize = iconSize / 3

		local firstDebuffIndex = 1
		local buffrows = 0
		local hadAnyBuffs = false

		--iterating through stored list
		local iconIndex = 1
		for _, aura in ipairs(kuiPlateFrame.unitAuras) do
			local name = aura.name

			-- Stop if no more auras OR if we ran out of our MAX icons
			if not name or iconIndex > UPConstants.maxAuras then
				break
			end

			--setup icon
			local icon = self.auraIcons[iconIndex]

			icon.isDebuff = aura.isDebuff

			-- Set Texture (only when it actually changed)
			if icon.lastTexture ~= aura.texture then
				icon.lastTexture = aura.texture
				icon.tex:SetTexture(aura.texture)
			end

			--set count
			icon.count = aura.count

			-- Set Cooldown
			local duration = aura.duration
			if duration > 0 then
				icon.expirationTime = aura.expirationTime
				icon.duration = duration
				icon.startTime = aura.expirationTime - duration
			elseif duration == -1 then
				icon.expirationTime = -1
				icon.duration = -1
				icon.startTime = -1
			else
				icon.expirationTime = 0
				icon.duration = 0
				icon.startTime = 0
			end

			local column = math_mod((iconIndex - 1), maxAuras)          -- Results in 0, 1, 2, 3
			local row = math_floor((iconIndex - 1) / maxAuras) -- Results in 0, 1, 2...

			if not aura.isDebuff then
				hadAnyBuffs = true
			end
			if hadAnyBuffs and aura.isDebuff and firstDebuffIndex == 1 then
				buffrows = (math_floor((iconIndex - 1 - 1) / maxAuras))
				firstDebuffIndex = iconIndex
			end

			if firstDebuffIndex > 1 then
				column = math_mod((iconIndex - firstDebuffIndex), maxAuras)
				row = math_floor((iconIndex - firstDebuffIndex) / maxAuras)
			end

			local xOffset = column * (iconSize + UPConstants.auraIconOffset)
			local yOffset = row * (iconSize + UPConstants.auraIconOffset)

			if firstDebuffIndex > 1 then
				yOffset = (buffrows * (iconSize + UPConstants.auraIconOffset)) + (row * (iconSize + UPConstants.auraIconOffset)) + (iconSize * 1.3)
			end

			icon:SetWidth(iconSize)
			icon:SetHeight(iconSize)

			-- SetFont is expensive; only re-apply when the size bucket changes.
			local timeLeftSeconds = aura.expirationTime - currentTime
			local cdFontSize = (timeLeftSeconds >= 60) and cdFontSizeLong or cdFontSizeShort
			if icon.lastCdFontSize ~= cdFontSize then
				icon.lastCdFontSize = cdFontSize
				icon.cdText:SetFont(mainFontPath, cdFontSize, "OUTLINE")
			end
			if icon.lastCountFontSize ~= countFontSize then
				icon.lastCountFontSize = countFontSize
				icon.countText:SetFont(mainFontPath, countFontSize, "OUTLINE")
			end

			icon:ClearAllPoints()
			-- We use BOTTOMLEFT so that as 'row' increases, icons move UP (on top)
			icon:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", xOffset, yOffset)

			icon:Show()
			iconIndex = iconIndex + 1
		end

		--Hide any remaining icons in our pool that aren't being used
		for i = iconIndex, UPConstants.maxAuras do
			if self.auraIcons[i] then
				self.auraIcons[i]:Hide()
			end
		end
	end)
	--aura onupdate end
	
	--kuiPlateFrame.aurasContainer:SetFrameStrata("TOOLTIP")	
	for i = 1, UPConstants.maxAuras do		
		local icon = CreateFrame("Frame", nil, kuiPlateFrame.aurasContainer)
		icon:SetWidth(16)
		icon:SetHeight(16)
		icon:SetFrameLevel(1)
		
		icon.tex = icon:CreateTexture(nil, "BACKGROUND")
		icon.tex:SetTexture("Interface\\AddOns\\UnitPlates\\img\\loading.tga")
		icon.tex:SetAllPoints(icon)
		--icon.tex:SetFrameLevel(0)
		
		icon.countText = icon:CreateFontString(nil, "OVERLAY", "SubSpellFont")
		icon.countText:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, 0)
		icon.countText:SetFont(mainFontPath, UPConstants.powerFontSize, "OUTLINE")
		icon.countText:SetTextColor(1,1,1,1)
		
		icon.cdText = icon:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		icon.cdText:SetPoint("CENTER", icon, "CENTER", 0, 0)
		icon.cdText:SetFont(mainFontPath, UPConstants.levelFontSize, "OUTLINE")
		icon.cdText:SetTextColor(1,1,1,1)
		
		icon.quads = {
			TR = UPCoreCreateQuadrant(icon, "TOPRIGHT"),
			BR = UPCoreCreateQuadrant(icon, "BOTTOMRIGHT"),
			BL = UPCoreCreateQuadrant(icon, "BOTTOMLEFT"),
			TL = UPCoreCreateQuadrant(icon, "TOPLEFT"),
		}
		
		icon:SetScript("OnUpdate", function()
			local self = icon
			local elapsed = arg1

			-- IsVisible also covers the plate being hidden or off-screen; the
			-- old IsShown check kept 80 scripts per plate firing on hidden
			-- plates in crowded areas.
			if self:IsVisible() then
				self.nextUpdate = (self.nextUpdate or 0) - elapsed
				if self.nextUpdate > 0 then return end
				self.nextUpdate = 0.1

				--count
				local countText = (self.count and self.count > 1) and (""..self.count) or ""
				if self.lastCountText ~= countText then
					self.lastCountText = countText
					self.countText:SetText(countText)
				end
				
				--time left
				if self.duration == -1 then
					self.cdText:SetText("")
					self.quads.TR:Hide() self.quads.BR:Hide()
					self.quads.BL:Hide() self.quads.TL:Hide()
					return nil
				end
				
				local timeLeftSeconds = self.expirationTime-GetTime()
				if timeLeftSeconds > 0 then
					local cooldownText = ""..timeLeftSeconds
					if timeLeftSeconds >= 60*60 then
						cooldownText = math.floor(timeLeftSeconds / 3600) .. "h"
						if self.isDebuff then
							self.cdText:SetTextColor(0.70, 0.30, 1.0, 1.0)
						else
							self.cdText:SetTextColor(0.53,0.81,0.98,1)
						end
					elseif timeLeftSeconds >= 60 then
						cooldownText = math.floor(timeLeftSeconds / 60) .. "m"
						if self.isDebuff then
							self.cdText:SetTextColor(0.70, 0.30, 1.0, 1.0)
						else
							self.cdText:SetTextColor(0.53,0.81,0.98,1)
						end
					elseif timeLeftSeconds >= 1 then
						cooldownText = math.floor(timeLeftSeconds) .. ""
						if self.isDebuff then
							self.cdText:SetTextColor(1,0.8,0.8,1)
						else
							self.cdText:SetTextColor(0.8,0.8,1,1)
						end
						if timeLeftSeconds <= 3 then
							self.cdText:SetTextColor(0.99,0,0,1)
						elseif timeLeftSeconds <= 7 then
							self.cdText:SetTextColor(0.99,0.99,0,1)
						end
					elseif timeLeftSeconds > 0 then
						local s = string.format("%.1f", timeLeftSeconds)
						--cooldownText = string.gsub(s, "^0", "")
						cooldownText = string.sub(s, 2)
						self.cdText:SetTextColor(0.99,0,0,1)
					else
						cooldownText = "0"
						self.cdText:SetTextColor(0.99,0,0,1)
					end
					
					self.cdText:SetText(cooldownText)--show
				else
					self.cdText:SetText("0")--show
					if timeLeftSeconds < 0 then
						--probably negative values are more informative than questions
						local cooldownText = ""..timeLeftSeconds
						local s = string.format("%.1f", timeLeftSeconds)
						cooldownText = string.sub(s, 2)
						self.cdText:SetTextColor(0.99,0,0,1)
						
						--self.cdText:SetText("??")--show
						--print("aura duration seems to be incorrect for: "..auraName)
					end
				end
				
				local pct = timeLeftSeconds / self.duration -- 1.0 down to 0.0
				if pct > 1 then
					pct = 1 -- Clamp to 100%
				end
				if pct < 0 then
					pct = 0  -- Clamp to 0%
				end
				local size = self:GetWidth() / 2 -- Half the icon size (e.g., 18)

				-- Reset state (direct field access avoids the pairs() iterator
				-- overhead four times per icon per tick)
				local qTR, qBR, qBL, qTL = self.quads.TR, self.quads.BR, self.quads.BL, self.quads.TL
				qTR:Show() qTR:SetWidth(size) qTR:SetHeight(size)
				qBR:Show() qBR:SetWidth(size) qBR:SetHeight(size)
				qBL:Show() qBL:SetWidth(size) qBL:SetHeight(size)
				qTL:Show() qTL:SetWidth(size) qTL:SetHeight(size)

				if pct > 0.75 then
					-- 100% to 75%: Shrink TOP RIGHT width
					qTR:SetWidth(size * ((pct - 0.75) / 0.25))
				elseif pct > 0.50 then
					-- 75% to 50%: TR is gone, shrink BOTTOM RIGHT height
					qTR:Hide()
					qBR:SetHeight(size * ((pct - 0.50) / 0.25))
				elseif pct > 0.25 then
					-- 50% to 25%: TR/BR gone, shrink BOTTOM LEFT width
					qTR:Hide()
					qBR:Hide()
					qBL:SetWidth(size * ((pct - 0.25) / 0.25))
				elseif pct > 0 then
					-- 25% to 0%: Only TL left, shrink TOP LEFT height
					qTR:Hide()
					qBR:Hide()
					qBL:Hide()
					qTL:SetHeight(size * (pct / 0.25))
				else
					qTR:Hide() qBR:Hide() qBL:Hide() qTL:Hide()
				end
			end
		end)

		icon.expirationTime = 0
		icon.duration = 0
		icon.startTime = 0
		icon:Hide() -- Hide by default
		kuiPlateFrame.aurasContainer.auraIcons[i] = icon -- Store in our pool
	end
	--auras END

	----------------------------------------------------------------- Scripts --
	-- Plate content updates run from the central throttled loop over
	-- UPVisiblePlates (pfUI-style). Per-plate OnUpdate is disabled.

	-- Manual Hook for OnShow
	local oldOnShow = originalPlateFrame:GetScript("OnShow")
	originalPlateFrame:SetScript("OnShow", function()
		if oldOnShow then oldOnShow() end
		OnFrameShow(this)
		-- SuperWoW-only fallback: ClassicAPI ADDED owns visibility + unit bind.
		if not UPHasClassicNamePlates then
			if not UPVisiblePlates[this] then
				UPVisiblePlates[this] = this
				UPVisiblePlateCount = UPVisiblePlateCount + 1
			end
			-- Re-bind after ResetFrame so recycled/shown plates keep a GUID.
			UPBindPlateUnit(this, nil)
		end
	end)

	-- Manual Hook for OnHide
	local oldOnHide = originalPlateFrame:GetScript("OnHide")
	originalPlateFrame:SetScript("OnHide", function()
		if oldOnHide then oldOnHide() end
		if UPVisiblePlates[this] then
			UPVisiblePlates[this] = nil
			UPVisiblePlateCount = UPVisiblePlateCount > 0 and (UPVisiblePlateCount - 1) or 0
			UPUnbindPlateUnit(this)
		end
		this:Hide()
		ResetFrame(this.kui, this)
	end)

	-- Disable Blizzard/per-plate OnUpdate; central loop owns updates.
	originalPlateFrame:SetScript("OnUpdate", nil)

	-- Per-plate unit events (ClassicAPI RegisterUnitEvent). `this` is the
	-- kui overlay which receives only events for its bound nameplateN token.
	kuiPlateFrame:SetScript("OnEvent", function()
		if event == "UNIT_AURA" then
			this.auraUpdate = true
		elseif event == "UNIT_FLAGS" then
			this.eventcache = true
		elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
			if this.unit and UPApiPollCastFromUnit(this.unit) then
				this.castUpdate = true
			end
		elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
			if this.cachedGuid then
				UPApiClearCastForGuid(this.cachedGuid)
				this.castUpdate = true
			end
		end
	end)

	kuiPlateFrame.oldHealth.kuiParent = originalPlateFrame
	-- kuiPlateFrame.oldHealth:HookScript("OnValueChanged", function(self)
		-- kuiPlateFrame:OnHealthValueChanged(unpack(arg)) 
	-- end)
	-- local oldOnValueChanged = kuiPlateFrame.oldHealth:GetScript("OnValueChanged")
	-- kuiPlateFrame.oldHealth:SetScript("OnValueChanged", function()
		-- if oldOnValueChanged then oldOnValueChanged(arg1) end
		-- -- We use 'kuiPlateFrame' directly since it's in the scope of InitFrame
		-- --kuiPlateFrame:OnHealthValueChanged() 
		-- UpdateHealth(kuiPlateFrame)
	-- end)
	
	--kuiPlateFrame:EnableMouse(1)
	kuiPlateFrame.health:EnableMouse(true)
	kuiPlateFrame.typeIcon:EnableMouse(true)
	kuiPlateFrame.power:EnableMouse(true)
	originalPlateFrame.totem:EnableMouse(true)
	
	kuiPlateFrame.lastMouseClickEvent = ""
	
	kuiPlateFrame.health:SetScript("OnMouseUp", function()
		kuiPlateFrame.lastMouseClickEvent = "OnMouseUp"
		--print("here1")
		if (not IsMouselooking()) and MouseIsOver(kuiPlateFrame.health) then
			--print("here")
			originalPlateFrame:Click(arg1)
		end
	end)
	kuiPlateFrame.typeIcon:SetScript("OnMouseUp", function()
		kuiPlateFrame.lastMouseClickEvent = "OnMouseUp"
		--print("here1")
		if (not IsMouselooking()) and MouseIsOver(kuiPlateFrame.typeIcon) then
			--print("here")
			originalPlateFrame:Click(arg1)
		end
	end)
	kuiPlateFrame.power:SetScript("OnMouseUp", function()
		kuiPlateFrame.lastMouseClickEvent = "OnMouseUp"
		--print("here1")
		if (not IsMouselooking()) and MouseIsOver(kuiPlateFrame.power) then
			--print("here")
			originalPlateFrame:Click(arg1)
		end
	end)
	originalPlateFrame.totem:SetScript("OnMouseUp", function()
		kuiPlateFrame.lastMouseClickEvent = "OnMouseUp"
		--print("here1")
		if MouseIsOver(originalPlateFrame.totem) then
			--print("here")
			originalPlateFrame:Click(arg1)
		end
	end)
	
	kuiPlateFrame.health:SetScript("OnMouseDown", function()
		kuiPlateFrame.lastMouseClickEvent = "OnMouseDown"
		if MouseIsOver(kuiPlateFrame.health) and arg1 == "RightButton" then
			MouselookStart()
			SetMouseoverUnit()			
			originalPlateFrame.rightClickStartTime = GetTime()
		end
	end)
	kuiPlateFrame.typeIcon:SetScript("OnMouseDown", function()
		kuiPlateFrame.lastMouseClickEvent = "OnMouseDown"
		if MouseIsOver(kuiPlateFrame.typeIcon) and arg1 == "RightButton" then
			MouselookStart()
			SetMouseoverUnit()			
			originalPlateFrame.rightClickStartTime = GetTime()
		end
	end)
	kuiPlateFrame.power:SetScript("OnMouseDown", function()
		kuiPlateFrame.lastMouseClickEvent = "OnMouseDown"
		if MouseIsOver(kuiPlateFrame.power) and arg1 == "RightButton" then
			MouselookStart()
			SetMouseoverUnit()			
			originalPlateFrame.rightClickStartTime = GetTime()
		end
	end)
	originalPlateFrame.totem:SetScript("OnMouseDown", function()
		kuiPlateFrame.lastMouseClickEvent = "OnMouseDown"
		-- arg1 contains "LeftButton" or "RightButton"
		if MouseIsOver(originalPlateFrame.totem) and arg1 == "RightButton" then
			MouselookStart()
			SetMouseoverUnit()			
			originalPlateFrame.rightClickStartTime = GetTime()
		end
	end)
	
	kuiPlateFrame.health:SetScript("OnEnter", function()
		--print("here1")
		if (not IsMouselooking()) and kuiPlateFrame.guid then
			SetMouseoverUnit(kuiPlateFrame.guid)
		end
	end)
	kuiPlateFrame.typeIcon:SetScript("OnEnter", function()
		--print("here1")
		if (not IsMouselooking()) and kuiPlateFrame.guid then
			SetMouseoverUnit(kuiPlateFrame.guid)
		end
	end)
	kuiPlateFrame.power:SetScript("OnEnter", function()
		--print("here1")
		if (not IsMouselooking()) and kuiPlateFrame.guid then
			SetMouseoverUnit(kuiPlateFrame.guid)
		end
	end)
	originalPlateFrame.totem:SetScript("OnEnter", function()
		--print("here1")
		if (not IsMouselooking()) and kuiPlateFrame.guid then
			SetMouseoverUnit(kuiPlateFrame.guid)
		end
	end)
	
	
	kuiPlateFrame.health:SetScript("OnLeave", function()
		--print("here1")
		SetMouseoverUnit()
	end)
	kuiPlateFrame.typeIcon:SetScript("OnLeave", function()
		--print("here1")
		SetMouseoverUnit()
	end)
	kuiPlateFrame.power:SetScript("OnLeave", function()
		--print("here1")
		SetMouseoverUnit()
	end)
	originalPlateFrame.totem:SetScript("OnLeave", function()
		--print("here1")
		SetMouseoverUnit()
	end)
	------------------------------------------------------------ Finishing up --
	-- addon:SendMessage("UnitPlates_PostCreate", kuiPlateFrame)
	
	------------------------------------------------------------

	if originalPlateFrame:IsShown() then
		OnFrameShow(originalPlateFrame)
		-- SuperWoW discovery may InitFrame an already-visible plate without a
		-- fresh OnShow; register it. ClassicAPI waits for NAME_PLATE_UNIT_ADDED.
		if not UPHasClassicNamePlates then
			if not UPVisiblePlates[originalPlateFrame] then
				UPVisiblePlates[originalPlateFrame] = originalPlateFrame
				UPVisiblePlateCount = UPVisiblePlateCount + 1
			end
			UPBindPlateUnit(originalPlateFrame, nil)
		end
	else
		kuiPlateFrame:Hide()
	end
end
-----------PLATE CREATION END


---------------------------------------------------------------------- Events --

local function OnPlayerEnteringWorld()
	--set cvars as needed

	--SetCVar("chatBubbles", 1) 
    --SetCVar("chatBubblesParty", 1)
	
	-- Enable overlapping (Disable collision)
    --SetCVar("nameplateAllowOverlap", 1)
	
	--SetCVar("ShowClassColorInNameplate", 0)
	
	--SetCVar("showVKeyCastbar", 1)
	
	-- force enable threat on nameplates - this is a hidden CVar
	--SetCVar("threatWarning", 3)
	
	--UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")[cite: 1]
	
	-- Optional: These are the only other common CVars in 3.3.5
    -- They control how far away plates appear
    -- SetCVar("nameplateMaxDistance", 40)
	
	if ShaguTweaks_config then
		local hasConflicts = false
		
		if ShaguTweaks_config["Nameplate Castbar"] == 1 then
			ShaguTweaks_config["Nameplate Castbar"] = 0
			hasConflicts = true
		end
		
		if ShaguTweaks_config["Nameplate Scale"] == 1 then
			ShaguTweaks_config["Nameplate Scale"] = 0
			hasConflicts = true
		end
		
		if ShaguTweaks_config["Nameplate Class Colors"] == 1 then
			ShaguTweaks_config["Nameplate Class Colors"] = 0
			hasConflicts = true
		end
		
		if hasConflicts then
			print("---------")
			print("!!!UnitPlates detected ShaguTweaks and disabled conflicting config options, please type /reload or restart the game for the changes to take effect")
			print("---------")
		end
	end
	
	if pfQuest_config then
		local hasConflicts = false
		
		if (not UPCompatPfQuestHasHearthDB()) and pfQuest_config["nameplatesEnabled"] == "1" then
			pfQuest_config["nameplatesEnabled"] = "0"
			hasConflicts = true
		end
		
		if hasConflicts then
			print("---------")
			print("!!!UnitPlates detected PfQuest and disabled conflicting config options, please type /reload or restart the game for the changes to take effect")
			print("---------")
		end
	end
end

--event processing
local UnitPlatesMainFrame = CreateFrame("Frame", "UnitPlatesMainFrame", UIParent)
UnitPlatesMainFrame:SetFrameStrata("LOW")
UnitPlatesMainFrame.TimeToCheck = 0
UnitPlatesMainFrame.numFrames = 0
UnitPlatesMainFrame.frameTick = 0
UnitPlatesMainFrame.sortElapsed = 0
UnitPlatesMainFrame.bubbleElapsed = 0
UnitPlatesMainFrame.eventcache = nil
UnitPlatesMainFrame.frameState = {
	now = 0,
	elapsed = 0,
	targetGuid = nil,
	visibleCount = 0,
}

UnitPlatesMainFrame:SetScript("OnEvent", function()
	UnitPlatesAddonIsLoaded = true

	if event == "ADDON_LOADED" and arg1 == "UnitPlates" then
		UnitPlatesAddonIsLoaded = true
		UnitPlatesMainFrame:UnregisterEvent("ADDON_LOADED")

		if UnitPlatesAddonIsLoaded and UnitPlatesPlayerEnteredWorld then
			UPConfigInitUnitPlatesSettings()
			InitUPConstants()
		end
		if UPHasClassicNamePlates then
			DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99UnitPlates|r: ClassicAPI nameplates enabled (event-driven)")
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99UnitPlates|r: ClassicAPI not found - using SuperWoW WorldFrame scan fallback")
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		UnitPlatesPlayerEnteredWorld = true
		UnitPlatesMainFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")

		if UnitPlatesAddonIsLoaded and UnitPlatesPlayerEnteredWorld then
			UPConfigInitUnitPlatesSettings()
			InitUPConstants()
			OnPlayerEnteringWorld()
		end
		local targetGuid = UPHasUnitGUID and UnitGUID("target") or nil
		if not UPHasUnitGUID then
			local exists, g = UnitExists("target")
			if exists then targetGuid = g end
		end
		UPApiSetCachedTargetGuid(targetGuid)
		UnitPlatesMainFrame.frameState.targetGuid = targetGuid
	elseif event == "NAME_PLATE_CREATED" then
		-- arg1 = the nameplate Frame; build overlay once per pool slot
		local plate = arg1
		if plate and not plate.kui then
			InitFrame(plate)
		end
	elseif event == "NAME_PLATE_UNIT_ADDED" then
		-- arg1 = "nameplateN"
		local plate = C_NamePlate.GetNamePlateForUnit(arg1)
		if plate then
			if not plate.kui then
				InitFrame(plate)
			end
			if not UPVisiblePlates[plate] then
				UPVisiblePlates[plate] = plate
				UPVisiblePlateCount = UPVisiblePlateCount + 1
			end
			OnFrameShow(plate)
			UPBindPlateUnit(plate, arg1)
			if plate.kui then
				plate.kui:Show()
			end
		end
	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		local plate = C_NamePlate.GetNamePlateForUnit(arg1)
		if plate and UPVisiblePlates[plate] then
			UPVisiblePlates[plate] = nil
			UPVisiblePlateCount = UPVisiblePlateCount > 0 and (UPVisiblePlateCount - 1) or 0
			UPUnbindPlateUnit(plate)
			if plate.kui then
				ResetFrame(plate.kui, plate)
				plate.kui:Hide()
			end
		end
	elseif event == "PLAYER_TARGET_CHANGED" then
		local targetGuid = nil
		if UPHasUnitGUID then
			targetGuid = UnitGUID("target")
		else
			local exists, g = UnitExists("target")
			if exists then targetGuid = g end
		end
		-- Force the API cache in sync so UpdatePlate's UPApiIsTarget is instant.
		UPApiSetCachedTargetGuid(targetGuid)
		UnitPlatesMainFrame.frameState.targetGuid = targetGuid
		UnitPlatesMainFrame.eventcache = true
		if UPHasClassicNamePlates then
			local plate = C_NamePlate.GetNamePlateForUnit("target")
			if plate and plate.kui then
				plate.kui.eventcache = true
				plate.kui.doFullUpdate = true
			end
		end
	elseif event == "UPDATE_MOUSEOVER_UNIT" then
		UnitPlatesMainFrame.eventcache = true
	elseif event == "PLAYER_FOCUS_CHANGED"
		or event == "PARTY_MEMBERS_CHANGED"
		or event == "RAID_ROSTER_UPDATE" then
		UnitPlatesMainFrame.eventcache = true
	end
end)

UnitPlatesMainFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
UnitPlatesMainFrame:RegisterEvent("ADDON_LOADED")
UnitPlatesMainFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
UnitPlatesMainFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
UnitPlatesMainFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
UnitPlatesMainFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
UnitPlatesMainFrame:RegisterEvent("RAID_ROSTER_UPDATE")
if UPHasClassicNamePlates then
	UnitPlatesMainFrame:RegisterEvent("NAME_PLATE_CREATED")
	UnitPlatesMainFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	UnitPlatesMainFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
end
--event processing end



--MAIN LOOP
-- Applies the per-plate frame-level sandbox stack. This is ~25 SetFrameLevel
-- calls per plate, so it only runs when the sorted plate order (or a plate's
-- target/pet status) actually changed, not on every main-loop tick.
local function UPApplyFrameLevelStack(activePlates, activeCount)
	for i = 1, activeCount do
		local f = activePlates[i]
		local kuiPlateFrame = f.kui

		-- Each plate gets an exclusive block of 7 levels.
		local targetLevel = i * 7

		-- Target priority: force the current target (and own pet) to the top
		if f.isTarget then
			targetLevel = 120 -- Safe ceiling just below the Vanilla engine cap of 128
		end
		if kuiPlateFrame.isMyPet then
			targetLevel = 119
		end

		f:SetFrameLevel(targetLevel)
		kuiPlateFrame:SetFrameLevel(targetLevel + 1)

		if kuiPlateFrame.health then
			if kuiPlateFrame.health.bgOffsetFrame then
				kuiPlateFrame.health.bgOffsetFrame:SetFrameLevel(targetLevel + 2)
			end
			kuiPlateFrame.health:SetFrameLevel(targetLevel + 3)
			if kuiPlateFrame.health.overlayMask then
				kuiPlateFrame.health.overlayMask:SetFrameLevel(targetLevel + 4)
			end
		end

		if kuiPlateFrame.rarityIcon then
			kuiPlateFrame.rarityIcon:SetFrameLevel(targetLevel + 3)
		end
		if kuiPlateFrame.rarityIconR then
			kuiPlateFrame.rarityIconR:SetFrameLevel(targetLevel + 3)
		end
		if kuiPlateFrame.glow then
			kuiPlateFrame.glow:SetFrameLevel(targetLevel + 4)
		end
		if kuiPlateFrame.glow2 then
			kuiPlateFrame.glow2:SetFrameLevel(targetLevel + 4)
		end

		if kuiPlateFrame.typeIcon then
			if kuiPlateFrame.typeIcon.bgOffsetFrame then
				kuiPlateFrame.typeIcon.bgOffsetFrame:SetFrameLevel(targetLevel + 2)
			end
			kuiPlateFrame.typeIcon:SetFrameLevel(targetLevel + 3)
			if kuiPlateFrame.typeIcon.overlayMask then
				kuiPlateFrame.typeIcon.overlayMask:SetFrameLevel(targetLevel + 4)
			end
		end

		if kuiPlateFrame.power then
			kuiPlateFrame.power:SetFrameLevel(targetLevel + 1)
		end
		if kuiPlateFrame.classIcon then
			kuiPlateFrame.classIcon:SetFrameLevel(targetLevel + 5)
		end

		-- aura icons are children of aurasContainer and inherit its level
		-- relative to it; the old per-icon SetFrameLevel loop (80 calls per
		-- plate per tick) was redundant with this single call.
		if kuiPlateFrame.aurasContainer then
			kuiPlateFrame.aurasContainer:SetFrameLevel(targetLevel + 5)
		end

		if kuiPlateFrame.textLayerHost then
			kuiPlateFrame.textLayerHost:SetFrameLevel(targetLevel + 5)
		end
		if kuiPlateFrame.shootingIcon then
			kuiPlateFrame.shootingIcon:SetFrameLevel(targetLevel + 5)
		end
		if kuiPlateFrame.pvpRankIcon then
			kuiPlateFrame.pvpRankIcon:SetFrameLevel(targetLevel + 5)
		end
		if kuiPlateFrame.pvpIcon then
			kuiPlateFrame.pvpIcon:SetFrameLevel(targetLevel + 5)
		end
		if kuiPlateFrame.combopoints then
			kuiPlateFrame.combopoints:SetFrameLevel(targetLevel + 5)
		end
		if kuiPlateFrame.questIcon then
			kuiPlateFrame.questIcon:SetFrameLevel(targetLevel + 5)
		end
		if kuiPlateFrame.petHappiness then
			kuiPlateFrame.petHappiness:SetFrameLevel(targetLevel + 5)
		end
		if kuiPlateFrame.combatIcon then
			kuiPlateFrame.combatIcon:SetFrameLevel(targetLevel + 5)
		end

		if kuiPlateFrame.originalPlateFrame.totem then
			if kuiPlateFrame.originalPlateFrame.totem.bgOffsetFrame then
				kuiPlateFrame.originalPlateFrame.totem.bgOffsetFrame:SetFrameLevel(targetLevel + 2)
			end
			kuiPlateFrame.originalPlateFrame.totem:SetFrameLevel(targetLevel + 3)
			if kuiPlateFrame.originalPlateFrame.totem.overlayMask then
				kuiPlateFrame.originalPlateFrame.totem.overlayMask:SetFrameLevel(targetLevel + 4)
			end
		end
	end
end

UnitPlatesMainFrame:SetScript("OnUpdate", function()
	if UnitPlatesAddonIsLoaded and UnitPlatesPlayerEnteredWorld then
		UnitPlatesElapsedTimeSinceFullyLoaded = UnitPlatesElapsedTimeSinceFullyLoaded + arg1
	end

	if not (UnitPlatesAddonIsLoaded and UnitPlatesPlayerEnteredWorld
		and (UnitPlatesElapsedTimeSinceFullyLoaded > UnitPlatesLoadDelay)
		and UnitPlatesConstantsInitialized) then
		return
	end

	local self = UnitPlatesMainFrame
	local elapsed = arg1
	local now = GetTime()

	-- Central loop ~100 Hz (pfUI). Saves work at high client FPS.
	if (self.frameTick or 0) + UP_THROTTLE_CENTRAL > now then
		return
	end
	local tickElapsed = now - (self.frameTick or now)
	if tickElapsed <= 0 then tickElapsed = UP_THROTTLE_CENTRAL end
	self.frameTick = now

	local state = self.frameState
	state.now = now
	state.elapsed = tickElapsed
	state.visibleCount = UPVisiblePlateCount

	-- Propagate global event flags to every visible plate.
	if self.eventcache then
		self.eventcache = nil
		for plate in pairs(UPVisiblePlates) do
			if plate.kui then
				plate.kui.eventcache = true
			end
		end
	end

	-- SuperWoW-only discovery: scan WorldFrame when ClassicAPI is absent.
	if not UPHasClassicNamePlates then
		self.TimeToCheck = (self.TimeToCheck or 0) - tickElapsed
		if self.TimeToCheck <= 0 then
			self.TimeToCheck = UP_SORT_INTERVAL
			local framesCount = WorldFrame:GetNumChildren()
			local childrenChanged = framesCount ~= self.numFrames
			local frames = self.framesCache or {}
			self.framesCache = frames
			if childrenChanged then
				frames = {WorldFrame:GetChildren()}
				self.framesCache = frames
				self.numFrames = framesCount
			end
			for i = 1, framesCount do
				local f = frames[i]
				if childrenChanged and UPCoreIsNameplate(f) and not f.kui then
					InitFrame(f)
				end
			end
		end
	end

	-- Update visible plates (event registry, or SuperWoW OnShow registry).
	for plate in pairs(UPVisiblePlates) do
		if plate:IsShown() and plate.kui then
			ProcessVisiblePlate(plate, state)
		end
	end

	-- Chat bubbles still live as WorldFrame children (not nameplates).
	self.bubbleElapsed = (self.bubbleElapsed or 0) - tickElapsed
	if UnitPlatesSettings and UnitPlatesSettings.enableChatBubbleHandling
		and self.bubbleElapsed <= 0 then
		self.bubbleElapsed = UP_BUBBLE_INTERVAL
		local framesCount = WorldFrame:GetNumChildren()
		if framesCount ~= self.bubbleNumFrames then
			self.bubbleFramesCache = {WorldFrame:GetChildren()}
			self.bubbleNumFrames = framesCount
		end
		local frames = self.bubbleFramesCache
		if frames then
			for i = 1, framesCount do
				local v = frames[i]
				if v and UPCoreIsBalloon(v) then
					UPCoreStyleBalloon(v)
				end
			end
		end
	end

	-- FRAME LEVEL SORTING (throttled): sort by screen Y, apply only on change.
	self.sortElapsed = (self.sortElapsed or 0) - tickElapsed
	if self.sortElapsed > 0 then
		return
	end
	self.sortElapsed = UP_SORT_INTERVAL

	local activePlates = self.activePlatesCache or {}
	self.activePlatesCache = activePlates
	local activeCount = 0
	for plate in pairs(UPVisiblePlates) do
		if plate.kui and plate:IsShown() then
			activeCount = activeCount + 1
			activePlates[activeCount] = plate
			-- isTarget on the engine plate is used by the stack priority.
			plate.isTarget = plate.kui.isTarget
		end
	end
	for i = activeCount + 1, table_getn(activePlates) do
		activePlates[i] = nil
	end

	self.sortYCache = self.sortYCache or {}
	for i = 1, activeCount do
		local f = activePlates[i]
		local _, y = f:GetCenter()
		self.sortYCache[f] = y or 0
	end
	table_sort(activePlates, function(a, b)
		return UnitPlatesMainFrame.sortYCache[a] > UnitPlatesMainFrame.sortYCache[b]
	end)

	local stackChanged = (activeCount ~= self.lastActiveCount)
	if not stackChanged then
		for i = 1, activeCount do
			local f = activePlates[i]
			if self.lastSortOrder[i] ~= f
				or f.isTarget ~= self.lastSortTarget[f]
				or f.kui.isMyPet ~= self.lastSortPet[f] then
				stackChanged = true
				break
			end
		end
	end

	if stackChanged then
		self.lastSortOrder = self.lastSortOrder or {}
		self.lastSortTarget = self.lastSortTarget or {}
		self.lastSortPet = self.lastSortPet or {}
		for i = 1, activeCount do
			local f = activePlates[i]
			self.lastSortOrder[i] = f
			self.lastSortTarget[f] = f.isTarget
			self.lastSortPet[f] = f.kui.isMyPet
		end
		for i = activeCount + 1, table_getn(self.lastSortOrder) do
			self.lastSortOrder[i] = nil
		end
		self.lastActiveCount = activeCount
		UPApplyFrameLevelStack(activePlates, activeCount)
	end
end)
--MAIN LOOP END