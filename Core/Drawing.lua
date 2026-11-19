local Drawing = {}

Drawing.HALF_CHARACTER = string.char(131)

function Drawing.drawHalf(target, x, y, topColor, bottomColor)
    target.setCursorPos(x, y)
    target.setTextColor(topColor)
    target.setBackgroundColor(bottomColor)
    target.write(Drawing.HALF_CHARACTER)
end

function Drawing.fill(target, x, y, width, height, color)
    if width <= 0 or height <= 0 then
        return
    end

    target.setBackgroundColor(color)
    local line = string.rep(" ", width)

    for row = 0, height - 1 do
        target.setCursorPos(x, y + row)
        target.write(line)
    end
end

function Drawing.write(target, x, y, value, textColor, backgroundColor)
    if textColor then
        target.setTextColor(textColor)
    end

    if backgroundColor then
        target.setBackgroundColor(backgroundColor)
    end

    target.setCursorPos(x, y)
    target.write(tostring(value or ""))
end

return Drawing