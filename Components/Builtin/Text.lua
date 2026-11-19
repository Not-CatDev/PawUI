local Component = require("/PawUI/Core/Component")

local Text = {}

function Text.new(props)
    return Component.create("Text", {
        Text = "",
        TextColor = colors.white,
        BackgroundVisible = false
    }, props)
end

return Text