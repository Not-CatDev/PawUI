local Component = require("/PawUI/Core/Component")
local Text = require("/PawUI/Components/Builtin/Text")
local UDim2 = require("/PawUI/Core/Udim2")

local Button = {}

function Button.new(props)
    props = props or {}

    return Component.create("Frame", {
        Name = "Button",
        BackgroundVisible = true,
        OnClick = props.OnClick,
        Children = {
            Text.new({
                Name = "Label",
                Text = props.Text or "",
                TextColor = props.TextColor,
                Size = UDim2.new(1, 0, 1, 0)
            })
        }
    }, props)
end

return Button