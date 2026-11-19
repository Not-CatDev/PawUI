local Hooks = {}

local activeRoot
local activeInstance

local function copyDependencies(dependencies)
    if dependencies == nil then
        return nil
    end

    local copy = {}
    for index, value in ipairs(dependencies) do
        copy[index] = value
    end
    return copy
end

local function dependenciesChanged(previous, current)
    if previous == nil or current == nil then
        return true
    end

    if #previous ~= #current then
        return true
    end

    for index, value in ipairs(current) do
        if previous[index] ~= value then
            return true
        end
    end

    return false
end

function Hooks.begin(root, instanceKey)
    activeRoot = root
    activeInstance = root.HookInstances[instanceKey]

    if not activeInstance then
        activeInstance = {
            Slots = {},
            HookCount = 0,
            Key = instanceKey
        }
        root.HookInstances[instanceKey] = activeInstance
    end

    activeInstance.HookCount = 0
end

function Hooks.finish()
    activeRoot = nil
    activeInstance = nil
end

local function getSlot()
    assert(activeRoot and activeInstance, "Hooks can only be called while rendering a custom component")

    activeInstance.HookCount = activeInstance.HookCount + 1
    local index = activeInstance.HookCount

    if not activeInstance.Slots[index] then
        activeInstance.Slots[index] = {}
    end

    return activeInstance.Slots[index], activeRoot
end

function Hooks.useState(initialValue)
    local slot, root = getSlot()

    if not slot.Initialized then
        slot.Value = initialValue
        slot.Initialized = true
    end

    local function setValue(nextValue)
        if type(nextValue) == "function" then
            nextValue = nextValue(slot.Value)
        end

        if slot.Value ~= nextValue then
            slot.Value = nextValue
            root.Dirty = true
        end
    end

    return slot.Value, setValue
end

function Hooks.useEffect(callback, dependencies)
    assert(type(callback) == "function", "useEffect expects a callback function")
    assert(dependencies == nil or type(dependencies) == "table", "useEffect dependencies must be a table or nil")

    local slot, root = getSlot()

    if not slot.EffectInitialized or dependenciesChanged(slot.Dependencies, dependencies) then
        slot.EffectInitialized = true
        slot.Dependencies = copyDependencies(dependencies)

        table.insert(root.PendingEffects, {
            Slot = slot,
            Callback = callback
        })
    end
end

function Hooks.cleanup(instance)
    for _, slot in pairs(instance.Slots) do
        if slot.Cleanup then
            pcall(slot.Cleanup)
            slot.Cleanup = nil
        end
    end
end

return Hooks