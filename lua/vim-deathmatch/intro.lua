local log = require("vim-deathmatch.print")
local BufferM = require("vim-deathmatch.buffer")
local Buffer = BufferM.Buffer

local Intro = {}

local findGameContents = "1. Find Game"
local statsContent = "2. Stats (Not Available)"
local findGameLine = 9
local statsLine = 10

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
    "Delete the line (dd or Vd) to select the option.",
    "",
    "1. Find Game",
    "2. Stats (Not Available)",
    "",
    "",
    "Powered by Linode. https://linode.com/prime $100 of hosting credit.",
}

local footers = {
    "",
    "",
    "",
    "",
    "",
    "",
    "Sponsored by Beastco.  TJ gave me the answers.  Beginbot has a nice mustache.",
    "OnlyDevs   8 is equivalent to D.",
}

function ltrim(s)
    if not s then
        return ""
    end

    return s:match'^%s*(.*)'
end

function Intro:new(findGame)
    local config = {
        marks = {},
        findGame = findGame,
    }

    self.__index = self
    local intro = setmetatable(config, self)

    intro:createWindow()
    intro:_render()

    return intro
end

function Intro:createWindow()
    if not self.buffer then
        self.buffer = Buffer:new(function(idx)
            self:onBufferUpdate()
        end)
    end

    self.buffer:createOrResize({
        count = 1,
        padding = 7,
    })
    self.buffer:setEditable(true)
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

    self.buffer:clear()

    local dims = self.buffer:getBufferDimensions(1)
    local width = dims.width
    local height = dims.height
    local options = groupCenter(gameOptions, width)
    local vdm = groupCenter(vimDeathMatch, width, vdmLen)
    local footer = groupCenter(footers, width)

    local toRender = {}

    append(toRender, vdm)
    append(toRender, options)
    append(toRender, footer)

    self.rendering = true
    self.buffer:write(1, toRender)
    vim.schedule(function()
        self.rendering = false
    end)
end

function Intro:hasWindowId(winId)
    return self.buffer:hasWindowId(winId)
end

function Intro:resize()
    self:createWindow()
    self:_render()
end

-- TODO: If there is more options added, then its clear, we just simply need to
-- use ext marks, nonmodifiable, and "enter" will select the buffer this means
-- we will have to allow for enter keys to pass through the onKeystrokeCallback
function Intro:_optionSelected()
    local content = self.buffer:getBufferContents(1)
    local findGame = ltrim(content[findGameLine])
    local stats = ltrim(content[statsLine])

    -- TODO: This better...
    if findGame == findGameContents and stats == statsContent then
        return false
    end

    if findGame == findGameContents then
        -- We don't have stats yet
        print("We have not implemented stats yet.")
    end

    local lineBefore = ltrim(content[findGameLine - 1])
    if lineBefore ~= findGameContents and findGame == statsContent then
        self.findGame()
        return true
    end

    return false
end

function Intro:onWinClose(winId)
    self.buffer:destroy()
end

function Intro:onBufferUpdate()
    if self.rendering or self:_optionSelected() then
        return
    end

    vim.schedule(function()
        log.info("Intro:onBufferUpdate#rerender")
        self:_render()
    end)
end

function Intro:focus()
    self.buffer:focus(1)
end

return Intro
