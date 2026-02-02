local _, BCDM = ...

-- Assistant Module - Rotation Highlight
--
-- Highlights cooldown icons that match the assisted combat rotation suggestion.
-- Shows a blue border on icons suggested by C_AssistedCombat.GetNextCastSpell()

local Assistant = {}
BCDM.Assistant = Assistant

local BCDM_ASSISTANT_DEBUG = false
local PrintDebug = function(...)
    if BCDM_ASSISTANT_DEBUG then
        print("[BCDM Assistant]", ...)
    end
end

local isModuleAssistantEnabled = false
local areHooksInitialized = false

local viewersSettingKey = {
    EssentialCooldownViewer = "Essential",
    UtilityCooldownViewer = "Utility",
    BuffIconCooldownViewer = "Buffs",
}

local function IsAssistantEnabledForAnyViewer()
    if not BCDM.db or not BCDM.db.profile then
        return false
    end

    if BCDM.db.profile.CooldownManager.Essential.ShowHighlight then
        return true
    end
    return false
end

local flipbookConfig = {
    atlas = "RotationHelper_Ants_Flipbook_2x",
    rows = 6,
    columns = 5,
    frames = 30,
    duration = 1.0,
    scale = 1.5,
}

local rotationSpellsCache = {}
local rotationSpellsCacheValid = false
local currentSuggestedSpellID = nil

local iconSpellCache = {}

local function IsIconSquareStyled(icon)
    return icon and icon.bcdmSquareStyled == true
end

local function ExtractSpellIDFromIcon(icon)
    if icon.cooldownID then
        local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(icon.cooldownID)
        -- PrintDebug("Extracted spellID from icon.cooldownID:", info.spellID)
        -- Not secret?!
        return info.spellID, info.overrideSpellID
    end
    -- Everything is secret below
    -- if icon.spellID then
    --     PrintDebug("Extracted spellID from icon.spellID:", icon.spellID)
    --     return icon.spellID
    -- end
    -- if icon.GetSpellID and type(icon.GetSpellID) == "function" then
    --     PrintDebug("Extracted spellID from icon:GetSpellID():", icon:GetSpellID())
    --     return icon:GetSpellID()
    -- end
    return nil
end

local function UpdateRotationSpellsCache()
    wipe(rotationSpellsCache)

    local rotationSpells = C_AssistedCombat.GetRotationSpells()
    if rotationSpells then
        for _, spellID in ipairs(rotationSpells) do
            rotationSpellsCache[spellID] = true
        end
    end

    rotationSpellsCacheValid = true
    PrintDebug("Cached rotation spell IDs")
end

local function IsSpellIDInRotation(spellID)
    if not spellID then
        return false
    end
    if not rotationSpellsCacheValid then
        UpdateRotationSpellsCache()
    end
    return rotationSpellsCache[spellID] == true
end

local function BuildIconSpellCacheForViewer(viewerName)
    local viewerFrame = _G[viewerName]
    if not viewerFrame then
        return
    end
    PrintDebug(
        "|cffff0000 BuildIconSpellCacheForViewer called for",
        viewerName,
        "inLockdown:",
        tostring(InCombatLockdown())
    )

    local settingName = viewersSettingKey[viewerName]
    if not settingName then
        return
    end

    iconSpellCache[viewerName] = iconSpellCache[viewerName] or {}
    wipe(iconSpellCache[viewerName])

    if not rotationSpellsCacheValid then
        UpdateRotationSpellsCache()
    end

    local children = { viewerFrame:GetChildren() }
    for _, child in ipairs(children) do
        if child.Icon then
            local layoutIndex = child.layoutIndex or child:GetName() or tostring(child)

            local rawSpellID, overrideSpellID = ExtractSpellIDFromIcon(child)
            local spellId = rawSpellID
            if rawSpellID then
                local inRotation = IsSpellIDInRotation(rawSpellID)
                if not inRotation and overrideSpellID then
                    inRotation = IsSpellIDInRotation(overrideSpellID)
                    spellId = overrideSpellID
                end

                iconSpellCache[viewerName][layoutIndex] = {
                    spellID = spellId,
                    inRotation = inRotation,
                }

                child._bcdm_inRotation = inRotation
            end
        end
    end
end

local function BuildAllIconSpellCaches()
    if InCombatLockdown() then
        PrintDebug("Skipping cache build - not safe (combat or other restriction)")
        return false
    end

    for viewerName, _ in pairs(viewersSettingKey) do
        BuildIconSpellCacheForViewer(viewerName)
    end

    return true
end

local function GetOrCreateFlipbookHighlight(icon)
    if icon.bcdmFlipbookHighlight then
        return icon.bcdmFlipbookHighlight
    end

    -- Create the flipbook frame
    local flipbookFrame = CreateFrame("Frame", nil, icon)
    flipbookFrame:SetFrameLevel(icon:GetFrameLevel() + 10)
    flipbookFrame:SetAllPoints(icon)

    -- Create the flipbook texture - size to match icon
    local flipbookTexture = flipbookFrame:CreateTexture(nil, "OVERLAY")
    flipbookTexture:SetAtlas(flipbookConfig.atlas)
    flipbookTexture:SetBlendMode("ADD")
    flipbookTexture:SetPoint("CENTER", icon, "CENTER", 0, 0)
    -- Set size to match icon dimensions
    local iconWidth, iconHeight = icon:GetSize()
    flipbookTexture:SetSize(iconWidth * flipbookConfig.scale, iconHeight * flipbookConfig.scale)
    flipbookFrame.Texture = flipbookTexture

    -- Create animation group
    local animGroup = flipbookFrame:CreateAnimationGroup()
    animGroup:SetLooping("REPEAT")
    animGroup:SetToFinalAlpha(true)
    flipbookFrame.Anim = animGroup

    -- Create alpha animation to keep texture visible
    local alphaAnim = animGroup:CreateAnimation("Alpha")
    alphaAnim:SetChildKey("Texture")
    alphaAnim:SetFromAlpha(1)
    alphaAnim:SetToAlpha(1)
    alphaAnim:SetDuration(0.001)
    alphaAnim:SetOrder(0)

    -- Create flipbook animation
    local flipAnim = animGroup:CreateAnimation("FlipBook")
    flipAnim:SetChildKey("Texture")
    flipAnim:SetDuration(flipbookConfig.duration)
    flipAnim:SetOrder(0)
    flipAnim:SetFlipBookRows(flipbookConfig.rows)
    flipAnim:SetFlipBookColumns(flipbookConfig.columns)
    flipAnim:SetFlipBookFrames(flipbookConfig.frames)
    flipAnim:SetFlipBookFrameWidth(0)
    flipAnim:SetFlipBookFrameHeight(0)
    flipbookFrame.FlipAnim = flipAnim

    -- Initially hidden
    flipbookFrame:SetAlpha(0)
    flipbookFrame:Show()

    icon.bcdmFlipbookHighlight = flipbookFrame
    return flipbookFrame
end

local function HideHighlights(icon)
    if icon.bcdmFlipbookHighlight then
        icon.bcdmFlipbookHighlight:SetAlpha(0)
        if icon.bcdmFlipbookHighlight.Anim:IsPlaying() then
            icon.bcdmFlipbookHighlight.Anim:Stop()
        end
    end
end

local function UpdateIconHighlight(icon, viewerSettingName)
    if not icon then
        return
    end

    if not BCDM.db or not BCDM.db.profile then
        return
    end

    local enabledKey = "ShowHighlight"
    local enabledValue = false
    
    if viewerSettingName == "Essential" then
        enabledValue = BCDM.db.profile.CooldownManager.Essential[enabledKey]
    else
        enabledValue = false
    end

    if not enabledValue then
        HideHighlights(icon)
        return
    end

    local iconSpellID, overrideSpellID = ExtractSpellIDFromIcon(icon)
    if not iconSpellID then
        HideHighlights(icon)
        return
    end

    local inRotation = icon._bcdm_inRotation
    if not inRotation then
        HideHighlights(icon)
        return
    end

    local isSuggested = currentSuggestedSpellID
        and (iconSpellID == currentSuggestedSpellID or (overrideSpellID and overrideSpellID == currentSuggestedSpellID))

    local flipbook = GetOrCreateFlipbookHighlight(icon)
    if isSuggested then
        flipbook:SetAlpha(1)
        if not flipbook.Anim:IsPlaying() then
            flipbook.Anim:Play()
        end
    else
        flipbook:SetAlpha(0)
        if flipbook.Anim:IsPlaying() then
            flipbook.Anim:Stop()
        end
    end
end

function Assistant:UpdateViewerHighlights(viewerName)
    local viewerFrame = _G[viewerName]
    if not viewerFrame then
        return
    end

    local settingName = viewersSettingKey[viewerName]
    if not settingName then
        return
    end

    local children = { viewerFrame:GetChildren() }
    for _, child in ipairs(children) do
        if child.Icon then -- Only process icon-like children
            UpdateIconHighlight(child, settingName)
        end
    end
end

function Assistant:UpdateAllHighlights()
    currentSuggestedSpellID = C_AssistedCombat.GetNextCastSpell()

    for viewerName, _ in pairs(viewersSettingKey) do
        self:UpdateViewerHighlights(viewerName)
    end
end

-- Pre-creates borders for all rotation spells (call when safe to access spell IDs)
function Assistant:PrepareRotationBorders()
    -- Update the rotation cache first
    UpdateRotationSpellsCache()

    -- Only build icon cache if safe
    if not InCombatLockdown() then
        BuildAllIconSpellCaches()
    else
        -- Cache rebuild will happen after combat ends
    end

    -- Pre-create borders/flipbooks for all rotation spells
    for viewerName, settingName in pairs(viewersSettingKey) do
        local viewerFrame = _G[viewerName]
        if viewerFrame then
            if BCDM.db and BCDM.db.profile then
                local enabledKey = "ShowHighlight"
                local enabledValue = false
                
                if settingName == "Essential" then
                    enabledValue = BCDM.db.profile.CooldownManager.Essential[enabledKey]
                else
                    enabledValue = false
                end
                
                if enabledValue then
                    local children = { viewerFrame:GetChildren() }
                    for _, child in ipairs(children) do
                        if child.Icon and child._bcdm_inRotation then
                            -- Pre-create flipbook highlight
                            GetOrCreateFlipbookHighlight(child)
                        end
                    end
                end
            end
        end
    end

    PrintDebug("Borders/flipbooks prepared for rotation spells")
end

local eventFrame = CreateFrame("Frame")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if not isModuleAssistantEnabled then
        return
    end

    if event == "EDIT_MODE_LAYOUTS_UPDATED" then
        PrintDebug("EditMode layout changed - rebuilding cache")
        if not InCombatLockdown() then
            BuildAllIconSpellCaches()
            Assistant:UpdateAllHighlights()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        rotationSpellsCacheValid = false
        UpdateRotationSpellsCache()
        BuildAllIconSpellCaches()
        Assistant:UpdateAllHighlights()
        PrintDebug("PLAYER_ENTERING_WORLD - inLockdown:", tostring(InCombatLockdown()))
    elseif
        event == "PLAYER_TALENT_UPDATE"
        or event == "SPELLS_CHANGED"
        or event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "UPDATE_SHAPESHIFT_FORM"
        or event == "TRAIT_CONFIG_UPDATED"
    then
        rotationSpellsCacheValid = false
        Assistant:PrepareRotationBorders()
        Assistant:UpdateAllHighlights()
    end
end)

hooksecurefunc(AssistedCombatManager, "UpdateAllAssistedHighlightFramesForSpell", function(self, spellID)
    if BCDM.db and BCDM.db.profile then
        local shouldUpdate = false
        
        if BCDM.db.profile.CooldownManager.Essential.ShowHighlight then
            shouldUpdate = true
        end

        if shouldUpdate then
            Assistant:UpdateAllHighlights()
        end
    end
end)

function Assistant:Shutdown()
    PrintDebug("Shutting down module")

    isModuleAssistantEnabled = false

    eventFrame:UnregisterAllEvents()

    wipe(rotationSpellsCache)
    rotationSpellsCacheValid = false
    wipe(iconSpellCache)

    for viewerName, _ in pairs(viewersSettingKey) do
        local viewerFrame = _G[viewerName]
        if viewerFrame then
            local children = { viewerFrame:GetChildren() }
            for _, child in ipairs(children) do
                HideHighlights(child)
            end
        end
    end
end

function Assistant:Enable()
    if isModuleAssistantEnabled then
        return
    end
    PrintDebug("Enabling module")

    isModuleAssistantEnabled = true

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
    eventFrame:RegisterEvent("SPELLS_CHANGED")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    eventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")

    if not areHooksInitialized then
        areHooksInitialized = true

        for viewerName, settingName in pairs(viewersSettingKey) do
            local viewerFrame = _G[viewerName]
            if viewerFrame then
                hooksecurefunc(viewerFrame, "RefreshLayout", function()
                    if not isModuleAssistantEnabled then
                        return
                    end

                    PrintDebug("RefreshLayout called for viewer:", viewerName)
                    if not InCombatLockdown() then
                        BuildIconSpellCacheForViewer(viewerName)
                        Assistant:PrepareRotationBorders()
                    end
                    Assistant:UpdateViewerHighlights(viewerName)
                end)
            end
        end
    end

    rotationSpellsCacheValid = false
    UpdateRotationSpellsCache()
    self:PrepareRotationBorders()
    self:UpdateAllHighlights()
end

function Assistant:Disable()
    if not isModuleAssistantEnabled then
        return
    end
    PrintDebug("Disabling module")

    self:Shutdown()
end

function Assistant:Initialize()
    if not IsAssistantEnabledForAnyViewer() then
        PrintDebug("Not initializing - no viewers enabled")
        return
    end

    PrintDebug("Initializing module")
    self:Enable()

    BCDM.db.profile.assistantCache = nil
end

function Assistant:OnSettingChanged(viewerSettingName)
    -- Check if module should be enabled or disabled
    local shouldBeEnabled = IsAssistantEnabledForAnyViewer()

    if shouldBeEnabled and not isModuleAssistantEnabled then
        self:Enable()
    elseif not shouldBeEnabled and isModuleAssistantEnabled then
        self:Disable()
    elseif isModuleAssistantEnabled then
        -- Already enabled, just update display
        if viewerSettingName then
            for viewerName, settingName in pairs(viewersSettingKey) do
                if settingName == viewerSettingName then
                    if not InCombatLockdown() then
                        self:PrepareRotationBorders()
                    end
                    self:UpdateViewerHighlights(viewerName)
                    return
                end
            end
        end
        -- If no specific viewer, update all
        if not InCombatLockdown() then
            self:PrepareRotationBorders()
        end
        self:UpdateAllHighlights()
    end
end