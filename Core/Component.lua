local Component = {}

local function copyTable(source)
    local result = {}

    for key, value in pairs(source or {}) do
        result[key] = value
    end

    return result
end

function Component.create(componentType, defaults, props)
    props = props or {}

    assert(type(props) == "table", "Component properties must be a table")

    local element = copyTable(defaults)

    for key, value in pairs(props) do
        element[key] = value
    end

    element.Type = componentType
    element.Name = element.Name or componentType
    element.Visible = element.Visible ~= false
    element.Position = element.Position or {
        X = { Scale = 0, Offset = 0 },
        Y = { Scale = 0, Offset = 0 }
    }
    element.Size = element.Size or {
        X = { Scale = 0, Offset = 0 },
        Y = { Scale = 0, Offset = 0 }
    }
    element.Children = element.Children or {}

    element._PawUIElement = true

    assert(type(element.Children) == "table", "Children must be a table")

    for _, child in ipairs(element.Children) do
        assert(
            type(child) == "table" and child._PawUIElement,
            "Children must contain PawUI elements"
        )
    end

    return element
end

return Component