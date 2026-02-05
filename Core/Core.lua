local _, BCDM = ...
local BetterCooldownManager = LibStub("AceAddon-3.0"):NewAddon("BetterCooldownManager")

function BetterCooldownManager:OnInitialize()
    BCDM.db = LibStub("AceDB-3.0"):New("BCDMDB", BCDM:GetDefaultDB(), true)
    BCDM.LDS:EnhanceDatabase(BCDM.db, "UnhaltedUnitFrames")
    if BCDM.db.global.UseGlobalProfile then BCDM.db:SetProfile(BCDM.db.global.GlobalProfile or "Default") end
    BCDM.db.RegisterCallback(BCDM, "OnProfileChanged", function() BCDM:UpdateBCDM() end)
end

function BetterCooldownManager:OnEnable()
    -- 首先初始化透明度状态
    BCDM:InitializeAlphaState()
    
    BCDM:Init()
    BCDM:SetupEventManager()
    BCDM:SkinCooldownManager()
    BCDM:RefreshAuraOverlayRemoval()
    BCDM:SetupCustomGlows()
    BCDM:CreatePowerBar()
    BCDM:CreateSecondaryPowerBar()
    BCDM:CreateCastBar()
    BCDM:CreateCastSequenceBar()
    C_Timer.After(0.1, function()
        BCDM:SetupCustomCooldownViewer()
        BCDM:SetupAdditionalCustomCooldownViewer()
        BCDM:SetupCustomItemBar()
        BCDM:SetupTrinketBar()
        BCDM:SetupCustomItemsSpellsBar()
        BCDM:CreateCooldownViewerOverlays()
    end)
    BCDM:SetupEditModeManager()
    BCDM:CreateMinimapIcon()
    
    -- 初始化完成后更新透明度
    C_Timer.After(0.2, function()
        BCDM:UpdateCombatVisibility()
    end)
end

function BetterCooldownManager:OnDisable()
    -- 清理透明度过渡定时器
    if BCDM.AlphaTransitionTimer then
        BCDM.AlphaTransitionTimer:Cancel()
        BCDM.AlphaTransitionTimer = nil
    end
end

function BCDM:CreateMinimapIcon()
    local L = BCDM.L
    local LDB = LibStub("LibDataBroker-1.1")
    local LibDBIcon = LibStub("LibDBIcon-1.0")
    
    -- Create LDB data object for compatibility with icon management addons
    BCDM.LDBIcon = LDB:NewDataObject("BetterCooldownManager", {
        type = "launcher",
        label = "BCDM",
        text = "BCDM",
        icon = "Interface\\AddOns\\BetterCooldownManager\\Media\\Logo.png",
        OnClick = function(self, button)
            if button == "LeftButton" then
                BCDM:CreateGUI()
            end
        end,
        OnEnter = function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
            GameTooltip:SetText("|cFF8080FFBetterCooldownManager|r", 1, 1, 1)
            GameTooltip:AddLine(L["Slash Commands"])
            GameTooltip:Show()
        end,
        OnLeave = function(self)
            GameTooltip:Hide()
        end
    })
    
    -- Ensure icon is set (for compatibility with different LibDBIcon versions)
    if not BCDM.LDBIcon.icon or BCDM.LDBIcon.icon == "" then
        BCDM.LDBIcon.icon = "Interface\\Icons\\INV_Misc_QuestionMark"
    end
    
    -- Initialize minimap icon settings
    if not BCDM.db.profile.MinimapIcon then
        BCDM.db.profile.MinimapIcon = {
            hide = false,
            minimapPos = 225,
            radius = 80
        }
    end
    
    -- Register with LibDBIcon-1.0 for standard minimap icon management
    -- Use the correct format for LibDBIcon (profile.minimap table)
    BCDM.MinimapIcon = LibDBIcon:Register("BetterCooldownManager", BCDM.LDBIcon, BCDM.db.profile.MinimapIcon)
end

-- 全局透明度状态变量
BCDM.AlphaTransitionTimer = nil
BCDM.CurrentAlpha = 1.0

-- 初始化透明度状态
function BCDM:InitializeAlphaState()
    local initialAlpha = BCDM:GetDesiredAlpha()
    BCDM.CurrentAlpha = initialAlpha
end

-- 全局透明度函数，根据战斗状态和设置状态决定透明度
function BCDM:GetDesiredAlpha()
    local inCombat = InCombatLockdown()
    local hideOutOfCombat = (BCDM.db and BCDM.db.profile and BCDM.db.profile.General and BCDM.db.profile.General.HideOutOfCombat) or false
    
    -- 如果设置了战斗外隐藏且当前不在战斗中，则透明度设为0
    if hideOutOfCombat and not inCombat then
        return 0.0
    else
        -- 否则透明度为1（完全可见）
        return 1.0
    end
end

function BCDM:StartAlphaTransition(targetAlpha)
    -- 如果目标透明度与当前相同，无需过渡
    if BCDM.CurrentAlpha == targetAlpha then
        return
    end
    
    -- 如果已经有过渡定时器在运行，则取消它
    if BCDM.AlphaTransitionTimer then
        BCDM.AlphaTransitionTimer:Cancel()
        BCDM.AlphaTransitionTimer = nil
    end
    
    -- 根据过渡方向设置不同的持续时间
    local duration = 0.3 -- 默认显示时的过渡时间（0到1）
    if targetAlpha < BCDM.CurrentAlpha then
        duration = 2.0 -- 隐藏时的过渡时间（1到0）
    end
    
    -- 设置起始时间和起始透明度
    local startTime = GetTime()
    local startAlpha = BCDM.CurrentAlpha
    
    -- 创建一个计时器来处理平滑过渡
    BCDM.AlphaTransitionTimer = C_Timer.NewTicker(0.016, function() -- 约每帧一次 (60 FPS)
        local elapsed = GetTime() - startTime
        local progress = math.min(elapsed / duration, 1)
        
        -- 使用缓动函数使过渡更平滑 (ease out)
        local easeProgress = 1 - math.pow(1 - progress, 3)
        local currentAlpha = startAlpha + (targetAlpha - startAlpha) * easeProgress
        
        BCDM.CurrentAlpha = currentAlpha
        BCDM:UpdateAllFramesAlpha()
        
        if progress >= 1 then
            -- 过渡完成，设置最终透明度
            BCDM.CurrentAlpha = targetAlpha
            BCDM:UpdateAllFramesAlpha()
            
            -- 清理定时器
            if BCDM.AlphaTransitionTimer then
                BCDM.AlphaTransitionTimer:Cancel()
                BCDM.AlphaTransitionTimer = nil
            end
        end
    end)
end

function BCDM:UpdateCombatVisibility()
    -- 获取期望的透明度
    local desiredAlpha = BCDM:GetDesiredAlpha()
    BCDM:StartAlphaTransition(desiredAlpha)
end

-- 检查框架是否应该受透明度控制影响
function BCDM:IsFrameAlphaControlled(frameName)
    local db = BCDM.db and BCDM.db.profile
    if not db then return false end
    
    -- 根据框架名称检查对应功能是否启用
    if frameName == "BCDM_PowerBar" then
        return db.PowerBar.Enabled
    elseif frameName == "BCDM_SecondaryPowerBar" then
        return db.SecondaryPowerBar.Enabled
    elseif frameName == "BCDM_CastBar" then
        return db.CastBar.Enabled
    elseif frameName == "BCDM_CastSequenceBar" then
        return db.CastSequenceBar.Enabled
    elseif frameName == "BCDM_TrinketBar" then
        return db.CooldownManager.Trinket.Enabled
    elseif frameName:find("CooldownViewer") and not frameName:find("Container") then
        -- 对于冷却管理器视图器，只有当冷却管理器功能启用时才受控制
        return db.CooldownManager.Enable
    elseif frameName == "BCDM_CustomCooldownViewerContainer" then
        -- 自定义冷却管理器容器
        return db.CooldownManager.Enable
    elseif frameName == "BCDM_AdditionalCustomCooldownViewerContainer" then
        -- 额外自定义冷却管理器容器
        return db.CooldownManager.Enable
    elseif frameName == "BCDM_CustomItemBarContainer" then
        -- 自定义物品栏容器
        return true  -- 物品栏总是受控制，只要有物品配置
    elseif frameName == "BCDM_CustomItemSpellBarContainer" then
        -- 自定义物品法术栏容器
        return true  -- 物品法术栏总是受控制，只要有物品法术配置
    elseif frameName == "BCDM_TrinketBarContainer" then
        -- 饰品栏容器
        return db.CooldownManager.Trinket.Enabled
    end
    
    -- 对于未知框架，默认受控制
    return true
end

function BCDM:UpdateAllFramesAlpha()
    -- 所有需要更新的帧
    local framesToUpdate = {
        "BCDM_PowerBar",
        "BCDM_SecondaryPowerBar",
        "BCDM_CastBar",
        "BCDM_CastSequenceBar",
        "EssentialCooldownViewer",
        "UtilityCooldownViewer",
        "BuffIconCooldownViewer",
        "CustomCooldownViewer",
        "AdditionalCustomCooldownViewer",
        "CustomItemViewer",
        "TrinketBar",
        "CustomItemSpellViewer",
        -- 容器框架也需要更新可见性
        "BCDM_CustomCooldownViewerContainer",
        "BCDM_AdditionalCustomCooldownViewerContainer",
        "BCDM_CustomItemBarContainer",
        "BCDM_CustomItemSpellBarContainer",
        "BCDM_TrinketBarContainer"
    }
    
    -- 批量更新所有帧的透明度
    for _, frameName in ipairs(framesToUpdate) do
        local frame = _G[frameName]
        if frame and BCDM:IsFrameAlphaControlled(frameName) then
            -- 总是应用透明度，但确保框架可见以使透明度变化有效
            frame:Show()
            frame:SetAlpha(BCDM.CurrentAlpha)
        end
    end
end