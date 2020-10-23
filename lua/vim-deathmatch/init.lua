local Channel = require("vim-deathmatch.channel")
local Game = require("vim-deathmatch.game")
local log = require("vim-deathmatch.print")

channel = channel or nil
game = game or nil

local function onWinClose(winId)
    winId = tonumber(winId)

    if game and game:isWindowId(winId) then
        game:onWinClose(winId)
        channel:onWinClose(winId)
    end
end

local function start()
    channel = Channel:new(function(data)
        print("Data", data)
    end)

    channel:open("45.56.120.121", 42069, vim.schedule_wrap(function(err)
        if err ~= nil then
            print("Could not connect to Vim-Deathmatch's Servers.")
            return
        end

        game = Game:new(channel)
        game:start()
    end))
end

return {
    onWinClose = onWinClose,
    start = start
}

