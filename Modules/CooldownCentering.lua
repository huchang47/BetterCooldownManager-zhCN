local _, BCDM = ...

-- 布局引擎函数
local function CenteredRowXOffsets(count, itemWidth, padding, directionModifier)
    -- Why: Produce symmetric X offsets to center a horizontal row.
    -- When: Positioning icons in rows; supports reversed direction via modifier.
    if not count or count <= 0 then
        return {}
    end
    local dir = directionModifier or 1
    local totalWidth = (count * itemWidth) + ((count - 1) * padding)
    local startX = ((-totalWidth / 2 + itemWidth / 2) * dir)
    local offsets = {}
    for i = 1, count do
        offsets[i] = startX + (i - 1) * (itemWidth + padding) * dir
    end
    return offsets
end

local function BuildRows(iconLimit, children)
    -- Why: Group a flat list of icons into rows limited by `iconLimit`.
    -- When: Before computing centered layout for Essential/Utility viewers.
    local rows = {}
    local limit = iconLimit or 0
    if limit <= 0 then
        return rows
    end
    for i = 1, #children do
        local rowIndex = math.floor((i - 1) / limit) + 1
        rows[rowIndex] = rows[rowIndex] or {}
        rows[rowIndex][#rows[rowIndex] + 1] = children[i]
    end
    return rows
end

local function CollectViewerChildren(viewer)
    -- Why: Standardized filtered list of visible icon-like children sorted by layoutIndex.
    -- When: Building rows/columns for Essential/Utility centered layouts.
    local all = {}
    for _, child in ipairs({ viewer:GetChildren() }) do
        if child and child:IsShown() and child.Icon then
            all[#all + 1] = child
        end
    end
    table.sort(all, function(a, b)
        return (a.layoutIndex or 0) < (b.layoutIndex or 0)
    end)
    return all
end

local function PositionRowHorizontal(viewer, row, yOffset, w, padding, iconDirectionModifier, rowAnchor)
    -- Why: Place a single horizontal row centered with optional reversed direction and stack visuals.
    -- When: Essential/Utility viewers are horizontal or configured to grow by rows.
    local count = #row
    local xOffsets = CenteredRowXOffsets(count, w, padding, iconDirectionModifier)
    for i, icon in ipairs(row) do
        local x = xOffsets[i] or 0

        icon:ClearAllPoints()
        icon:SetPoint(rowAnchor, viewer, rowAnchor, x, yOffset)
    end
end

local function CenterAllRowsForViewer(viewer, fromDirection, iconLimit)
    -- Why: Core centering routine that groups children into rows/columns and applies offsets.
    -- When: `UpdateViewerLayout` determines centering is enabled and changes require recompute.
    
    local children = CollectViewerChildren(viewer)

    local first = children[1]
    if not first then
        return
    end
    local w, h = first:GetWidth(), first:GetHeight()
    if not w or w == 0 or not h or h == 0 then
        return
    end

    -- 保持与原始代码一致的默认值设置
    local isHorizontal = viewer.isHorizontal ~= false
    
    local iconDirection = viewer.iconDirection == 1 and "NORMAL" or "REVERSED"
    local iconDirectionModifier = iconDirection == "NORMAL" and 1 or -1
    local padding = isHorizontal and viewer.childXPadding or viewer.childYPadding
    
    -- 优先使用传入的iconLimit，如果为0或nil，则尝试使用viewer的iconLimit属性，默认为20
    local effectiveIconLimit = iconLimit and iconLimit > 0 and iconLimit or viewer.iconLimit or 20
    
    if effectiveIconLimit <= 0 then
        -- Fallback to old centering method if no iconLimit is set
        local visibleCount = #children
        if visibleCount == 0 then return end
        
        local totalWidth = (visibleCount * w) + ((visibleCount - 1) * padding)
        local startX = -totalWidth / 2 + w / 2

        for index, iconFrame in ipairs(children) do
            iconFrame:ClearAllPoints()
            iconFrame:SetPoint("CENTER", viewer, "CENTER", startX + (index - 1) * (w + padding), 0)
        end
        
        return
    end

    local rows = BuildRows(effectiveIconLimit, children)
    if #rows == 0 then
        return
    end

    -- 为 Buff 查看器特殊处理，确保水平居中
    if viewer == _G["BuffIconCooldownViewer"] then
        -- 强制使用水平布局
        local growDirection = BCDM.db.profile.CooldownManager.Buffs.GrowDirection or "TOP"
        
        local rowOffsetModifier = growDirection == "BOTTOM" and 1 or -1
        local rowAnchor = (growDirection == "BOTTOM") and "BOTTOM" or "TOP"
        
        -- 为 Buff 查看器设置更小的 iconLimit，确保图标排列成多行
        local buffIconLimit = 10  -- 每行最多10个图标
        local buffRows = BuildRows(buffIconLimit, children)
        
        for iRow, row in ipairs(buffRows) do
            local yOffset = (iRow - 1) * (h + padding) * rowOffsetModifier
            PositionRowHorizontal(viewer, row, yOffset, w, padding, iconDirectionModifier, rowAnchor)
        end
    elseif isHorizontal then
        -- 其他查看器的水平布局处理
        local growDirection = "TOP"  -- Default
        if viewer == _G["EssentialCooldownViewer"] then
            growDirection = BCDM.db.profile.CooldownManager.Essential.GrowDirection or "TOP"
        elseif viewer == _G["UtilityCooldownViewer"] then
            growDirection = BCDM.db.profile.CooldownManager.Utility.GrowDirection or "TOP"
        end
        
        local rowOffsetModifier = growDirection == "BOTTOM" and 1 or -1
        local rowAnchor = (growDirection == "BOTTOM") and "BOTTOM" or "TOP"
        for iRow, row in ipairs(rows) do
            local yOffset = (iRow - 1) * (h + padding) * rowOffsetModifier
            PositionRowHorizontal(viewer, row, yOffset, w, padding, iconDirectionModifier, rowAnchor)
        end
    end
end

-- 保存函数到BCDM命名空间，以便其他模块可以访问
BCDM.CooldownCentering = {
    CenterAllRowsForViewer = CenterAllRowsForViewer,
    CollectViewerChildren = CollectViewerChildren,
    BuildRows = BuildRows,
    CenteredRowXOffsets = CenteredRowXOffsets,
}

-- 用于外部调用的便捷函数
function BCDM:ApplyCenteringToViewer(viewerType)
    local viewerFrame = _G[BCDM.DBViewerToCooldownManagerViewer[viewerType]]
    if not viewerFrame then return end
    
    local settings = BCDM.db.profile.CooldownManager[viewerType]
    if settings and settings.CenterBuffs or settings.CenterUtility or (viewerType == "Essential" and settings.CenterEssential) then
        local iconLimit = settings.IconLimitPerRow or viewerFrame.iconLimit or 20
        CenterAllRowsForViewer(viewerFrame, "CENTER", iconLimit)
    end
end