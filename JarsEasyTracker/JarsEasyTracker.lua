-- Jar's Easy Tracker for WoW 12.0.1
-- Mini WeakAuras-style tracker for icons and progress bars

--------------------------------------------------------------------------------
-- Section 1: Header & Locals
--------------------------------------------------------------------------------

JarsEasyTrackerCharDB = JarsEasyTrackerCharDB or {}
JarsEasyTrackerDB = JarsEasyTrackerDB or {}

-- Modern UI Color Palette
local UI_PALETTE = {
    bg = {0.10, 0.10, 0.12, 0.95},
    header = {0.15, 0.15, 0.18, 1},
    accent = {0.30, 0.75, 0.75, 1},
    text = {0.95, 0.95, 0.95, 1},
    textDim = {0.70, 0.70, 0.70, 1},
    border = {0.20, 0.20, 0.22, 1},
}

local modernBackdrop = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

local displayFrames = {}
local groupFrames = {}
local elementStates = {}
local configFrame
local selectedElementId
local selectedGroupId
local eventFrame
local leftPanelEntries = {}

-- Forward declarations
local RefreshAllDisplays, UpdateDisplay, DestroyDisplay, CreateDisplay
local RefreshLeftPanel, PopulateRightPanel, PopulateGroupPanel, ClearRightPanel
local UpdateGroupLayout, RegisterDynamicEvents
local UpdateAuraElement, UpdateSpellDataElement

--------------------------------------------------------------------------------
-- Section 2: Constants
--------------------------------------------------------------------------------

local BAR_TEXTURES = {
    ["Blizzard"] = "Interface\\TargetingFrame\\UI-StatusBar",
    ["Smooth"] = "Interface\\Buttons\\WHITE8X8",
    ["Minimalist"] = "Interface\\ChatFrame\\ChatFrameBackground",
}

local CLASS_LIST = {
    "DEATHKNIGHT", "DEMONHUNTER", "DRUID", "EVOKER", "HUNTER",
    "MAGE", "MONK", "PALADIN", "PRIEST", "ROGUE",
    "SHAMAN", "WARLOCK", "WARRIOR",
}

local CLASS_DISPLAY = {
    DEATHKNIGHT = "Death Knight", DEMONHUNTER = "Demon Hunter", DRUID = "Druid",
    EVOKER = "Evoker", HUNTER = "Hunter", MAGE = "Mage", MONK = "Monk",
    PALADIN = "Paladin", PRIEST = "Priest", ROGUE = "Rogue",
    SHAMAN = "Shaman", WARLOCK = "Warlock", WARRIOR = "Warrior",
}

local INSTANCE_TYPES = {
    { key = "none", label = "Open World" },
    { key = "party", label = "Dungeon" },
    { key = "raid", label = "Raid" },
    { key = "arena", label = "Arena" },
    { key = "pvp", label = "Battleground" },
}

local FONT_POSITIONS = {
    { key = "CENTER", label = "Center", point = "CENTER", x = 0, y = 0 },
    { key = "BOTTOM", label = "Bottom", point = "BOTTOM", x = 0, y = 2 },
    { key = "TOP", label = "Top", point = "TOP", x = 0, y = -2 },
    { key = "ABOVE", label = "Above (outside)", point = "BOTTOM", relPoint = "TOP", x = 0, y = 2 },
    { key = "BELOW", label = "Below (outside)", point = "TOP", relPoint = "BOTTOM", x = 0, y = -2 },
    { key = "LEFT", label = "Left (outside)", point = "RIGHT", relPoint = "LEFT", x = -2, y = 0 },
    { key = "RIGHT", label = "Right (outside)", point = "LEFT", relPoint = "RIGHT", x = 2, y = 0 },
}

local function FindFontPosition(key)
    for _, pos in ipairs(FONT_POSITIONS) do
        if pos.key == key then return pos end
    end
    return FONT_POSITIONS[1]  -- default to CENTER
end

local GLOW_STYLES = {
    { key = "glow", label = "Static Glow" },
    { key = "pulse", label = "Pulse Glow" },
    { key = "proc", label = "Proc Glow" },
    { key = "border", label = "Highlight Border" },
}

local function FindGlowStyle(key)
    for _, style in ipairs(GLOW_STYLES) do
        if style.key == key then return style end
    end
    return GLOW_STYLES[1]
end

local DEFAULT_ELEMENT = {
    name = "New Tracker",
    enabled = true,
    elementType = "icon",
    positioning = "independent",
    groupId = nil,
    position = { point = "CENTER", x = 0, y = 0 },
    iconSpellId = nil,
    iconTexture = nil,
    iconSize = 48,
    showStacks = true,
    showTimer = true,
    stackFontSize = 28,
    timerFontSize = 14,
    desaturateInactive = true,
    showGlow = false,
    glowStyle = "glow",
    groupOrder = 0,
    stackPosition = "CENTER",
    timerPosition = "BOTTOM",
    iconAlpha = 1.0,
    barWidth = 150,
    barHeight = 20,
    barTexture = "Blizzard",
    barColor = { r = 0.2, g = 0.6, b = 1.0 },
    barBgColor = { r = 0, g = 0, b = 0, a = 0.5 },
    showBarText = true,
    showBarTimer = true,
    barFontSize = 12,
    triggerType = "spellcast",
    spellcast = {
        addRules = {},
        clearRules = {},
        maxStacks = 4,
        duration = 20,
    },
    aura = {
        spellId = 0,
        unit = "player",
        showStacks = true,
        showDuration = true,
    },
    spelldata = {
        actionSlot = 0,
    },
    loadConditions = {
        class = nil,
        specIndex = nil,
        talentSpellId = nil,
        inCombat = nil,
        inGroup = nil,
        instanceType = nil,
        playerName = nil,
    },
}

local DEFAULT_GROUP = {
    name = "Group",
    position = { point = "CENTER", x = 0, y = 0 },
    layout = "horizontal",
    spacing = 4,
    locked = true,
    loadConditions = {
        class = nil,
        specIndex = nil,
        talentSpellId = nil,
        inCombat = nil,
        inGroup = nil,
        instanceType = nil,
        playerName = nil,
    },
}

--------------------------------------------------------------------------------
-- Section 3: Utility Functions
--------------------------------------------------------------------------------

local function DeepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = DeepCopy(v)
    end
    return copy
end

local function GenerateId()
    local id = JarsEasyTrackerCharDB.nextId or 1
    JarsEasyTrackerCharDB.nextId = id + 1
    return id
end

local function GenerateGroupId()
    local id = JarsEasyTrackerCharDB.nextGroupId or 1
    JarsEasyTrackerCharDB.nextGroupId = id + 1
    return id
end

local function FindElementById(id)
    for i, elem in ipairs(JarsEasyTrackerCharDB.elements) do
        if elem.id == id then
            return elem, i
        end
    end
    return nil
end

local function FindGroupById(id)
    for i, grp in ipairs(JarsEasyTrackerCharDB.groups) do
        if grp.id == id then
            return grp, i
        end
    end
    return nil
end

-- Simple serialization for import/export
local function SerializeElement(element)
    local function SerializeValue(val)
        if type(val) == "string" then
            return string.format("%q", val)
        elseif type(val) == "number" then
            return tostring(val)
        elseif type(val) == "boolean" then
            return val and "true" or "false"
        elseif type(val) == "nil" then
            return "nil"
        elseif type(val) == "table" then
            local parts = {}
            -- Check if array-like
            local isArray = true
            local maxN = 0
            for k in pairs(val) do
                if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
                    isArray = false
                    break
                end
                if k > maxN then maxN = k end
            end
            if isArray and maxN == #val then
                for i = 1, #val do
                    parts[i] = SerializeValue(val[i])
                end
            else
                for k, v in pairs(val) do
                    local keyStr
                    if type(k) == "string" then
                        keyStr = k
                    else
                        keyStr = "[" .. tostring(k) .. "]"
                    end
                    table.insert(parts, keyStr .. "=" .. SerializeValue(v))
                end
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
        return "nil"
    end

    local copy = DeepCopy(element)
    copy.id = nil  -- Strip ID for export
    return "JET:" .. SerializeValue(copy)
end

local function DeserializeElement(str)
    if not str or not str:find("^JET:") then return nil end
    local dataStr = str:sub(5)
    -- Use loadstring to parse the serialized table (sandbox it)
    local func = loadstring("return " .. dataStr)
    if not func then return nil end
    -- Run in empty environment for safety
    setfenv(func, {})
    local ok, result = pcall(func)
    if ok and type(result) == "table" then
        return result
    end
    return nil
end

--------------------------------------------------------------------------------
-- Section 4: Load Condition Checker
--------------------------------------------------------------------------------

local function ShouldLoad(element)
    if element.enabled == false then return false end

    local lc = element.loadConditions
    if not lc then return true end

    -- Class check
    if lc.class then
        local _, playerClass = UnitClass("player")
        if playerClass ~= lc.class then return false end
    end

    -- Spec check
    if lc.specIndex then
        local currentSpec = GetSpecialization()
        if currentSpec ~= lc.specIndex then return false end
    end

    -- Talent check (spell ID must be known)
    if lc.talentSpellId and lc.talentSpellId > 0 then
        if not IsPlayerSpell(lc.talentSpellId) then return false end
    end

    -- Combat check
    if lc.inCombat == true then
        if not UnitAffectingCombat("player") then return false end
    elseif lc.inCombat == false then
        if UnitAffectingCombat("player") then return false end
    end

    -- Group check
    if lc.inGroup then
        if lc.inGroup == "solo" then
            if IsInGroup() then return false end
        elseif lc.inGroup == "group" then
            if not IsInGroup() or IsInRaid() then return false end
        elseif lc.inGroup == "raid" then
            if not IsInRaid() then return false end
        end
    end

    -- Instance check
    if lc.instanceType then
        local _, instanceType = GetInstanceInfo()
        if lc.instanceType == "none" then
            if instanceType ~= "none" then return false end
        else
            if instanceType ~= lc.instanceType then return false end
        end
    end

    -- Player name check
    if lc.playerName and lc.playerName ~= "" then
        local name = UnitName("player")
        if name ~= lc.playerName then return false end
    end

    return true
end

-- Collect and sort group members by groupOrder
local function GetGroupMembersSorted(groupId, requireLoaded)
    local members = {}
    for _, element in ipairs(JarsEasyTrackerCharDB.elements) do
        if element.positioning == "grouped" and element.groupId == groupId then
            if not requireLoaded or ShouldLoad(element) then
                table.insert(members, element)
            end
        end
    end
    table.sort(members, function(a, b)
        return (a.groupOrder or 0) < (b.groupOrder or 0)
    end)
    return members
end

-- Get the next groupOrder value for a group
local function GetNextGroupOrder(groupId)
    local maxOrder = 0
    for _, element in ipairs(JarsEasyTrackerCharDB.elements) do
        if element.positioning == "grouped" and element.groupId == groupId then
            if (element.groupOrder or 0) > maxOrder then
                maxOrder = element.groupOrder or 0
            end
        end
    end
    return maxOrder + 1
end

--------------------------------------------------------------------------------
-- Section 5: Trigger Engine — State Management
--------------------------------------------------------------------------------

local function InitElementState(element)
    elementStates[element.id] = {
        stacks = 0,
        duration = 0,
        expirationTime = 0,
        active = false,
        -- spelldata specific
        cooldownStart = 0,
        cooldownDuration = 0,
        charges = 0,
        maxCharges = 0,
        chargeCooldownStart = 0,
        chargeCooldownDuration = 0,
    }
end

local function GetElementState(elementId)
    return elementStates[elementId]
end

--------------------------------------------------------------------------------
-- Section 6: Trigger Engine — Spellcast Handler
--------------------------------------------------------------------------------

local function OnSpellCastSucceeded(spellId)
    for _, element in ipairs(JarsEasyTrackerCharDB.elements) do
        if element.triggerType == "spellcast" and ShouldLoad(element) then
            local state = GetElementState(element.id)
            if not state then
                InitElementState(element)
                state = GetElementState(element.id)
            end

            local sc = element.spellcast

            -- Check clear rules first (so clear takes priority if same spell)
            local cleared = false
            for _, rule in ipairs(sc.clearRules) do
                if rule.spellId == spellId then
                    local clearAmount = rule.stacks or 0
                    if clearAmount > 0 then
                        state.stacks = math.max(0, state.stacks - clearAmount)
                    else
                        state.stacks = 0
                    end
                    if state.stacks == 0 then
                        state.expirationTime = 0
                        state.duration = 0
                        state.active = false
                    end
                    cleared = true
                    break
                end
            end

            -- Check add rules
            if not cleared then
                for _, rule in ipairs(sc.addRules) do
                    if rule.spellId == spellId then
                        local addAmount = rule.stacks or 1
                        state.stacks = math.min(state.stacks + addAmount, sc.maxStacks)
                        if sc.duration and sc.duration > 0 then
                            state.duration = sc.duration
                            state.expirationTime = GetTime() + sc.duration
                        end
                        state.active = true
                        break
                    end
                end
            end

            UpdateDisplay(element)
        end
    end
end

--------------------------------------------------------------------------------
-- Section 7: Trigger Engine — Aura Handler
--------------------------------------------------------------------------------

UpdateAuraElement = function(element, state)
    if not element.aura or not element.aura.spellId or element.aura.spellId == 0 then
        state.active = false
        return
    end

    local auraData
    if element.aura.unit == "player" then
        auraData = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID and
                   C_UnitAuras.GetPlayerAuraBySpellID(element.aura.spellId)
    end

    if auraData then
        state.stacks = auraData.applications or 0
        state.duration = auraData.duration or 0
        state.expirationTime = auraData.expirationTime or 0
        state.active = true
    else
        state.stacks = 0
        state.duration = 0
        state.expirationTime = 0
        state.active = false
    end
end

--------------------------------------------------------------------------------
-- Section 8: Trigger Engine — SpellData Handler
--------------------------------------------------------------------------------

UpdateSpellDataElement = function(element, state)
    if not element.spelldata or not element.spelldata.actionSlot or element.spelldata.actionSlot == 0 then
        state.active = false
        state.overlayActive = false
        return
    end
    local actionSlot = element.spelldata.actionSlot
    if HasAction(actionSlot) then
        local actionType, id = GetActionInfo(actionSlot)
        state.actionSpellId = (actionType == "spell") and id or nil
        state.active = true
        -- Check if the spell currently has an overlay glow active
        if state.actionSpellId and IsSpellOverlayed and IsSpellOverlayed(state.actionSpellId) then
            state.overlayActive = true
        elseif not state.overlayActive then
            state.overlayActive = false
        end
    else
        state.active = false
        state.overlayActive = false
    end
end

--------------------------------------------------------------------------------
-- Section 8b: Mover Overlay (anchored to display frames when unlocked)
--------------------------------------------------------------------------------

local function CreateMoverOverlay(f)
    if f.moverOverlay then return f.moverOverlay end

    local overlay = CreateFrame("Frame", nil, f)
    overlay:SetPoint("TOP", f, "BOTTOM", 0, -2)
    overlay:SetSize(190, 24)
    overlay:SetFrameStrata("TOOLTIP")

    -- Background
    local bg = overlay:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.75)

    -- Border
    local border = overlay:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0.4, 0.4, 0.4, 0.6)

    -- Coordinate text
    overlay.coordText = overlay:CreateFontString(nil, "OVERLAY")
    overlay.coordText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    overlay.coordText:SetPoint("LEFT", 6, 0)
    overlay.coordText:SetTextColor(1, 1, 1, 1)

    -- Arrow buttons (right-aligned): [<] [>]  [^] [v]
    local btnSize = 20

    local nudgeDown = CreateFrame("Button", nil, overlay, "UIPanelButtonTemplate")
    nudgeDown:SetSize(btnSize, btnSize)
    nudgeDown:SetPoint("RIGHT", -3, 0)
    nudgeDown:SetText("v")

    local nudgeUp = CreateFrame("Button", nil, overlay, "UIPanelButtonTemplate")
    nudgeUp:SetSize(btnSize, btnSize)
    nudgeUp:SetPoint("RIGHT", nudgeDown, "LEFT", -1, 0)
    nudgeUp:SetText("^")

    local nudgeRight = CreateFrame("Button", nil, overlay, "UIPanelButtonTemplate")
    nudgeRight:SetSize(btnSize, btnSize)
    nudgeRight:SetPoint("RIGHT", nudgeUp, "LEFT", -6, 0)
    nudgeRight:SetText(">")

    local nudgeLeft = CreateFrame("Button", nil, overlay, "UIPanelButtonTemplate")
    nudgeLeft:SetSize(btnSize, btnSize)
    nudgeLeft:SetPoint("RIGHT", nudgeRight, "LEFT", -1, 0)
    nudgeLeft:SetText("<")

    function overlay:UpdateCoords(x, y)
        self.coordText:SetText(string.format("X: %.0f  Y: %.0f", x, y))
    end

    -- Nudge callback — set by the caller via overlay:SetNudgeCallback(fn)
    overlay.nudgeCb = nil
    function overlay:SetNudgeCallback(cb)
        self.nudgeCb = cb
    end

    local function DoNudge(dx, dy)
        if overlay.nudgeCb then
            overlay.nudgeCb(dx, dy)
        end
    end

    nudgeLeft:SetScript("OnClick", function() DoNudge(-1, 0) end)
    nudgeRight:SetScript("OnClick", function() DoNudge(1, 0) end)
    nudgeUp:SetScript("OnClick", function() DoNudge(0, 1) end)
    nudgeDown:SetScript("OnClick", function() DoNudge(0, -1) end)

    overlay:Hide()
    f.moverOverlay = overlay
    return overlay
end

local function ShowMoverOverlay(f, positionTable)
    local overlay = CreateMoverOverlay(f)
    overlay:SetNudgeCallback(function(dx, dy)
        positionTable.x = positionTable.x + dx
        positionTable.y = positionTable.y + dy
        overlay:UpdateCoords(positionTable.x, positionTable.y)
        f:ClearAllPoints()
        f:SetPoint(positionTable.point, UIParent, positionTable.point, positionTable.x, positionTable.y)
    end)
    overlay:UpdateCoords(positionTable.x, positionTable.y)
    overlay:Show()
end

local function HideMoverOverlay(f)
    if f.moverOverlay then
        f.moverOverlay:Hide()
    end
end

--------------------------------------------------------------------------------
-- Section 9: Display — Icon Element
--------------------------------------------------------------------------------

local function ShowGlowEffect(f, style)
    if not f then return end
    -- Hide all glow types first
    if f.glow then f.glow:Hide() end
    if f.glowPulseAG then f.glowPulseAG:Stop() end
    if f.glowAnts then f.glowAnts:Hide() end
    if f.glowAntsAG then f.glowAntsAG:Stop() end
    if f.glowProcAG then f.glowProcAG:Stop() end
    if f.glowBorder then f.glowBorder:Hide() end

    if style == "glow" then
        if f.glow then f.glow:Show() end
    elseif style == "pulse" then
        if f.glow then
            f.glow:Show()
            if f.glowPulseAG then f.glowPulseAG:Play() end
        end
    elseif style == "proc" then
        if f.glow then
            f.glow:Show()
            if f.glowProcAG then f.glowProcAG:Play() end
        end
        if f.glowAnts then
            f.glowAnts:Show()
            if f.glowAntsAG then f.glowAntsAG:Play() end
        end
    elseif style == "border" then
        if f.glowBorder then f.glowBorder:Show() end
    end
end

local function HideGlowEffect(f)
    if not f then return end
    if f.glow then f.glow:Hide() end
    if f.glowPulseAG then f.glowPulseAG:Stop() end
    if f.glowAnts then f.glowAnts:Hide() end
    if f.glowAntsAG then f.glowAntsAG:Stop() end
    if f.glowProcAG then f.glowProcAG:Stop() end
    if f.glowBorder then f.glowBorder:Hide() end
end

local function CreateIconDisplay(element)
    local f = CreateFrame("Frame", "JET_Icon_" .. element.id, UIParent)
    f:SetSize(element.iconSize, element.iconSize)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f.elementId = element.id

    -- Icon texture
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()
    f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    -- Set texture
    local texturePath
    if element.iconSpellId and element.iconSpellId > 0 then
        texturePath = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(element.iconSpellId)
    end
    if not texturePath and element.iconTexture then
        texturePath = element.iconTexture
    end
    if texturePath then
        f.icon:SetTexture(texturePath)
    else
        f.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end

    -- Border (at BORDER layer so it sits below the icon at ARTWORK)
    f.border = f:CreateTexture(nil, "BORDER")
    f.border:SetPoint("TOPLEFT", -1, 1)
    f.border:SetPoint("BOTTOMRIGHT", 1, -1)
    f.border:SetColorTexture(0.3, 0.3, 0.3, 0.8)

    -- Background (behind icon, acts as border fill)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetPoint("TOPLEFT", -1, 1)
    f.bg:SetPoint("BOTTOMRIGHT", 1, -1)
    f.bg:SetColorTexture(0, 0, 0, 0.8)

    -- Stack text (positioned via element settings)
    f.stackText = f:CreateFontString(nil, "OVERLAY")
    f.stackText:SetFont("Fonts\\FRIZQT__.TTF", element.stackFontSize, "OUTLINE")
    f.stackText:SetTextColor(1, 1, 1, 1)
    local stackPos = FindFontPosition(element.stackPosition or "CENTER")
    if stackPos.relPoint then
        f.stackText:SetPoint(stackPos.point, f, stackPos.relPoint, stackPos.x, stackPos.y)
    else
        f.stackText:SetPoint(stackPos.point, stackPos.x, stackPos.y)
    end

    -- Timer text (positioned via element settings)
    f.timerText = f:CreateFontString(nil, "OVERLAY")
    f.timerText:SetFont("Fonts\\FRIZQT__.TTF", element.timerFontSize, "OUTLINE")
    f.timerText:SetTextColor(1, 1, 0, 1)
    local timerPos = FindFontPosition(element.timerPosition or "BOTTOM")
    if timerPos.relPoint then
        f.timerText:SetPoint(timerPos.point, f, timerPos.relPoint, timerPos.x, timerPos.y)
    else
        f.timerText:SetPoint(timerPos.point, timerPos.x, timerPos.y)
    end

    -- Glow overlays (multiple styles) — use a child frame so glow renders above the icon
    local glowPad = math.max(10, element.iconSize * 0.25)

    f.glowFrame = CreateFrame("Frame", nil, f)
    f.glowFrame:SetAllPoints()
    f.glowFrame:SetFrameLevel(f:GetFrameLevel() + 5)

    -- Style: glow (static) / pulse / proc — all use this base texture
    f.glow = f.glowFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    f.glow:SetPoint("TOPLEFT", f, "TOPLEFT", -glowPad, glowPad)
    f.glow:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", glowPad, -glowPad)
    f.glow:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
    f.glow:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
    f.glow:SetBlendMode("ADD")
    f.glow:SetAlpha(1.0)
    f.glow:Hide()

    -- Pulse animation group (for "pulse" style)
    f.glowPulseAG = f.glow:CreateAnimationGroup()
    local pulseOut = f.glowPulseAG:CreateAnimation("Alpha")
    pulseOut:SetFromAlpha(1.0)
    pulseOut:SetToAlpha(0.4)
    pulseOut:SetDuration(0.6)
    pulseOut:SetOrder(1)
    pulseOut:SetSmoothing("IN_OUT")
    local pulseIn = f.glowPulseAG:CreateAnimation("Alpha")
    pulseIn:SetFromAlpha(0.4)
    pulseIn:SetToAlpha(1.0)
    pulseIn:SetDuration(0.6)
    pulseIn:SetOrder(2)
    pulseIn:SetSmoothing("IN_OUT")
    f.glowPulseAG:SetLooping("REPEAT")

    -- Proc glow animation (alpha throb on base glow for "proc" style)
    f.glowProcAG = f.glow:CreateAnimationGroup()
    local procAlphaOut = f.glowProcAG:CreateAnimation("Alpha")
    procAlphaOut:SetFromAlpha(1.0)
    procAlphaOut:SetToAlpha(0.5)
    procAlphaOut:SetDuration(0.4)
    procAlphaOut:SetOrder(1)
    procAlphaOut:SetSmoothing("IN_OUT")
    local procAlphaIn = f.glowProcAG:CreateAnimation("Alpha")
    procAlphaIn:SetFromAlpha(0.5)
    procAlphaIn:SetToAlpha(1.0)
    procAlphaIn:SetDuration(0.4)
    procAlphaIn:SetOrder(2)
    procAlphaIn:SetSmoothing("IN_OUT")
    f.glowProcAG:SetLooping("REPEAT")

    -- Proc ants texture (spinning sparkle border for "proc" style)
    f.glowAnts = f.glowFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    f.glowAnts:SetPoint("TOPLEFT", f, "TOPLEFT", -glowPad, glowPad)
    f.glowAnts:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", glowPad, -glowPad)
    f.glowAnts:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
    f.glowAnts:SetTexCoord(0.00781250, 0.50781250, 0.53515625, 0.78515625)
    f.glowAnts:SetBlendMode("ADD")
    f.glowAnts:SetAlpha(0.8)
    f.glowAnts:Hide()

    -- Ants rotation animation
    f.glowAntsAG = f.glowAnts:CreateAnimationGroup()
    local antsRot = f.glowAntsAG:CreateAnimation("Rotation")
    antsRot:SetDegrees(-360)
    antsRot:SetDuration(6)
    f.glowAntsAG:SetLooping("REPEAT")

    -- Border highlight style
    f.glowBorder = f.glowFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    f.glowBorder:SetPoint("TOPLEFT", f, "TOPLEFT", -3, 3)
    f.glowBorder:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 3, -3)
    f.glowBorder:SetColorTexture(1, 0.82, 0, 0.6)
    f.glowBorder:Hide()

    -- Cooldown sweep overlay (for spelldata action bar style)
    f.cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cooldown:SetAllPoints(f.icon)
    f.cooldown:SetDrawEdge(false)

    -- Unlock indicator
    f.unlockBorder = f:CreateTexture(nil, "OVERLAY", nil, 7)
    f.unlockBorder:SetPoint("TOPLEFT", -2, 2)
    f.unlockBorder:SetPoint("BOTTOMRIGHT", 2, -2)
    f.unlockBorder:SetColorTexture(1, 1, 0, 0.3)
    f.unlockBorder:Hide()

    -- Drag handling
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if not JarsEasyTrackerCharDB.locked or self.manualUnlock then
            self:StartMoving()
        end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        local elem = FindElementById(self.elementId)
        if elem then
            elem.position.point = point
            elem.position.x = x
            elem.position.y = y
            if self.moverOverlay and self.moverOverlay:IsShown() then
                self.moverOverlay:UpdateCoords(x, y)
            end
        end
    end)

    -- OnUpdate for timer
    f:SetScript("OnUpdate", function(self, elapsed)
        local state = GetElementState(self.elementId)
        if not state then return end

        local elem = FindElementById(self.elementId)
        if not elem then return end

        -- Timer display (not for spelldata — cooldown frame handles it)
        if elem.triggerType ~= "spelldata" then
            if elem.showTimer and state.expirationTime > 0 then
                local remaining = state.expirationTime - GetTime()
                if remaining > 0 then
                    self.timerText:SetText(string.format("%.1f", remaining))
                    self.timerText:Show()
                else
                    self.timerText:SetText("")
                    self.timerText:Hide()
                    -- Auto-expire for spellcast triggers
                    if elem.triggerType == "spellcast" then
                        state.stacks = 0
                        state.expirationTime = 0
                        state.duration = 0
                        state.active = false
                        UpdateDisplay(elem)
                    end
                end
            else
                self.timerText:Hide()
            end
        end

        -- Update aura/spelldata on each frame (throttled internally by WoW)
        if elem.triggerType == "aura" then
            UpdateAuraElement(elem, state)
            -- Update stack display
            if elem.showStacks and state.stacks > 0 then
                self.stackText:SetText(tostring(state.stacks))
                self.stackText:Show()
            else
                self.stackText:Hide()
            end
            -- Update active/inactive visual
            if state.active then
                self.icon:SetDesaturated(false)
                self:SetAlpha(elem.iconAlpha or 1)
                if elem.showGlow then
                    ShowGlowEffect(self, elem.glowStyle or "glow")
                else
                    HideGlowEffect(self)
                end
            elseif elem.desaturateInactive then
                self.icon:SetDesaturated(true)
                self:SetAlpha(0.5)
                HideGlowEffect(self)
            else
                self:Hide()
            end
        elseif elem.triggerType == "spelldata" then
            local actionSlot = elem.spelldata and elem.spelldata.actionSlot
            if actionSlot and actionSlot > 0 and HasAction(actionSlot) then
                -- Update spell ID for glow event matching
                UpdateSpellDataElement(elem, state)

                -- Update texture
                local texture = GetActionTexture(actionSlot)
                if texture and self._lastTexture ~= texture then
                    self.icon:SetTexture(texture)
                    self._lastTexture = texture
                end

                -- Cooldown - pass directly, CooldownFrame handles secrets
                if self.cooldown then
                    if C_ActionBar and C_ActionBar.GetActionCooldown then
                        local cooldownInfo = C_ActionBar.GetActionCooldown(actionSlot)
                        if cooldownInfo and cooldownInfo.startTime and cooldownInfo.duration then
                            self.cooldown:SetCooldown(cooldownInfo.startTime, cooldownInfo.duration)
                        end
                    else
                        local start, duration = GetActionCooldown(actionSlot)
                        if start and duration then
                            self.cooldown:SetCooldown(start, duration)
                        end
                    end
                    if not self.cooldown:IsShown() then
                        self.cooldown:Show()
                    end
                end

                -- Count display (charges, ammo, etc)
                if C_ActionBar and C_ActionBar.GetActionDisplayCount then
                    local displayCount = C_ActionBar.GetActionDisplayCount(actionSlot, 9999)
                    self.stackText:SetText(displayCount)
                    self.stackText:Show()
                else
                    local count = GetActionCount(actionSlot)
                    if count and count > 0 then
                        self.stackText:SetText(count)
                        self.stackText:Show()
                    else
                        self.stackText:Hide()
                    end
                end

                -- Usability (vertex color)
                pcall(function()
                    local isUsable, notEnoughMana = IsUsableAction(actionSlot)
                    if isUsable then
                        self.icon:SetVertexColor(1, 1, 1)
                    elseif notEnoughMana then
                        self.icon:SetVertexColor(0.5, 0.5, 1)
                    else
                        self.icon:SetVertexColor(0.4, 0.4, 0.4)
                    end
                end)

                -- Range check
                pcall(function()
                    local inRange = IsActionInRange(actionSlot)
                    if inRange == false then
                        self.icon:SetVertexColor(1, 0, 0)
                    end
                end)

                self.icon:SetDesaturated(false)
                self:SetAlpha(elem.iconAlpha or 1)
                self:Show()
                self.timerText:Hide()
                -- Glow managed by SPELL_ACTIVATION_OVERLAY events
            end
        end
    end)

    return f
end

local function UpdateIconDisplay(element, state, f)
    if not f then return end

    -- Update size
    f:SetSize(element.iconSize, element.iconSize)

    -- Update glow size to match icon
    local glowPad = math.max(10, element.iconSize * 0.25)
    if f.glow then
        f.glow:ClearAllPoints()
        f.glow:SetPoint("TOPLEFT", f, "TOPLEFT", -glowPad, glowPad)
        f.glow:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", glowPad, -glowPad)
    end
    if f.glowAnts then
        f.glowAnts:ClearAllPoints()
        f.glowAnts:SetPoint("TOPLEFT", f, "TOPLEFT", -glowPad, glowPad)
        f.glowAnts:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", glowPad, -glowPad)
    end

    -- Update texture
    local texturePath
    if element.iconSpellId and element.iconSpellId > 0 then
        texturePath = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(element.iconSpellId)
    end
    if not texturePath and element.iconTexture then
        texturePath = element.iconTexture
    end
    if texturePath then
        f.icon:SetTexture(texturePath)
    end

    -- Update fonts
    f.stackText:SetFont("Fonts\\FRIZQT__.TTF", element.stackFontSize, "OUTLINE")
    f.timerText:SetFont("Fonts\\FRIZQT__.TTF", element.timerFontSize, "OUTLINE")

    -- Update font positions
    f.stackText:ClearAllPoints()
    local stackPos = FindFontPosition(element.stackPosition or "CENTER")
    if stackPos.relPoint then
        f.stackText:SetPoint(stackPos.point, f, stackPos.relPoint, stackPos.x, stackPos.y)
    else
        f.stackText:SetPoint(stackPos.point, stackPos.x, stackPos.y)
    end

    f.timerText:ClearAllPoints()
    local timerPos = FindFontPosition(element.timerPosition or "BOTTOM")
    if timerPos.relPoint then
        f.timerText:SetPoint(timerPos.point, f, timerPos.relPoint, timerPos.x, timerPos.y)
    else
        f.timerText:SetPoint(timerPos.point, timerPos.x, timerPos.y)
    end

    -- Update stack display
    if element.showStacks and state.stacks > 0 then
        f.stackText:SetText(tostring(state.stacks))
        f.stackText:Show()
    else
        f.stackText:SetText("")
        f.stackText:Hide()
    end

    -- Desaturate/alpha/glow logic for all trigger types
    if element.triggerType == "spellcast" then
        if f.cooldown then f.cooldown:Hide() end
        if state.active and state.stacks > 0 then
            f.icon:SetDesaturated(false)
            f:SetAlpha(element.iconAlpha or 1)
            f:Show()
            if element.showGlow and state.stacks >= (element.spellcast.maxStacks or 0) then ShowGlowEffect(f, element.glowStyle or "glow") else HideGlowEffect(f) end
        elseif element.desaturateInactive then
            f.icon:SetDesaturated(true)
            f:SetAlpha(0.5)
            f:Show()
            HideGlowEffect(f)
        else
            f:Hide()
        end
    elseif element.triggerType == "aura" then
        if f.cooldown then f.cooldown:Hide() end
        if state.active then
            f.icon:SetDesaturated(false)
            f:SetAlpha(element.iconAlpha or 1)
            f:Show()
            if element.showGlow then ShowGlowEffect(f, element.glowStyle or "glow") else HideGlowEffect(f) end
        elseif element.desaturateInactive then
            f.icon:SetDesaturated(true)
            f:SetAlpha(0.5)
            f:Show()
            HideGlowEffect(f)
        else
            f:Hide()
        end
    elseif element.triggerType == "spelldata" then
        -- Action bar style: always visible, OnUpdate handles all data
        f.icon:SetDesaturated(false)
        f:SetAlpha(element.iconAlpha or 1)
        f:Show()
        -- Show/hide glow based on overlay state (set by SPELL_ACTIVATION events)
        if state.overlayActive then
            ShowGlowEffect(f, element.glowStyle or "glow")
        else
            HideGlowEffect(f)
        end
        if f.cooldown then f.cooldown:Show() end
    end

    -- Lock state
    if JarsEasyTrackerCharDB.locked and not f.manualUnlock then
        f:EnableMouse(false)
        f.unlockBorder:Hide()
        HideMoverOverlay(f)
    else
        f:EnableMouse(true)
        f.unlockBorder:Show()
        ShowMoverOverlay(f, element.position)
        if f.manualUnlock then
            f:Show()
        end
    end
end

--------------------------------------------------------------------------------
-- Section 10: Display — Progress Bar Element
--------------------------------------------------------------------------------

local function CreateBarDisplay(element)
    local f = CreateFrame("Frame", "JET_Bar_" .. element.id, UIParent)
    f:SetSize(element.barWidth, element.barHeight)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f.elementId = element.id

    -- Status bar
    f.bar = CreateFrame("StatusBar", nil, f)
    f.bar:SetAllPoints()
    f.bar:SetStatusBarTexture(BAR_TEXTURES[element.barTexture] or BAR_TEXTURES["Blizzard"])
    f.bar:SetStatusBarColor(element.barColor.r, element.barColor.g, element.barColor.b)
    f.bar:SetMinMaxValues(0, 1)
    f.bar:SetValue(0)

    -- Background
    f.bg = f.bar:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    local bgc = element.barBgColor
    f.bg:SetColorTexture(bgc.r, bgc.g, bgc.b, bgc.a or 0.5)

    -- Label text (left)
    f.labelText = f.bar:CreateFontString(nil, "OVERLAY")
    f.labelText:SetPoint("LEFT", 4, 0)
    f.labelText:SetFont("Fonts\\FRIZQT__.TTF", element.barFontSize, "OUTLINE")
    f.labelText:SetTextColor(1, 1, 1, 1)
    if element.showBarText then
        f.labelText:SetText(element.name)
    end

    -- Timer text (right)
    f.timerText = f.bar:CreateFontString(nil, "OVERLAY")
    f.timerText:SetPoint("RIGHT", -4, 0)
    f.timerText:SetFont("Fonts\\FRIZQT__.TTF", element.barFontSize, "OUTLINE")
    f.timerText:SetTextColor(1, 1, 1, 1)

    -- Unlock indicator
    f.unlockBorder = f:CreateTexture(nil, "OVERLAY", nil, 7)
    f.unlockBorder:SetPoint("TOPLEFT", -2, 2)
    f.unlockBorder:SetPoint("BOTTOMRIGHT", 2, -2)
    f.unlockBorder:SetColorTexture(1, 1, 0, 0.3)
    f.unlockBorder:Hide()

    -- Drag handling
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if not JarsEasyTrackerCharDB.locked or self.manualUnlock then
            self:StartMoving()
        end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        local elem = FindElementById(self.elementId)
        if elem then
            elem.position.point = point
            elem.position.x = x
            elem.position.y = y
            if self.moverOverlay and self.moverOverlay:IsShown() then
                self.moverOverlay:UpdateCoords(x, y)
            end
        end
    end)

    -- OnUpdate for bar drain and timer
    f:SetScript("OnUpdate", function(self, elapsed)
        local state = GetElementState(self.elementId)
        if not state then return end

        local elem = FindElementById(self.elementId)
        if not elem then return end

        -- Update aura/spelldata
        if elem.triggerType == "aura" then
            UpdateAuraElement(elem, state)
        elseif elem.triggerType == "spelldata" then
            UpdateSpellDataElement(elem, state)
        end

        -- Bar value and timer
        if state.expirationTime > 0 and state.duration > 0 then
            local remaining = state.expirationTime - GetTime()
            if remaining > 0 then
                self.bar:SetValue(remaining / state.duration)
                if elem.showBarTimer then
                    self.timerText:SetText(string.format("%.1f", remaining))
                end
                self:Show()
            else
                self.bar:SetValue(0)
                self.timerText:SetText("")
                -- Auto-expire for spellcast
                if elem.triggerType == "spellcast" then
                    state.stacks = 0
                    state.expirationTime = 0
                    state.duration = 0
                    state.active = false
                end
                if not (not JarsEasyTrackerCharDB.locked or self.manualUnlock) then
                    self:Hide()
                end
            end
        elseif state.active and elem.triggerType == "spellcast" and state.stacks > 0 then
            -- Active with stacks but no timer
            self.bar:SetValue(state.stacks / (elem.spellcast.maxStacks or 1))
            self.timerText:SetText("")
            self:Show()
        else
            self.bar:SetValue(0)
            self.timerText:SetText("")
            if not state.active then
                if not (not JarsEasyTrackerCharDB.locked or self.manualUnlock) then
                    self:Hide()
                end
            end
        end

        -- Label
        if elem.showBarText then
            if state.stacks > 0 then
                self.labelText:SetText(elem.name .. " (" .. state.stacks .. ")")
            else
                self.labelText:SetText(elem.name)
            end
        end
    end)

    return f
end

local function UpdateBarDisplay(element, state, f)
    if not f then return end

    f:SetSize(element.barWidth, element.barHeight)
    f.bar:SetStatusBarTexture(BAR_TEXTURES[element.barTexture] or BAR_TEXTURES["Blizzard"])
    f.bar:SetStatusBarColor(element.barColor.r, element.barColor.g, element.barColor.b)
    local bgc = element.barBgColor
    f.bg:SetColorTexture(bgc.r, bgc.g, bgc.b, bgc.a or 0.5)
    f.labelText:SetFont("Fonts\\FRIZQT__.TTF", element.barFontSize, "OUTLINE")
    f.timerText:SetFont("Fonts\\FRIZQT__.TTF", element.barFontSize, "OUTLINE")

    if element.showBarText then
        f.labelText:SetText(element.name)
        f.labelText:Show()
    else
        f.labelText:Hide()
    end

    -- Lock state
    if JarsEasyTrackerCharDB.locked and not f.manualUnlock then
        f:EnableMouse(false)
        f.unlockBorder:Hide()
        HideMoverOverlay(f)
    else
        f:EnableMouse(true)
        f.unlockBorder:Show()
        ShowMoverOverlay(f, element.position)
        if f.manualUnlock then
            f:Show()
        end
    end

    -- Visibility
    if state.active or (state.stacks and state.stacks > 0) then
        f:Show()
    elseif not JarsEasyTrackerCharDB.locked or f.manualUnlock then
        f:Show()
    else
        f:Hide()
    end
end

--------------------------------------------------------------------------------
-- Section 11: Display Manager
--------------------------------------------------------------------------------

CreateDisplay = function(element)
    if displayFrames[element.id] then
        DestroyDisplay(element)
    end

    if not elementStates[element.id] then
        InitElementState(element)
    end

    local f
    if element.elementType == "icon" then
        f = CreateIconDisplay(element)
    elseif element.elementType == "progressbar" then
        f = CreateBarDisplay(element)
    end

    if f then
        -- Position
        if element.positioning == "independent" then
            local pos = element.position
            f:ClearAllPoints()
            f:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
        end
        -- Will be repositioned by group layout if grouped

        displayFrames[element.id] = f
        UpdateDisplay(element)
    end
end

UpdateDisplay = function(element)
    local f = displayFrames[element.id]
    if not f then return end

    local state = GetElementState(element.id)
    if not state then
        InitElementState(element)
        state = GetElementState(element.id)
    end

    if not ShouldLoad(element) then
        f:Hide()
        return
    end

    if element.elementType == "icon" then
        UpdateIconDisplay(element, state, f)
    elseif element.elementType == "progressbar" then
        UpdateBarDisplay(element, state, f)
    end
end

DestroyDisplay = function(element)
    local f = displayFrames[element.id]
    if f then
        f:Hide()
        f:SetScript("OnUpdate", nil)
        f:SetParent(nil)
        displayFrames[element.id] = nil
    end
end

RefreshAllDisplays = function()
    -- Destroy all existing displays
    for id, f in pairs(displayFrames) do
        f:Hide()
        f:SetScript("OnUpdate", nil)
        f:SetParent(nil)
    end
    wipe(displayFrames)

    -- Destroy group frames
    for id, f in pairs(groupFrames) do
        f:Hide()
        f:SetParent(nil)
    end
    wipe(groupFrames)

    -- Create displays for loaded elements
    for _, element in ipairs(JarsEasyTrackerCharDB.elements) do
        if ShouldLoad(element) then
            CreateDisplay(element)
        end
    end

    -- Create and layout groups
    for _, group in ipairs(JarsEasyTrackerCharDB.groups) do
        UpdateGroupLayout(group)
    end

    RegisterDynamicEvents()
end

--------------------------------------------------------------------------------
-- Section 12: Group Container System
--------------------------------------------------------------------------------

local function CreateGroupContainer(group)
    if groupFrames[group.id] then return groupFrames[group.id] end

    local f = CreateFrame("Frame", "JET_Group_" .. group.id, UIParent)
    f:SetSize(10, 10)  -- Will be resized by layout
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f.groupId = group.id

    -- Unlock indicator
    f.unlockBorder = f:CreateTexture(nil, "OVERLAY", nil, 7)
    f.unlockBorder:SetPoint("TOPLEFT", -2, 2)
    f.unlockBorder:SetPoint("BOTTOMRIGHT", 2, -2)
    f.unlockBorder:SetColorTexture(0, 1, 0, 0.3)
    f.unlockBorder:Hide()

    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if not JarsEasyTrackerCharDB.locked or self.manualUnlock then
            self:StartMoving()
        end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        local grp = FindGroupById(self.groupId)
        if grp then
            grp.position.point = point
            grp.position.x = x
            grp.position.y = y
            if self.moverOverlay and self.moverOverlay:IsShown() then
                self.moverOverlay:UpdateCoords(x, y)
            end
        end
    end)

    -- Position
    local pos = group.position
    f:ClearAllPoints()
    f:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)

    groupFrames[group.id] = f
    return f
end

UpdateGroupLayout = function(group)
    -- Check group-level load conditions first
    if not ShouldLoad(group) then
        if groupFrames[group.id] then
            groupFrames[group.id]:Hide()
            HideMoverOverlay(groupFrames[group.id])
        end
        return
    end

    -- Find elements belonging to this group (sorted by groupOrder)
    local members = GetGroupMembersSorted(group.id, true)

    if #members == 0 then
        if groupFrames[group.id] then
            groupFrames[group.id]:Hide()
        end
        return
    end

    local container = CreateGroupContainer(group)
    container:Show()

    -- Lock state
    if JarsEasyTrackerCharDB.locked and not container.manualUnlock then
        container:EnableMouse(false)
        container.unlockBorder:Hide()
        HideMoverOverlay(container)
    else
        container:EnableMouse(true)
        container.unlockBorder:Show()
        ShowMoverOverlay(container, group.position)
    end

    -- Calculate total size and position children
    local totalWidth, totalHeight = 0, 0
    local spacing = group.spacing or 4

    for i, element in ipairs(members) do
        local df = displayFrames[element.id]
        if df then
            df:ClearAllPoints()
            df:SetParent(container)

            local w = df:GetWidth()
            local h = df:GetHeight()

            if group.layout == "horizontal" then
                df:SetPoint("TOPLEFT", container, "TOPLEFT", totalWidth, 0)
                totalWidth = totalWidth + w + (i < #members and spacing or 0)
                if h > totalHeight then totalHeight = h end
            else -- vertical
                df:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -totalHeight)
                totalHeight = totalHeight + h + (i < #members and spacing or 0)
                if w > totalWidth then totalWidth = w end
            end
        end
    end

    container:SetSize(math.max(totalWidth, 1), math.max(totalHeight, 1))
end

--------------------------------------------------------------------------------
-- Section 13: Event Handler
--------------------------------------------------------------------------------

RegisterDynamicEvents = function()
    if not eventFrame then return end

    -- Unregister dynamic events first
    pcall(function() eventFrame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED") end)
    pcall(function() eventFrame:UnregisterEvent("UNIT_AURA") end)
    pcall(function() eventFrame:UnregisterEvent("SPELL_UPDATE_COOLDOWN") end)
    pcall(function() eventFrame:UnregisterEvent("SPELL_UPDATE_CHARGES") end)
    pcall(function() eventFrame:UnregisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW") end)
    pcall(function() eventFrame:UnregisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE") end)
    pcall(function() eventFrame:UnregisterEvent("ACTIONBAR_SLOT_CHANGED") end)
    pcall(function() eventFrame:UnregisterEvent("ACTIONBAR_UPDATE_STATE") end)
    pcall(function() eventFrame:UnregisterEvent("ACTIONBAR_UPDATE_USABLE") end)
    pcall(function() eventFrame:UnregisterEvent("ACTIONBAR_UPDATE_COOLDOWN") end)

    local needSpellcast = false
    local needAura = false
    local needSpelldata = false

    for _, element in ipairs(JarsEasyTrackerCharDB.elements) do
        if element.enabled then
            if element.triggerType == "spellcast" then
                needSpellcast = true
            elseif element.triggerType == "aura" then
                needAura = true
            elseif element.triggerType == "spelldata" then
                needSpelldata = true
            end
        end
    end

    if needSpellcast then
        eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    end
    if needAura then
        eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
    end
    if needSpelldata then
        eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        eventFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
        eventFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
        eventFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
        eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
        eventFrame:RegisterEvent("ACTIONBAR_UPDATE_STATE")
        eventFrame:RegisterEvent("ACTIONBAR_UPDATE_USABLE")
        eventFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
    end
end

eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("SPELLS_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        -- InitDB
        if not JarsEasyTrackerCharDB.elements then
            JarsEasyTrackerCharDB.elements = {}
        end
        if not JarsEasyTrackerCharDB.groups then
            JarsEasyTrackerCharDB.groups = {}
        end
        if not JarsEasyTrackerCharDB.nextId then
            JarsEasyTrackerCharDB.nextId = 1
        end
        if not JarsEasyTrackerCharDB.nextGroupId then
            JarsEasyTrackerCharDB.nextGroupId = 1
        end
        if JarsEasyTrackerCharDB.locked == nil then
            JarsEasyTrackerCharDB.locked = true
        end
        if not JarsEasyTrackerCharDB.configScale then
            JarsEasyTrackerCharDB.configScale = 1.0
        end
        if not JarsEasyTrackerCharDB.collapsedGroups then
            JarsEasyTrackerCharDB.collapsedGroups = {}
        end

        if not JarsEasyTrackerDB.profiles then
            JarsEasyTrackerDB.profiles = {}
        end

        -- Merge defaults into existing elements
        for _, element in ipairs(JarsEasyTrackerCharDB.elements) do
            for k, v in pairs(DEFAULT_ELEMENT) do
                if element[k] == nil then
                    element[k] = DeepCopy(v)
                end
            end
            -- Merge sub-tables
            if not element.spellcast then element.spellcast = DeepCopy(DEFAULT_ELEMENT.spellcast) end
            if not element.aura then element.aura = DeepCopy(DEFAULT_ELEMENT.aura) end
            if not element.spelldata then element.spelldata = DeepCopy(DEFAULT_ELEMENT.spelldata) end
            if not element.loadConditions then element.loadConditions = DeepCopy(DEFAULT_ELEMENT.loadConditions) end
        end

        -- Merge defaults into existing groups
        for _, group in ipairs(JarsEasyTrackerCharDB.groups) do
            for k, v in pairs(DEFAULT_GROUP) do
                if group[k] == nil then
                    group[k] = DeepCopy(v)
                end
            end
            if not group.loadConditions then group.loadConditions = DeepCopy(DEFAULT_GROUP.loadConditions) end
        end

        C_Timer.After(0.5, function()
            RefreshAllDisplays()
        end)

        print("|cff00ff00Jar's Easy Tracker|r loaded. Type |cff00ffff/jtrack|r to configure.")

    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, function()
            RefreshAllDisplays()
        end)

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellId = ...
        if unit == "player" then
            OnSpellCastSucceeded(spellId)
        end

    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" then
            for _, element in ipairs(JarsEasyTrackerCharDB.elements) do
                if element.triggerType == "aura" and ShouldLoad(element) then
                    local state = GetElementState(element.id)
                    if state then
                        UpdateAuraElement(element, state)
                        UpdateDisplay(element)
                    end
                end
            end
        end

    elseif event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES" then
        for _, element in ipairs(JarsEasyTrackerCharDB.elements) do
            if element.triggerType == "spelldata" and ShouldLoad(element) then
                local state = GetElementState(element.id)
                if state then
                    UpdateSpellDataElement(element, state)
                    UpdateDisplay(element)
                end
            end
        end

    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
        local spellID = ...
        for _, element in ipairs(JarsEasyTrackerCharDB.elements) do
            if element.triggerType == "spelldata" and ShouldLoad(element) then
                local state = GetElementState(element.id)
                if state and state.actionSpellId == spellID then
                    state.overlayActive = true
                    local f = displayFrames[element.id]
                    if f then ShowGlowEffect(f, element.glowStyle or "glow") end
                end
            end
        end

    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        local spellID = ...
        for _, element in ipairs(JarsEasyTrackerCharDB.elements) do
            if element.triggerType == "spelldata" and ShouldLoad(element) then
                local state = GetElementState(element.id)
                if state and state.actionSpellId == spellID then
                    state.overlayActive = false
                    local f = displayFrames[element.id]
                    if f then HideGlowEffect(f) end
                end
            end
        end

    elseif event == "ACTIONBAR_SLOT_CHANGED" or event == "ACTIONBAR_UPDATE_STATE" or
           event == "ACTIONBAR_UPDATE_USABLE" or event == "ACTIONBAR_UPDATE_COOLDOWN" then
        for _, element in ipairs(JarsEasyTrackerCharDB.elements) do
            if element.triggerType == "spelldata" and ShouldLoad(element) then
                local state = GetElementState(element.id)
                if state then
                    UpdateSpellDataElement(element, state)
                end
                UpdateDisplay(element)
            end
        end

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "SPELLS_CHANGED" then
        C_Timer.After(0.5, RefreshAllDisplays)

    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then
        -- Combat state changed — re-check load conditions
        for _, element in ipairs(JarsEasyTrackerCharDB.elements) do
            if element.loadConditions and element.loadConditions.inCombat ~= nil then
                if ShouldLoad(element) then
                    if not displayFrames[element.id] then
                        CreateDisplay(element)
                    else
                        displayFrames[element.id]:Show()
                        UpdateDisplay(element)
                    end
                else
                    if displayFrames[element.id] then
                        displayFrames[element.id]:Hide()
                    end
                end
            end
        end
        -- Also refresh groups in case grouped elements changed visibility
        for _, group in ipairs(JarsEasyTrackerCharDB.groups) do
            UpdateGroupLayout(group)
        end

    elseif event == "GROUP_ROSTER_UPDATE" or event == "ZONE_CHANGED_NEW_AREA" then
        C_Timer.After(0.5, RefreshAllDisplays)
    end
end)


--------------------------------------------------------------------------------
-- Section 13b: Spell Search Dialog
--------------------------------------------------------------------------------

local spellSearchDialog

local function ShowSpellSearchDialog(callback)
    if spellSearchDialog then
        spellSearchDialog:Show()
        spellSearchDialog:Raise()
        spellSearchDialog.callback = callback
        return
    end

    local dialog = CreateFrame("Frame", "JET_SpellSearchDialog", UIParent, "BasicFrameTemplateWithInset")
    dialog:SetSize(420, 450)
    dialog:SetPoint("CENTER", 0, 50)
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    dialog:SetFrameStrata("FULLSCREEN_DIALOG")
    dialog.callback = callback

    dialog.title = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dialog.title:SetPoint("TOP", 0, -5)
    dialog.title:SetText("Search Spell by Name")

    -- Search box
    local searchBox = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    searchBox:SetPoint("TOPLEFT", 20, -35)
    searchBox:SetSize(300, 20)
    searchBox:SetAutoFocus(true)
    searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    dialog.searchBox = searchBox

    -- Search button
    local searchBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    searchBtn:SetSize(70, 22)
    searchBtn:SetPoint("LEFT", searchBox, "RIGHT", 6, 0)
    searchBtn:SetText("Search")

    -- Status text
    local statusText = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -4)
    statusText:SetTextColor(0.7, 0.7, 0.7)
    statusText:SetText("Type a spell name and click Search")
    dialog.statusText = statusText

    -- Scroll frame for results
    local resultScroll = CreateFrame("ScrollFrame", "JET_SpellSearchScroll", dialog, "UIPanelScrollFrameTemplate")
    resultScroll:SetPoint("TOPLEFT", 12, -80)
    resultScroll:SetPoint("BOTTOMRIGHT", -30, 10)

    local resultChild = CreateFrame("Frame")
    resultChild:SetWidth(360)
    resultChild:SetHeight(1)
    resultScroll:SetScrollChild(resultChild)
    dialog.resultChild = resultChild
    dialog.resultEntries = {}

    -- Clear old results
    local function ClearResults()
        for _, entry in ipairs(dialog.resultEntries) do
            entry:Hide()
            entry:SetParent(nil)
        end
        wipe(dialog.resultEntries)
    end

    -- Display results
    local function DisplayResults(results)
        ClearResults()
        local yOff = 0
        for i, info in ipairs(results) do
            local row = CreateFrame("Frame", nil, resultChild)
            row:SetSize(360, 28)
            row:SetPoint("TOPLEFT", 0, -yOff)

            -- Alternate row background
            local rowBg = row:CreateTexture(nil, "BACKGROUND")
            rowBg:SetAllPoints()
            if i % 2 == 0 then
                rowBg:SetColorTexture(0.15, 0.15, 0.15, 0.5)
            else
                rowBg:SetColorTexture(0.1, 0.1, 0.1, 0.3)
            end

            -- Spell icon
            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(24, 24)
            icon:SetPoint("LEFT", 4, 0)
            icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            if info.texture then
                icon:SetTexture(info.texture)
            else
                icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end

            -- Spell name
            local nameStr = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            nameStr:SetPoint("LEFT", icon, "RIGHT", 6, 0)
            nameStr:SetWidth(180)
            nameStr:SetJustifyH("LEFT")
            nameStr:SetText(info.name)
            nameStr:SetWordWrap(false)

            -- Spell ID
            local idStr = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            idStr:SetPoint("LEFT", nameStr, "RIGHT", 4, 0)
            idStr:SetWidth(60)
            idStr:SetJustifyH("LEFT")
            idStr:SetTextColor(0.7, 0.7, 0.7)
            idStr:SetText("ID: " .. info.spellId)

            -- Select button
            local selectBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            selectBtn:SetSize(55, 20)
            selectBtn:SetPoint("RIGHT", -2, 0)
            selectBtn:SetText("Select")
            local capturedId = info.spellId
            selectBtn:SetScript("OnClick", function()
                if dialog.callback then
                    dialog.callback(capturedId)
                end
                dialog:Hide()
            end)

            table.insert(dialog.resultEntries, row)
            yOff = yOff + 29
        end
        resultChild:SetHeight(math.max(yOff, 1))
    end

    -- Search function
    local function DoSearch()
        local searchText = searchBox:GetText()
        if not searchText or searchText == "" then
            statusText:SetText("Enter a spell name to search")
            ClearResults()
            return
        end

        searchText = searchText:lower()
        local results = {}
        local seen = {}

        -- Search player spellbook
        local numTabs = C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetNumSpellBookSkillLines() or 0
        if numTabs > 0 then
            for tabIndex = 1, numTabs do
                local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(tabIndex)
                if skillLineInfo then
                    local offset = skillLineInfo.itemIndexOffset
                    local numSlots = skillLineInfo.numSpellBookItems
                    for i = 1, numSlots do
                        local slotIndex = offset + i
                        local itemType, actionId = C_SpellBook.GetSpellBookItemType(slotIndex, Enum.SpellBookSpellBank.Player)
                        if itemType == Enum.SpellBookItemType.Spell and actionId then
                            local spellName = C_Spell.GetSpellName(actionId)
                            if spellName and spellName:lower():find(searchText, 1, true) and not seen[actionId] then
                                seen[actionId] = true
                                local texture = C_Spell.GetSpellTexture(actionId)
                                table.insert(results, {
                                    spellId = actionId,
                                    name = spellName,
                                    texture = texture,
                                })
                            end
                        end
                    end
                end
            end
        end

        -- Also try a brute-force range scan for common spell IDs
        -- This catches spells not in the spellbook (talents, passives, NPC abilities)
        local maxScan = 500000
        local batchSize = 5000
        local scanned = 0
        statusText:SetText("Searching spellbook... found " .. #results .. " so far")
        DisplayResults(results)

        local function ScanBatch(start)
            for id = start, math.min(start + batchSize - 1, maxScan) do
                local spellName = C_Spell.GetSpellName(id)
                if spellName and spellName:lower():find(searchText, 1, true) and not seen[id] then
                    seen[id] = true
                    local texture = C_Spell.GetSpellTexture(id)
                    table.insert(results, {
                        spellId = id,
                        name = spellName,
                        texture = texture,
                    })
                end
            end

            scanned = start + batchSize
            if scanned < maxScan and #results < 100 then
                statusText:SetText("Scanning... " .. math.floor(scanned / maxScan * 100) .. "%  (" .. #results .. " found)")
                DisplayResults(results)
                C_Timer.After(0.01, function()
                    if dialog:IsShown() then
                        ScanBatch(scanned)
                    end
                end)
            else
                if #results == 0 then
                    statusText:SetText("No spells found matching \"" .. searchBox:GetText() .. "\"")
                else
                    statusText:SetText("Found " .. #results .. " spells")
                end
                DisplayResults(results)
            end
        end

        -- Start scanning from ID 1
        ScanBatch(1)
    end

    searchBtn:SetScript("OnClick", DoSearch)
    searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        DoSearch()
    end)

    spellSearchDialog = dialog
    dialog:Show()
end

--------------------------------------------------------------------------------
-- Modern UI Helper Functions
--------------------------------------------------------------------------------

local function CreateModernSlider(parent, label, minVal, maxVal, step, getValue, setValue)
    local slider = CreateFrame("Slider", nil, parent, "MinimalSliderTemplate")
    slider:SetSize(200, 18)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    
    local bg = slider:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.05, 0.8)
    
    local fill = slider:CreateTexture(nil, "ARTWORK")
    fill:SetHeight(4)
    fill:SetPoint("LEFT")
    fill:SetColorTexture(UI_PALETTE.accent[1], UI_PALETTE.accent[2], UI_PALETTE.accent[3], 0.6)
    slider.fill = fill
    
    slider:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local thumb = slider:GetThumbTexture()
    thumb:SetSize(14, 14)
    thumb:SetColorTexture(UI_PALETTE.accent[1], UI_PALETTE.accent[2], UI_PALETTE.accent[3], 1)
    
    local labelText = slider:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("BOTTOM", slider, "TOP", 0, 4)
    labelText:SetTextColor(UI_PALETTE.text[1], UI_PALETTE.text[2], UI_PALETTE.text[3])
    slider.label = labelText
    
    local function updateLabel()
        local value = getValue()
        labelText:SetText(label .. ": " .. value)
        local pct = (value - minVal) / (maxVal - minVal)
        fill:SetWidth(slider:GetWidth() * pct)
    end
    
    slider:SetScript("OnValueChanged", function(self, value)
        setValue(value)
        updateLabel()
    end)
    
    updateLabel()
    return slider
end

local function CreateModernCheck(parent, label, getValue, setValue)
    local check = CreateFrame("CheckButton", nil, parent)
    check:SetSize(18, 18)
    
    local bg = check:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.05, 0.9)
    
    local border = check:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(UI_PALETTE.border[1], UI_PALETTE.border[2], UI_PALETTE.border[3], 1)
    
    local checkTex = check:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    checkTex:SetPoint("CENTER", 0, 0)
    checkTex:SetText("✓")
    checkTex:SetTextColor(UI_PALETTE.accent[1], UI_PALETTE.accent[2], UI_PALETTE.accent[3], 1)
    check.checkTex = checkTex
    
    local labelText = check:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("LEFT", check, "RIGHT", 8, 0)
    labelText:SetText(label)
    labelText:SetTextColor(UI_PALETTE.text[1], UI_PALETTE.text[2], UI_PALETTE.text[3])
    check.text = labelText
    
    local function updateCheck()
        checkTex:SetShown(getValue())
    end
    
    check:SetScript("OnClick", function()
        setValue(not getValue())
        updateCheck()
    end)
    
    updateCheck()
    return check
end

local function CreateSectionHeader(parent, text)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetTextColor(UI_PALETTE.accent[1], UI_PALETTE.accent[2], UI_PALETTE.accent[3], 1)
    header:SetText(text:upper())
    
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("LEFT", header, "RIGHT", 8, 0)
    line:SetColorTexture(UI_PALETTE.accent[1], UI_PALETTE.accent[2], UI_PALETTE.accent[3], 0.3)
    line:SetWidth(100)
    
    header.line = line
    return header
end

--------------------------------------------------------------------------------
-- Section 14-17: Config UI
--------------------------------------------------------------------------------

local function CreateConfigWindow()
    if configFrame then return configFrame end

    configFrame = CreateFrame("Frame", "JET_ConfigFrame", UIParent, "BackdropTemplate")
    configFrame:SetSize(720, 620)
    configFrame:SetPoint("CENTER")
    configFrame:SetMovable(true)
    configFrame:EnableMouse(true)
    configFrame:RegisterForDrag("LeftButton")
    configFrame:SetScript("OnDragStart", configFrame.StartMoving)
    configFrame:SetScript("OnDragStop", configFrame.StopMovingOrSizing)
    configFrame:SetFrameStrata("DIALOG")
    configFrame:SetScale(JarsEasyTrackerCharDB.configScale or 1.0)
    
    -- Modern background
    configFrame:SetBackdrop(modernBackdrop)
    configFrame:SetBackdropColor(unpack(UI_PALETTE.bg))
    configFrame:SetBackdropBorderColor(unpack(UI_PALETTE.border))
    
    -- Title bar with teal accent
    local titleBar = configFrame:CreateTexture(nil, "OVERLAY")
    titleBar:SetPoint("TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", -1, -1)
    titleBar:SetHeight(32)
    titleBar:SetColorTexture(UI_PALETTE.header[1], UI_PALETTE.header[2], UI_PALETTE.header[3], UI_PALETTE.header[4])
    
    local titleAccent = configFrame:CreateTexture(nil, "OVERLAY")
    titleAccent:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
    titleAccent:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)
    titleAccent:SetHeight(2)
    titleAccent:SetColorTexture(UI_PALETTE.accent[1], UI_PALETTE.accent[2], UI_PALETTE.accent[3], UI_PALETTE.accent[4])
    
    configFrame.title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    configFrame.title:SetPoint("TOP", titleBar, "TOP", 0, -8)
    configFrame.title:SetText("Jar's Easy Tracker")
    configFrame.title:SetTextColor(UI_PALETTE.text[1], UI_PALETTE.text[2], UI_PALETTE.text[3])
    
    -- Modern close button
    local closeBtn = CreateFrame("Button", nil, configFrame)
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("TOPRIGHT", -6, -6)
    closeBtn:SetNormalTexture("Interface\\AddOns\\JarsEasyTracker\\Assets\\close")
    closeBtn:SetHighlightTexture("Interface\\AddOns\\JarsEasyTracker\\Assets\\close")
    closeBtn:GetHighlightTexture():SetAlpha(0.3)
    local closeBtnBg = closeBtn:CreateTexture(nil, "BACKGROUND")
    closeBtnBg:SetAllPoints()
    closeBtnBg:SetColorTexture(0.05, 0.05, 0.05, 0.8)
    local closeBtnText = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    closeBtnText:SetPoint("CENTER", 0, 1)
    closeBtnText:SetText("✕")
    closeBtnText:SetTextColor(UI_PALETTE.textDim[1], UI_PALETTE.textDim[2], UI_PALETTE.textDim[3])
    closeBtn:SetScript("OnEnter", function(self)
        closeBtnText:SetTextColor(UI_PALETTE.accent[1], UI_PALETTE.accent[2], UI_PALETTE.accent[3])
    end)
    closeBtn:SetScript("OnLeave", function(self)
        closeBtnText:SetTextColor(UI_PALETTE.textDim[1], UI_PALETTE.textDim[2], UI_PALETTE.textDim[3])
    end)
    closeBtn:SetScript("OnClick", function() configFrame:Hide() end)

    ---------------------------------------------------------------------------
    -- Left Panel (200px) — Element List
    ---------------------------------------------------------------------------
    local leftPanel = CreateFrame("Frame", nil, configFrame)
    leftPanel:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 8, -40)
    leftPanel:SetPoint("BOTTOMLEFT", configFrame, "BOTTOMLEFT", 8, 45)
    leftPanel:SetWidth(195)

    leftPanel.bg = leftPanel:CreateTexture(nil, "BACKGROUND", nil, -1)
    leftPanel.bg:SetAllPoints()
    leftPanel.bg:SetColorTexture(0.1, 0.1, 0.1, 0.5)

    -- Scroll frame for element list
    local scrollFrame = CreateFrame("ScrollFrame", "JET_ListScroll", leftPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", -24, 30)

    local scrollChild = CreateFrame("Frame")
    scrollChild:SetWidth(165)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    configFrame.scrollChild = scrollChild

    -- Buttons below list
    local addBtn = CreateFrame("Button", nil, leftPanel, "UIPanelButtonTemplate")
    addBtn:SetSize(55, 22)
    addBtn:SetPoint("BOTTOMLEFT", 4, 4)
    addBtn:SetText("+Add")

    local delBtn = CreateFrame("Button", nil, leftPanel, "UIPanelButtonTemplate")
    delBtn:SetSize(55, 22)
    delBtn:SetPoint("LEFT", addBtn, "RIGHT", 4, 0)
    delBtn:SetText("-Del")

    local dupBtn = CreateFrame("Button", nil, leftPanel, "UIPanelButtonTemplate")
    dupBtn:SetSize(55, 22)
    dupBtn:SetPoint("LEFT", delBtn, "RIGHT", 4, 0)
    dupBtn:SetText("Dup")

    -- Add button — shows type picker
    addBtn:SetScript("OnClick", function(self)
        MenuUtil.CreateContextMenu(self, function(ownerRegion, rootDescription)
            rootDescription:CreateButton("Icon", function()
                local elem = DeepCopy(DEFAULT_ELEMENT)
                elem.id = GenerateId()
                elem.elementType = "icon"
                elem.name = "Icon " .. elem.id
                table.insert(JarsEasyTrackerCharDB.elements, elem)
                CreateDisplay(elem)
                RegisterDynamicEvents()
                RefreshLeftPanel()
                selectedGroupId = nil
                selectedElementId = elem.id
                PopulateRightPanel(elem)
            end)
            rootDescription:CreateButton("Progress Bar", function()
                local elem = DeepCopy(DEFAULT_ELEMENT)
                elem.id = GenerateId()
                elem.elementType = "progressbar"
                elem.name = "Bar " .. elem.id
                table.insert(JarsEasyTrackerCharDB.elements, elem)
                CreateDisplay(elem)
                RegisterDynamicEvents()
                RefreshLeftPanel()
                selectedGroupId = nil
                selectedElementId = elem.id
                PopulateRightPanel(elem)
            end)
            rootDescription:CreateButton("Group", function()
                local grp = DeepCopy(DEFAULT_GROUP)
                grp.id = GenerateGroupId()
                grp.name = "Group " .. grp.id
                table.insert(JarsEasyTrackerCharDB.groups, grp)
                RefreshLeftPanel()
                selectedElementId = nil
                selectedGroupId = grp.id
                PopulateGroupPanel(grp)
            end)
        end)
    end)

    -- Delete button
    delBtn:SetScript("OnClick", function()
        if selectedGroupId then
            -- Delete group: ungroup all members first
            local _, grpIdx = FindGroupById(selectedGroupId)
            if grpIdx then
                for _, element in ipairs(JarsEasyTrackerCharDB.elements) do
                    if element.groupId == selectedGroupId then
                        element.positioning = "independent"
                        element.groupId = nil
                    end
                end
                -- Destroy group container
                if groupFrames[selectedGroupId] then
                    groupFrames[selectedGroupId]:Hide()
                    groupFrames[selectedGroupId]:SetParent(nil)
                    groupFrames[selectedGroupId] = nil
                end
                table.remove(JarsEasyTrackerCharDB.groups, grpIdx)
                selectedGroupId = nil
                ClearRightPanel()
                RefreshLeftPanel()
                RefreshAllDisplays()
            end
        elseif selectedElementId then
            local elem, idx = FindElementById(selectedElementId)
            if idx then
                local wasGrouped = elem and elem.groupId
                DestroyDisplay(JarsEasyTrackerCharDB.elements[idx])
                elementStates[selectedElementId] = nil
                table.remove(JarsEasyTrackerCharDB.elements, idx)
                selectedElementId = nil
                ClearRightPanel()
                RefreshLeftPanel()
                RegisterDynamicEvents()
                -- Refresh group layout if element was grouped
                if wasGrouped then
                    for _, grp in ipairs(JarsEasyTrackerCharDB.groups) do
                        UpdateGroupLayout(grp)
                    end
                end
            end
        end
    end)

    -- Duplicate button
    dupBtn:SetScript("OnClick", function()
        if not selectedElementId then return end
        local elem = FindElementById(selectedElementId)
        if elem then
            local copy = DeepCopy(elem)
            copy.id = GenerateId()
            copy.name = elem.name .. " (Copy)"
            -- Offset position slightly
            copy.position.x = copy.position.x + 20
            copy.position.y = copy.position.y - 20
            table.insert(JarsEasyTrackerCharDB.elements, copy)
            CreateDisplay(copy)
            RegisterDynamicEvents()
            RefreshLeftPanel()
            selectedElementId = copy.id
            PopulateRightPanel(copy)
        end
    end)

    ---------------------------------------------------------------------------
    -- Right Panel (440px) — Detail View
    ---------------------------------------------------------------------------
    local rightPanel = CreateFrame("Frame", nil, configFrame)
    rightPanel:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 4, 0)
    rightPanel:SetPoint("BOTTOMRIGHT", configFrame, "BOTTOMRIGHT", -8, 45)
    configFrame.rightPanel = rightPanel

    rightPanel.bg = rightPanel:CreateTexture(nil, "BACKGROUND", nil, -1)
    rightPanel.bg:SetAllPoints()
    rightPanel.bg:SetColorTexture(0.1, 0.1, 0.1, 0.3)

    -- Scroll frame for right panel content
    local rightScroll = CreateFrame("ScrollFrame", "JET_RightScroll", rightPanel, "UIPanelScrollFrameTemplate")
    rightScroll:SetPoint("TOPLEFT", 4, -4)
    rightScroll:SetPoint("BOTTOMRIGHT", -24, 4)

    local rightScrollChild = CreateFrame("Frame")
    rightScrollChild:SetWidth(460)
    rightScrollChild:SetHeight(1)
    rightScroll:SetScrollChild(rightScrollChild)
    configFrame.rightScrollChild = rightScrollChild

    -- Placeholder text
    configFrame.placeholder = rightScrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    configFrame.placeholder:SetPoint("CENTER", rightPanel, "CENTER")
    configFrame.placeholder:SetText("Select an element from the list\nor click +Add to create one")

    ---------------------------------------------------------------------------
    -- Bottom bar — Lock, Import, Export
    ---------------------------------------------------------------------------
    local lockBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    lockBtn:SetSize(80, 22)
    lockBtn:SetPoint("BOTTOMLEFT", 12, 12)
    lockBtn:SetText(JarsEasyTrackerCharDB.locked and "Unlock" or "Lock")
    configFrame.lockBtn = lockBtn

    lockBtn:SetScript("OnClick", function(self)
        JarsEasyTrackerCharDB.locked = not JarsEasyTrackerCharDB.locked
        self:SetText(JarsEasyTrackerCharDB.locked and "Unlock" or "Lock")
        -- Update all display frames
        for _, element in ipairs(JarsEasyTrackerCharDB.elements) do
            UpdateDisplay(element)
        end
        for _, group in ipairs(JarsEasyTrackerCharDB.groups) do
            UpdateGroupLayout(group)
        end
    end)

    -- Export button
    local exportBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    exportBtn:SetSize(80, 22)
    exportBtn:SetPoint("LEFT", lockBtn, "RIGHT", 8, 0)
    exportBtn:SetText("Export")

    exportBtn:SetScript("OnClick", function()
        if not selectedElementId then
            print("|cffff0000JET:|r Select an element to export.")
            return
        end
        local elem = FindElementById(selectedElementId)
        if elem then
            local str = SerializeElement(elem)
            -- Show in a copyable dialog
            local dialog = CreateFrame("Frame", "JET_ExportDialog", UIParent, "BasicFrameTemplateWithInset")
            dialog:SetSize(400, 200)
            dialog:SetPoint("CENTER")
            dialog:SetFrameStrata("FULLSCREEN_DIALOG")
            dialog.title = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            dialog.title:SetPoint("TOP", 0, -5)
            dialog.title:SetText("Export — Copy this string")

            local editBox = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
            editBox:SetPoint("TOPLEFT", 20, -35)
            editBox:SetPoint("BOTTOMRIGHT", -20, 20)
            editBox:SetMultiLine(true)
            editBox:SetAutoFocus(true)
            editBox:SetText(str)
            editBox:HighlightText()
            editBox:SetScript("OnEscapePressed", function() dialog:Hide() end)
        end
    end)

    -- Import button
    local importBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    importBtn:SetSize(80, 22)
    importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 8, 0)
    importBtn:SetText("Import")

    importBtn:SetScript("OnClick", function()
        local dialog = CreateFrame("Frame", "JET_ImportDialog", UIParent, "BasicFrameTemplateWithInset")
        dialog:SetSize(400, 200)
        dialog:SetPoint("CENTER")
        dialog:SetFrameStrata("FULLSCREEN_DIALOG")
        dialog.title = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        dialog.title:SetPoint("TOP", 0, -5)
        dialog.title:SetText("Import — Paste string below")

        local editBox = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
        editBox:SetPoint("TOPLEFT", 20, -35)
        editBox:SetPoint("BOTTOMRIGHT", -20, 50)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(true)

        local confirmBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        confirmBtn:SetSize(80, 22)
        confirmBtn:SetPoint("BOTTOM", 0, 15)
        confirmBtn:SetText("Import")
        confirmBtn:SetScript("OnClick", function()
            local str = editBox:GetText()
            local data = DeserializeElement(str)
            if data then
                data.id = GenerateId()
                -- Merge missing defaults
                for k, v in pairs(DEFAULT_ELEMENT) do
                    if data[k] == nil then
                        data[k] = DeepCopy(v)
                    end
                end
                table.insert(JarsEasyTrackerCharDB.elements, data)
                CreateDisplay(data)
                RegisterDynamicEvents()
                RefreshLeftPanel()
                print("|cff00ff00JET:|r Imported element: " .. (data.name or "Unknown"))
                dialog:Hide()
            else
                print("|cffff0000JET:|r Invalid import string.")
            end
        end)

        editBox:SetScript("OnEscapePressed", function() dialog:Hide() end)
    end)

    configFrame:Hide()

    ---------------------------------------------------------------------------
    -- Refresh Left Panel function
    ---------------------------------------------------------------------------
    RefreshLeftPanel = function()
        -- Clear existing entries
        for _, entry in ipairs(leftPanelEntries) do
            entry:Hide()
            entry:SetParent(nil)
        end
        wipe(leftPanelEntries)

        local yOff = 0

        -- Helper: create an element row
        local function CreateElementRow(element, indent)
            local entry = CreateFrame("Button", nil, scrollChild)
            entry:SetSize(165, 24)
            entry:SetPoint("TOPLEFT", 0, -yOff)
            entry.elementId = element.id

            -- Highlight
            entry.highlight = entry:CreateTexture(nil, "BACKGROUND")
            entry.highlight:SetAllPoints()
            if selectedElementId and selectedElementId == element.id then
                entry.highlight:SetColorTexture(0.3, 0.3, 0.6, 0.5)
            else
                entry.highlight:SetColorTexture(0.2, 0.2, 0.2, 0.3)
            end

            -- Type indicator
            local typeIcon = entry:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            typeIcon:SetPoint("LEFT", indent + 4, 0)
            if element.elementType == "icon" then
                typeIcon:SetText("[I]")
                typeIcon:SetTextColor(0.5, 0.8, 1)
            else
                typeIcon:SetText("[B]")
                typeIcon:SetTextColor(0.5, 1, 0.5)
            end

            -- Enable indicator
            local enableDot = entry:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            enableDot:SetPoint("LEFT", typeIcon, "RIGHT", 2, 0)
            if element.enabled then
                enableDot:SetText("|cff00ff00*|r")
            else
                enableDot:SetText("|cffff0000*|r")
            end

            -- Name
            local nameText = entry:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            nameText:SetPoint("LEFT", enableDot, "RIGHT", 2, 0)
            nameText:SetPoint("RIGHT", -4, 0)
            nameText:SetJustifyH("LEFT")
            nameText:SetText(element.name)
            nameText:SetWordWrap(false)

            entry:SetScript("OnClick", function(self)
                selectedGroupId = nil
                selectedElementId = self.elementId
                local elem = FindElementById(self.elementId)
                if elem then
                    PopulateRightPanel(elem)
                end
                RefreshLeftPanel()
            end)

            entry:SetScript("OnEnter", function(self)
                if selectedElementId ~= self.elementId then
                    self.highlight:SetColorTexture(0.25, 0.25, 0.4, 0.4)
                end
            end)

            entry:SetScript("OnLeave", function(self)
                if selectedElementId ~= self.elementId then
                    self.highlight:SetColorTexture(0.2, 0.2, 0.2, 0.3)
                end
            end)

            table.insert(leftPanelEntries, entry)
            yOff = yOff + 25
        end

        -- Render groups with their members
        for _, group in ipairs(JarsEasyTrackerCharDB.groups) do
            local isCollapsed = JarsEasyTrackerCharDB.collapsedGroups[group.id]

            -- Group header row
            local header = CreateFrame("Button", nil, scrollChild)
            header:SetSize(165, 24)
            header:SetPoint("TOPLEFT", 0, -yOff)
            header.groupId = group.id

            header.highlight = header:CreateTexture(nil, "BACKGROUND")
            header.highlight:SetAllPoints()
            if selectedGroupId and selectedGroupId == group.id then
                header.highlight:SetColorTexture(0.2, 0.4, 0.2, 0.5)
            else
                header.highlight:SetColorTexture(0.15, 0.15, 0.15, 0.4)
            end

            -- [G] indicator
            local typeIcon = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            typeIcon:SetPoint("LEFT", 4, 0)
            typeIcon:SetText("[G]")
            typeIcon:SetTextColor(0.3, 0.9, 0.3)

            -- Collapse arrow
            local arrow = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            arrow:SetPoint("LEFT", typeIcon, "RIGHT", 2, 0)
            arrow:SetText(isCollapsed and ">" or "v")
            arrow:SetTextColor(0.7, 0.7, 0.7)

            -- Group name
            local nameText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            nameText:SetPoint("LEFT", arrow, "RIGHT", 3, 0)
            nameText:SetPoint("RIGHT", -4, 0)
            nameText:SetJustifyH("LEFT")
            nameText:SetText(group.name)
            nameText:SetWordWrap(false)

            header:SetScript("OnClick", function(self, button)
                selectedElementId = nil
                selectedGroupId = self.groupId
                local grp = FindGroupById(self.groupId)
                if grp then
                    PopulateGroupPanel(grp)
                end
                RefreshLeftPanel()
            end)

            header:SetScript("OnEnter", function(self)
                if selectedGroupId ~= self.groupId then
                    self.highlight:SetColorTexture(0.2, 0.3, 0.2, 0.5)
                end
            end)

            header:SetScript("OnLeave", function(self)
                if selectedGroupId ~= self.groupId then
                    self.highlight:SetColorTexture(0.15, 0.15, 0.15, 0.4)
                end
            end)

            -- Collapse toggle button (overlaid on the arrow area)
            local collapseBtn = CreateFrame("Button", nil, header)
            collapseBtn:SetSize(20, 24)
            collapseBtn:SetPoint("LEFT", typeIcon, "RIGHT", 0, 0)
            collapseBtn.groupId = group.id
            collapseBtn:SetScript("OnClick", function(self)
                local gId = self.groupId
                JarsEasyTrackerCharDB.collapsedGroups[gId] = not JarsEasyTrackerCharDB.collapsedGroups[gId]
                RefreshLeftPanel()
            end)

            table.insert(leftPanelEntries, header)
            yOff = yOff + 25

            -- Render member elements (if not collapsed), sorted by groupOrder
            if not isCollapsed then
                local sortedMembers = GetGroupMembersSorted(group.id, false)
                for _, element in ipairs(sortedMembers) do
                    CreateElementRow(element, 10)
                end
            end
        end

        -- Render ungrouped elements
        for _, element in ipairs(JarsEasyTrackerCharDB.elements) do
            if element.positioning ~= "grouped" or not element.groupId then
                CreateElementRow(element, 0)
            end
        end

        scrollChild:SetHeight(math.max(yOff, 1))
    end

    ---------------------------------------------------------------------------
    -- Clear Right Panel
    ---------------------------------------------------------------------------
    ClearRightPanel = function()
        if configFrame.rightContent then
            configFrame.rightContent:Hide()
            configFrame.rightContent:SetParent(nil)
            configFrame.rightContent = nil
        end
        local children = { configFrame.rightScrollChild:GetChildren() }
        for _, child in ipairs(children) do
            child:Hide()
            child:SetParent(nil)
        end
        local regions = { configFrame.rightScrollChild:GetRegions() }
        for _, region in ipairs(regions) do
            if region ~= configFrame.placeholder then
                region:Hide()
            end
        end
        if configFrame.placeholder then
            configFrame.placeholder:Show()
        end
    end

    ---------------------------------------------------------------------------
    -- Populate Group Panel (when a group is selected)
    ---------------------------------------------------------------------------
    PopulateGroupPanel = function(group)
        ClearRightPanel()
        if configFrame.placeholder then
            configFrame.placeholder:Hide()
        end

        local content = CreateFrame("Frame", nil, configFrame.rightScrollChild)
        content:SetPoint("TOPLEFT")
        content:SetPoint("TOPRIGHT")
        configFrame.rightContent = content
        local parent = content
        local yOff = -8
        local leftMargin = 10

        -- Helper: create a section header with separator line
        local function SectionHeader(text)
            yOff = yOff - 8
            local sep = parent:CreateTexture(nil, "ARTWORK")
            sep:SetPoint("TOPLEFT", leftMargin, yOff)
            sep:SetSize(430, 1)
            sep:SetColorTexture(0.5, 0.4, 0.1, 0.6)
            yOff = yOff - 6
            local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            header:SetPoint("TOPLEFT", leftMargin, yOff)
            header:SetText("|cffffcc00" .. text .. "|r")
            yOff = yOff - 20
            return header
        end

        -- Helper: create label
        local function Label(text, xOff)
            local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lbl:SetPoint("TOPLEFT", xOff or leftMargin, yOff)
            lbl:SetText(text)
            return lbl
        end

        -----------------------------------------------------------------------
        -- GENERAL
        -----------------------------------------------------------------------
        SectionHeader("General")

        -- Name
        Label("Name:", leftMargin)
        local nameBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        nameBox:SetPoint("TOPLEFT", leftMargin + 60, yOff + 3)
        nameBox:SetSize(200, 20)
        nameBox:SetAutoFocus(false)
        nameBox:SetText(group.name)
        nameBox:SetScript("OnEnterPressed", function(self)
            group.name = self:GetText()
            self:ClearFocus()
            RefreshLeftPanel()
        end)
        nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        yOff = yOff - 28

        -- Type label
        Label("Type: Group", leftMargin)
        yOff = yOff - 22

        -----------------------------------------------------------------------
        -- LAYOUT
        -----------------------------------------------------------------------
        SectionHeader("Layout")

        -- Direction dropdown
        Label("Direction:", leftMargin)
        local dirDropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
        dirDropdown:SetPoint("TOPLEFT", leftMargin + 70, yOff + 5)
        dirDropdown:SetWidth(140)
        dirDropdown:SetDefaultText(group.layout == "vertical" and "Vertical" or "Horizontal")
        dirDropdown:SetupMenu(function(_, rootDescription)
            rootDescription:CreateRadio("Horizontal",
                function() return group.layout == "horizontal" end,
                function()
                    group.layout = "horizontal"
                    UpdateGroupLayout(group)
                end)
            rootDescription:CreateRadio("Vertical",
                function() return group.layout == "vertical" end,
                function()
                    group.layout = "vertical"
                    UpdateGroupLayout(group)
                end)
        end)
        yOff = yOff - 38

        -- Spacing slider
        Label("Spacing:", leftMargin)
        local spacingSlider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
        spacingSlider:SetPoint("TOPLEFT", leftMargin + 70, yOff - 8)
        spacingSlider:SetWidth(200)
        spacingSlider:SetMinMaxValues(0, 20)
        spacingSlider:SetValue(group.spacing or 4)
        spacingSlider:SetValueStep(1)
        spacingSlider:SetObeyStepOnDrag(true)
        spacingSlider.Text:SetText("Spacing: " .. (group.spacing or 4))
        spacingSlider.Low:SetText("")
        spacingSlider.High:SetText("")
        spacingSlider:SetScript("OnValueChanged", function(self, value)
            group.spacing = math.floor(value)
            self.Text:SetText("Spacing: " .. group.spacing)
            UpdateGroupLayout(group)
        end)
        yOff = yOff - 45

        -----------------------------------------------------------------------
        -- POSITIONING
        -----------------------------------------------------------------------
        SectionHeader("Positioning")

        -- Unlock to Move button
        local unlockMoveBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        unlockMoveBtn:SetSize(130, 22)
        unlockMoveBtn:SetPoint("TOPLEFT", leftMargin, yOff)
        local gf = groupFrames[group.id]
        unlockMoveBtn:SetText(gf and gf.manualUnlock and "Lock Position" or "Unlock to Move")
        unlockMoveBtn:SetScript("OnClick", function(self)
            local f = groupFrames[group.id]
            if not f then
                -- Create the container if it doesn't exist yet
                UpdateGroupLayout(group)
                f = groupFrames[group.id]
            end
            if f then
                f.manualUnlock = not f.manualUnlock
                self:SetText(f.manualUnlock and "Lock Position" or "Unlock to Move")
                -- Update lock state on container
                if f.manualUnlock then
                    f:EnableMouse(true)
                    f.unlockBorder:Show()
                    f:Show()
                    ShowMoverOverlay(f, group.position)
                else
                    if JarsEasyTrackerCharDB.locked then
                        f:EnableMouse(false)
                        f.unlockBorder:Hide()
                    end
                    HideMoverOverlay(f)
                end
            end
        end)
        yOff = yOff - 30

        -- Helper: apply group changes
        local function ApplyGroupChanges()
            UpdateGroupLayout(group)
            RefreshLeftPanel()
        end

        -----------------------------------------------------------------------
        -- LOAD CONDITIONS
        -----------------------------------------------------------------------
        SectionHeader("Load Conditions")

        -- Class dropdown
        Label("Class:", leftMargin)
        local classDropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
        classDropdown:SetPoint("TOPLEFT", leftMargin + 50, yOff + 5)
        classDropdown:SetWidth(160)
        local currentClassDisplay = group.loadConditions.class and CLASS_DISPLAY[group.loadConditions.class] or "Any"
        classDropdown:SetDefaultText(currentClassDisplay)
        classDropdown:SetupMenu(function(_, rootDescription)
            rootDescription:CreateRadio("Any",
                function() return group.loadConditions.class == nil end,
                function()
                    group.loadConditions.class = nil
                    group.loadConditions.specIndex = nil
                    ApplyGroupChanges()
                    PopulateGroupPanel(group)
                end)
            for _, cls in ipairs(CLASS_LIST) do
                rootDescription:CreateRadio(CLASS_DISPLAY[cls],
                    function() return group.loadConditions.class == cls end,
                    function()
                        group.loadConditions.class = cls
                        ApplyGroupChanges()
                        PopulateGroupPanel(group)
                    end)
            end
        end)
        yOff = yOff - 35

        -- Spec dropdown (only if class is set)
        if group.loadConditions.class then
            Label("Spec:", leftMargin)
            local specDropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
            specDropdown:SetPoint("TOPLEFT", leftMargin + 50, yOff + 5)
            specDropdown:SetWidth(160)
            local specText = "Any"
            if group.loadConditions.specIndex then
                local _, _, classId = UnitClass("player")
                local _, specName = GetSpecializationInfoForClassID(classId or 0, group.loadConditions.specIndex)
                specText = specName or ("Spec " .. group.loadConditions.specIndex)
            end
            specDropdown:SetDefaultText(specText)
            specDropdown:SetupMenu(function(_, rootDescription)
                rootDescription:CreateRadio("Any",
                    function() return group.loadConditions.specIndex == nil end,
                    function()
                        group.loadConditions.specIndex = nil
                        ApplyGroupChanges()
                    end)
                -- Get class ID for spec lookup
                local _, _, classId = UnitClass("player")
                for i = 1, 4 do
                    local _, specName = GetSpecializationInfoForClassID(classId or 0, i)
                    if specName then
                        rootDescription:CreateRadio(specName,
                            function() return group.loadConditions.specIndex == i end,
                            function()
                                group.loadConditions.specIndex = i
                                ApplyGroupChanges()
                            end)
                    end
                end
            end)
            yOff = yOff - 35
        end

        -- Talent Spell ID
        Label("Talent Spell ID:", leftMargin)
        local talentBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        talentBox:SetPoint("TOPLEFT", leftMargin + 110, yOff + 3)
        talentBox:SetSize(80, 20)
        talentBox:SetAutoFocus(false)
        talentBox:SetText(group.loadConditions.talentSpellId and tostring(group.loadConditions.talentSpellId) or "")
        talentBox:SetScript("OnEnterPressed", function(self)
            local val = tonumber(self:GetText())
            group.loadConditions.talentSpellId = (val and val > 0) and val or nil
            self:ClearFocus()
            ApplyGroupChanges()
        end)
        talentBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

        -- Search button for talent
        local talentSearchBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        talentSearchBtn:SetSize(22, 20)
        talentSearchBtn:SetPoint("LEFT", talentBox, "RIGHT", 4, 0)
        talentSearchBtn:SetText("?")
        talentSearchBtn:SetScript("OnClick", function()
            ShowSpellSearchDialog(function(spellId)
                talentBox:SetText(tostring(spellId))
                group.loadConditions.talentSpellId = spellId
                ApplyGroupChanges()
            end)
        end)
        yOff = yOff - 28

        -- Combat dropdown
        Label("Combat:", leftMargin)
        local combatDropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
        combatDropdown:SetPoint("TOPLEFT", leftMargin + 60, yOff + 5)
        combatDropdown:SetWidth(140)
        local combatText = "Always"
        if group.loadConditions.inCombat == true then combatText = "In Combat Only"
        elseif group.loadConditions.inCombat == false then combatText = "Out of Combat" end
        combatDropdown:SetDefaultText(combatText)
        combatDropdown:SetupMenu(function(_, rootDescription)
            rootDescription:CreateRadio("Always",
                function() return group.loadConditions.inCombat == nil end,
                function() group.loadConditions.inCombat = nil; ApplyGroupChanges() end)
            rootDescription:CreateRadio("In Combat Only",
                function() return group.loadConditions.inCombat == true end,
                function() group.loadConditions.inCombat = true; ApplyGroupChanges() end)
            rootDescription:CreateRadio("Out of Combat",
                function() return group.loadConditions.inCombat == false end,
                function() group.loadConditions.inCombat = false; ApplyGroupChanges() end)
        end)
        yOff = yOff - 35

        -- Group dropdown
        Label("Group:", leftMargin)
        local grpDropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
        grpDropdown:SetPoint("TOPLEFT", leftMargin + 60, yOff + 5)
        grpDropdown:SetWidth(120)
        local grpText = "Any"
        if group.loadConditions.inGroup == "solo" then grpText = "Solo"
        elseif group.loadConditions.inGroup == "group" then grpText = "Group"
        elseif group.loadConditions.inGroup == "raid" then grpText = "Raid" end
        grpDropdown:SetDefaultText(grpText)
        grpDropdown:SetupMenu(function(_, rootDescription)
            rootDescription:CreateRadio("Any",
                function() return group.loadConditions.inGroup == nil end,
                function() group.loadConditions.inGroup = nil; ApplyGroupChanges() end)
            rootDescription:CreateRadio("Solo",
                function() return group.loadConditions.inGroup == "solo" end,
                function() group.loadConditions.inGroup = "solo"; ApplyGroupChanges() end)
            rootDescription:CreateRadio("Group",
                function() return group.loadConditions.inGroup == "group" end,
                function() group.loadConditions.inGroup = "group"; ApplyGroupChanges() end)
            rootDescription:CreateRadio("Raid",
                function() return group.loadConditions.inGroup == "raid" end,
                function() group.loadConditions.inGroup = "raid"; ApplyGroupChanges() end)
        end)
        yOff = yOff - 35

        -- Instance dropdown
        Label("Instance:", leftMargin)
        local instDropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
        instDropdown:SetPoint("TOPLEFT", leftMargin + 70, yOff + 5)
        instDropdown:SetWidth(140)
        local instText = "Any"
        if group.loadConditions.instanceType then
            for _, it in ipairs(INSTANCE_TYPES) do
                if it.key == group.loadConditions.instanceType then
                    instText = it.label
                    break
                end
            end
        end
        instDropdown:SetDefaultText(instText)
        instDropdown:SetupMenu(function(_, rootDescription)
            rootDescription:CreateRadio("Any",
                function() return group.loadConditions.instanceType == nil end,
                function() group.loadConditions.instanceType = nil; ApplyGroupChanges() end)
            for _, it in ipairs(INSTANCE_TYPES) do
                rootDescription:CreateRadio(it.label,
                    function() return group.loadConditions.instanceType == it.key end,
                    function() group.loadConditions.instanceType = it.key; ApplyGroupChanges() end)
            end
        end)
        yOff = yOff - 35

        -- Player Name
        Label("Player Name:", leftMargin)
        local nameFilterBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        nameFilterBox:SetPoint("TOPLEFT", leftMargin + 100, yOff + 3)
        nameFilterBox:SetSize(120, 20)
        nameFilterBox:SetAutoFocus(false)
        nameFilterBox:SetText(group.loadConditions.playerName or "")
        nameFilterBox:SetScript("OnEnterPressed", function(self)
            local val = self:GetText()
            group.loadConditions.playerName = (val and val ~= "") and val or nil
            self:ClearFocus()
            ApplyGroupChanges()
        end)
        nameFilterBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        yOff = yOff - 28

        -----------------------------------------------------------------------
        -- MEMBER ORDER
        -----------------------------------------------------------------------
        SectionHeader("Member Order")

        local sortedMembers = GetGroupMembersSorted(group.id, false)
        if #sortedMembers == 0 then
            local noMembers = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            noMembers:SetPoint("TOPLEFT", leftMargin, yOff)
            noMembers:SetText("|cff888888No members in this group|r")
            yOff = yOff - 22
        else
            for i, member in ipairs(sortedMembers) do
                -- Row background
                local rowBg = parent:CreateTexture(nil, "BACKGROUND")
                rowBg:SetPoint("TOPLEFT", leftMargin, yOff)
                rowBg:SetSize(420, 22)
                if i % 2 == 0 then
                    rowBg:SetColorTexture(0.15, 0.15, 0.18, 0.5)
                else
                    rowBg:SetColorTexture(0.12, 0.12, 0.14, 0.3)
                end

                -- Index number
                local idxLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                idxLabel:SetPoint("TOPLEFT", leftMargin + 4, yOff - 4)
                idxLabel:SetText("|cffaaaaaa" .. i .. ".|r")

                -- Type indicator
                local typeLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                typeLabel:SetPoint("LEFT", idxLabel, "RIGHT", 4, 0)
                if member.elementType == "icon" then
                    typeLabel:SetText("|cff80ccff[I]|r")
                else
                    typeLabel:SetText("|cff80ff80[B]|r")
                end

                -- Name
                local nameLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                nameLabel:SetPoint("LEFT", typeLabel, "RIGHT", 4, 0)
                nameLabel:SetText(member.name)
                nameLabel:SetWidth(250)
                nameLabel:SetJustifyH("LEFT")
                nameLabel:SetWordWrap(false)

                -- Move Up button
                if i > 1 then
                    local upBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
                    upBtn:SetSize(28, 18)
                    upBtn:SetPoint("TOPLEFT", leftMargin + 340, yOff - 1)
                    upBtn:SetText("Up")
                    upBtn:SetScript("OnClick", function()
                        -- Swap groupOrder with the previous member
                        local prev = sortedMembers[i - 1]
                        local prevOrder = prev.groupOrder or 0
                        local curOrder = member.groupOrder or 0
                        prev.groupOrder = curOrder
                        member.groupOrder = prevOrder
                        -- If they were equal, force distinct values
                        if prev.groupOrder == member.groupOrder then
                            member.groupOrder = member.groupOrder - 1
                        end
                        UpdateGroupLayout(group)
                        RefreshLeftPanel()
                        PopulateGroupPanel(group)
                    end)
                end

                -- Move Down button
                if i < #sortedMembers then
                    local downBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
                    downBtn:SetSize(28, 18)
                    downBtn:SetPoint("TOPLEFT", leftMargin + 372, yOff - 1)
                    downBtn:SetText("Dn")
                    downBtn:SetScript("OnClick", function()
                        -- Swap groupOrder with the next member
                        local nxt = sortedMembers[i + 1]
                        local nxtOrder = nxt.groupOrder or 0
                        local curOrder = member.groupOrder or 0
                        nxt.groupOrder = curOrder
                        member.groupOrder = nxtOrder
                        -- If they were equal, force distinct values
                        if nxt.groupOrder == member.groupOrder then
                            member.groupOrder = member.groupOrder + 1
                        end
                        UpdateGroupLayout(group)
                        RefreshLeftPanel()
                        PopulateGroupPanel(group)
                    end)
                end

                yOff = yOff - 24
            end
        end

        yOff = yOff - 8

        -- Set content height
        local totalH = math.abs(yOff) + 20
        content:SetHeight(totalH)
        configFrame.rightScrollChild:SetHeight(totalH)
    end

    ---------------------------------------------------------------------------
    -- Populate Right Panel
    ---------------------------------------------------------------------------
    PopulateRightPanel = function(element)
        ClearRightPanel()
        if configFrame.placeholder then
            configFrame.placeholder:Hide()
        end

        local content = CreateFrame("Frame", nil, configFrame.rightScrollChild)
        content:SetPoint("TOPLEFT")
        content:SetPoint("TOPRIGHT")
        configFrame.rightContent = content
        local parent = content
        local yOff = -8
        local leftMargin = 10

        -- Helper: create a section header with separator line
        local function SectionHeader(text)
            -- Separator line
            yOff = yOff - 8
            local sep = parent:CreateTexture(nil, "ARTWORK")
            sep:SetPoint("TOPLEFT", leftMargin, yOff)
            sep:SetSize(430, 1)
            sep:SetColorTexture(0.5, 0.4, 0.1, 0.6)
            yOff = yOff - 6
            -- Header text
            local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            header:SetPoint("TOPLEFT", leftMargin, yOff)
            header:SetText("|cffffcc00" .. text .. "|r")
            yOff = yOff - 20
            return header
        end

        -- Helper: create label
        local function Label(text, xOff)
            local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lbl:SetPoint("TOPLEFT", xOff or leftMargin, yOff)
            lbl:SetText(text)
            return lbl
        end

        -- Helper: create a spell search button next to an editbox
        local function SpellSearchButton(editBox, onSelect)
            local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
            btn:SetSize(22, 20)
            btn:SetPoint("LEFT", editBox, "RIGHT", 4, 0)
            btn:SetText("?")
            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Search spell by name")
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            btn:SetScript("OnClick", function()
                ShowSpellSearchDialog(function(spellId)
                    editBox:SetText(tostring(spellId))
                    if onSelect then onSelect(spellId) end
                end)
            end)
            return btn
        end

        -- Helper: apply button that refreshes display
        local function ApplyChanges()
            if displayFrames[element.id] then
                DestroyDisplay(element)
            end
            if ShouldLoad(element) then
                CreateDisplay(element)
            end
            RegisterDynamicEvents()
            RefreshLeftPanel()
            -- Re-layout groups so grouped elements get reparented
            for _, grp in ipairs(JarsEasyTrackerCharDB.groups) do
                UpdateGroupLayout(grp)
            end
        end

        -----------------------------------------------------------------------
        -- TAB BUTTONS
        -----------------------------------------------------------------------
        local settingsTab = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        settingsTab:SetSize(100, 22)
        settingsTab:SetPoint("TOPLEFT", leftMargin, yOff)
        settingsTab:SetText("Settings")

        local loadTab = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        loadTab:SetSize(100, 22)
        loadTab:SetPoint("LEFT", settingsTab, "RIGHT", 4, 0)
        loadTab:SetText("Load")

        yOff = yOff - 30
        local tabContentY = yOff

        -- Settings content frame
        local settingsContent = CreateFrame("Frame", nil, parent)
        settingsContent:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, tabContentY)
        settingsContent:SetPoint("TOPRIGHT", parent, "TOPRIGHT")

        -- Load content frame
        local loadContent = CreateFrame("Frame", nil, parent)
        loadContent:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, tabContentY)
        loadContent:SetPoint("TOPRIGHT", parent, "TOPRIGHT")
        loadContent:Hide()

        -- Tab highlight helper
        local function UpdateTabHighlight()
            if settingsContent:IsShown() then
                settingsTab:LockHighlight()
                loadTab:UnlockHighlight()
            else
                settingsTab:UnlockHighlight()
                loadTab:LockHighlight()
            end
        end

        settingsTab:SetScript("OnClick", function()
            settingsContent:Show()
            loadContent:Hide()
            configFrame.activeTab = "settings"
            UpdateTabHighlight()
        end)

        loadTab:SetScript("OnClick", function()
            settingsContent:Hide()
            loadContent:Show()
            configFrame.activeTab = "load"
            UpdateTabHighlight()
        end)

        -- Restore active tab or default to Settings
        if configFrame.activeTab == "load" then
            settingsContent:Hide()
            loadContent:Show()
            loadTab:LockHighlight()
        else
            settingsTab:LockHighlight()
        end

        -- Switch parent to settingsContent for settings widgets
        parent = settingsContent
        yOff = -8

        -----------------------------------------------------------------------
        -- GENERAL
        -----------------------------------------------------------------------
        SectionHeader("General")

        -- Name
        Label("Name:", leftMargin)
        local nameBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        nameBox:SetPoint("TOPLEFT", leftMargin + 60, yOff + 3)
        nameBox:SetSize(200, 20)
        nameBox:SetAutoFocus(false)
        nameBox:SetText(element.name)
        nameBox:SetScript("OnEnterPressed", function(self)
            element.name = self:GetText()
            self:ClearFocus()
            RefreshLeftPanel()
            if displayFrames[element.id] then
                UpdateDisplay(element)
            end
        end)
        nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        yOff = yOff - 28

        -- Type label
        Label("Type: " .. (element.elementType == "icon" and "Icon" or "Progress Bar"), leftMargin)
        yOff = yOff - 22

        -- Enabled
        local enableCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        enableCheck:SetPoint("TOPLEFT", leftMargin, yOff)
        enableCheck:SetChecked(element.enabled)
        enableCheck.text = enableCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        enableCheck.text:SetPoint("LEFT", enableCheck, "RIGHT", 2, 0)
        enableCheck.text:SetText("Enabled")
        enableCheck:SetScript("OnClick", function(self)
            element.enabled = self:GetChecked()
            ApplyChanges()
        end)
        yOff = yOff - 30

        -----------------------------------------------------------------------
        -- TRIGGER
        -----------------------------------------------------------------------
        SectionHeader("Trigger")

        Label("Type:", leftMargin)
        local triggerDropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
        triggerDropdown:SetPoint("TOPLEFT", leftMargin + 50, yOff + 5)
        triggerDropdown:SetWidth(180)
        local triggerLabels = {
            spellcast = "Spell Cast",
            aura = "Aura (Buff/Debuff)",
            spelldata = "Spell Data (Action Bar)",
        }
        triggerDropdown:SetDefaultText(triggerLabels[element.triggerType] or "Spell Cast")
        triggerDropdown:SetupMenu(function(_, rootDescription)
            for key, label in pairs(triggerLabels) do
                rootDescription:CreateRadio(label,
                    function() return element.triggerType == key end,
                    function()
                        element.triggerType = key
                        ApplyChanges()
                        PopulateRightPanel(element)
                    end)
            end
        end)
        yOff = yOff - 38

        -- Trigger-specific options
        if element.triggerType == "spellcast" then
            -- Add Stack Rules
            Label("|cff88ff88Add Stack Rules:|r", leftMargin)
            yOff = yOff - 20

            for ruleIdx, rule in ipairs(element.spellcast.addRules) do
                Label("Spell ID:", leftMargin + 10)
                local ruleSpellBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
                ruleSpellBox:SetPoint("TOPLEFT", leftMargin + 75, yOff + 3)
                ruleSpellBox:SetSize(80, 20)
                ruleSpellBox:SetAutoFocus(false)
                ruleSpellBox:SetText(tostring(rule.spellId or 0))
                ruleSpellBox:SetScript("OnEnterPressed", function(self)
                    rule.spellId = tonumber(self:GetText()) or 0
                    self:ClearFocus()
                end)
                ruleSpellBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

                -- Search button for rule spell ID
                SpellSearchButton(ruleSpellBox, function(spellId)
                    rule.spellId = spellId
                end)

                local stacksLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                stacksLabel:SetPoint("TOPLEFT", leftMargin + 190, yOff)
                stacksLabel:SetText("Stacks:")

                local ruleStacksBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
                ruleStacksBox:SetPoint("LEFT", stacksLabel, "RIGHT", 5, 0)
                ruleStacksBox:SetSize(40, 20)
                ruleStacksBox:SetAutoFocus(false)
                ruleStacksBox:SetText(tostring(rule.stacks or 1))
                ruleStacksBox:SetScript("OnEnterPressed", function(self)
                    rule.stacks = tonumber(self:GetText()) or 1
                    self:ClearFocus()
                end)
                ruleStacksBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

                local removeBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
                removeBtn:SetSize(20, 20)
                removeBtn:SetPoint("LEFT", ruleStacksBox, "RIGHT", 5, 0)
                removeBtn:SetText("X")
                removeBtn:SetScript("OnClick", function()
                    table.remove(element.spellcast.addRules, ruleIdx)
                    PopulateRightPanel(element)
                end)

                yOff = yOff - 28
            end

            -- Add rule button
            local addRuleBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
            addRuleBtn:SetSize(80, 20)
            addRuleBtn:SetPoint("TOPLEFT", leftMargin + 10, yOff)
            addRuleBtn:SetText("+ Rule")
            addRuleBtn:SetScript("OnClick", function()
                table.insert(element.spellcast.addRules, { spellId = 0, stacks = 1 })
                PopulateRightPanel(element)
            end)
            yOff = yOff - 30

            -- Clear Rules
            Label("|cffff8888Clear Rules:|r", leftMargin)
            yOff = yOff - 20

            for ruleIdx, rule in ipairs(element.spellcast.clearRules) do
                Label("Spell ID:", leftMargin + 10)
                local clearSpellBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
                clearSpellBox:SetPoint("TOPLEFT", leftMargin + 75, yOff + 3)
                clearSpellBox:SetSize(80, 20)
                clearSpellBox:SetAutoFocus(false)
                clearSpellBox:SetText(tostring(rule.spellId or 0))
                clearSpellBox:SetScript("OnEnterPressed", function(self)
                    rule.spellId = tonumber(self:GetText()) or 0
                    self:ClearFocus()
                end)
                clearSpellBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

                -- Search button for clear rule spell ID
                SpellSearchButton(clearSpellBox, function(spellId)
                    rule.spellId = spellId
                end)

                local clearStacksLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                clearStacksLabel:SetPoint("TOPLEFT", leftMargin + 190, yOff)
                clearStacksLabel:SetText("Stacks:")

                local clearStacksBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
                clearStacksBox:SetPoint("LEFT", clearStacksLabel, "RIGHT", 5, 0)
                clearStacksBox:SetSize(40, 20)
                clearStacksBox:SetAutoFocus(false)
                clearStacksBox:SetText(tostring(rule.stacks or 0))
                clearStacksBox:SetScript("OnEnterPressed", function(self)
                    rule.stacks = tonumber(self:GetText()) or 0
                    self:ClearFocus()
                end)
                clearStacksBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

                local removeClearBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
                removeClearBtn:SetSize(20, 20)
                removeClearBtn:SetPoint("LEFT", clearStacksBox, "RIGHT", 5, 0)
                removeClearBtn:SetText("X")
                removeClearBtn:SetScript("OnClick", function()
                    table.remove(element.spellcast.clearRules, ruleIdx)
                    PopulateRightPanel(element)
                end)

                yOff = yOff - 28
            end

            local addClearBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
            addClearBtn:SetSize(80, 20)
            addClearBtn:SetPoint("TOPLEFT", leftMargin + 10, yOff)
            addClearBtn:SetText("+ Rule")
            addClearBtn:SetScript("OnClick", function()
                table.insert(element.spellcast.clearRules, { spellId = 0, stacks = 0 })
                PopulateRightPanel(element)
            end)
            yOff = yOff - 30

            -- Max Stacks
            Label("Max Stacks:", leftMargin)
            local maxStacksBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
            maxStacksBox:SetPoint("TOPLEFT", leftMargin + 90, yOff + 3)
            maxStacksBox:SetSize(60, 20)
            maxStacksBox:SetAutoFocus(false)
            maxStacksBox:SetText(tostring(element.spellcast.maxStacks or 4))
            maxStacksBox:SetScript("OnEnterPressed", function(self)
                element.spellcast.maxStacks = tonumber(self:GetText()) or 4
                self:ClearFocus()
            end)
            maxStacksBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            yOff = yOff - 28

            -- Duration
            Label("Duration (0=none):", leftMargin)
            local durationBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
            durationBox:SetPoint("TOPLEFT", leftMargin + 130, yOff + 3)
            durationBox:SetSize(60, 20)
            durationBox:SetAutoFocus(false)
            durationBox:SetText(tostring(element.spellcast.duration or 0))
            durationBox:SetScript("OnEnterPressed", function(self)
                element.spellcast.duration = tonumber(self:GetText()) or 0
                self:ClearFocus()
            end)
            durationBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            yOff = yOff - 28

        elseif element.triggerType == "aura" then
            -- Aura Spell ID
            Label("Aura Spell ID:", leftMargin)
            local auraSpellBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
            auraSpellBox:SetPoint("TOPLEFT", leftMargin + 100, yOff + 3)
            auraSpellBox:SetSize(100, 20)
            auraSpellBox:SetAutoFocus(false)
            auraSpellBox:SetText(tostring(element.aura.spellId or 0))
            auraSpellBox:SetScript("OnEnterPressed", function(self)
                element.aura.spellId = tonumber(self:GetText()) or 0
                self:ClearFocus()
                ApplyChanges()
            end)
            auraSpellBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

            -- Search button
            SpellSearchButton(auraSpellBox, function(spellId)
                element.aura.spellId = spellId
                ApplyChanges()
            end)
            yOff = yOff - 28

            -- Unit dropdown
            Label("Unit:", leftMargin)
            local unitDropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
            unitDropdown:SetPoint("TOPLEFT", leftMargin + 50, yOff + 5)
            unitDropdown:SetWidth(120)
            unitDropdown:SetDefaultText(element.aura.unit == "player" and "Player" or "Target")
            unitDropdown:SetupMenu(function(_, rootDescription)
                rootDescription:CreateRadio("Player",
                    function() return element.aura.unit == "player" end,
                    function() element.aura.unit = "player"; ApplyChanges() end)
                rootDescription:CreateRadio("Target",
                    function() return element.aura.unit == "target" end,
                    function() element.aura.unit = "target"; ApplyChanges() end)
            end)
            yOff = yOff - 35

            -- Show stacks / duration checkboxes
            local auraStacksCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
            auraStacksCheck:SetPoint("TOPLEFT", leftMargin, yOff)
            auraStacksCheck:SetChecked(element.aura.showStacks)
            auraStacksCheck.text = auraStacksCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            auraStacksCheck.text:SetPoint("LEFT", auraStacksCheck, "RIGHT", 2, 0)
            auraStacksCheck.text:SetText("Show Stacks")
            auraStacksCheck:SetScript("OnClick", function(self)
                element.aura.showStacks = self:GetChecked()
                ApplyChanges()
            end)

            local auraDurCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
            auraDurCheck:SetPoint("LEFT", auraStacksCheck.text, "RIGHT", 20, 0)
            auraDurCheck:SetChecked(element.aura.showDuration)
            auraDurCheck.text = auraDurCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            auraDurCheck.text:SetPoint("LEFT", auraDurCheck, "RIGHT", 2, 0)
            auraDurCheck.text:SetText("Show Duration")
            auraDurCheck:SetScript("OnClick", function(self)
                element.aura.showDuration = self:GetChecked()
                ApplyChanges()
            end)
            yOff = yOff - 30

        elseif element.triggerType == "spelldata" then
            -- Action Slot
            Label("Action Slot:", leftMargin)
            local slotBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
            slotBox:SetPoint("TOPLEFT", leftMargin + 80, yOff + 3)
            slotBox:SetSize(80, 20)
            slotBox:SetAutoFocus(false)
            slotBox:SetText(tostring(element.spelldata.actionSlot or 0))
            slotBox:SetScript("OnEnterPressed", function(self)
                element.spelldata.actionSlot = tonumber(self:GetText()) or 0
                self:ClearFocus()
                ApplyChanges()
                PopulateRightPanel(element)
            end)
            slotBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

            -- Show the action info for context
            if element.spelldata.actionSlot and element.spelldata.actionSlot > 0 then
                pcall(function()
                    if HasAction(element.spelldata.actionSlot) then
                        local actionType, id = GetActionInfo(element.spelldata.actionSlot)
                        local name = (actionType == "spell" and C_Spell and C_Spell.GetSpellName) and C_Spell.GetSpellName(id) or "Unknown"
                        local infoLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                        infoLabel:SetPoint("LEFT", slotBox, "RIGHT", 8, 0)
                        infoLabel:SetText("|cff88ff88" .. (name or "?") .. "|r")
                    end
                end)
            end
            yOff = yOff - 28

            -- Slot reference
            local refLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            refLabel:SetPoint("TOPLEFT", leftMargin + 10, yOff)
            refLabel:SetTextColor(0.5, 0.5, 0.5)
            refLabel:SetText("Bar1: 1-12 | Bar2: 13-24 | Bar3: 25-36 | Bar4: 37-48 | Bar5: 49-60 | Bar6: 61-72")
            yOff = yOff - 18
        end

        -----------------------------------------------------------------------
        -- DISPLAY
        -----------------------------------------------------------------------
        if element.elementType == "icon" then
            SectionHeader("Display (Icon)")

            -- Spell ID for icon texture (not needed for spelldata — texture comes from action slot)
            if element.triggerType ~= "spelldata" then
                Label("Icon Spell ID:", leftMargin)
                local iconSpellBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
                iconSpellBox:SetPoint("TOPLEFT", leftMargin + 100, yOff + 3)
                iconSpellBox:SetSize(100, 20)
                iconSpellBox:SetAutoFocus(false)
                iconSpellBox:SetText(element.iconSpellId and tostring(element.iconSpellId) or "")
                iconSpellBox:SetScript("OnEnterPressed", function(self)
                    local val = tonumber(self:GetText())
                    element.iconSpellId = val
                    self:ClearFocus()
                    ApplyChanges()
                    PopulateRightPanel(element)
                end)
                iconSpellBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

                -- Search button
                SpellSearchButton(iconSpellBox, function(spellId)
                    element.iconSpellId = spellId
                    ApplyChanges()
                    PopulateRightPanel(element)
                end)

                -- Icon preview
                local preview = parent:CreateTexture(nil, "ARTWORK")
                preview:SetSize(32, 32)
                preview:SetPoint("TOPLEFT", leftMargin + 240, yOff + 9)
                if element.iconSpellId and element.iconSpellId > 0 then
                    local tex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(element.iconSpellId)
                    preview:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
                else
                    preview:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                end
                yOff = yOff - 35
            end

            -- Icon size slider
            Label("Size:", leftMargin)
            local sizeSlider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
            sizeSlider:SetPoint("TOPLEFT", leftMargin + 60, yOff - 8)
            sizeSlider:SetWidth(200)
            sizeSlider:SetMinMaxValues(24, 96)
            sizeSlider:SetValue(element.iconSize)
            sizeSlider:SetValueStep(4)
            sizeSlider:SetObeyStepOnDrag(true)
            sizeSlider.Text:SetText("Size: " .. element.iconSize)
            sizeSlider.Low:SetText("")
            sizeSlider.High:SetText("")
            sizeSlider:SetScript("OnValueChanged", function(self, value)
                element.iconSize = math.floor(value)
                self.Text:SetText("Size: " .. element.iconSize)
                ApplyChanges()
            end)
            yOff = yOff - 45

            -- These options only apply to non-spelldata triggers
            if element.triggerType ~= "spelldata" then
                -- Show stacks checkbox
                local stackCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
                stackCheck:SetPoint("TOPLEFT", leftMargin, yOff)
                stackCheck:SetChecked(element.showStacks)
                stackCheck.text = stackCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                stackCheck.text:SetPoint("LEFT", stackCheck, "RIGHT", 2, 0)
                stackCheck.text:SetText("Show Stacks")
                stackCheck:SetScript("OnClick", function(self)
                    element.showStacks = self:GetChecked()
                    ApplyChanges()
                end)

                -- Show timer checkbox
                local timerCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
                timerCheck:SetPoint("LEFT", stackCheck.text, "RIGHT", 20, 0)
                timerCheck:SetChecked(element.showTimer)
                timerCheck.text = timerCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                timerCheck.text:SetPoint("LEFT", timerCheck, "RIGHT", 2, 0)
                timerCheck.text:SetText("Show Timer")
                timerCheck:SetScript("OnClick", function(self)
                    element.showTimer = self:GetChecked()
                    ApplyChanges()
                end)
                yOff = yOff - 30

                -- Desaturate inactive
                local desatCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
                desatCheck:SetPoint("TOPLEFT", leftMargin, yOff)
                desatCheck:SetChecked(element.desaturateInactive)
                desatCheck.text = desatCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                desatCheck.text:SetPoint("LEFT", desatCheck, "RIGHT", 2, 0)
                desatCheck.text:SetText("Desaturate When Inactive (dim icon)")
                desatCheck:SetScript("OnClick", function(self)
                    element.desaturateInactive = self:GetChecked()
                    ApplyChanges()
                end)
                yOff = yOff - 30
            end

            -- Stack/Charges font size (always shown)
            local fontLabel = element.triggerType == "spelldata" and "Font:" or "Stack Font:"
            Label(fontLabel, leftMargin)
            local stackFontSlider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
            stackFontSlider:SetPoint("TOPLEFT", leftMargin + 80, yOff - 8)
            stackFontSlider:SetWidth(150)
            stackFontSlider:SetMinMaxValues(12, 48)
            stackFontSlider:SetValue(element.stackFontSize)
            stackFontSlider:SetValueStep(2)
            stackFontSlider:SetObeyStepOnDrag(true)
            stackFontSlider.Text:SetText(tostring(element.stackFontSize))
            stackFontSlider.Low:SetText("")
            stackFontSlider.High:SetText("")
            stackFontSlider:SetScript("OnValueChanged", function(self, value)
                element.stackFontSize = math.floor(value)
                self.Text:SetText(tostring(element.stackFontSize))
                ApplyChanges()
            end)
            yOff = yOff - 45

            -- Timer font size (only for non-spelldata)
            if element.triggerType ~= "spelldata" then
                Label("Timer Font:", leftMargin)
                local timerFontSlider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
                timerFontSlider:SetPoint("TOPLEFT", leftMargin + 80, yOff - 8)
                timerFontSlider:SetWidth(150)
                timerFontSlider:SetMinMaxValues(8, 32)
                timerFontSlider:SetValue(element.timerFontSize)
                timerFontSlider:SetValueStep(2)
                timerFontSlider:SetObeyStepOnDrag(true)
                timerFontSlider.Text:SetText(tostring(element.timerFontSize))
                timerFontSlider.Low:SetText("")
                timerFontSlider.High:SetText("")
                timerFontSlider:SetScript("OnValueChanged", function(self, value)
                    element.timerFontSize = math.floor(value)
                    self.Text:SetText(tostring(element.timerFontSize))
                    ApplyChanges()
                end)
                yOff = yOff - 45
            end

            -- Show glow checkbox (label varies by trigger type) — not for spelldata
            if element.triggerType ~= "spelldata" then
                local glowCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
                glowCheck:SetPoint("TOPLEFT", leftMargin, yOff)
                glowCheck:SetChecked(element.showGlow)
                glowCheck.text = glowCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                glowCheck.text:SetPoint("LEFT", glowCheck, "RIGHT", 2, 0)
                local glowLabel = "Show Glow When Active"
                if element.triggerType == "spellcast" then
                    glowLabel = "Glow at Max Stacks"
                end
                glowCheck.text:SetText(glowLabel)
                glowCheck:SetScript("OnClick", function(self)
                    element.showGlow = self:GetChecked()
                    ApplyChanges()
                end)
                yOff = yOff - 30

                -- Glow style dropdown
                Label("Glow Style:", leftMargin)
                local glowStyleDropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
                glowStyleDropdown:SetPoint("TOPLEFT", leftMargin + 80, yOff + 5)
                glowStyleDropdown:SetWidth(150)
                glowStyleDropdown:SetDefaultText(FindGlowStyle(element.glowStyle or "glow").label)
                glowStyleDropdown:SetupMenu(function(dropdown, rootDescription)
                    for _, style in ipairs(GLOW_STYLES) do
                        rootDescription:CreateButton(style.label, function()
                            element.glowStyle = style.key
                            ApplyChanges()
                        end)
                    end
                end)
                yOff = yOff - 38
            end

            -- Opacity slider
            Label("Opacity:", leftMargin)
            local alphaSlider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
            alphaSlider:SetPoint("TOPLEFT", leftMargin + 80, yOff - 8)
            alphaSlider:SetWidth(150)
            alphaSlider:SetMinMaxValues(0.1, 1.0)
            alphaSlider:SetValue(element.iconAlpha or 1.0)
            alphaSlider:SetValueStep(0.1)
            alphaSlider:SetObeyStepOnDrag(true)
            alphaSlider.Text:SetText(string.format("%.0f%%", (element.iconAlpha or 1.0) * 100))
            alphaSlider.Low:SetText("")
            alphaSlider.High:SetText("")
            alphaSlider:SetScript("OnValueChanged", function(self, value)
                value = math.floor(value * 10 + 0.5) / 10
                element.iconAlpha = value
                self.Text:SetText(string.format("%.0f%%", value * 100))
                ApplyChanges()
            end)
            yOff = yOff - 45

            -- Stack/Charges text position dropdown
            local posLabel = element.triggerType == "spelldata" and "Charges Pos:" or "Stack Pos:"
            Label(posLabel, leftMargin)
            local stackPosDropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
            stackPosDropdown:SetPoint("TOPLEFT", leftMargin + 80, yOff + 5)
            stackPosDropdown:SetWidth(150)
            local curStackPos = FindFontPosition(element.stackPosition or "CENTER")
            stackPosDropdown:SetDefaultText(curStackPos.label)
            stackPosDropdown:SetupMenu(function(_, rootDescription)
                for _, pos in ipairs(FONT_POSITIONS) do
                    rootDescription:CreateRadio(pos.label,
                        function() return (element.stackPosition or "CENTER") == pos.key end,
                        function()
                            element.stackPosition = pos.key
                            ApplyChanges()
                        end)
                end
            end)
            yOff = yOff - 35

            -- Timer text position dropdown (only for non-spelldata)
            if element.triggerType ~= "spelldata" then
                Label("Timer Pos:", leftMargin)
                local timerPosDropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
                timerPosDropdown:SetPoint("TOPLEFT", leftMargin + 80, yOff + 5)
                timerPosDropdown:SetWidth(150)
                local curTimerPos = FindFontPosition(element.timerPosition or "BOTTOM")
                timerPosDropdown:SetDefaultText(curTimerPos.label)
                timerPosDropdown:SetupMenu(function(_, rootDescription)
                    for _, pos in ipairs(FONT_POSITIONS) do
                        rootDescription:CreateRadio(pos.label,
                            function() return (element.timerPosition or "BOTTOM") == pos.key end,
                            function()
                                element.timerPosition = pos.key
                                ApplyChanges()
                            end)
                    end
                end)
                yOff = yOff - 35
            end

        elseif element.elementType == "progressbar" then
            SectionHeader("Display (Progress Bar)")

            -- Bar width
            Label("Width:", leftMargin)
            local widthSlider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
            widthSlider:SetPoint("TOPLEFT", leftMargin + 60, yOff - 8)
            widthSlider:SetWidth(200)
            widthSlider:SetMinMaxValues(50, 400)
            widthSlider:SetValue(element.barWidth)
            widthSlider:SetValueStep(10)
            widthSlider:SetObeyStepOnDrag(true)
            widthSlider.Text:SetText("Width: " .. element.barWidth)
            widthSlider.Low:SetText("")
            widthSlider.High:SetText("")
            widthSlider:SetScript("OnValueChanged", function(self, value)
                element.barWidth = math.floor(value)
                self.Text:SetText("Width: " .. element.barWidth)
                ApplyChanges()
            end)
            yOff = yOff - 45

            -- Bar height
            Label("Height:", leftMargin)
            local heightSlider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
            heightSlider:SetPoint("TOPLEFT", leftMargin + 60, yOff - 8)
            heightSlider:SetWidth(200)
            heightSlider:SetMinMaxValues(10, 40)
            heightSlider:SetValue(element.barHeight)
            heightSlider:SetValueStep(2)
            heightSlider:SetObeyStepOnDrag(true)
            heightSlider.Text:SetText("Height: " .. element.barHeight)
            heightSlider.Low:SetText("")
            heightSlider.High:SetText("")
            heightSlider:SetScript("OnValueChanged", function(self, value)
                element.barHeight = math.floor(value)
                self.Text:SetText("Height: " .. element.barHeight)
                ApplyChanges()
            end)
            yOff = yOff - 45

            -- Bar texture dropdown
            Label("Texture:", leftMargin)
            local barTexDropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
            barTexDropdown:SetPoint("TOPLEFT", leftMargin + 70, yOff + 5)
            barTexDropdown:SetWidth(150)
            barTexDropdown:SetDefaultText(element.barTexture or "Blizzard")
            barTexDropdown:SetupMenu(function(_, rootDescription)
                for name in pairs(BAR_TEXTURES) do
                    rootDescription:CreateRadio(name,
                        function() return element.barTexture == name end,
                        function()
                            element.barTexture = name
                            ApplyChanges()
                        end)
                end
            end)
            yOff = yOff - 35

            -- Bar color picker
            Label("Bar Color:", leftMargin)
            local barColorBtn = CreateFrame("Button", nil, parent)
            barColorBtn:SetSize(50, 20)
            barColorBtn:SetPoint("TOPLEFT", leftMargin + 80, yOff)
            barColorBtn.tex = barColorBtn:CreateTexture(nil, "BACKGROUND")
            barColorBtn.tex:SetAllPoints()
            barColorBtn.tex:SetColorTexture(element.barColor.r, element.barColor.g, element.barColor.b)
            barColorBtn:SetScript("OnClick", function(self)
                local c = element.barColor
                ColorPickerFrame:SetupColorPickerAndShow({
                    r = c.r, g = c.g, b = c.b,
                    hasOpacity = false,
                    swatchFunc = function()
                        local r, g, b = ColorPickerFrame:GetColorRGB()
                        element.barColor = { r = r, g = g, b = b }
                        self.tex:SetColorTexture(r, g, b)
                        ApplyChanges()
                    end,
                    cancelFunc = function()
                        self.tex:SetColorTexture(c.r, c.g, c.b)
                        element.barColor = c
                        ApplyChanges()
                    end,
                })
            end)
            yOff = yOff - 28

            -- Show text / timer checkboxes
            local showTextCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
            showTextCheck:SetPoint("TOPLEFT", leftMargin, yOff)
            showTextCheck:SetChecked(element.showBarText)
            showTextCheck.text = showTextCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            showTextCheck.text:SetPoint("LEFT", showTextCheck, "RIGHT", 2, 0)
            showTextCheck.text:SetText("Show Label")
            showTextCheck:SetScript("OnClick", function(self)
                element.showBarText = self:GetChecked()
                ApplyChanges()
            end)

            local showTimerCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
            showTimerCheck:SetPoint("LEFT", showTextCheck.text, "RIGHT", 20, 0)
            showTimerCheck:SetChecked(element.showBarTimer)
            showTimerCheck.text = showTimerCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            showTimerCheck.text:SetPoint("LEFT", showTimerCheck, "RIGHT", 2, 0)
            showTimerCheck.text:SetText("Show Timer")
            showTimerCheck:SetScript("OnClick", function(self)
                element.showBarTimer = self:GetChecked()
                ApplyChanges()
            end)
            yOff = yOff - 30

            -- Font size
            Label("Font Size:", leftMargin)
            local barFontSlider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
            barFontSlider:SetPoint("TOPLEFT", leftMargin + 80, yOff - 8)
            barFontSlider:SetWidth(150)
            barFontSlider:SetMinMaxValues(8, 24)
            barFontSlider:SetValue(element.barFontSize)
            barFontSlider:SetValueStep(1)
            barFontSlider:SetObeyStepOnDrag(true)
            barFontSlider.Text:SetText(tostring(element.barFontSize))
            barFontSlider.Low:SetText("")
            barFontSlider.High:SetText("")
            barFontSlider:SetScript("OnValueChanged", function(self, value)
                element.barFontSize = math.floor(value)
                self.Text:SetText(tostring(element.barFontSize))
                ApplyChanges()
            end)
            yOff = yOff - 45
        end

        -----------------------------------------------------------------------
        -- POSITIONING
        -----------------------------------------------------------------------
        SectionHeader("Positioning")

        -- Positioning mode dropdown
        Label("Mode:", leftMargin)
        local posDropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
        posDropdown:SetPoint("TOPLEFT", leftMargin + 50, yOff + 5)
        posDropdown:SetWidth(160)
        posDropdown:SetDefaultText(element.positioning == "grouped" and "Grouped" or "Independent")
        posDropdown:SetupMenu(function(_, rootDescription)
            rootDescription:CreateRadio("Independent",
                function() return element.positioning == "independent" end,
                function()
                    element.positioning = "independent"
                    element.groupId = nil
                    ApplyChanges()
                    for _, grp in ipairs(JarsEasyTrackerCharDB.groups) do
                        UpdateGroupLayout(grp)
                    end
                    PopulateRightPanel(element)
                end)
            rootDescription:CreateRadio("Grouped",
                function() return element.positioning == "grouped" end,
                function()
                    element.positioning = "grouped"
                    ApplyChanges()
                    PopulateRightPanel(element)
                end)
        end)
        yOff = yOff - 35

        -- Group selector (only when grouped)
        if element.positioning == "grouped" then
            Label("Group:", leftMargin)
            local groupSelDropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
            groupSelDropdown:SetPoint("TOPLEFT", leftMargin + 50, yOff + 5)
            groupSelDropdown:SetWidth(160)
            local currentGroupName = "None"
            if element.groupId then
                local grp = FindGroupById(element.groupId)
                if grp then currentGroupName = grp.name end
            end
            groupSelDropdown:SetDefaultText(currentGroupName)
            groupSelDropdown:SetupMenu(function(_, rootDescription)
                rootDescription:CreateRadio("None",
                    function() return element.groupId == nil end,
                    function()
                        element.groupId = nil
                        ApplyChanges()
                        for _, grp in ipairs(JarsEasyTrackerCharDB.groups) do
                            UpdateGroupLayout(grp)
                        end
                    end)
                for _, grp in ipairs(JarsEasyTrackerCharDB.groups) do
                    rootDescription:CreateRadio(grp.name .. " (ID: " .. grp.id .. ")",
                        function() return element.groupId == grp.id end,
                        function()
                            element.groupId = grp.id
                            element.groupOrder = GetNextGroupOrder(grp.id)
                            ApplyChanges()
                            for _, g in ipairs(JarsEasyTrackerCharDB.groups) do
                                UpdateGroupLayout(g)
                            end
                        end)
                end
            end)
            yOff = yOff - 35
        end

        -- Unlock to Move button
        local unlockMoveBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        unlockMoveBtn:SetSize(130, 22)
        unlockMoveBtn:SetPoint("TOPLEFT", leftMargin, yOff)
        local df = displayFrames[element.id]
        unlockMoveBtn:SetText(df and df.manualUnlock and "Lock Position" or "Unlock to Move")
        unlockMoveBtn:SetScript("OnClick", function(self)
            local f = displayFrames[element.id]
            if f then
                f.manualUnlock = not f.manualUnlock
                self:SetText(f.manualUnlock and "Lock Position" or "Unlock to Move")
                UpdateDisplay(element)
            end
        end)
        yOff = yOff - 30

        -- Save settings content height
        local settingsH = math.abs(yOff) + 20
        settingsContent:SetHeight(settingsH)

        -----------------------------------------------------------------------
        -- LOAD CONDITIONS (on Load tab)
        -----------------------------------------------------------------------
        parent = loadContent
        yOff = -8

        SectionHeader("Load Conditions")

        -- Class dropdown
        Label("Class:", leftMargin)
        local classDropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
        classDropdown:SetPoint("TOPLEFT", leftMargin + 50, yOff + 5)
        classDropdown:SetWidth(160)
        local currentClassDisplay = element.loadConditions.class and CLASS_DISPLAY[element.loadConditions.class] or "Any"
        classDropdown:SetDefaultText(currentClassDisplay)
        classDropdown:SetupMenu(function(_, rootDescription)
            rootDescription:CreateRadio("Any",
                function() return element.loadConditions.class == nil end,
                function()
                    element.loadConditions.class = nil
                    element.loadConditions.specIndex = nil
                    ApplyChanges()
                    PopulateRightPanel(element)
                end)
            for _, cls in ipairs(CLASS_LIST) do
                rootDescription:CreateRadio(CLASS_DISPLAY[cls],
                    function() return element.loadConditions.class == cls end,
                    function()
                        element.loadConditions.class = cls
                        ApplyChanges()
                        PopulateRightPanel(element)
                    end)
            end
        end)
        yOff = yOff - 35

        -- Spec dropdown (only if class is set)
        if element.loadConditions.class then
            Label("Spec:", leftMargin)
            local specDropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
            specDropdown:SetPoint("TOPLEFT", leftMargin + 50, yOff + 5)
            specDropdown:SetWidth(160)
            local specText = "Any"
            if element.loadConditions.specIndex then
                local _, _, classId = UnitClass("player")
                local _, specName = GetSpecializationInfoForClassID(classId or 0, element.loadConditions.specIndex)
                specText = specName or ("Spec " .. element.loadConditions.specIndex)
            end
            specDropdown:SetDefaultText(specText)
            specDropdown:SetupMenu(function(_, rootDescription)
                rootDescription:CreateRadio("Any",
                    function() return element.loadConditions.specIndex == nil end,
                    function()
                        element.loadConditions.specIndex = nil
                        ApplyChanges()
                    end)
                local _, _, classId = UnitClass("player")
                for i = 1, 4 do
                    local _, specName = GetSpecializationInfoForClassID(classId or 0, i)
                    if specName then
                        rootDescription:CreateRadio(specName,
                            function() return element.loadConditions.specIndex == i end,
                            function()
                                element.loadConditions.specIndex = i
                                ApplyChanges()
                            end)
                    end
                end
            end)
            yOff = yOff - 35
        end

        -- Talent Spell ID
        Label("Talent Spell ID:", leftMargin)
        local talentBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        talentBox:SetPoint("TOPLEFT", leftMargin + 110, yOff + 3)
        talentBox:SetSize(80, 20)
        talentBox:SetAutoFocus(false)
        talentBox:SetText(element.loadConditions.talentSpellId and tostring(element.loadConditions.talentSpellId) or "")
        talentBox:SetScript("OnEnterPressed", function(self)
            local val = tonumber(self:GetText())
            element.loadConditions.talentSpellId = (val and val > 0) and val or nil
            self:ClearFocus()
            ApplyChanges()
        end)
        talentBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

        -- Search button for talent
        SpellSearchButton(talentBox, function(spellId)
            element.loadConditions.talentSpellId = spellId
            ApplyChanges()
        end)
        yOff = yOff - 28

        -- Combat dropdown
        Label("Combat:", leftMargin)
        local combatDropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
        combatDropdown:SetPoint("TOPLEFT", leftMargin + 60, yOff + 5)
        combatDropdown:SetWidth(140)
        local combatText = "Always"
        if element.loadConditions.inCombat == true then combatText = "In Combat Only"
        elseif element.loadConditions.inCombat == false then combatText = "Out of Combat" end
        combatDropdown:SetDefaultText(combatText)
        combatDropdown:SetupMenu(function(_, rootDescription)
            rootDescription:CreateRadio("Always",
                function() return element.loadConditions.inCombat == nil end,
                function() element.loadConditions.inCombat = nil; ApplyChanges() end)
            rootDescription:CreateRadio("In Combat Only",
                function() return element.loadConditions.inCombat == true end,
                function() element.loadConditions.inCombat = true; ApplyChanges() end)
            rootDescription:CreateRadio("Out of Combat",
                function() return element.loadConditions.inCombat == false end,
                function() element.loadConditions.inCombat = false; ApplyChanges() end)
        end)
        yOff = yOff - 35

        -- Group dropdown
        Label("Group:", leftMargin)
        local grpDropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
        grpDropdown:SetPoint("TOPLEFT", leftMargin + 60, yOff + 5)
        grpDropdown:SetWidth(120)
        local grpText = "Any"
        if element.loadConditions.inGroup == "solo" then grpText = "Solo"
        elseif element.loadConditions.inGroup == "group" then grpText = "Group"
        elseif element.loadConditions.inGroup == "raid" then grpText = "Raid" end
        grpDropdown:SetDefaultText(grpText)
        grpDropdown:SetupMenu(function(_, rootDescription)
            rootDescription:CreateRadio("Any",
                function() return element.loadConditions.inGroup == nil end,
                function() element.loadConditions.inGroup = nil; ApplyChanges() end)
            rootDescription:CreateRadio("Solo",
                function() return element.loadConditions.inGroup == "solo" end,
                function() element.loadConditions.inGroup = "solo"; ApplyChanges() end)
            rootDescription:CreateRadio("Group",
                function() return element.loadConditions.inGroup == "group" end,
                function() element.loadConditions.inGroup = "group"; ApplyChanges() end)
            rootDescription:CreateRadio("Raid",
                function() return element.loadConditions.inGroup == "raid" end,
                function() element.loadConditions.inGroup = "raid"; ApplyChanges() end)
        end)
        yOff = yOff - 35

        -- Instance dropdown
        Label("Instance:", leftMargin)
        local instDropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
        instDropdown:SetPoint("TOPLEFT", leftMargin + 70, yOff + 5)
        instDropdown:SetWidth(140)
        local instText = "Any"
        if element.loadConditions.instanceType then
            for _, it in ipairs(INSTANCE_TYPES) do
                if it.key == element.loadConditions.instanceType then
                    instText = it.label
                    break
                end
            end
        end
        instDropdown:SetDefaultText(instText)
        instDropdown:SetupMenu(function(_, rootDescription)
            rootDescription:CreateRadio("Any",
                function() return element.loadConditions.instanceType == nil end,
                function() element.loadConditions.instanceType = nil; ApplyChanges() end)
            for _, it in ipairs(INSTANCE_TYPES) do
                rootDescription:CreateRadio(it.label,
                    function() return element.loadConditions.instanceType == it.key end,
                    function() element.loadConditions.instanceType = it.key; ApplyChanges() end)
            end
        end)
        yOff = yOff - 35

        -- Player Name
        Label("Player Name:", leftMargin)
        local nameFilterBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        nameFilterBox:SetPoint("TOPLEFT", leftMargin + 100, yOff + 3)
        nameFilterBox:SetSize(120, 20)
        nameFilterBox:SetAutoFocus(false)
        nameFilterBox:SetText(element.loadConditions.playerName or "")
        nameFilterBox:SetScript("OnEnterPressed", function(self)
            local val = self:GetText()
            element.loadConditions.playerName = (val and val ~= "") and val or nil
            self:ClearFocus()
            ApplyChanges()
        end)
        nameFilterBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        yOff = yOff - 28

        -- Save load content height
        local loadH = math.abs(yOff) + 20
        loadContent:SetHeight(loadH)

        -- Set overall scroll child height
        local totalH = math.abs(tabContentY) + math.max(settingsH, loadH)
        content:SetHeight(totalH)
        configFrame.rightScrollChild:SetHeight(totalH)
    end

    return configFrame
end

--------------------------------------------------------------------------------
-- Section 18: Slash Commands
--------------------------------------------------------------------------------

-- Global entry point for external launchers (e.g. JarsAddonConfig)
function JarsEasyTracker_OpenConfig()
    local frame = CreateConfigWindow()
    if frame:IsShown() then
        frame:Hide()
    else
        RefreshLeftPanel()
        frame:Show()
    end
end

SLASH_JARSEASYTRACKER1 = "/jtrack"
SLASH_JARSEASYTRACKER2 = "/jet"
SlashCmdList["JARSEASYTRACKER"] = function(msg)
    msg = (msg or ""):lower():trim()

    if msg == "lock" then
        JarsEasyTrackerCharDB.locked = true
        for _, element in ipairs(JarsEasyTrackerCharDB.elements) do
            UpdateDisplay(element)
        end
        for _, group in ipairs(JarsEasyTrackerCharDB.groups) do
            UpdateGroupLayout(group)
        end
        if configFrame and configFrame.lockBtn then
            configFrame.lockBtn:SetText("Unlock")
        end
        print("|cff00ff00JET:|r Frames locked.")
        return
    elseif msg == "unlock" then
        JarsEasyTrackerCharDB.locked = false
        for _, element in ipairs(JarsEasyTrackerCharDB.elements) do
            UpdateDisplay(element)
        end
        for _, group in ipairs(JarsEasyTrackerCharDB.groups) do
            UpdateGroupLayout(group)
        end
        if configFrame and configFrame.lockBtn then
            configFrame.lockBtn:SetText("Lock")
        end
        print("|cff00ff00JET:|r Frames unlocked. Drag to reposition.")
        return
    elseif msg == "reset" then
        for _, element in ipairs(JarsEasyTrackerCharDB.elements) do
            element.position = { point = "CENTER", x = 0, y = 0 }
        end
        for _, group in ipairs(JarsEasyTrackerCharDB.groups) do
            group.position = { point = "CENTER", x = 0, y = 0 }
        end
        RefreshAllDisplays()
        print("|cff00ff00JET:|r All positions reset.")
        return
    end

    -- Toggle config window
    local frame = CreateConfigWindow()
    if frame:IsShown() then
        frame:Hide()
    else
        RefreshLeftPanel()
        frame:Show()
    end
end
