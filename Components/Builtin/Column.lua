local Component = require("/PawUI/Core/Component")

local Column = {}

function Column.new(props)
    return Component.create("Frame", {
        Name = "Column",
        Layout = "Vertical"
    }, props)
end

return Column