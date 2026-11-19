local Root = require("/PawUI/Core/Root")
local Component = require("/PawUI/Core/Component")
local Hooks = require("/PawUI/Core/Hooks")

local PawUI = {}

PawUI.UDim2 = require("/PawUI/Core/Udim2")
PawUI.Vector2 = require("/PawUI/Core/Vector2")

function PawUI.createRoot(target, config)
    config = config or {}

    if target then
        assert(type(target) == "string", "Target must be a peripheral name")

        local monitor = peripheral.wrap(target)

        assert(monitor, "Could not find monitor: " .. target)

        target = monitor

        if config.TextScale then
            target.setTextScale(config.TextScale)
        end
    else
        target = term.current()
    end

    return Root.new(target)
end

function PawUI.forward(source, root)
    assert(type(source) == "table", "Source must be a table")
    assert(type(root) == "table", "Root must be a table")

    root.onEvent = function(event, ...)
        if source.onEvent then
            source.onEvent(event, ...)
        end
    end

    root.onExternalEvent = function(event, ...)
        if source.onExternalEvent then
            source.onExternalEvent(event, ...)
        end
    end
end

function PawUI.useState(initialValue)
    return Hooks.useState(initialValue)
end

function PawUI.useEffect(callback, dependencies)
    return Hooks.useEffect(callback, dependencies)
end

local componentCache = {}

local function loadComponent(name)
    assert(type(name) == "string" and name:match("^[%w_]+$"), "Invalid component name: " .. tostring(name))

    local customPath = "/PawUI/Components/Custom/" .. name
    local builtinPath = "/PawUI/Components/Builtin/" .. name
    local path

    if fs.exists(customPath) then
        path = customPath
    elseif fs.exists(builtinPath) then
        path = builtinPath
    else
        return nil
    end

    local module = require(path)

    if path == customPath and type(module) == "function" then
        return function(props)
            props = props or {}
            assert(type(props) == "table", "Component properties must be a table")

            return {
                _PawUIElement = true,
                Type = "Function",
                Name = props.Name or name,
                Component = module,
                Props = props,
                Position = props.Position or { X = { Scale = 0, Offset = 0 }, Y = { Scale = 0, Offset = 0 } },
                Size = props.Size or { X = { Scale = 0, Offset = 0 }, Y = { Scale = 0, Offset = 0 } },
                AnchorPoint = props.AnchorPoint,
                Visible = props.Visible ~= false,
                ExplicitPosition = props.Position ~= nil,
                ExplicitSize = props.Size ~= nil,
                ExplicitAnchorPoint = props.AnchorPoint ~= nil,
                Children = {}
            }
        end
    end

    assert(type(module) == "table" and type(module.new) == "function", "Component " .. name .. " must return a table with a .new function")

    return function(props)
        return module.new(props)
    end
end

setmetatable(PawUI, {
    __index = function(_, name)
        local cached = componentCache[name]
        if cached then
            return cached
        end

        local component = loadComponent(name)
        if component then
            componentCache[name] = component
            return component
        end

        return nil
    end
})

return PawUI