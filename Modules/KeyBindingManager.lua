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
    key = key:gsub("SHIFT%-", "S")
    key = key:gsub("CTRL%-", "C")
    key = key:gsub("ALT%-", "A")
    key = key:gsub("STRG%-", "C")
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
    
    -- 确保 id 是一个数字，以防止传递受保护值时出现 "table index is secret" 错误。
    local numericId = tonumber(id)
    if not numericId then return "" end
    
    type = type or "spell"
    
    -- 使用 pcall 处理 numericId 可能是秘密值的情况，
    -- 这种情况在用作表键时会导致 "table index is secret" 错误。
    local success, binding = pcall(function() 
        return self.SpellBindingCache[type .. ":" .. numericId] 
    end)
    
    if success then
        return binding or ""
    end
    
    return ""
end

function KBM:GetKeyBindingByTexture(texture)
    if not texture then return "" end
    
    local success, binding = pcall(function()
        return self.TextureBindingCache[texture]
    end)
    
    if success then
        return binding or ""
    end
    
    return ""
end

-- Initialize event handling
local frame = CreateFrame("Frame")
frame:RegisterEvent("UPDATE_BINDINGS")
frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
frame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
frame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

local UPDATE_THROTTLE = 0.2 -- 更新节流时间，单位：秒

local function PerformUpdate()
    KBM:UpdateKeyBindings()
    -- 仅更新按键绑定文本，避免全量刷新带来的性能开销
    if BCDM.UpdateKeyBindingTexts and BCDM.Media then
        BCDM:UpdateKeyBindingTexts()
    -- 如果轻量级更新函数不可用，则回退到全量更新（需要 Media 模块加载完成）
    elseif BCDM.UpdateCooldownViewers and BCDM.Media then
        BCDM:UpdateCooldownViewers()
    end
end

local function OnUpdate(self, elapsed)
    self.timeSinceEvent = (self.timeSinceEvent or 0) + elapsed
    if self.timeSinceEvent >= UPDATE_THROTTLE then
        self:SetScript("OnUpdate", nil) -- 停止 OnUpdate 脚本
        PerformUpdate()      -- 执行实际更新
    end
end

frame:SetScript("OnEvent", function(self, event, ...)
    self.timeSinceEvent = 0 -- 重置计时器
    self:SetScript("OnUpdate", OnUpdate) -- 开启 OnUpdate 脚本进行倒计时
end)
