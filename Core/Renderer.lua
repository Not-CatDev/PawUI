local Drawing = require("/PawUI/Core/Drawing")

local Renderer = {}

local function axisValue(axis, parentSize)
    axis = axis or {}
    return math.floor((axis.Scale or 0) * parentSize + (axis.Offset or 0) + 0.5)
end

local function anchorValue(anchor, size, axisName)
    if type(anchor) ~= "table" then
        return 0
    end

    local value = anchor[axisName]
    if type(value) == "table" then
        return axisValue(value, size)
    end

    return math.floor((value or 0) * size + 0.5)
end

local function intersect(a, b)
    local left = math.max(a.X, b.X)
    local top = math.max(a.Y, b.Y)
    local right = math.min(a.X + a.Width, b.X + b.Width)
    local bottom = math.min(a.Y + a.Height, b.Y + b.Height)

    return {
        X = left,
        Y = top,
        Width = math.max(0, right - left),
        Height = math.max(0, bottom - top)
    }
end

local function resolveRect(element, parentRect, positionOverride, sizeOverride)
    local position = positionOverride or element.Position or {}
    local size = sizeOverride or element.Size or {}

    local width = math.max(0, axisValue(size.X, parentRect.Width))
    local height = math.max(0, axisValue(size.Y, parentRect.Height))

    local x = parentRect.X + axisValue(position.X, parentRect.Width)
    local y = parentRect.Y + axisValue(position.Y, parentRect.Height)

    x = x - anchorValue(element.AnchorPoint, width, "X")
    y = y - anchorValue(element.AnchorPoint, height, "Y")

    return { X = x, Y = y, Width = width, Height = height }
end

local function halfCell(root, target, x, logicalY, color)
    local physicalY = math.floor((logicalY - 1) / 2) + 1
    local key = x .. ":" .. physicalY
    local cell = root.HalfPixels[key]

    if not cell then
        cell = { Top = colors.black, Bottom = colors.black }
        root.HalfPixels[key] = cell
    end

    if logicalY % 2 == 1 then
        cell.Top = color
    else
        cell.Bottom = color
    end

    Drawing.drawHalf(target, x, physicalY, cell.Top, cell.Bottom)
end

local function fillRect(root, target, element, rect, clip, color, halfMode)
    local visible = intersect(rect, clip)
    if visible.Width <= 0 or visible.Height <= 0 then
        return
    end

    if halfMode then
        for y = visible.Y, visible.Y + visible.Height - 1 do
            for x = visible.X, visible.X + visible.Width - 1 do
                halfCell(root, target, x, y, color)
            end
        end
    else
        Drawing.fill(target, visible.X, visible.Y, visible.Width, visible.Height, color)
    end
end

local function drawText(target, element, rect, clip, halfMode, inheritedBackground)
    local text = tostring(element.Text or "")
    local textColor = element.TextColor or colors.white
    local backgroundColor = element.BackgroundVisible and (element.BackgroundColor or colors.black) or inheritedBackground
    local lineNumber = 0

    for line in (text .. "\n"):gmatch("(.-)\n") do
        local logicalY = rect.Y + lineNumber * (halfMode and 2 or 1)
        local physicalY = halfMode and (math.floor((logicalY - 1) / 2) + 1) or logicalY

        if physicalY >= (halfMode and (math.floor((clip.Y - 1) / 2) + 1) or clip.Y)
            and physicalY < (halfMode and (math.ceil((clip.Y + clip.Height - 1) / 2) + 1) or (clip.Y + clip.Height)) then
            local startX = math.max(rect.X, clip.X)
            local endX = math.min(rect.X + rect.Width, clip.X + clip.Width)
            local leftTrim = math.max(0, startX - rect.X)
            local rightLimit = math.max(0, endX - rect.X)
            local visibleText = line:sub(leftTrim + 1, rightLimit)

            if #visibleText > 0 then
                Drawing.write(target, startX, physicalY, visibleText, textColor, backgroundColor)
            end
        end

        lineNumber = lineNumber + 1
    end
end

local function drawElement(root, target, element, rect, clip, halfMode, inheritedBackground)
    local background = inheritedBackground

    if element.BackgroundVisible then
        background = element.BackgroundColor or colors.black
        fillRect(root, target, element, rect, clip, background, halfMode)
    end

    if element.Type == "Text" then
        drawText(target, element, rect, clip, halfMode, background)
    end

    return background
end

local function addHitTarget(root, element, rect, clip, halfMode)
    if type(element.OnClick) ~= "function" then
        return
    end

    local visible = intersect(rect, clip)
    if visible.Width > 0 and visible.Height > 0 then
        table.insert(root.HitTargets, {
            Element = element,
            Rect = visible,
            HalfMode = halfMode
        })
    end
end

local function invokeCustom(root, element, path)
    root.SeenHookInstances[path] = true
    root.Hooks.begin(root, path)

    local ok, result = pcall(element.Component, element.Props or {})
    root.Hooks.finish()

    if not ok then
        error("PawUI custom component '" .. tostring(element.Name) .. "' failed: " .. tostring(result), 0)
    end

    assert(type(result) == "table" and result._PawUIElement,
        "Custom component '" .. tostring(element.Name) .. "' must return a PawUI element")

    if element.ExplicitPosition then result.Position = element.Position end
    if element.ExplicitSize then result.Size = element.Size end
    if element.ExplicitAnchorPoint then result.AnchorPoint = element.AnchorPoint end
    if element.Visible == false then result.Visible = false end

    return result
end

local function renderNode(root, target, element, parentRect, parentClip, path, halfMode, positionOverride, inheritedBackground)
    if not element or element.Visible == false then
        return nil
    end

    if element.Type == "Function" then
        local rendered = invokeCustom(root, element, path)
        return renderNode(root, target, rendered, parentRect, parentClip,
            path .. "/$component", halfMode, positionOverride, inheritedBackground)
    end

    local rect = resolveRect(element, parentRect, positionOverride)
    local clip = intersect(rect, parentClip)

    if clip.Width <= 0 or clip.Height <= 0 then
        return rect
    end

    local background = drawElement(root, target, element, rect, clip, halfMode, inheritedBackground)
    addHitTarget(root, element, rect, clip, halfMode)

    local layout = element.Layout
    local cursor = 0

    for index, child in ipairs(element.Children or {}) do
        local childPosition = child.Position or {}
        local childOverride = {
            X = {
                Scale = (childPosition.X and childPosition.X.Scale) or 0,
                Offset = (childPosition.X and childPosition.X.Offset) or 0
            },
            Y = {
                Scale = (childPosition.Y and childPosition.Y.Scale) or 0,
                Offset = (childPosition.Y and childPosition.Y.Offset) or 0
            }
        }

        if layout == "Horizontal" then
            childOverride.X.Offset = childOverride.X.Offset + cursor
        elseif layout == "Vertical" then
            childOverride.Y.Offset = childOverride.Y.Offset + cursor
        end

        local childKey = child.Key ~= nil and tostring(child.Key) or tostring(index)
        local childPath = path .. "/" .. childKey .. ":" .. tostring(child.Name or child.Type)
        local childRect = renderNode(root, target, child, rect, clip,
            childPath, halfMode, childOverride, background)

        if childRect then
            if layout == "Horizontal" then
                cursor = cursor + childRect.Width
            elseif layout == "Vertical" then
                cursor = cursor + childRect.Height
            end
        end
    end

    return rect
end

function Renderer.render(root)
    local target = root.Target
    local width, physicalHeight = target.getSize()
    local halfMode = root.Element and root.Element.UseHalfCharacters == true or false
    local logicalHeight = halfMode and physicalHeight * 2 or physicalHeight

    target.setBackgroundColor(colors.black)
    target.setTextColor(colors.white)
    target.clear()

    root.HitTargets = {}
    root.SeenHookInstances = {}
    root.HalfPixels = {}
    root.HalfMode = halfMode

    local bounds = { X = 1, Y = 1, Width = width, Height = logicalHeight }

    if root.Element then
        renderNode(root, target, root.Element, bounds, bounds,
            tostring(root.Element.Name or "Root"), halfMode, nil, colors.black)
    end

    for key, instance in pairs(root.HookInstances) do
        if not root.SeenHookInstances[key] then
            root.Hooks.cleanup(instance)
            root.HookInstances[key] = nil
        end
    end

    local effects = root.PendingEffects
    root.PendingEffects = {}
    root.Dirty = false

    for _, effect in ipairs(effects) do
        if effect.Slot.Cleanup then
            pcall(effect.Slot.Cleanup)
            effect.Slot.Cleanup = nil
        end

        local ok, cleanup = pcall(effect.Callback)
        if ok and type(cleanup) == "function" then
            effect.Slot.Cleanup = cleanup
        elseif not ok then
            printError("PawUI useEffect: " .. tostring(cleanup))
        end
    end
end

function Renderer.hitTest(root, x, y)
    for index = #root.HitTargets, 1, -1 do
        local target = root.HitTargets[index]
        local rect = target.Rect
        local insideX = x >= rect.X and x < rect.X + rect.Width
        local insideY

        if target.HalfMode then
            local topHalf = (y - 1) * 2 + 1
            local bottomHalf = topHalf + 1
            insideY = (topHalf >= rect.Y and topHalf < rect.Y + rect.Height)
                or (bottomHalf >= rect.Y and bottomHalf < rect.Y + rect.Height)
        else
            insideY = y >= rect.Y and y < rect.Y + rect.Height
        end

        if insideX and insideY then
            return target.Element
        end
    end

    return nil
end

return Renderer