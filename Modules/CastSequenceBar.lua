local _, BCDM = ...

BCDM.CastSequenceBar = {}
BCDM.CastSequenceBar.CastsTable = {}
BCDM.CastSequenceBar.castContent = {}
BCDM.CastSequenceBar.squares = {}
BCDM.CastSequenceBar.totalSquares = 0

local ignoredSpells = {
    [49821] = true,
    [121557] = true,
}

local recentCasts = {}
local DUPLICATE_THRESHOLD = 0.5

local lastDisplayedSpell = {}
local DISPLAY_DUPLICATE_THRESHOLD = 0.4

local lastSpell, lastCastId, lastChannelId, isChanneling, lastSpellId
local channelSpells = {}
local lastChannelSpell = ""

local function GetSpellInfo(spellId)
    local spellInfo = C_Spell.GetSpellInfo(spellId)
    if spellInfo then
        return spellInfo.name, nil, spellInfo.iconID
    end
end

local function GetSpellInformation(spellId)
    local _, _, icon = GetSpellInfo(spellId)
    local backgroundcolor = {0.5, 0.5, 0.5, 0.4}
    local bordercolor = {0, 0, 0, 0}

    local isHarmful = C_Spell.IsSpellHarmful(spellId)
    local isHelpful = C_Spell.IsSpellHelpful(spellId)

    if isHarmful then
        backgroundcolor = {0.9, 0.5, 0.5, 0.4}
    elseif isHelpful then
        backgroundcolor = {0.1, 0.9, 0.1, 0.4}
    end

    return icon, backgroundcolor, bordercolor
end

local function ParseTargetName(target)
    return ""
end

local function DebugPrint(spellId, event, msg)
    local debugMode = BCDM.db.profile.CastSequenceBar.DebugMode
    if not debugMode then return end
    local spellName = GetSpellInfo(spellId) or "Unknown"
    print(string.format("|cff00ff00[CSBar Debug]|r [%s] %s - %s", event, spellName, msg))
end

local function CreateSquareBox(index)
    local CastSequenceBarDB = BCDM.db.profile.CastSequenceBar
    local squareSize = CastSequenceBarDB.SquareSize

    local square = CreateFrame("Frame", "BCDM_CastSequenceSquare" .. index, BCDM.CastSequenceBar.MainFrame)
    square:SetSize(squareSize, squareSize)
    square.squareIndex = index

    square.texture = square:CreateTexture(nil, "ARTWORK")
    square.texture:SetAllPoints()

    square.interruptedTexture = square:CreateTexture(nil, "OVERLAY")
    square.interruptedTexture:SetColorTexture(1, 0, 0, 0.4)
    square.interruptedTexture:SetAllPoints()
    square.interruptedTexture:Hide()

    local cooldown = CreateFrame("Cooldown", "$parentCooldown", square, "CooldownFrameTemplate, BackdropTemplate")
    cooldown:SetAllPoints()
    cooldown:EnableMouse(false)
    cooldown:SetHideCountdownNumbers(true)
    square.cooldown = cooldown

    square:EnableMouse(true)
    square:SetScript("OnEnter", function(self)
        if not CastSequenceBarDB.ShowTooltip then return end
        local data = self.activeEntry
        if data then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            if data.spellId then
                local success = pcall(function()
                    GameTooltip:SetSpellByID(data.spellId)
                end)
                if success then
                    if data.target and data.target ~= "" then
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine("目标: " .. data.target, 0.7, 0.7, 0.7)
                    end
                    GameTooltip:AddLine("法术ID: " .. data.spellId, 0.5, 0.5, 0.5)
                else
                    GameTooltip:AddLine(data.spellName or "未知法术", 1, 1, 1)
                    if data.target and data.target ~= "" then
                        GameTooltip:AddLine("目标: " .. data.target, 0.7, 0.7, 0.7)
                    end
                    GameTooltip:AddLine("法术ID: " .. data.spellId, 0.5, 0.5, 0.5)
                end
            else
                GameTooltip:AddLine(data.spellName or "未知法术", 1, 1, 1)
                if data.target and data.target ~= "" then
                    GameTooltip:AddLine("目标: " .. data.target, 0.7, 0.7, 0.7)
                end
            end
            GameTooltip:Show()
        end
    end)
    square:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    BCDM.CastSequenceBar.squares[index] = square
    square.in_use = 1
    square:Hide()
    return square
end

function BCDM.CastSequenceBar:ReorderSquares()
    -- Deprecated by dynamic animation
end

local function UpdateCooldownFrame(square, inCooldown, startTime, endTime, castInfo)
    if castInfo and (castInfo.Interrupted or castInfo.ChannelStopped) and castInfo.InterruptedPct then
        local completedPct = castInfo.InterruptedPct
        if completedPct < 0 then completedPct = 0 end
        if completedPct > 1 then completedPct = 1 end
        CooldownFrame_SetDisplayAsPercentage(square.cooldown, completedPct)
        square.cooldown:Show()
        return
    end

    if endTime and endTime < GetTime() then
        CooldownFrame_Clear(square.cooldown)
        square.cooldown:Hide()
        return
    end

    if inCooldown then
        local duration = endTime - startTime
        CooldownFrame_Set(square.cooldown, startTime, duration, duration > 0, true)
        square.cooldown:Show()
    else
        CooldownFrame_Clear(square.cooldown)
        square.cooldown:Hide()
    end
end

function BCDM.CastSequenceBar:UpdateSquares()
    for _, entry in ipairs(self.castContent) do
        self:UpdateSquare(entry)
    end
end

function BCDM.CastSequenceBar:UpdateSquare(entry)
    local square = entry.square
    if not square then return end

    local data = entry
    square:Show()
    square:SetAlpha(data.alpha or 1)
    square.texture:SetTexture(data.icon)
    square.texture:SetTexCoord(5/64, 59/64, 5/64, 59/64)

    local castinfo = self.CastsTable[data.castID]
    local percent = castinfo and castinfo.Percent or 0
    if percent > 100 then percent = 100 end

    local startTime = data.startTime
    local endTime = data.endTime
    UpdateCooldownFrame(square, true, startTime, endTime, castinfo)

    if castinfo and castinfo.Interrupted and not castinfo.IsChanneled then
        square.interruptedTexture:Show()
    else
        square.interruptedTexture:Hide()
    end
    
    square.activeEntry = entry
end

function BCDM.CastSequenceBar:NewCast(icon, spellName, spellId, target, backgroundcolor, bordercolor, castID, castStart, startTime, endTime)
    local now = GetTime()
    if lastDisplayedSpell.spellName == spellName and 
       lastDisplayedSpell.time and 
       (now - lastDisplayedSpell.time) < DISPLAY_DUPLICATE_THRESHOLD then
        DebugPrint(spellId, "NewCast", "BLOCKED: duplicate within " .. (now - lastDisplayedSpell.time) .. "s")
        return
    end

    lastDisplayedSpell.spellName = spellName
    lastDisplayedSpell.time = now

    DebugPrint(spellId, "NewCast", string.format("Adding: %s, castID: ...%s", spellName, tostring(castID):sub(-8)))

    local square
    for _, sq in ipairs(self.squares) do
        if not sq.activeEntry then
            square = sq
            break
        end
    end
    if not square then
        square = CreateSquareBox(#self.squares + 1)
    end

    local CastSequenceBarDB = BCDM.db.profile.CastSequenceBar
    local spacing = CastSequenceBarDB.Spacing
    local squareSize = CastSequenceBarDB.SquareSize
    
    local startX, startY = 0, 0
    if CastSequenceBarDB.GrowDirection == "RIGHT" then
        startX = -squareSize
        startY = -spacing
    else
        startX = squareSize
        startY = -spacing
    end

    local newEntry = {
        icon = icon,
        spellName = spellName,
        spellId = spellId,
        target = target,
        backgroundcolor = backgroundcolor,
        bordercolor = bordercolor,
        castID = castID,
        castStart = castStart,
        startTime = startTime,
        endTime = endTime,
        square = square,
        currentX = startX,
        currentY = startY,
        alpha = 0 -- Start transparent for fade-in
    }
    
    square.activeEntry = newEntry
    self:UpdateSquare(newEntry)
    
    square:ClearAllPoints()
    if CastSequenceBarDB.GrowDirection == "RIGHT" then
         square:SetPoint("TOPLEFT", self.MainFrame, "TOPLEFT", startX, startY)
    else
         square:SetPoint("TOPRIGHT", self.MainFrame, "TOPRIGHT", startX, startY)
    end

    table.insert(self.castContent, 1, newEntry)
end

function BCDM.CastSequenceBar:CastStart(castGUID)
    local castInfo = self.CastsTable[castGUID]
    if not castInfo then return end

    if castInfo.Displayed then
        return
    end

    local spellId = castInfo.SpellId
    local target = castInfo.Target
    local castStart = castInfo.CastStart
    local startTime = castInfo.CastTimeStart
    local endTime = castInfo.CastTimeEnd

    if ignoredSpells[spellId] then
        return
    end

    local icon, backgroundcolor, bordercolor = GetSpellInformation(spellId)
    local spellName = GetSpellInfo(spellId)

    target = ParseTargetName(target)

    castInfo.Displayed = true
    DebugPrint(spellId, "CastStart", string.format("Displaying, castGUID=...%s", tostring(castGUID):sub(-8)))
    self:NewCast(icon, spellName, spellId, target, backgroundcolor, bordercolor, castGUID, castStart, startTime, endTime)
end

function BCDM.CastSequenceBar:CastFinished(castId)
    local castInfo = self.CastsTable[castId]
    if not castInfo then
        DebugPrint(nil, "CastFinished", "No castInfo for " .. tostring(castId))
        return
    end

    local spellId = castInfo.SpellId

    if castInfo.Displayed then
        DebugPrint(spellId, "CastFinished", "Skipped: already displayed")
        return
    end

    local target = castInfo.Target
    local castStart = castInfo.CastStart

    if spellId and ignoredSpells[spellId] then
        return
    end

    local icon, backgroundcolor, bordercolor = GetSpellInformation(spellId)
    local spellName = GetSpellInfo(spellId)

    target = ParseTargetName(target)

    castInfo.Displayed = true
    DebugPrint(spellId, "CastFinished", string.format("Displaying, castGUID=...%s", tostring(castId):sub(-8)))
    self:NewCast(icon, spellName, spellId, target, backgroundcolor, bordercolor, castId, castStart, GetTime(), GetTime() + 1.2)
end

local function TrackSpellCast(frame, elapsed)
    local self = BCDM.CastSequenceBar
    if not self.castContent then return end

    local CastSequenceBarDB = BCDM.db.profile.CastSequenceBar
    local spacing = CastSequenceBarDB.Spacing
    local squareSize = CastSequenceBarDB.SquareSize
    local direction = CastSequenceBarDB.GrowDirection
    
    local LERP_FACTOR = 10 * (elapsed or 0.033)
    local FADE_IN_SPEED = 2 * (elapsed or 0.033)
    local FADE_OUT_SPEED = 2 * (elapsed or 0.033)
    local toRemove = {}

    local isTimeline = CastSequenceBarDB.TimelineAnimation
    local speed = 0
    if isTimeline then
        local haste = UnitSpellHaste("player") or 0
        local gcd = 1.5 / (1 + haste / 100)
        if gcd < 0.75 then gcd = 0.75 end
        speed = (squareSize + spacing) / gcd
    end

    for i, entry in ipairs(self.castContent) do
        if isTimeline then
             local elapsedTime = GetTime() - entry.castStart
             local distance = elapsedTime * speed
             
             if direction == "RIGHT" then
                 entry.currentX = -squareSize + distance
             else
                 entry.currentX = squareSize - distance
             end

             local maxDist = CastSequenceBarDB.Width + squareSize
             if distance > CastSequenceBarDB.Width then
                 entry.alpha = (entry.alpha or 1) - FADE_OUT_SPEED
                 if entry.alpha < 0 then entry.alpha = 0 end
             else
                 if (entry.alpha or 0) < 1 then
                    entry.alpha = (entry.alpha or 0) + FADE_IN_SPEED
                    if entry.alpha > 1 then entry.alpha = 1 end
                 end
             end
        else
            local targetX = 0
            if direction == "RIGHT" then
                 targetX = spacing + (i - 1) * (squareSize + spacing)
            else
                 targetX = -spacing - (i - 1) * (squareSize + spacing)
            end
            
            local diff = targetX - entry.currentX
            if math.abs(diff) < 0.5 then
                entry.currentX = targetX
            else
                entry.currentX = entry.currentX + diff * LERP_FACTOR
            end

            -- Fade In logic
            if (entry.alpha or 0) < 1 and i <= self.totalSquares then
                entry.alpha = (entry.alpha or 0) + FADE_IN_SPEED
                if entry.alpha > 1 then entry.alpha = 1 end
            end

            -- Fade Out logic
            if i > self.totalSquares then
                entry.alpha = (entry.alpha or 1) - FADE_OUT_SPEED
                if entry.alpha < 0 then entry.alpha = 0 end
            end
        end
        
        if entry.square then
             entry.square:SetAlpha(entry.alpha or 1)
             entry.square:ClearAllPoints()
             if direction == "RIGHT" then
                 entry.square:SetPoint("TOPLEFT", self.MainFrame, "TOPLEFT", entry.currentX, entry.currentY)
             else
                 entry.square:SetPoint("TOPRIGHT", self.MainFrame, "TOPRIGHT", entry.currentX, entry.currentY)
             end
             
             local square = entry.square
             local castInfo = self.CastsTable[entry.castID]
             
             if castInfo and not castInfo.Done then
                if castInfo.PendingInterrupt then
                    square.in_use = GetTime()
                elseif castInfo.HasCastTime then
                    if castInfo.Success then
                        castInfo.Done = true
                        castInfo.Percent = 100
                        UpdateCooldownFrame(square, false)
                    elseif castInfo.IsChanneled then
                        local name, _, _, startTime, endTime = UnitChannelInfo("player")
                        if name then
                            startTime = startTime / 1000
                            endTime = endTime / 1000
                            local diff = endTime - startTime
                            local current = GetTime() - startTime
                            local percent = current / diff * 100
                            castInfo.Percent = percent
                            UpdateCooldownFrame(square, true, startTime, endTime, castInfo)
                        end
                    else
                        local _, _, _, startTime, endTime = UnitCastingInfo("player")
                        if startTime and endTime then
                            startTime = startTime / 1000
                            endTime = endTime / 1000
                            local diff = endTime - startTime
                            local current = GetTime() - startTime
                            local percent = current / diff * 100
                            castInfo.Percent = percent
                            UpdateCooldownFrame(square, true, startTime, endTime, castInfo)
                        else
                            UpdateCooldownFrame(square, false)
                        end
                    end
                else
                    if castInfo.CastStart + 1.2 < GetTime() then
                        castInfo.Done = true
                        castInfo.Percent = 100
                        UpdateCooldownFrame(square, false)
                    else
                        local startTime = castInfo.CastStart
                        local endTime = castInfo.CastStart + 1.2
                        local diff = endTime - startTime
                        local current = GetTime() - startTime
                        local percent = current / diff * 100
                        castInfo.Percent = percent
                        UpdateCooldownFrame(square, true, startTime, endTime, castInfo)
                    end
                end
                square.in_use = GetTime()
            end
        end

        if isTimeline then
            if (entry.alpha or 0) <= 0 and (GetTime() - entry.castStart) > 0.5 then
                table.insert(toRemove, i)
            end
        else
            if i > self.totalSquares and (entry.alpha or 0) <= 0 then
                table.insert(toRemove, i)
            end
        end
    end
    
    for k = #toRemove, 1, -1 do
        local idx = toRemove[k]
        local entry = self.castContent[idx]
        if entry and entry.square then
            entry.square:Hide()
            entry.square.activeEntry = nil
        end
        table.remove(self.castContent, idx)
    end
end

local function OnEvent(self, event, ...)
    if event == "UNIT_SPELLCAST_SENT" then
        local unitID, target, castGUID, spellId = ...
        local spell = GetSpellInfo(spellId)

        if unitID == "player" then
            local existed = BCDM.CastSequenceBar.CastsTable[castGUID] ~= nil
            DebugPrint(spellId, "SENT", string.format("castGUID=%s target=%s existed=%s", tostring(castGUID), tostring(target), tostring(existed)))

            if not existed then
                BCDM.CastSequenceBar.CastsTable[castGUID] = {
                    Target = target or "",
                    Id = castGUID,
                    CastStart = GetTime(),
                    SpellId = spellId
                }
            else
                BCDM.CastSequenceBar.CastsTable[castGUID].Target = target or BCDM.CastSequenceBar.CastsTable[castGUID].Target
                BCDM.CastSequenceBar.CastsTable[castGUID].SpellId = BCDM.CastSequenceBar.CastsTable[castGUID].SpellId or spellId
            end
            lastChannelSpell = castGUID
            lastSpell = spell
            lastSpellId = spellId
            lastCastId = castGUID
        end

    elseif event == "UNIT_SPELLCAST_START" then
        local unitID, castGUID, spellId = ...
        if unitID ~= "player" then return end

        DebugPrint(spellId, "START", string.format("castGUID=%s hasCastEntry=%s", tostring(castGUID), tostring(BCDM.CastSequenceBar.CastsTable[castGUID] ~= nil)))

        if BCDM.CastSequenceBar.CastsTable[castGUID] then
            BCDM.CastSequenceBar.CastsTable[castGUID].SpellId = spellId
            BCDM.CastSequenceBar.CastsTable[castGUID].HasCastTime = true

            local _, _, _, startTime, endTime = UnitCastingInfo("player")
            if startTime and endTime then
                BCDM.CastSequenceBar.CastsTable[castGUID].CastTimeStart = startTime / 1000
                BCDM.CastSequenceBar.CastsTable[castGUID].CastTimeEnd = endTime / 1000
            end

            BCDM.CastSequenceBar:CastStart(castGUID)
            DebugPrint(spellId, "START", "Called CastStart")
        end

    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        local unitID, castGUID, spellId = ...
        if unitID ~= "player" then return end

        DebugPrint(spellId, "INTERRUPTED", string.format("castGUID=%s, hasEntry=%s",
            tostring(castGUID), tostring(BCDM.CastSequenceBar.CastsTable[castGUID] ~= nil)))

        if BCDM.CastSequenceBar.CastsTable[castGUID] then
            local castInfo = BCDM.CastSequenceBar.CastsTable[castGUID]

            if castInfo.Success then
                DebugPrint(spellId, "INTERRUPTED", "Ignored: spell already succeeded")
                return
            end

            castInfo.PendingInterrupt = true
            castInfo.InterruptTime = GetTime()
            castInfo.InterruptPct = (castInfo.Percent or 0) / 100

            local _, _, _, startTime, endTime = UnitCastingInfo("player")
            if startTime and endTime then
                startTime = startTime / 1000
                endTime = endTime / 1000
                local totalTime = endTime - startTime
                local elapsed = GetTime() - startTime
                castInfo.InterruptPct = elapsed / totalTime
            end

            if castInfo.InterruptPct < 0 then castInfo.InterruptPct = 0 end
            if castInfo.InterruptPct > 1 then castInfo.InterruptPct = 1 end

            DebugPrint(spellId, "INTERRUPTED", string.format("Pending, pct=%s, waiting...", tostring(castInfo.InterruptPct * 100)))

            C_Timer.After(0.25, function()
                if castInfo.Success then
                    DebugPrint(spellId, "INTERRUPTED", "Cancelled: spell succeeded during delay")
                    castInfo.PendingInterrupt = false
                    return
                end

                if castInfo.PendingInterrupt then
                    castInfo.Interrupted = true
                    castInfo.InterruptedTime = castInfo.InterruptTime
                    castInfo.Done = true
                    castInfo.Percent = castInfo.InterruptPct * 100
                    castInfo.InterruptedPct = castInfo.InterruptPct
                    castInfo.PendingInterrupt = false

                    for i, content in ipairs(BCDM.CastSequenceBar.castContent) do
                        if content.castID == castGUID then
                            content.endTime = castInfo.InterruptTime
                            break
                        end
                    end

                    DebugPrint(spellId, "INTERRUPTED", string.format("Finalized: pct=%s", tostring(castInfo.InterruptPct * 100)))
                    BCDM.CastSequenceBar:UpdateSquares()
                end
            end)
        end

    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        local unitID, castGUID, spellId = ...

        if unitID == "player" then
            castGUID = lastChannelId

            if not BCDM.CastSequenceBar.CastsTable[castGUID] then
                castGUID = lastChannelSpell
                if not castGUID or not BCDM.CastSequenceBar.CastsTable[castGUID] then
                    isChanneling = false
                    lastChannelId = nil
                    return
                end
            end

            local castInfo = BCDM.CastSequenceBar.CastsTable[castGUID]

            local wasCompleted = castInfo.CastTimeEnd and GetTime() >= (castInfo.CastTimeEnd - 0.1)

            if wasCompleted then
                castInfo.Success = true
                castInfo.Done = true
                castInfo.Percent = 100
            else
                local completedPct = (castInfo.Percent or 0) / 100

                if castInfo.CastTimeStart and castInfo.CastTimeEnd then
                    local totalTime = castInfo.CastTimeEnd - castInfo.CastTimeStart
                    local elapsed = GetTime() - castInfo.CastTimeStart
                    completedPct = elapsed / totalTime
                end

                if completedPct < 0 then completedPct = 0 end
                if completedPct > 1 then completedPct = 1 end

                castInfo.ChannelStopped = true
                castInfo.Done = true
                castInfo.Percent = completedPct * 100
                castInfo.InterruptedPct = completedPct

                for i, content in ipairs(BCDM.CastSequenceBar.castContent) do
                    if content.castID == castGUID then
                        content.endTime = GetTime()
                        break
                    end
                end
            end

            isChanneling = false
            lastChannelId = nil

            BCDM.CastSequenceBar:UpdateSquares()
        end

    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        local unitID, castGUID, spellId = ...

        if unitID == "player" then
            if not castGUID or castGUID == "" then
                castGUID = lastCastId
            end

            if not BCDM.CastSequenceBar.CastsTable[castGUID] then
                castGUID = lastChannelSpell
            end

            if not BCDM.CastSequenceBar.CastsTable[castGUID] then
                castGUID = lastCastId or ("channel_" .. GetTime())
                BCDM.CastSequenceBar.CastsTable[castGUID] = {Target = "", Id = castGUID, CastStart = GetTime()}
            end

            if isChanneling and lastChannelId and BCDM.CastSequenceBar.CastsTable[lastChannelId] then
                BCDM.CastSequenceBar.CastsTable[lastChannelId].Interrupted = true
                BCDM.CastSequenceBar.CastsTable[lastChannelId].InterruptedTime = GetTime()
            end

            BCDM.CastSequenceBar.CastsTable[castGUID].HasCastTime = true
            BCDM.CastSequenceBar.CastsTable[castGUID].IsChanneled = true
            BCDM.CastSequenceBar.CastsTable[castGUID].SpellId = lastSpellId
            lastChannelId = castGUID
            isChanneling = true

            local _, _, _, startTime, endTime = UnitChannelInfo("player")
            if startTime and endTime then
                BCDM.CastSequenceBar.CastsTable[castGUID].CastTimeStart = startTime / 1000
                BCDM.CastSequenceBar.CastsTable[castGUID].CastTimeEnd = endTime / 1000
            end

            if lastSpell then
                channelSpells[lastSpell] = true
            end

            BCDM.CastSequenceBar:CastStart(castGUID)
        end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unitID, castGUID, spellId = ...

        if unitID ~= "player" then return end

        local spell = GetSpellInfo(spellId)

        DebugPrint(spellId, "SUCCEEDED", string.format("castGUID=%s hasCastEntry=%s isChannel=%s",
            tostring(castGUID), tostring(BCDM.CastSequenceBar.CastsTable[castGUID] ~= nil), tostring(channelSpells[spell])))

        if not channelSpells[spell] then
            local castInfo = BCDM.CastSequenceBar.CastsTable[castGUID]

            if castInfo and castInfo.Displayed then
                DebugPrint(spellId, "SUCCEEDED", "Skipped: already displayed by CastStart")
                castInfo.Success = true
                return
            end

            local now = GetTime()
            if recentCasts[spellId] and (now - recentCasts[spellId]) < DUPLICATE_THRESHOLD then
                DebugPrint(spellId, "SUCCEEDED", string.format("Skipped: duplicate within %.3fs", now - recentCasts[spellId]))
                return
            end

            recentCasts[spellId] = now

            if not castInfo then
                BCDM.CastSequenceBar.CastsTable[castGUID] = {
                    Target = "",
                    Id = castGUID,
                    CastStart = GetTime(),
                    SpellId = spellId,
                    Success = true
                }
                castInfo = BCDM.CastSequenceBar.CastsTable[castGUID]
                DebugPrint(spellId, "SUCCEEDED", "Created missing entry")
            end

            castInfo.Success = true
            castInfo.SpellId = spellId

            BCDM.CastSequenceBar:CastFinished(castGUID)
            DebugPrint(spellId, "SUCCEEDED", "Called CastFinished")
        end
    end
end

C_Timer.NewTicker(60, function()
    local now = GetTime()
    for castGUID, info in pairs(BCDM.CastSequenceBar.CastsTable) do
        if info.CastStart and (now - info.CastStart) > 120 then
            BCDM.CastSequenceBar.CastsTable[castGUID] = nil
        end
    end
    for spellId, timestamp in pairs(recentCasts) do
        if (now - timestamp) > 10 then
            recentCasts[spellId] = nil
        end
    end
    local channelCount = 0
    for _ in pairs(channelSpells) do channelCount = channelCount + 1 end
    if channelCount > 20 then
        channelSpells = {}
    end
end)

C_Timer.NewTicker(10, function()
    local now = GetTime()
    local EXPIRE_TIME = 60

    local i = 1
    while i <= #BCDM.CastSequenceBar.castContent do
        local content = BCDM.CastSequenceBar.castContent[i]
        if content and content.castStart and (content.castStart + EXPIRE_TIME < now) then
            if content.square then
                content.square:Hide()
                content.square.activeEntry = nil
            end
            table.remove(BCDM.CastSequenceBar.castContent, i)
        else
            i = i + 1
        end
    end

    BCDM.CastSequenceBar:UpdateSquares()
end)

local function SetHooks()
    hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function() 
        if InCombatLockdown() then return end
        BCDM:UpdateCastSequenceBarWidth()
        if BCDM.CastSequenceBar and BCDM.CastSequenceBar.MainFrame and BCDM.CastSequenceBar.MainFrame.UpdateVisibility then
            BCDM.CastSequenceBar.MainFrame.UpdateVisibility()
        end
    end)
    hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function() 
        if InCombatLockdown() then return end
        BCDM:UpdateCastSequenceBarWidth()
        if BCDM.CastSequenceBar and BCDM.CastSequenceBar.MainFrame and BCDM.CastSequenceBar.MainFrame.UpdateVisibility then
            BCDM.CastSequenceBar.MainFrame.UpdateVisibility()
        end
    end)
end

function BCDM:UpdateCastSequenceBarWidth()
    local CastSequenceBarDB = BCDM.db.profile.CastSequenceBar
    local MainFrame = BCDM.CastSequenceBar.MainFrame
    if CastSequenceBarDB.Enabled and CastSequenceBarDB.MatchWidthOfAnchor and MainFrame then
        local anchorFrame = _G[CastSequenceBarDB.Layout[2]]
        if anchorFrame then
            C_Timer.After(0.5, function() local anchorWidth = anchorFrame:GetWidth() MainFrame:SetWidth(anchorWidth) end)
        end
    end
end

function BCDM:CreateCastSequenceBar()
    local CastSequenceBarDB = self.db.profile.CastSequenceBar
    local borderSize = self.db.profile.CooldownManager.General.BorderSize

    SetHooks()

    local MainFrame = CreateFrame("Frame", "BCDM_CastSequenceBar", UIParent, "BackdropTemplate")
    MainFrame:SetClipsChildren(true)
    MainFrame:SetBackdrop(self.BACKDROP)
    if borderSize > 0 then
        MainFrame:SetBackdropBorderColor(CastSequenceBarDB.BorderColour[1], CastSequenceBarDB.BorderColour[2], CastSequenceBarDB.BorderColour[3], CastSequenceBarDB.BorderColour[4])
    else
        MainFrame:SetBackdropBorderColor(0, 0, 0, 0)
    end
    MainFrame:SetBackdropColor(CastSequenceBarDB.BackgroundColour[1], CastSequenceBarDB.BackgroundColour[2], CastSequenceBarDB.BackgroundColour[3], CastSequenceBarDB.BackgroundColour[4])
    
    local squareSize = CastSequenceBarDB.SquareSize
    local spacing = CastSequenceBarDB.Spacing
    local frameHeight = squareSize + spacing * 2
    MainFrame:SetSize(CastSequenceBarDB.Width, frameHeight)
    MainFrame:SetPoint(CastSequenceBarDB.Layout[1], _G[CastSequenceBarDB.Layout[2]], CastSequenceBarDB.Layout[3], CastSequenceBarDB.Layout[4], CastSequenceBarDB.Layout[5])
    MainFrame:SetFrameStrata(CastSequenceBarDB.FrameStrata or "LOW")

    if CastSequenceBarDB.MatchWidthOfAnchor then
        local anchorFrame = _G[CastSequenceBarDB.Layout[2]]
        if anchorFrame then
            C_Timer.After(0.1, function() local anchorWidth = anchorFrame:GetWidth() MainFrame:SetWidth(anchorWidth) end)
        end
    end

    self.CastSequenceBar.MainFrame = MainFrame
    self.CastSequenceBar.castContent = {}
    self.CastSequenceBar.squares = {}
    self.CastSequenceBar.CastsTable = {}

    local squareSize = CastSequenceBarDB.SquareSize
    local frameWidth = CastSequenceBarDB.Width
    local maxSquares = math.floor(frameWidth / squareSize)
    if maxSquares < 1 then maxSquares = 1 end

    local amount = math.min(CastSequenceBarDB.SquareAmount or 8, maxSquares)
    self.CastSequenceBar.totalSquares = amount

    for i = 1, amount do
        CreateSquareBox(i)
    end

    local function UpdateVisibility()
        local isEditMode = EditModeManagerFrame and EditModeManagerFrame:IsShown()
        if CastSequenceBarDB.Enabled or isEditMode then
            MainFrame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
            MainFrame:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
            MainFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
            MainFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
            MainFrame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED_QUIET", "player")
            MainFrame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
            MainFrame:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", "player")
            MainFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
            MainFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
            MainFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
            MainFrame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
            MainFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", "player")
            MainFrame:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "player")

            MainFrame:SetScript("OnEvent", OnEvent)
            MainFrame:SetScript("OnUpdate", TrackSpellCast)

            MainFrame:Show()
        else
            MainFrame:Hide()
            MainFrame:SetScript("OnEvent", nil)
            MainFrame:SetScript("OnUpdate", nil)
            MainFrame:UnregisterAllEvents()
        end
    end

    UpdateVisibility()

    MainFrame.UpdateVisibility = UpdateVisibility
end

function BCDM:ClearCastSequenceBar()
    if not self.CastSequenceBar or not self.CastSequenceBar.castContent then return end

    for _, entry in ipairs(self.CastSequenceBar.castContent) do
        if entry.square then
            entry.square:Hide()
            entry.square.activeEntry = nil
        end
    end
    wipe(self.CastSequenceBar.castContent)
end

function BCDM:UpdateCastSequenceBar()
    local CastSequenceBarDB = self.db.profile.CastSequenceBar
    local borderSize = self.db.profile.CooldownManager.General.BorderSize
    local MainFrame = self.CastSequenceBar.MainFrame
    if not MainFrame then return end

    MainFrame:SetBackdropColor(CastSequenceBarDB.BackgroundColour[1], CastSequenceBarDB.BackgroundColour[2], CastSequenceBarDB.BackgroundColour[3], CastSequenceBarDB.BackgroundColour[4])
    
    local squareSize = CastSequenceBarDB.SquareSize
    local spacing = CastSequenceBarDB.Spacing
    local frameHeight = squareSize + spacing * 2
    MainFrame:SetSize(CastSequenceBarDB.Width, frameHeight)
    MainFrame:ClearAllPoints()
    if CastSequenceBarDB.Layout[2] == "SCREEN_CENTER" then
        MainFrame:SetPoint(CastSequenceBarDB.Layout[1], UIParent, "CENTER", CastSequenceBarDB.Layout[4], CastSequenceBarDB.Layout[5])
    elseif CastSequenceBarDB.Layout[2] == "SCREEN_TOP" then
        MainFrame:SetPoint(CastSequenceBarDB.Layout[1], UIParent, "TOP", CastSequenceBarDB.Layout[4], CastSequenceBarDB.Layout[5])
    elseif CastSequenceBarDB.Layout[2] == "SCREEN_BOTTOM" then
        MainFrame:SetPoint(CastSequenceBarDB.Layout[1], UIParent, "BOTTOM", CastSequenceBarDB.Layout[4], CastSequenceBarDB.Layout[5])
    else
        MainFrame:SetPoint(CastSequenceBarDB.Layout[1], _G[CastSequenceBarDB.Layout[2]], CastSequenceBarDB.Layout[3], CastSequenceBarDB.Layout[4], CastSequenceBarDB.Layout[5])
    end
    MainFrame:SetFrameStrata(CastSequenceBarDB.FrameStrata or "LOW")
    MainFrame:SetBackdrop(self.BACKDROP)
    if borderSize > 0 then
        MainFrame:SetBackdropBorderColor(CastSequenceBarDB.BorderColour[1], CastSequenceBarDB.BorderColour[2], CastSequenceBarDB.BorderColour[3], CastSequenceBarDB.BorderColour[4])
    else
        MainFrame:SetBackdropBorderColor(0, 0, 0, 0)
    end
    MainFrame:SetBackdropColor(CastSequenceBarDB.BackgroundColour[1], CastSequenceBarDB.BackgroundColour[2], CastSequenceBarDB.BackgroundColour[3], CastSequenceBarDB.BackgroundColour[4])

    if CastSequenceBarDB.MatchWidthOfAnchor then
        local anchorFrame = _G[CastSequenceBarDB.Layout[2]]
        if anchorFrame then
            C_Timer.After(0.1, function() local anchorWidth = anchorFrame:GetWidth() MainFrame:SetWidth(anchorWidth) end)
        end
    end

    local squareSize = CastSequenceBarDB.SquareSize
    local frameWidth = CastSequenceBarDB.Width
    local maxSquares = math.floor(frameWidth / squareSize)
    if maxSquares < 1 then maxSquares = 1 end

    local amount = math.min(CastSequenceBarDB.SquareAmount or 8, maxSquares)
    self.CastSequenceBar.totalSquares = amount

    while #self.CastSequenceBar.squares < amount do
        CreateSquareBox(#self.CastSequenceBar.squares + 1)
    end

    for i = 1, #self.CastSequenceBar.squares do
        local square = self.CastSequenceBar.squares[i]
        square:SetSize(squareSize, squareSize)
        if square.activeEntry then
            square:Show()
        else
            square:Hide()
        end
    end

    MainFrame:SetHeight(frameHeight)
    self.CastSequenceBar:ReorderSquares()

    if CastSequenceBarDB.Enabled then
        MainFrame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
        MainFrame:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
        MainFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        MainFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
        MainFrame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED_QUIET", "player")
        MainFrame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
        MainFrame:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", "player")
        MainFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
        MainFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
        MainFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
        MainFrame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
        MainFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", "player")
        MainFrame:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "player")

        MainFrame:SetScript("OnEvent", OnEvent)
        MainFrame:SetScript("OnUpdate", TrackSpellCast)

        MainFrame:Show()
    else
        MainFrame:Hide()
        MainFrame:SetScript("OnEvent", nil)
        MainFrame:SetScript("OnUpdate", nil)
        MainFrame:UnregisterAllEvents()
    end
end

function BCDM:UpdateCastSequenceBarWidth()
    local CastSequenceBarDB = self.db.profile.CastSequenceBar
    local MainFrame = self.CastSequenceBar.MainFrame
    if CastSequenceBarDB.Enabled and CastSequenceBarDB.MatchWidthOfAnchor then
        local anchorFrame = _G[CastSequenceBarDB.Layout[2]]
        if anchorFrame then
            C_Timer.After(0.5, function() local anchorWidth = anchorFrame:GetWidth() MainFrame:SetWidth(anchorWidth) end)
        end
    end
end
