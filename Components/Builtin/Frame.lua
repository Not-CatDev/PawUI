local Component = require("/PawUI/Core/Component")

local Frame = {}

function Frame.new(props)
    return Component.create("Frame", {
        BackgroundVisible = false
    }, props)
end

return Frame