local log = require("vim-deathmatch.print")
local BufferM = require("vim-deathmatch.buffer")
local Buffer = BufferM.Buffer

local states = {
    waitingToStart = 1,
    editing = 2,
    waitingForResults = 3,
}

local Game = {}
local I_AM_SORRY_SOME_CODING_GUY_PLEASE_FORGIVE_ME = "[^%s]+"

local function getTime()
    return vim.fn.reltimefloat(vim.fn.reltime())
end

local function tokenize(str)
    if type(str) == "table" then
        str = table.concat(str, "\n")
    end

    local bucket = {}
    for token in string.gmatch(str, I_AM_SORRY_SOME_CODING_GUY_PLEASE_FORGIVE_ME) do
        table.insert(bucket, token)
    end

    return bucket
end

function Game:new(channel)
    local gameConfig = {
        channel = channel,
        winId = nil,
        buffer = nil,
        bufh = nil,
    }

    self.__index = self

    local game = setmetatable(gameConfig, self)
    game:_createOrResizeWindow()
    game.buffer:setEditable(false)

    return game
end

function Game:start()
    log.info("Game:start")
    self.channel:setCallback(function(msgType, msg)
        log.info("Game:start#setCallback", msgType, msg)
        self:_onMessage(msgType, msg)
    end)
    self.channel:send("ready")

    self.state = states.waitingToStart
    self.buffer:write(1, "Waiting for server response...")
    self.buffer:setEditable(false)
end

function Game:hasWindowId(winId)
    return self.buffer:hasWindowId(winId)
end

function Game:onWinClose(winId)
    self.buffer:destroy(winId)
end

function Game:_onMessage(msgType, data)
    local msg = vim.fn.json_decode(data)

    log.info("Game:_onMessage", msgType, data)

    self.buffer:setEditable(true)
    self.buffer:clear()

    self.left = msg.left
    self.right = msg.right
    self.buffer:write(1, self.left)
    self.buffer:write(2, self.right)
    self.buffer:setEditable(msg.editable)

    if msgType == "waiting" then
        self.state = states.waitingToStart
    elseif msgType == "start-game" then
        self.state = states.editing
        self.right = tokenize(self.right)
        self.buffer:setFiletype(msg.filetype or "javascript")

    elseif msgType == "finished" then
        self.state = states.waitingForResults
    end

end

function Game:resize()
    self:_createOrResizeWindow()
end

function Game:onBufferUpdate(id, ...)
    log.info("Game:on_buffer_update", id, self.state, not self.buffer.editable)
    if not self.buffer.editable then
        return
    end

    if self.state ~= states.editing then
        return
    end

    local gameText = tokenize(self.buffer:getBufferContents(1))
    local idx = 1
    if #gameText ~= #self.right then
        log.info("Game:on_buffer_update#return", #gameText, #self.right)
        return
    end
    log.info("Game:on_buffer_update gameText", vim.inspect(gameText))
    log.info("Game:on_buffer_update expectedText", vim.inspect(self.right))

    local matched = true
    while matched and idx <= #gameText do
        matched = matched and gameText[idx] == self.right[idx]
        idx = idx + 1
    end

    log.info("Game:on_buffer_update", matched, self.keysPressed, "----", gameText)
    if matched then
        local msg = vim.fn.json_encode({
            undoCount = 0,
            keys = self.keysPressed
        })
        self.channel:send("finished", msg)
    end
end

function Game:_createOrResizeWindow()
    self.keysPressed = {}

    if not self.buffer then
        self.buffer = Buffer:new(function(idx)
            self:onBufferUpdate(idx)
        end, function(keyCodePressed)

            if self.state == states.editing then
                table.insert(self.keysPressed, keyCodePressed)
            end

            if self.state == states.ended then
                return false
            end
        end)
    end

    self.buffer:createOrResize({
        count = 2,
        padding = 2,
    })
end

function Game:focus()
    self.buffer:focus(1)
end

return Game

