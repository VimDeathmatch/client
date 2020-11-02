local Channel = require("vim-deathmatch.channel")
local Intro = require("vim-deathmatch.intro")
local Game = require("vim-deathmatch.game")
local log = require("vim-deathmatch.print")

local channel = nil
local game = nil

local function onWinLeave()
    if game then
        game:focus()
    end
end

local function onResized()
    if game then
        game:_createOrResizeWindow()
    end
end

local function onWinClose(winId)
    winId = tonumber(winId)

    if game and game:hasWindowId(winId) then
        game:onWinClose()
        channel:onWinClose(winId)
    end

    game = nil
    channel = nil
end

local function startGame()
    channel = Channel:new(function(data)
        print("Data", data)
    end)

    channel:open("deathmatch.theprimeagen.tv", 42069, vim.schedule_wrap(function(err)
        if err ~= nil then
            print("Could not connect to Vim-Deathmatch's Servers.")
            return
        end

        game = Game:new(channel)
        game:start()
    end))
end

local function start()
    local intro = Intro:new()
end

return {
    onWinClose = onWinClose,
    onWinLeave = onWinLeave,
    onResized = onResized,
    start = start
}

