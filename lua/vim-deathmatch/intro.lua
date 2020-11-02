local log = require("vim-deathmatch.print")
local Buffer = require("vim-deathmatch.buffer")

local Intro = {}

local vdmLen = 68;
local vimDeathMatch = {
    "╔╗  ╔╗      ╔═══╗         ╔╗ ╔╗           ╔╗     ╔╗       ╔═══╗╔═══╗",
    "║╚╗╔╝║      ╚╗╔╗║        ╔╝╚╗║║          ╔╝╚╗    ║║       ║╔══╝║╔═╗║",
    "╚╗║║╔╝╔╗╔╗╔╗ ║║║║╔══╗╔══╗╚╗╔╝║╚═╗╔╗╔╗╔══╗╚╗╔╝╔══╗║╚═╗     ║╚══╗║╚═╝║",
    " ║╚╝║ ╠╣║╚╝║ ║║║║║╔╗║╚ ╗║ ║║ ║╔╗║║╚╝║╚ ╗║ ║║ ║╔═╝║╔╗║╔═══╗║╔═╗║╚══╗║",
    " ╚╗╔╝ ║║║║║║╔╝╚╝║║║═╣║╚╝╚╗║╚╗║║║║║║║║║╚╝╚╗║╚╗║╚═╗║║║║╚═══╝║╚═╝║╔══╝║",
    "  ╚╝  ╚╝╚╩╩╝╚═══╝╚══╝╚═══╝╚═╝╚╝╚╝╚╩╩╝╚═══╝╚═╝╚══╝╚╝╚╝     ╚═══╝╚═══╝",
}

local gameOptions = {
    "1. Find Game",
    "2. Stats (Not Available)",
    "3. Powered by Linode",
}

local footers = {
    "1. Find Game",
    "2. Stats (Not Available)",
    "3. Powered by Linode",
}

function Intro:new()
    local config = {
        buffer = Buffer:new(function(idx)
            self:onBufferUpdate()
        end)
    }

    self.__index = self
    local intro = setmetatable(config, self)

    intro.buffer:createOrResize({
        count = 1,
        padding = 7,
    })
    intro:_render()

    return intro
end

function append(t1, t2)
    if type(t2) == "string" then
        table.insert(t1, t2)
        return t1
    end

    for _,v in ipairs(t2) do
        table.insert(t1, v)
    end

    return t1
end

function groupCenter(lines, width, forceLongest)
    local longestLine = forceLongest or 0

    if longestLine == 0 then
        for idx = 1, #lines do
            local line = lines[idx]
            if longestLine < #line then
                print("groupCenter#SetLongest", longestLine, #line, line)
                longestLine = #lines[idx]
            end
        end
    end

    local padding = string.rep(" ", math.floor((width - longestLine) / 2))
    local adjustedLines = {}
    for idx = 1, #lines do
        table.insert(adjustedLines, padding .. lines[idx])
    end

    return adjustedLines
end

function Intro:_render()
    local dims = self.buffer:getBufferDimensions(1)
    local width = dims.width
    local height = dims.height

    self.buffer:clear()
    local options = groupCenter(gameOptions, width)
    local vdm = groupCenter(vimDeathMatch, width, vdmLen)

    local toRender = {}

    append(toRender, vdm)
    append(toRender, options)

    self.buffer:write(1, toRender)
end

function Intro:onBufferUpdate()
end

return Intro


