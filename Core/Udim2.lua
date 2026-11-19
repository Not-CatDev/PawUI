local UDim2 = {}
UDim2.__index = UDim2

function UDim2.new(xScale, xOffset, yScale, yOffset)
    return setmetatable({
        X = {
            Scale = xScale or 0,
            Offset = xOffset or 0
        },
        Y = {
            Scale = yScale or 0,
            Offset = yOffset or 0
        }
    }, UDim2)
end

function UDim2.__add(a, b)
    return UDim2.new(
        a.X.Scale + b.X.Scale,
        a.X.Offset + b.X.Offset,
        a.Y.Scale + b.Y.Scale,
        a.Y.Offset + b.Y.Offset
    )
end

function UDim2.__sub(a, b)
    return UDim2.new(
        a.X.Scale - b.X.Scale,
        a.X.Offset - b.X.Offset,
        a.Y.Scale - b.Y.Scale,
        a.Y.Offset - b.Y.Offset
    )
end

return UDim2