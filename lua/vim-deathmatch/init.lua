local Channel = require("vim-deathmatch.channel")
local Intro = require("vim-deathmatch.intro")
local Game = require("vim-deathmatch.game")
local log = require("vim-deathmatch.print")
local isWindowValid = require("vim-deathmatch.buffer").isWindowValid

local channel = nil
local game = nil
local intro = nil

local function onWinLeave()
    if game then
        game:focus()
    elseif intro then
        intro:focus()
    end
end

local function onResized()
    if game then
        game:resize()
    elseif intro then
        intro:resize()
    end
end

local function onWinClose(winId)
    winId = tonumber(winId)

    if game and game:hasWindowId(winId) then
        game:onWinClose()
        channel:onWinClose(winId)
    elseif intro and intro:hasWindowId(windId) then
        intro:onWinClose()
    end

    game = nil
    channel = nil
    intro = nil
end

local function startGame()
    log.info("init#startGame")
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
    if not isWindowValid() then
        vim.api.nvim_err_write("You need to provide a larger window to play Vim Deathmatch. 80x24 Required\n")
        return
    end

    intro = Intro:new(function()
        vim.schedule(function()
            intro:onWinClose()
            intro = nil
            startGame()
        end)
    end)
end

return {
    onWinClose = onWinClose,
    onWinLeave = onWinLeave,
    onResized = onResized,
    start = start
}

