local Vector2 = {}
Vector2.__index = Vector2

function Vector2.new(x, y)
    return setmetatable({
        X = x or 0,
        Y = y or 0
    }, Vector2)
end

return Vector2