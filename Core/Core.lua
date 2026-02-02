local _, BCDM = ...
local BetterCooldownManager = LibStub("AceAddon-3.0"):NewAddon("BetterCooldownManager")

function BetterCooldownManager:OnInitialize()
    BCDM.db = LibStub("AceDB-3.0"):New("BCDMDB", BCDM:GetDefaultDB(), true)
    BCDM.LDS:EnhanceDatabase(BCDM.db, "UnhaltedUnitFrames")
    for k, v in pairs(BCDM:GetDefaultDB()) do
        if BCDM.db.profile[k] == nil then
            BCDM.db.profile[k] = v
        end
    end
    if BCDM.db.global.UseGlobalProfile then BCDM.db:SetProfile(BCDM.db.global.GlobalProfile or "Default") end
    BCDM.db.RegisterCallback(BCDM, "OnProfileChanged", function() BCDM:UpdateBCDM() end)
end

function BetterCooldownManager:OnEnable()
    BCDM:Init()
    BCDM:SetupEventManager()
    BCDM:SkinCooldownManager()
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