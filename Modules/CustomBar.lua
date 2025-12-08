local _, BCDM = ...
BCDM.CustomFrames = BCDM.CustomFrames or {}

local CustomSpells = {
    -- Monk
    ["MONK"] = {
        [115203] = true,        -- Fortifying Brew
        [1241059] = true,       -- Celestial Infusion
        [322507] = true,        -- Celestial Brew
        [122470] = true,        -- Touch of Karma
    },
    -- Demon Hunter
    ["DEMONHUNTER"] = {
        [196718] = true,        -- Darkness
        [198589] = true,        -- Blur
        [203720] = true,        -- Demon Spikes
    },
    -- Death Knight
    ["DEATHKNIGHT"] = {
        [55233] = true,         -- Vampiric Blood
        [48707] = true,         -- Anti-Magic Shell
        [51052] = true,         -- Anti-Magic Zone
        [49039] = true,         -- Lichborne
        [48792] = true,         -- Icebound Fortitude
    },
    -- Mage
    ["MAGE"] = {
        [342245] = true,        -- Alter Time
        [11426] = true,         -- Ice Barrier
        [235313] = true,        -- Blazing Barrier
        [235450] = true,        -- Prismatic Barrier
        [45438] = true,         -- Ice Block
    },
    -- Paladin
    ["PALADIN"] = {
        [1022] = true,          -- Blessing of Protection
        [642] = true,           -- Divine Shield
        [403876] = true,        -- Divine Shield
        [6940] = true,          -- Blessing of Sacrifice
        [86659] = true,         -- Guardian of Ancient Kings
        [31850] = true,         -- Ardent Defender
        [204018] = true,        -- Blessing of Spellwarding
        [633] = true,           -- Lay on Hands
    },
    -- Shaman
    ["SHAMAN"] = {
        [108271] = true,        -- Astral Shift
    },
    -- Druid
    ["DRUID"] = {
        [22812] = true,         -- Barkskin
        [61336] = true,         -- Survival Instincts
    },
    -- Evoker
    ["EVOKER"] = {
        [363916] = true,        -- Obsidian Scales
        [374227] = true,        -- Zephyr
    },
    -- Warrior
    ["WARRIOR"] = {
        [118038] = true,        -- Die by the Sword
        [184364] = true,        -- Enraged Regeneration
        [23920] = true,         -- Spell Reflection
        [97462] = true,         -- Rallying Cry
        [871] = true,           -- Shield Wall
    },
    -- Priest
    ["PRIEST"] = {
        [47585] = true,         -- Dispersion
        [19236] = true,         -- Desperate Prayer
        [586] = true,           -- Fade
    },
    -- Warlock
    ["WARLOCK"] = {
        [104773] = true,        -- Unending Resolve
        [108416] = true,        -- Dark Pact
    },
    -- Hunter
    ["HUNTER"] = {
        [186265] = true,        -- Aspect of the Turtle
        [264735] = true,        -- Survival of the Fittest
        [109304] = true,        -- Exhilaration
        [272682] = true,        -- Command Pet: Master's Call
        [272678] = true,        -- Command Pet: Primal Rage
    },
    -- Rogue
    ["ROGUE"] = {
        [31224] = true,         -- Cloak of Shadows
        [1966] = true,          -- Feint
        [5277] = true,          -- Evasion
        [185311] = true,        -- Crimson Vial
    }
}

BCDM.CustomSpells = CustomSpells

function CreateCustomIcon(spellId)
    local CooldownManagerDB = BCDM.db.profile
    local GeneralDB = CooldownManagerDB.General
    local CustomDB = CooldownManagerDB.Custom
    if not spellId then return end
    -- if not C_SpellBook.IsSpellKnown(spellId, Enum.SpellBookSpellBank.Player) and not C_SpellBook.IsSpellKnown(spellId, Enum.SpellBookSpellBank.Pet) then return end
    if not C_SpellBook.IsSpellInSpellBook(spellId) then return end

    local customSpellIcon = CreateFrame("Button", "BCDM_Custom_" .. spellId, UIParent, "BackdropTemplate")
    customSpellIcon:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1, insets = { left = 0, right = 0, top = 0, bottom = 0 } })
    customSpellIcon:SetBackdropBorderColor(0, 0, 0, 1)
    customSpellIcon:SetSize(CustomDB.IconSize[1], CustomDB.IconSize[2])
    customSpellIcon:SetPoint(unpack(CustomDB.Anchors))
    customSpellIcon:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    customSpellIcon:RegisterEvent("PLAYER_ENTERING_WORLD")
    customSpellIcon:RegisterEvent("SPELL_UPDATE_CHARGES")

    local HighLevelContainer = CreateFrame("Frame", nil, customSpellIcon)
    HighLevelContainer:SetAllPoints(customSpellIcon)
    HighLevelContainer:SetFrameLevel(customSpellIcon:GetFrameLevel() + 999)

    customSpellIcon.Charges = HighLevelContainer:CreateFontString(nil, "OVERLAY")
    customSpellIcon.Charges:SetFont(BCDM.Media.Font, CustomDB.Count.FontSize, GeneralDB.FontFlag)
    customSpellIcon.Charges:SetPoint(CustomDB.Count.Anchors[1], customSpellIcon, CustomDB.Count.Anchors[2], CustomDB.Count.Anchors[3], CustomDB.Count.Anchors[4])
    customSpellIcon.Charges:SetTextColor(CustomDB.Count.Colour[1], CustomDB.Count.Colour[2], CustomDB.Count.Colour[3], 1)
    customSpellIcon.Charges:SetShadowColor(GeneralDB.Shadows.Colour[1], GeneralDB.Shadows.Colour[2], GeneralDB.Shadows.Colour[3], GeneralDB.Shadows.Colour[4])
    customSpellIcon.Charges:SetShadowOffset(GeneralDB.Shadows.OffsetX, GeneralDB.Shadows.OffsetY)

    customSpellIcon.Cooldown = CreateFrame("Cooldown", nil, customSpellIcon, "CooldownFrameTemplate")
    customSpellIcon.Cooldown:SetAllPoints(customSpellIcon)
    customSpellIcon.Cooldown:SetDrawEdge(false)
    customSpellIcon.Cooldown:SetDrawSwipe(true)
    customSpellIcon.Cooldown:SetSwipeColor(0, 0, 0, 0.8)
    customSpellIcon.Cooldown:SetHideCountdownNumbers(false)
    customSpellIcon.Cooldown:SetReverse(false)

    customSpellIcon:HookScript("OnEvent", function(self, event, ...)
        if event == "SPELL_UPDATE_COOLDOWN" or event == "PLAYER_ENTERING_WORLD" or event == "SPELL_UPDATE_CHARGES" then
            local spellCharges = C_Spell.GetSpellCharges(spellId)
            if spellCharges then
                customSpellIcon.Charges:SetText(tostring(spellCharges.currentCharges))
                customSpellIcon.Cooldown:SetCooldown(spellCharges.cooldownStartTime, spellCharges.cooldownDuration)
            else
                local cooldownData = C_Spell.GetSpellCooldown(spellId)
                customSpellIcon.Cooldown:SetCooldown(cooldownData.startTime, cooldownData.duration)
            end
        end
    end)

    customSpellIcon.Icon = customSpellIcon:CreateTexture(nil, "BACKGROUND")
    customSpellIcon.Icon:SetPoint("TOPLEFT", customSpellIcon, "TOPLEFT", 1, -1)
    customSpellIcon.Icon:SetPoint("BOTTOMRIGHT", customSpellIcon, "BOTTOMRIGHT", -1, 1)
    customSpellIcon.Icon:SetTexCoord((GeneralDB.IconZoom) * 0.5, 1 - (GeneralDB.IconZoom) * 0.5, (GeneralDB.IconZoom) * 0.5, 1 - (GeneralDB.IconZoom) * 0.5)
    customSpellIcon.Icon:SetTexture(C_Spell.GetSpellInfo(spellId).iconID)

    return customSpellIcon
end

local LayoutConfig = {
    TOPLEFT     = { anchor="TOPLEFT",   offsetMultiplier=0   },
    TOP         = { anchor="TOP",       offsetMultiplier=0   },
    TOPRIGHT    = { anchor="TOPRIGHT",  offsetMultiplier=0   },
    BOTTOMLEFT  = { anchor="TOPLEFT",   offsetMultiplier=1   },
    BOTTOM      = { anchor="TOP",       offsetMultiplier=1   },
    BOTTOMRIGHT = { anchor="TOPRIGHT",  offsetMultiplier=1   },
    CENTER      = { anchor="CENTER",    offsetMultiplier=0.5, isCenter=true },
    LEFT        = { anchor="LEFT",      offsetMultiplier=0.5, isCenter=true },
    RIGHT       = { anchor="RIGHT",     offsetMultiplier=0.5, isCenter=true },
}

function LayoutCustomIcons()
    local CustomDB = BCDM.db.profile.Custom
    local icons = BCDM.CustomBar
    if #icons == 0 then return end
    if not BCDM.CustomContainer then BCDM.CustomContainer = CreateFrame("Frame", "CustomCooldownViewer", UIParent) end

    local CustomContainer = BCDM.CustomContainer
    local spacing = CustomDB.Spacing
    local iconW   = icons[1]:GetWidth()
    local iconH   = icons[1]:GetHeight()
    local totalW  = (iconW + spacing) * #icons - spacing

    CustomContainer:SetSize(totalW, iconH)
    local layoutConfig = LayoutConfig[CustomDB.Anchors[1]]

    local offsetX = totalW * layoutConfig.offsetMultiplier
    if layoutConfig.isCenter then offsetX = offsetX - iconW / 2 end

    CustomContainer:ClearAllPoints()
    CustomContainer:SetPoint(CustomDB.Anchors[1], CustomDB.Anchors[2], CustomDB.Anchors[3], CustomDB.Anchors[4], CustomDB.Anchors[5])

    local growLeft  = (CustomDB.GrowthDirection == "LEFT")
    for i, icon in ipairs(icons) do
        icon:ClearAllPoints()
        if i == 1 then
            if growLeft then
                icon:SetPoint("RIGHT", CustomContainer, "RIGHT", 0, 0)
            else
                icon:SetPoint("LEFT", CustomContainer, "LEFT", 0, 0)
            end
        else
            local previousIcon = icons[i-1]
            if growLeft then
                icon:SetPoint("RIGHT", previousIcon, "LEFT", -spacing, 0)
            else
                icon:SetPoint("LEFT", previousIcon, "RIGHT", spacing, 0)
            end
        end
    end

    CustomContainer:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    CustomContainer:SetScript("OnEvent", function(self, event, ...)
        if event == "PLAYER_SPECIALIZATION_CHANGED" then
            BCDM:ResetCustomIcons()
        end
    end)
end

function BCDM:SetupCustomIcons()
    local CooldownManagerDB = BCDM.db.profile
    wipe(BCDM.CustomFrames)
    wipe(BCDM.CustomBar)
    local _, class = UnitClass("player")

    local spellList = CooldownManagerDB.Custom.CustomSpells[class] or {}
    for spellId, isActive in pairs(spellList) do
        if spellId and isActive then
            local frame = CreateCustomIcon(spellId)
            BCDM.CustomFrames[spellId] = frame
            table.insert(BCDM.CustomBar, frame)
        end
    end
    LayoutCustomIcons()
end

function BCDM:ResetCustomIcons()
    local CooldownManagerDB = BCDM.db.profile
    -- Can we even destroy frames?
    for spellId, frame in pairs(BCDM.CustomFrames) do
        if frame then
            frame:Hide()
            frame:ClearAllPoints()
            frame:SetParent(nil)
            frame:UnregisterAllEvents()
            frame:SetScript("OnUpdate", nil)
            frame:SetScript("OnEvent", nil)
        end
        _G["BCDM_Custom_" .. spellId] = nil
    end
    wipe(BCDM.CustomFrames)
    wipe(BCDM.CustomBar)
    local _, class = UnitClass("player")
    local spellList = CooldownManagerDB.Custom.CustomSpells[class] or {}
    for spellId, isActive in pairs(spellList) do
        if spellId and isActive then
            local frame = CreateCustomIcon(spellId)
            BCDM.CustomFrames[spellId] = frame
            table.insert(BCDM.CustomBar, frame)
        end
    end
    LayoutCustomIcons()
end

function BCDM:UpdateCustomIcons()
    local CooldownManagerDB = BCDM.db.profile
    local GeneralDB = CooldownManagerDB.General
    local CustomDB = CooldownManagerDB.Custom
    BCDM.CustomContainer:ClearAllPoints()
    BCDM.CustomContainer:SetPoint(CustomDB.Anchors[1], CustomDB.Anchors[2], CustomDB.Anchors[3], CustomDB.Anchors[4], CustomDB.Anchors[5])
    for _, icon in ipairs(BCDM.CustomBar) do
        if icon then
            icon:SetSize(CustomDB.IconSize[1], CustomDB.IconSize[2])
            icon.Icon:SetTexCoord((GeneralDB.IconZoom) * 0.5, 1 - (GeneralDB.IconZoom) * 0.5, (GeneralDB.IconZoom) * 0.5, 1 - (GeneralDB.IconZoom) * 0.5)
            icon.Charges:ClearAllPoints()
            icon.Charges:SetFont(BCDM.Media.Font, CustomDB.Count.FontSize, GeneralDB.FontFlag)
            icon.Charges:SetPoint(CustomDB.Count.Anchors[1], icon, CustomDB.Count.Anchors[2], CustomDB.Count.Anchors[3], CustomDB.Count.Anchors[4])
            icon.Charges:SetTextColor(CustomDB.Count.Colour[1], CustomDB.Count.Colour[2], CustomDB.Count.Colour[3], 1)
            icon.Charges:SetShadowColor(GeneralDB.Shadows.Colour[1], GeneralDB.Shadows.Colour[2], GeneralDB.Shadows.Colour[3], GeneralDB.Shadows.Colour[4])
            icon.Charges:SetShadowOffset(GeneralDB.Shadows.OffsetX, GeneralDB.Shadows.OffsetY)
        end
    end
    LayoutCustomIcons()
end

local SpellsChangedEventFrame = CreateFrame("Frame")
SpellsChangedEventFrame:RegisterEvent("SPELLS_CHANGED")
SpellsChangedEventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "SPELLS_CHANGED" then
        if InCombatLockdown() then return end
        BCDM:ResetCustomIcons()
    end
end)

function BCDM:CopyCustomSpellsToDB()
    local profileDB = BCDM.db.profile

    local _, class = UnitClass("player")
    local sourceTable = CustomSpells[class]
    if not profileDB.Custom.CustomSpells[class] then profileDB.Custom.CustomSpells[class] = {} end

    local classDB = profileDB.Custom.CustomSpells[class]
    for spellId, value in pairs(sourceTable) do
        if classDB[spellId] == nil then
            classDB[spellId] = value
        end
    end
end

function BCDM:AddCustomSpell(value)
    if value == nil then return end
    local spellId = C_Spell.GetSpellInfo(value).spellID or value
    if not spellId then return end
    local profileDB = BCDM.db.profile
    local _, class = UnitClass("player")
    if not profileDB.Custom.CustomSpells[class] then profileDB.Custom.CustomSpells[class] = {} end
    profileDB.Custom.CustomSpells[class][spellId] = true
    BCDM:ResetCustomIcons()
end

function BCDM:RemoveCustomSpell(value)
    if value == nil then return end
    local spellId = C_Spell.GetSpellInfo(value).spellID or value
    if not spellId then return end
    local profileDB = BCDM.db.profile
    local _, class = UnitClass("player")
    if not profileDB.Custom.CustomSpells[class] then profileDB.Custom.CustomSpells[class] = {} end
    profileDB.Custom.CustomSpells[class][spellId] = nil
    BCDM:ResetCustomIcons()
end
