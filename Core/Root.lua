local Root = {}
Root.__index = Root

local Hooks = require("/PawUI/Core/Hooks")
local Renderer = require("/PawUI/Core/Renderer")

function Root.new(target)
    return setmetatable({
        Target = target,
        Running = false,
        Dirty = true,
        Element = nil,
        onEvent = nil,
        onExternalEvent = nil,
        EventHandlers = {},
        HitTargets = {},
        HookInstances = {},
        PendingEffects = {},
        SeenHookInstances = {},
        TimerCallbacks = {},
        Hooks = Hooks
    }, Root)
end

function Root:Mount(element)
    assert(type(element) == "table" and element._PawUIElement, "Mount expects a PawUI element")
    self.Element = element
    self.Dirty = true
    return element
end

local function findByName(element, name)
    if element.Name == name then
        return element
    end

    for _, child in ipairs(element.Children or {}) do
        local found = findByName(child, name)
        if found then
            return found
        end
    end

    return nil
end

function Root:getElement(path)
    assert(self.Element, "No element has been mounted")

    if type(path) == "table" then
        local current = self.Element
        for _, name in ipairs(path) do
            local found
            for _, child in ipairs(current.Children or {}) do
                if child.Name == name then
                    found = child
                    break
                end
            end
            current = found
            if not current then return nil end
        end
        return current
    end

    assert(type(path) == "string", "Element path must be a string or table")

    local current = self.Element
    local first = true
    for name in path:gmatch("[^/]+") do
        if first and current.Name == name then
            first = false
        else
            first = false
            local found
            for _, child in ipairs(current.Children or {}) do
                if child.Name == name then
                    found = child
                    break
                end
            end
            current = found
            if not current then
                return findByName(self.Element, path)
            end
        end
    end

    return current
end

function Root:setTimeout(callback, seconds)
    assert(type(callback) == "function", "Timer callback must be a function")
    local timerId = os.startTimer(seconds)
    self.TimerCallbacks[timerId] = callback
    return timerId
end

function Root:clearTimeout(timerId)
    if self.TimerCallbacks[timerId] then
        self.TimerCallbacks[timerId] = nil
        pcall(os.cancelTimer, timerId)
    end
end

function Root:HandleEvent(event, ...)
    local handler = self.EventHandlers[event]
    if handler and handler(self, ...) == true then
        return true
    end

    if event == "mouse_click" then
        local _, x, y = ...
        local element = Renderer.hitTest(self, x, y)

        if element and type(element.OnClick) == "function" then
            element.OnClick()
            self.Dirty = true
            return true
        end
    elseif event == "timer" then
        local timerId = ...
        local callback = self.TimerCallbacks[timerId]
        if callback then
            self.TimerCallbacks[timerId] = nil
            callback()
            self.Dirty = true
            return true
        end
    elseif event == "term_resize" or event == "monitor_resize" then
        self.Dirty = true
    end

    return false
end

function Root:Start()
    assert(not self.Running, "Root is already running")
    assert(self.Element, "Mount an element before starting")

    self.Running = true
    self.Dirty = true

    while self.Running do
        if self.Dirty then
            Renderer.render(self)
        end

        local event = { os.pullEventRaw() }
        local eventName = table.remove(event, 1)
        local consumed = self:HandleEvent(eventName, table.unpack(event))

        if self.onEvent then
            self.onEvent(eventName, table.unpack(event))
        end

        if not consumed and self.onExternalEvent then
            self.onExternalEvent(eventName, table.unpack(event))
        end

        if eventName == "terminate" then
            self.Running = false
        end
    end
end

function Root:Stop()
    self.Running = false
end

function Root:Render()
    Renderer.render(self)
end

function Root:Destroy()
    self:Stop()
    for _, instance in pairs(self.HookInstances) do
        Hooks.cleanup(instance)
    end
    self.HookInstances = {}
    self.Element = nil
end

return Root