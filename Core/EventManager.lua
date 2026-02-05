local _, BCDM = ...
local LEMO = LibStub("LibEditModeOverride-1.0")

function BCDM:SetupEventManager()
    local BCDMEventManager = CreateFrame("Frame", "BCDMEventManagerFrame")
    BCDMEventManager:RegisterEvent("PLAYER_ENTERING_WORLD")
    BCDMEventManager:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    BCDMEventManager:RegisterEvent("TRAIT_CONFIG_UPDATED")
    BCDMEventManager:RegisterEvent("PLAYER_REGEN_ENABLED")
    BCDMEventManager:RegisterEvent("PLAYER_REGEN_DISABLED")
    BCDMEventManager:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    BCDMEventManager:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_REGEN_DISABLED" then
            -- 进入战斗，强制开始显示过渡
            if BCDM.AlphaTransitionTimer then
                BCDM.AlphaTransitionTimer:Cancel()
                BCDM.AlphaTransitionTimer = nil
            end
            BCDM:StartAlphaTransition(1.0)
        elseif event == "PLAYER_REGEN_ENABLED" then
            -- 离开战斗，根据设置更新透明度
            BCDM:UpdateCombatVisibility()
        elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
            BCDM:UpdateCombatVisibility()
        elseif InCombatLockdown() then
            -- 非战斗状态变化事件，在战斗中则返回
            return
        elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
            local unit = ...
            if unit ~= "player" then return end
            BCDM:SafeApplyChanges()
            BCDM:UpdateBCDM()
        else
            BCDM:UpdateBCDM()
        end
    end)
end