local _, BCDM = ...

local function ShouldSkin()
    if not BCDM.db.profile.CooldownManager.Enable then return false end
    if C_AddOns.IsAddOnLoaded("ElvUI") and ElvUI[1].private.skins.blizzard.cooldownManager then return false end
    if C_AddOns.IsAddOnLoaded("MasqueBlizzBars") then return false end
    return true
end

local function NudgeViewer(viewerName, xOffset, yOffset)
    local viewerFrame = _G[viewerName]
    if not viewerFrame then return end
    local point, relativeTo, relativePoint, currentX, currentY = viewerFrame:GetPoint(1)
    viewerFrame:ClearAllPoints()
    viewerFrame:SetPoint(point, relativeTo, relativePoint, currentX + xOffset, currentY + yOffset)
end

local function FetchCooldownTextRegion(cooldown)
    if not cooldown then return end
    for _, region in ipairs({ cooldown:GetRegions() }) do
        if region:GetObjectType() == "FontString" then
            return region
        end
    end
end

-- local function FetchClassColour()
--     local CooldownManagerDB = BCDM.db.profile
--     local GeneralDB = CooldownManagerDB.General
--     local BuffBarDB = CooldownManagerDB.CooldownManager.BuffBar
--     if BuffBarDB then
--         if BuffBarDB.ColourByClass then
--             local _, class = UnitClass("player")
--             local classColour = RAID_CLASS_COLORS[class]
--             if classColour then return classColour.r, classColour.g, classColour.b, 1 end
--         else
--             return BuffBarDB.ForegroundColour[1], BuffBarDB.ForegroundColour[2], BuffBarDB.ForegroundColour[3], BuffBarDB.ForegroundColour[4]
--         end
--     end
-- end

local function ApplyCooldownText(cooldownViewer)
    local CooldownManagerDB = BCDM.db.profile
    local GeneralDB = CooldownManagerDB.General
    local CooldownTextDB = CooldownManagerDB.CooldownManager.General.CooldownText
    local Viewer = _G[cooldownViewer]
    if not Viewer then return end
    for _, icon in ipairs({ Viewer:GetChildren() }) do
        if icon and icon.Cooldown then
            local textRegion = FetchCooldownTextRegion(icon.Cooldown)
            if textRegion then
                if CooldownTextDB.ScaleByIconSize then
                    local iconWidth = icon:GetWidth()
                    local scaleFactor = iconWidth / 36
                    textRegion:SetFont(BCDM.Media.Font, CooldownTextDB.FontSize * scaleFactor, GeneralDB.Fonts.FontFlag)
                else
                    textRegion:SetFont(BCDM.Media.Font, CooldownTextDB.FontSize, GeneralDB.Fonts.FontFlag)
                end
                textRegion:SetTextColor(CooldownTextDB.Colour[1], CooldownTextDB.Colour[2], CooldownTextDB.Colour[3], 1)
                textRegion:ClearAllPoints()
                textRegion:SetPoint(CooldownTextDB.Layout[1], icon, CooldownTextDB.Layout[2], CooldownTextDB.Layout[3], CooldownTextDB.Layout[4])
                if GeneralDB.Fonts.Shadow.Enabled then
                    textRegion:SetShadowColor(GeneralDB.Fonts.Shadow.Colour[1], GeneralDB.Fonts.Shadow.Colour[2], GeneralDB.Fonts.Shadow.Colour[3], GeneralDB.Fonts.Shadow.Colour[4])
                    textRegion:SetShadowOffset(GeneralDB.Fonts.Shadow.OffsetX, GeneralDB.Fonts.Shadow.OffsetY)
                else
                    textRegion:SetShadowColor(0, 0, 0, 0)
                    textRegion:SetShadowOffset(0, 0)
                end
            end
        end
    end
end

local function ApplyKeyBindingText(cooldownViewer)
    local CooldownManagerDB = BCDM.db.profile
    local GeneralDB = CooldownManagerDB.General
    local KeyBindingTextDB = CooldownManagerDB.CooldownManager.General.KeyBindingText
    local Viewer = _G[cooldownViewer]
    if not Viewer then return end

    for _, icon in ipairs({ Viewer:GetChildren() }) do
        -- Try to find spellId from icon (custom icons store it) or check if it's a known frame type
        local spellId = icon.spellId or icon.spellID
        if not spellId and icon.GetSpellID then
            spellId = icon:GetSpellID()
        end
        local itemId = icon.itemId or icon.itemID
        if not itemId and icon.GetItemID then
            itemId = icon:GetItemID()
        end
        
        local bindingText = ""
        if spellId then
            bindingText = BCDM.KeyBindingManager:GetKeyBinding(spellId, "spell")
        elseif itemId then
            bindingText = BCDM.KeyBindingManager:GetKeyBinding(itemId, "item")
        end
        
        -- Try to find binding by texture if not found by ID
        if bindingText == "" and icon.Icon and icon.Icon.GetTexture then
            local texture = icon.Icon:GetTexture()
            if texture then
                bindingText = BCDM.KeyBindingManager:GetKeyBindingByTexture(texture)
            end
        end
        
        if bindingText ~= "" or spellId or itemId then
            if not icon.KeyBindingText then
                -- Attach to HighLevelContainer if available (Custom Icons), otherwise icon itself
                local parent = icon.HighLevelContainer or icon
                icon.KeyBindingText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                icon.KeyBindingText:SetDrawLayer("OVERLAY", 7)
            end
            
            local keyBindingText = icon.KeyBindingText

            if KeyBindingTextDB.Enabled and bindingText ~= "" then
                keyBindingText:Show()
                keyBindingText:SetText(bindingText)
                
                if KeyBindingTextDB.ScaleByIconSize then -- Assuming this setting might exist or we use fixed size
                     -- If KeyBindingTextDB doesn't have ScaleByIconSize, we can default to false or check structure
                     -- For now, let's assume standard behavior similar to CooldownText
                     -- If KeyBindingText structure in Defaults.lua doesn't have ScaleByIconSize, we skip.
                     -- Checked Defaults.lua: KeyBindingText has FontSize but not ScaleByIconSize explicitly added yet.
                     -- Let's just use FontSize.
                     keyBindingText:SetFont(BCDM.Media.Font, KeyBindingTextDB.FontSize, GeneralDB.Fonts.FontFlag)
                else
                     keyBindingText:SetFont(BCDM.Media.Font, KeyBindingTextDB.FontSize, GeneralDB.Fonts.FontFlag)
                end
                
                keyBindingText:SetTextColor(KeyBindingTextDB.Colour[1], KeyBindingTextDB.Colour[2], KeyBindingTextDB.Colour[3], 1)
                keyBindingText:ClearAllPoints()
                keyBindingText:SetPoint(KeyBindingTextDB.Layout[1], icon, KeyBindingTextDB.Layout[2], KeyBindingTextDB.Layout[3], KeyBindingTextDB.Layout[4])
                
                if GeneralDB.Fonts.Shadow.Enabled then
                    keyBindingText:SetShadowColor(GeneralDB.Fonts.Shadow.Colour[1], GeneralDB.Fonts.Shadow.Colour[2], GeneralDB.Fonts.Shadow.Colour[3], GeneralDB.Fonts.Shadow.Colour[4])
                    keyBindingText:SetShadowOffset(GeneralDB.Fonts.Shadow.OffsetX, GeneralDB.Fonts.Shadow.OffsetY)
                else
                    keyBindingText:SetShadowColor(0, 0, 0, 0)
                    keyBindingText:SetShadowOffset(0, 0)
                end
            else
                keyBindingText:Hide()
            end
        end
    end
end

-- local function StyleBuffsBars()
--     local GeneralDB = BCDM.db.profile.General
--     local GeneralCooldownManagerSetting = BCDM.db.profile.CooldownManager.General
--     local BuffBarDB = BCDM.db.profile.CooldownManager.BuffBar
--     local buffBarChildren = {_G["BuffBarCooldownViewer"]:GetChildren()}

--     for _, childFrame in ipairs(buffBarChildren) do
--         local buffBar = childFrame.Bar
--         local buffIcon = childFrame.Icon
--         if childFrame.DebuffBorder then childFrame.DebuffBorder:SetAlpha(0) end

--         -- if BuffBarDB.MatchWidthOfAnchor then
--         --     local anchorFrame = _G[BuffBarDB.Layout[2]]
--         --     if anchorFrame then
--         --         local anchorWidth = anchorFrame:GetWidth()
--         --         childFrame:SetWidth(anchorWidth)
--         --         _G["BuffBarCooldownViewer"]:SetWidth(anchorWidth)
--         --     end
--         -- else
--             -- childFrame:SetWidth(BuffBarDB.Width)
--             -- _G["BuffBarCooldownViewer"]:SetWidth(BuffBarDB.Width)
--         -- end
--         -- childFrame:SetHeight(BuffBarDB.Height)

--         if childFrame.Bar then
--             childFrame.Bar:ClearAllPoints()
--             childFrame.Bar:SetPoint("TOPLEFT", childFrame, "TOPLEFT", 0, 0)
--             childFrame.Bar:SetPoint("BOTTOMRIGHT", childFrame, "BOTTOMRIGHT", 0, 0)
--             childFrame.Bar:SetStatusBarTexture(BCDM.Media.Foreground)
--             childFrame.Bar:SetStatusBarColor(FetchClassColour())
--             childFrame.Bar.Pip:SetAlpha(0)
--         end

--         if buffBar then
--             buffBar:ClearAllPoints()
--             buffBar:SetPoint("TOPLEFT", childFrame, "TOPLEFT", 0, 0)
--             buffBar:SetPoint("BOTTOMRIGHT", childFrame, "BOTTOMRIGHT", 0, 0)
--             buffBar.BarBG:SetPoint("TOPLEFT", buffBar, "TOPLEFT", 0, 0)
--             buffBar.BarBG:SetPoint("BOTTOMRIGHT", buffBar, "BOTTOMRIGHT", 0, 0)
--             buffBar.BarBG:SetTexture(BCDM.Media.Background)
--             buffBar.BarBG:SetVertexColor(BuffBarDB.BackgroundColour[1], BuffBarDB.BackgroundColour[2], BuffBarDB.BackgroundColour[3], BuffBarDB.BackgroundColour[4])

--             if buffIcon then
--                 if not BuffBarDB.Icon.Enabled then buffIcon:Hide() else buffIcon:Show() end
--                 BCDM:StripTextures(buffIcon.Icon)
--                 buffIcon.Icon:SetSize(BuffBarDB.Height, BuffBarDB.Height)
--                 buffIcon.Icon:ClearAllPoints()
--                 if BuffBarDB.Icon.Layout == "LEFT" then
--                     buffIcon.Icon:SetPoint("RIGHT", buffBar, "LEFT", 1, 0)
--                 else
--                     buffIcon.Icon:SetPoint("LEFT", buffBar, "RIGHT", -1, 0)
--                 end
--                 buffIcon.Icon:SetTexCoord(GeneralCooldownManagerSetting.IconZoom * 0.5, 1 - GeneralCooldownManagerSetting.IconZoom * 0.5, GeneralCooldownManagerSetting.IconZoom * 0.5, 1 - GeneralCooldownManagerSetting.IconZoom * 0.5)
--             end

--             if buffBar.Name then
--                 if not BuffBarDB.Text.SpellName.Enabled then buffBar.Name:Hide() else buffBar.Name:Show() end
--                 buffBar.Name:ClearAllPoints()
--                 buffBar.Name:SetPoint(BuffBarDB.Text.SpellName.Layout[1], buffBar, BuffBarDB.Text.SpellName.Layout[2], BuffBarDB.Text.SpellName.Layout[3], BuffBarDB.Text.SpellName.Layout[4])
--                 buffBar.Name:SetFont(BCDM.Media.Font, BuffBarDB.Text.SpellName.FontSize, GeneralDB.Fonts.FontFlag)
--                 buffBar.Name:SetTextColor(BuffBarDB.Text.SpellName.Colour[1], BuffBarDB.Text.SpellName.Colour[2], BuffBarDB.Text.SpellName.Colour[3], 1)
--                 if GeneralDB.Fonts.Shadow.Enabled then
--                     buffBar.Name:SetShadowColor(GeneralDB.Fonts.Shadow.Colour[1], GeneralDB.Fonts.Shadow.Colour[2], GeneralDB.Fonts.Shadow.Colour[3], GeneralDB.Fonts.Shadow.Colour[4])
--                     buffBar.Name:SetShadowOffset(GeneralDB.Fonts.Shadow.OffsetX, GeneralDB.Fonts.Shadow.OffsetY)
--                 else
--                     buffBar.Name:SetShadowColor(0, 0, 0, 0)
--                     buffBar.Name:SetShadowOffset(0, 0)
--                 end
--             end

--             if buffBar.Duration then
--                 if not BuffBarDB.Text.Duration.Enabled then buffBar.Duration:Hide() else buffBar.Duration:Show() end
--                 buffBar.Duration:ClearAllPoints()
--                 buffBar.Duration:SetPoint(BuffBarDB.Text.Duration.Layout[1], buffBar, BuffBarDB.Text.Duration.Layout[2], BuffBarDB.Text.Duration.Layout[3], BuffBarDB.Text.Duration.Layout[4])
--                 buffBar.Duration:SetFont(BCDM.Media.Font, BuffBarDB.Text.Duration.FontSize, GeneralDB.Fonts.FontFlag)
--                 buffBar.Duration:SetTextColor(BuffBarDB.Text.Duration.Colour[1], BuffBarDB.Text.Duration.Colour[2], BuffBarDB.Text.Duration.Colour[3], 1)
--                 if GeneralDB.Fonts.Shadow.Enabled then
--                     buffBar.Duration:SetShadowColor(GeneralDB.Fonts.Shadow.Colour[1], GeneralDB.Fonts.Shadow.Colour[2], GeneralDB.Fonts.Shadow.Colour[3], GeneralDB.Fonts.Shadow.Colour[4])
--                     buffBar.Duration:SetShadowOffset(GeneralDB.Fonts.Shadow.OffsetX, GeneralDB.Fonts.Shadow.OffsetY)
--                 else
--                     buffBar.Duration:SetShadowColor(0, 0, 0, 0)
--                     buffBar.Duration:SetShadowOffset(0, 0)
--                 end
--             end
--         end
--         BCDM:AddBorder(buffBar)
--         BCDM:AddBorder(buffIcon)
--     end
-- end

-- 统一的居中功能更新函数
local centerUpdateThrottle = 0.1  -- 增加更新间隔到0.1秒，减少性能消耗
local nextCenterUpdate = 0
local function UpdateAllCentering()
    local currentTime = GetTime()
    if currentTime < nextCenterUpdate then return end
    nextCenterUpdate = currentTime + centerUpdateThrottle
    
    local cooldownManagerSettings = BCDM.db.profile.CooldownManager
    
    -- 处理 Essential 居中
    if cooldownManagerSettings.Essential.CenterEssential then
        local iconLimit = cooldownManagerSettings.Essential.IconLimitPerRow or 20
        BCDM.CooldownCentering.CenterAllRowsForViewer(EssentialCooldownViewer, "CENTER", iconLimit)
    end
    
    -- 处理 Utility 居中
    if cooldownManagerSettings.Utility.CenterUtility then
        local iconLimit = cooldownManagerSettings.Utility.IconLimitPerRow or 20
        BCDM.CooldownCentering.CenterAllRowsForViewer(UtilityCooldownViewer, "CENTER", iconLimit)
    end
    
    -- 处理 Buffs 居中
    if cooldownManagerSettings.Buffs.CenterBuffs then
        local iconLimit = cooldownManagerSettings.Buffs.IconLimitPerRow or 20
        BCDM.CooldownCentering.CenterAllRowsForViewer(BuffIconCooldownViewer, "CENTER", iconLimit)
    end
end

local centerUpdateFrame = CreateFrame("Frame")

local function SetupCenterBuffs()
    local buffsSettings = BCDM.db.profile.CooldownManager.Buffs
    local essentialSettings = BCDM.db.profile.CooldownManager.Essential
    local utilitySettings = BCDM.db.profile.CooldownManager.Utility
    
    -- 检查是否需要启用居中更新
    local needsCentering = buffsSettings.CenterBuffs or essentialSettings.CenterEssential or utilitySettings.CenterUtility
    
    if needsCentering then
        centerUpdateFrame:SetScript("OnUpdate", UpdateAllCentering)
    else
        centerUpdateFrame:SetScript("OnUpdate", nil)
        centerUpdateFrame:Hide()
    end
end

-- 添加一个函数来检查并应用官方设置
local function SyncWithOfficialSettings()
    -- 检查是否需要根据官方设置更新我们的配置
    local cooldownManagerSettings = BCDM.db.profile.CooldownManager
    if cooldownManagerSettings.Essential.CenterEssential then
        local iconLimit = cooldownManagerSettings.Essential.IconLimitPerRow or EssentialCooldownViewer.iconLimit or 20
        BCDM.CooldownCentering.CenterAllRowsForViewer(EssentialCooldownViewer, "CENTER", iconLimit)
    end
    if cooldownManagerSettings.Utility.CenterUtility then
        local iconLimit = cooldownManagerSettings.Utility.IconLimitPerRow or UtilityCooldownViewer.iconLimit or 20
        BCDM.CooldownCentering.CenterAllRowsForViewer(UtilityCooldownViewer, "CENTER", iconLimit)
    end
    if cooldownManagerSettings.Buffs.CenterBuffs then
        local iconLimit = cooldownManagerSettings.Buffs.IconLimitPerRow or BuffIconCooldownViewer.iconLimit or 20
        BCDM.CooldownCentering.CenterAllRowsForViewer(BuffIconCooldownViewer, "CENTER", iconLimit)
    end
end

-- 简化的 SetupCenterUtility 和 SetupCenterEssential 函数
local function SetupCenterUtility()
    -- 调用统一的 SetupCenterBuffs 来管理居中更新
    SetupCenterBuffs()
end

local function SetupCenterEssential()
    -- 调用统一的 SetupCenterBuffs 来管理居中更新
    SetupCenterBuffs()
end

local function Position()
    local cooldownManagerSettings = BCDM.db.profile.CooldownManager
    -- _G["BuffBarCooldownViewer"]:SetFrameStrata("LOW")
    for _, viewerName in ipairs(BCDM.CooldownManagerViewers) do
        local viewerSettings = cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]]
        local viewerFrame = _G[viewerName]
        if viewerFrame then
            local anchorParent = viewerSettings.Layout[2] == "NONE" and UIParent or _G[viewerSettings.Layout[2]]
            
            -- 检查循环依赖：如果锚点父级是 BCDM_PowerBar 或 BCDM_SecondaryPowerBar，且当前查看器是它们的依赖项，则使用 UIParent
            if anchorParent and (anchorParent:GetName() == "BCDM_PowerBar" or anchorParent:GetName() == "BCDM_SecondaryPowerBar") then
                -- 检查是否存在循环依赖
                local hasCircularDependency = false
                for _, depViewerName in ipairs(BCDM.CooldownManagerViewers) do
                    if depViewerName == viewerName then
                        -- 找到当前查看器，检查前面的查看器是否依赖于锚点父级
                        for _, prevViewerName in ipairs(BCDM.CooldownManagerViewers) do
                            if prevViewerName == viewerName then
                                break
                            end
                            local prevViewerSettings = cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[prevViewerName]]
                            if prevViewerSettings and prevViewerSettings.Layout[2] == anchorParent:GetName() then
                                hasCircularDependency = true
                                break
                            end
                        end
                        break
                    end
                end
                
                if hasCircularDependency then
                    anchorParent = UIParent
                end
            end
            
            -- 如果锚点父级没有设置位置（例如未激活的次级能量条），则回退到 UIParent，防止位置异常
            if not anchorParent or (anchorParent ~= UIParent and anchorParent:GetNumPoints() == 0) then
                anchorParent = UIParent
            end

            if viewerName == "EssentialCooldownViewer" then
                -- 仅 Essential 使用 LEMO 接管，但需要检查布局是否可编辑
                if BCDM.LEMO:AreLayoutsLoaded() and BCDM.LEMO:CanEditActiveLayout() then
                    BCDM.LEMO:ReanchorFrame(viewerFrame, viewerSettings.Layout[1], anchorParent, viewerSettings.Layout[3], viewerSettings.Layout[4], viewerSettings.Layout[5])
                end
                -- 手动设置位置，避免依赖 ApplyChanges 导致死循环
                viewerFrame:ClearAllPoints()
                viewerFrame:SetPoint(viewerSettings.Layout[1], anchorParent, viewerSettings.Layout[3], viewerSettings.Layout[4], viewerSettings.Layout[5])
            else
                -- 其他组件恢复插件接管
                viewerFrame:ClearAllPoints()
                viewerFrame:SetPoint(viewerSettings.Layout[1], anchorParent, viewerSettings.Layout[3], viewerSettings.Layout[4], viewerSettings.Layout[5])
            end
            
            viewerFrame:SetFrameStrata("LOW")
        end
    end
    -- 移除此处的 ApplyChanges 调用，防止死循环
    -- BCDM.LEMO:ApplyChanges()
end

local function SyncFromEditMode()
    if InCombatLockdown() then return end
    
    local cooldownManagerSettings = BCDM.db.profile.CooldownManager
    for _, viewerName in ipairs(BCDM.CooldownManagerViewers) do
        -- 仅同步 EssentialCooldownViewer，其他组件不参与编辑模式同步
        if viewerName == "EssentialCooldownViewer" then
            local viewerFrame = _G[viewerName]
            if viewerFrame then
                local point, relativeTo, relativePoint, x, y = viewerFrame:GetPoint()
                if point then
                    local relativeToName = (relativeTo and relativeTo.GetName and relativeTo:GetName()) or "UIParent"
                    local viewerType = BCDM.CooldownManagerViewerToDBViewer[viewerName]
                    
                    if viewerType and cooldownManagerSettings[viewerType] then
                        local layout = cooldownManagerSettings[viewerType].Layout
                        
                        -- Update DB if position changed
                        if layout[1] ~= point or layout[2] ~= relativeToName or layout[3] ~= relativePoint or math.abs(layout[4] - x) > 0.1 or math.abs(layout[5] - y) > 0.1 then
                            layout[1] = point
                            layout[2] = relativeToName
                            layout[3] = relativePoint
                            layout[4] = x
                            layout[5] = y
                        end
                    end
                end
            end
        end
    end
end

-- function BCDM:UpdateBuffBarStyle()
--     Position()
--     StyleBuffsBars()
-- end

--[[
local cooldownFrameTbl = {}

for _, child in ipairs({ viewer:GetChildren() }) do
    cooldownFrameTbl[child:GetCooldownFrame()] = true
end

hooksecurefunc("CooldownFrame_Set", function(cooldownFrame)
    if cooldownFrameTbl[cooldownFrame] and cooldownFrame:GetUseAuraDisplayTime() then
        CooldownFrame_Clear(cooldownFrame)
    end
end)
]]

local function StyleIcons()
    if not ShouldSkin() then return end
    local cooldownManagerSettings = BCDM.db.profile.CooldownManager
    for _, viewerName in ipairs(BCDM.CooldownManagerViewers) do
        local viewerSettings = cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]]
        local iconWidth, iconHeight = BCDM:GetIconDimensions(viewerSettings)
        for _, childFrame in ipairs({_G[viewerName]:GetChildren()}) do
            if childFrame then
                if childFrame.Icon then
                    BCDM:StripTextures(childFrame.Icon)
                    local iconZoomAmount = cooldownManagerSettings.General.IconZoom * 0.5
                    BCDM:ApplyIconTexCoord(childFrame.Icon, iconWidth, iconHeight, iconZoomAmount)
                end
                if childFrame.Cooldown then
                    local borderSize = cooldownManagerSettings.General.BorderSize
                    childFrame.Cooldown:ClearAllPoints()
                    childFrame.Cooldown:SetPoint("TOPLEFT", childFrame, "TOPLEFT", borderSize, -borderSize)
                    childFrame.Cooldown:SetPoint("BOTTOMRIGHT", childFrame, "BOTTOMRIGHT", -borderSize, borderSize)
                    childFrame.Cooldown:SetSwipeColor(0, 0, 0, 0.8)
                    childFrame.Cooldown:SetDrawEdge(false)
                    childFrame.Cooldown:SetDrawSwipe(true)
                    childFrame.Cooldown:SetSwipeTexture("Interface\\Buttons\\WHITE8X8")
                end
                if childFrame.CooldownFlash then childFrame.CooldownFlash:SetAlpha(0) end
                if childFrame.DebuffBorder then childFrame.DebuffBorder:SetAlpha(0) end
                childFrame:SetSize(iconWidth, iconHeight)
                BCDM:AddBorder(childFrame)
                if not childFrame.layoutIndex then childFrame:SetShown(false) end
            end
        end
    end
end

local function SetHooks()
    -- 使用安全包装函数，避免在 secureexecuterange 中执行可能导致错误的操作
    local function SafeCall(func)
        local success, errorMsg = pcall(func)
        if not success and errorMsg then
            -- 静默处理错误，避免在安全执行环境中报错
        end
    end
    
    hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function() 
        if InCombatLockdown() then return end 
        SafeCall(Position)
    end)
    hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function() 
        if InCombatLockdown() then return end 
        SafeCall(function()
            SyncFromEditMode()
            BCDM.LEMO:LoadLayouts() 
            Position() 
        end)
    end)
    hooksecurefunc(CooldownViewerSettings, "RefreshLayout", function() 
        if InCombatLockdown() then return end 
        SafeCall(function() BCDM:UpdateBCDM() end)
    end)
    
    -- 添加事件监听器以响应官方设置的改变
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    eventFrame:RegisterEvent("CVAR_UPDATE") -- 监听CVAR更新，可能包含冷却管理器设置
    
    -- 事件节流，避免频繁处理相同事件
    local eventThrottle = 0.2
    local lastEventTime = 0
    local lastEvent = ""
    
    eventFrame:SetScript("OnEvent", function(self, event, arg1)
        local currentTime = GetTime()
        if currentTime - lastEventTime < eventThrottle and event == lastEvent then return end
        lastEventTime = currentTime
        lastEvent = event
        
        if event == "EDIT_MODE_LAYOUTS_UPDATED" then
            SyncFromEditMode()
        elseif event == "PLAYER_ENTERING_WORLD" then
            -- 游戏加载完成后重新应用布局
            C_Timer.After(1, function()
                if not InCombatLockdown() then
                    -- 使用统一的居中更新函数
                    UpdateAllCentering()
                end
            end)
        elseif event == "CVAR_UPDATE" and arg1 == "cooldownViewerEnabled" then
            -- 当冷却管理器设置发生变化时，重新应用布局
            C_Timer.After(0.2, function()
                if not InCombatLockdown() then
                    -- 使用统一的居中更新函数
                    UpdateAllCentering()
                end
            end)
        end
    end)
end

local function StyleChargeCount()
    local cooldownManagerSettings = BCDM.db.profile.CooldownManager
    local generalSettings = BCDM.db.profile.General
    for _, viewerName in ipairs(BCDM.CooldownManagerViewers) do
        for _, childFrame in ipairs({ _G[viewerName]:GetChildren() }) do
            if childFrame and childFrame.ChargeCount and childFrame.ChargeCount.Current then
                local currentChargeText = childFrame.ChargeCount.Current
                currentChargeText:SetFont(BCDM.Media.Font, cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]].Text.FontSize, generalSettings.Fonts.FontFlag)
                currentChargeText:ClearAllPoints()
                currentChargeText:SetPoint(cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]].Text.Layout[1], childFrame, cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]].Text.Layout[2], cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]].Text.Layout[3], cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]].Text.Layout[4])
                currentChargeText:SetTextColor(cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]].Text.Colour[1], cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]].Text.Colour[2], cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]].Text.Colour[3], 1)
                if generalSettings.Fonts.Shadow.Enabled then
                    currentChargeText:SetShadowColor(generalSettings.Fonts.Shadow.Colour[1], generalSettings.Fonts.Shadow.Colour[2], generalSettings.Fonts.Shadow.Colour[3], generalSettings.Fonts.Shadow.Colour[4])
                    currentChargeText:SetShadowOffset(generalSettings.Fonts.Shadow.OffsetX, generalSettings.Fonts.Shadow.OffsetY)
                else
                    currentChargeText:SetShadowColor(0, 0, 0, 0)
                    currentChargeText:SetShadowOffset(0, 0)
                end
                currentChargeText:SetDrawLayer("OVERLAY")
            end
        end
        for _, childFrame in ipairs({ _G[viewerName]:GetChildren() }) do
            if childFrame and childFrame.Applications then
                local applicationsText = childFrame.Applications.Applications
                applicationsText:SetFont(BCDM.Media.Font, cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]].Text.FontSize, generalSettings.Fonts.FontFlag)
                applicationsText:ClearAllPoints()
                applicationsText:SetPoint(cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]].Text.Layout[1], childFrame, cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]].Text.Layout[2], cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]].Text.Layout[3], cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]].Text.Layout[4])
                applicationsText:SetTextColor(cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]].Text.Colour[1], cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]].Text.Colour[2], cooldownManagerSettings[BCDM.CooldownManagerViewerToDBViewer[viewerName]].Text.Colour[3], 1)
                if generalSettings.Fonts.Shadow.Enabled then
                    applicationsText:SetShadowColor(generalSettings.Fonts.Shadow.Colour[1], generalSettings.Fonts.Shadow.Colour[2], generalSettings.Fonts.Shadow.Colour[3], generalSettings.Fonts.Shadow.Colour[4])
                    applicationsText:SetShadowOffset(generalSettings.Fonts.Shadow.OffsetX, generalSettings.Fonts.Shadow.OffsetY)
                else
                    applicationsText:SetShadowColor(0, 0, 0, 0)
                    applicationsText:SetShadowOffset(0, 0)
                end
                applicationsText:SetDrawLayer("OVERLAY")
            end
        end
    end
end

-- 统一的居中功能更新函数
local centerUpdateThrottle = 0.1  -- 增加更新间隔到0.1秒，减少性能消耗
local nextCenterUpdate = 0
local function UpdateAllCentering()
    local currentTime = GetTime()
    if currentTime < nextCenterUpdate then return end
    nextCenterUpdate = currentTime + centerUpdateThrottle
    
    local cooldownManagerSettings = BCDM.db.profile.CooldownManager
    
    -- 处理 Essential 居中
    if cooldownManagerSettings.Essential.CenterEssential then
        local iconLimit = cooldownManagerSettings.Essential.IconLimitPerRow or 20
        BCDM.CooldownCentering.CenterAllRowsForViewer(EssentialCooldownViewer, "CENTER", iconLimit)
    end
    
    -- 处理 Utility 居中
    if cooldownManagerSettings.Utility.CenterUtility then
        local iconLimit = cooldownManagerSettings.Utility.IconLimitPerRow or 20
        BCDM.CooldownCentering.CenterAllRowsForViewer(UtilityCooldownViewer, "CENTER", iconLimit)
    end
    
    -- 处理 Buffs 居中
    if cooldownManagerSettings.Buffs.CenterBuffs then
        local iconLimit = cooldownManagerSettings.Buffs.IconLimitPerRow or 20
        BCDM.CooldownCentering.CenterAllRowsForViewer(BuffIconCooldownViewer, "CENTER", iconLimit)
    end
end

local centerUpdateFrame = CreateFrame("Frame")

local function SetupCenterBuffs()
    local buffsSettings = BCDM.db.profile.CooldownManager.Buffs
    local essentialSettings = BCDM.db.profile.CooldownManager.Essential
    local utilitySettings = BCDM.db.profile.CooldownManager.Utility
    
    -- 检查是否需要启用居中更新
    local needsCentering = buffsSettings.CenterBuffs or essentialSettings.CenterEssential or utilitySettings.CenterUtility
    
    if needsCentering then
        centerUpdateFrame:SetScript("OnUpdate", UpdateAllCentering)
    else
        centerUpdateFrame:SetScript("OnUpdate", nil)
        centerUpdateFrame:Hide()
    end
end

-- 添加一个函数来检查并应用官方设置
local function SyncWithOfficialSettings()
    -- 检查是否需要根据官方设置更新我们的配置
    local cooldownManagerSettings = BCDM.db.profile.CooldownManager
    if cooldownManagerSettings.Essential.CenterEssential then
        local iconLimit = cooldownManagerSettings.Essential.IconLimitPerRow or EssentialCooldownViewer.iconLimit or 20
        BCDM.CooldownCentering.CenterAllRowsForViewer(EssentialCooldownViewer, "CENTER", iconLimit)
    end
    if cooldownManagerSettings.Utility.CenterUtility then
        local iconLimit = cooldownManagerSettings.Utility.IconLimitPerRow or UtilityCooldownViewer.iconLimit or 20
        BCDM.CooldownCentering.CenterAllRowsForViewer(UtilityCooldownViewer, "CENTER", iconLimit)
    end
    if cooldownManagerSettings.Buffs.CenterBuffs then
        local iconLimit = cooldownManagerSettings.Buffs.IconLimitPerRow or BuffIconCooldownViewer.iconLimit or 20
        BCDM.CooldownCentering.CenterAllRowsForViewer(BuffIconCooldownViewer, "CENTER", iconLimit)
    end
end

-- 简化的 SetupCenterUtility 和 SetupCenterEssential 函数
local function SetupCenterUtility()
    -- 调用统一的 SetupCenterBuffs 来管理居中更新
    SetupCenterBuffs()
end

local function SetupCenterEssential()
    -- 调用统一的 SetupCenterBuffs 来管理居中更新
    SetupCenterBuffs()
end

function BCDM:SkinCooldownManager()
    local LEMO = BCDM.LEMO
    LEMO:LoadLayouts()
    C_CVar.SetCVar("cooldownViewerEnabled", 1)
    StyleIcons()
    StyleChargeCount()
    Position()
    SetHooks()
    SetupCenterBuffs()
    SetupCenterUtility()
    SetupCenterEssential()
    for _, viewerName in ipairs(BCDM.CooldownManagerViewers) do
        C_Timer.After(0.1, function() 
            ApplyCooldownText(viewerName) 
            ApplyKeyBindingText(viewerName)
        end)
    end

    C_Timer.After(1, function()
        if not InCombatLockdown() then
            BCDM:SafeApplyChanges()
            -- 同步官方设置
            SyncWithOfficialSettings()
        end
    end)
    
    -- 初始化技能高亮功能
    if BCDM.Assistant then
        BCDM.Assistant:Initialize()
    end
end

function BCDM:UpdateCooldownViewer(viewerType)
    -- if viewerType == "BuffBar" then BCDM:UpdateBuffBarStyle() return end
    local cooldownManagerSettings = BCDM.db.profile.CooldownManager
    local cooldownViewerFrame = _G[BCDM.DBViewerToCooldownManagerViewer[viewerType]]
    local viewerSettings = cooldownManagerSettings[viewerType]
    local iconWidth, iconHeight = BCDM:GetIconDimensions(viewerSettings)
    if viewerType == "Custom" then BCDM:UpdateCustomCooldownViewer() return end
    if viewerType == "AdditionalCustom" then BCDM:UpdateAdditionalCustomCooldownViewer() return end
    if viewerType == "Item" then BCDM:UpdateCustomItemBar() return end
    if viewerType == "Trinket" then BCDM:UpdateTrinketBar() return end
    if viewerType == "ItemSpell" then BCDM:UpdateCustomItemsSpellsBar() return end
    if viewerType == "Buffs" then SetupCenterBuffs() end
    if viewerType == "Utility" then SetupCenterUtility() end
    if viewerType == "Essential" then SetupCenterEssential() end

    if not cooldownViewerFrame then return end

    for _, childFrame in ipairs({cooldownViewerFrame:GetChildren()}) do
        if childFrame then
            if childFrame.Icon and ShouldSkin() then
                BCDM:StripTextures(childFrame.Icon)
                BCDM:ApplyIconTexCoord(childFrame.Icon, iconWidth, iconHeight, cooldownManagerSettings.General.IconZoom)
            end
            if childFrame.Cooldown then
                childFrame.Cooldown:ClearAllPoints()
                childFrame.Cooldown:SetPoint("TOPLEFT", childFrame, "TOPLEFT", 1, -1)
                childFrame.Cooldown:SetPoint("BOTTOMRIGHT", childFrame, "BOTTOMRIGHT", -1, 1)
                childFrame.Cooldown:SetSwipeColor(0, 0, 0, 0.8)
                childFrame.Cooldown:SetDrawEdge(false)
                childFrame.Cooldown:SetDrawSwipe(true)
                childFrame.Cooldown:SetSwipeTexture("Interface\\Buttons\\WHITE8X8")
            end
            if childFrame.CooldownFlash then childFrame.CooldownFlash:SetAlpha(0) end
            childFrame:SetSize(iconWidth, iconHeight)
        end
    end

    StyleIcons()

    Position()

    StyleChargeCount()

    ApplyCooldownText(BCDM.DBViewerToCooldownManagerViewer[viewerType])
    ApplyKeyBindingText(BCDM.DBViewerToCooldownManagerViewer[viewerType])

    -- 重新应用居中布局，确保使用最新的设置
    if viewerType == "Essential" and cooldownManagerSettings.Essential.CenterEssential then
        local iconLimit = cooldownManagerSettings.Essential.IconLimitPerRow or cooldownViewerFrame.iconLimit or 20
        BCDM.CooldownCentering.CenterAllRowsForViewer(EssentialCooldownViewer, "CENTER", iconLimit)
    elseif viewerType == "Utility" and cooldownManagerSettings.Utility.CenterUtility then
        local iconLimit = cooldownManagerSettings.Utility.IconLimitPerRow or cooldownViewerFrame.iconLimit or 20
        BCDM.CooldownCentering.CenterAllRowsForViewer(UtilityCooldownViewer, "CENTER", iconLimit)
    elseif viewerType == "Buffs" and cooldownManagerSettings.Buffs.CenterBuffs then
        local iconLimit = cooldownManagerSettings.Buffs.IconLimitPerRow or cooldownViewerFrame.iconLimit or 20
        BCDM.CooldownCentering.CenterAllRowsForViewer(BuffIconCooldownViewer, "CENTER", iconLimit)
    end

    -- 强制更新Overlay框架的锚点，确保它们正确反映当前布局
    C_Timer.After(0.1, function()
        if viewerType == "Essential" and BCDM.EssentialCooldownViewerOverlay then
            BCDM.EssentialCooldownViewerOverlay:ClearAllPoints()
            BCDM.EssentialCooldownViewerOverlay:SetPoint("TOPLEFT", _G["EssentialCooldownViewer"], "TOPLEFT", -8, 8)
            BCDM.EssentialCooldownViewerOverlay:SetPoint("BOTTOMRIGHT", _G["EssentialCooldownViewer"], "BOTTOMRIGHT", 8, -8)
        elseif viewerType == "Utility" and BCDM.UtilityCooldownViewerOverlay then
            BCDM.UtilityCooldownViewerOverlay:ClearAllPoints()
            BCDM.UtilityCooldownViewerOverlay:SetPoint("TOPLEFT", _G["UtilityCooldownViewer"], "TOPLEFT", -8, 8)
            BCDM.UtilityCooldownViewerOverlay:SetPoint("BOTTOMRIGHT", _G["UtilityCooldownViewer"], "BOTTOMRIGHT", 8, -8)
        elseif viewerType == "Buffs" and BCDM.BuffIconCooldownViewerOverlay then
            BCDM.BuffIconCooldownViewerOverlay:ClearAllPoints()
            BCDM.BuffIconCooldownViewerOverlay:SetPoint("TOPLEFT", _G["BuffIconCooldownViewer"], "TOPLEFT", -8, 8)
            BCDM.BuffIconCooldownViewerOverlay:SetPoint("BOTTOMRIGHT", _G["BuffIconCooldownViewer"], "BOTTOMRIGHT", 8, -8)
        end
    end)

    BCDM:UpdatePowerBarWidth()
    BCDM:UpdateSecondaryPowerBarWidth()
    BCDM:UpdateCastBarWidth()
    
    -- 如果启用了技能高亮，重新初始化助理模块
    if BCDM.Assistant then
        BCDM.Assistant:Initialize()
    end
end

function BCDM:UpdateCooldownViewers()
    BCDM:UpdateCooldownViewer("Essential")
    BCDM:UpdateCooldownViewer("Utility")
    BCDM:UpdateCooldownViewer("Buffs")
    BCDM:UpdateCustomCooldownViewer()
    BCDM:UpdateAdditionalCustomCooldownViewer()
    BCDM:UpdateCustomItemBar()
    BCDM:UpdateCustomItemsSpellsBar()
    BCDM:UpdateTrinketBar()
    BCDM:UpdatePowerBar()
    BCDM:UpdateSecondaryPowerBar()
    BCDM:UpdateCastBar()
    
    -- 应用同步设置
    SyncWithOfficialSettings()
end
