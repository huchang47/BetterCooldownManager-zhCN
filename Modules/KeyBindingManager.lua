local _, BCDM = ...
BCDM.KeyBindingManager = {}
local KBM = BCDM.KeyBindingManager
local L = BCDM.L

-- Cache for spell ID to binding text
KBM.SpellBindingCache = {}
KBM.TextureBindingCache = {}

-- Map slots to binding commands
local slotToCommand = {}
for i = 1, 12 do slotToCommand[i] = "ACTIONBUTTON" .. i end
for i = 1, 12 do slotToCommand[60 + i] = "MULTIACTIONBAR1BUTTON" .. i end -- 61-72 BottomLeft
for i = 1, 12 do slotToCommand[48 + i] = "MULTIACTIONBAR2BUTTON" .. i end -- 49-60 BottomRight
for i = 1, 12 do slotToCommand[24 + i] = "MULTIACTIONBAR3BUTTON" .. i end -- 25-36 Right
for i = 1, 12 do slotToCommand[36 + i] = "MULTIACTIONBAR4BUTTON" .. i end -- 37-48 Right 2
for i = 1, 12 do slotToCommand[72 + i] = "MULTIACTIONBAR5BUTTON" .. i end -- 73-84
for i = 1, 12 do slotToCommand[84 + i] = "MULTIACTIONBAR6BUTTON" .. i end -- 85-96
for i = 1, 12 do slotToCommand[96 + i] = "MULTIACTIONBAR7BUTTON" .. i end -- 97-108

function KBM:GetAbbreviatedKey(key)
    if not key then return "" end
    key = key:upper()
    key = key:gsub("SHIFT%-", "S-")
    key = key:gsub("CTRL%-", "C-")
    key = key:gsub("ALT%-", "A-")
    key = key:gsub("STRG%-", "C-")
    key = key:gsub("NUMPAD", "N")
    key = key:gsub("PLUS", "+")
    key = key:gsub("MINUS", "-")
    key = key:gsub("MULTIPLY", "*")
    key = key:gsub("DIVIDE", "/")
    key = key:gsub("BACKSPACE", "BS")
    key = key:gsub("BUTTON", "B")
    key = key:gsub("MOUSEWHEELUP", "MWU")
    key = key:gsub("MOUSEWHEELDOWN", "MWD")
    key = key:gsub("MOUSEWHEEL", "MW")
    key = key:gsub("PAGEUP", "PgUp")
    key = key:gsub("PAGEDOWN", "PgDn")
    key = key:gsub("SPACE", "Spc")
    key = key:gsub("INSERT", "Ins")
    key = key:gsub("DELETE", "Del")
    key = key:gsub("HOME", "Home")
    key = key:gsub("END", "End")
    return key
end

function KBM:UpdateKeyBindings()
    wipe(self.SpellBindingCache)
    wipe(self.TextureBindingCache)
    
    for slot, command in pairs(slotToCommand) do
        local type, id = GetActionInfo(slot)
        local binding = GetBindingKey(command)
        
        if binding and binding ~= "" then
            -- Cache by texture
            local texture = GetActionTexture(slot)
            if texture then
                -- Store abbreviated key for this texture
                self.TextureBindingCache[texture] = self:GetAbbreviatedKey(binding)
            end

            if type == "spell" then
                if not self.SpellBindingCache["spell:" .. id] then
                    self.SpellBindingCache["spell:" .. id] = self:GetAbbreviatedKey(binding)
                end
            elseif type == "macro" then
                local spellId = GetMacroSpell(id)
                if spellId and not self.SpellBindingCache["spell:" .. spellId] then
                    self.SpellBindingCache["spell:" .. spellId] = self:GetAbbreviatedKey(binding)
                end
                
                local itemId = GetMacroItem(id)
                if itemId and not self.SpellBindingCache["item:" .. itemId] then
                    self.SpellBindingCache["item:" .. itemId] = self:GetAbbreviatedKey(binding)
                end
            elseif type == "item" then
                if not self.SpellBindingCache["item:" .. id] then
                    self.SpellBindingCache["item:" .. id] = self:GetAbbreviatedKey(binding)
                end
            end
        end
    end
end

function KBM:GetKeyBinding(id, type)
    if not id then return "" end
    type = type or "spell"
    return self.SpellBindingCache[type .. ":" .. id] or ""
end

function KBM:GetKeyBindingByTexture(texture)
    if not texture then return "" end
    return self.TextureBindingCache[texture] or ""
end

-- Initialize event handling
local frame = CreateFrame("Frame")
frame:RegisterEvent("UPDATE_BINDINGS")
frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
frame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
frame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event, ...)
    KBM:UpdateKeyBindings()
    -- Also refresh the cooldown text when bindings change
    if BCDM.UpdateCooldownViewers and BCDM.Media then
        BCDM:UpdateCooldownViewers()
    end
end)
