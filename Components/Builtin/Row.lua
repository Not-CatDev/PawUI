local Component = require("/PawUI/Core/Component")

local Row = {}

function Row.new(props)
    return Component.create("Frame", {
        Name = "Row",
        Layout = "Horizontal"
    }, props)
end

return Row