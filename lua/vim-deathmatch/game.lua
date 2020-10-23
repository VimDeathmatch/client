local log = require("vim-deathmatch.print")

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
        bufh = nil,
    }

    self.__index = self

    local game = setmetatable(gameConfig, self)
    game:_createOrResizeWindow()
    game:_setEditable(true)

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
    self:_writeBuffer(self.bufh[1], "Waiting for server response...")
    game:_setEditable(false)
end

function Game:isWindowId(winId)
    return self.winId[1] == winId or self.winId[2] == winId
end

function Game:onWinClose(winId)
    log.info("onWinClose", winId, self.winId[1], self.winId[2])
    if self:isWindowId(winId) then
        vim.api.nvim_win_close(self.winId[1], true)
        vim.api.nvim_win_close(self.winId[2], true)
    end
end

function Game:_onMessage(msgType, data)
    local msg = vim.fn.json_decode(data)

    log.info("Game:_onMessage", msgType, data)

    self:_setEditable(true)
    self:_clearBuffer(self.bufh[1])
    self:_clearBuffer(self.bufh[2])

    self.left = msg.left
    self.right = msg.right

    self:_writeBuffer(self.bufh[1], self.left)
    self:_writeBuffer(self.bufh[2], self.right)
    self:_setEditable(msg.editable)

    if msgType == "waiting" then
        self.state = states.waitingToStart
    elseif msgType == "start-game" then
        self.state = states.editing
        self.right = tokenize(self.right)
    elseif msgType == "finished" then
        self.state = states.waitingForResults
    end

end

function Game:resize()
    self:_createOrResizeWindow()
end

function Game:isRunning()
    return self.bufh ~= nil
end

function Game:on_buffer_update(id, ...)
    log.info("Game:on_buffer_update", id, self.state, not self.editable)
    if not self.editable then
        return
    end

    if self.state ~= states.editing then
        return
    end

    local lineCount = vim.api.nvim_buf_line_count(id)
    local gameText = tokenize(
        vim.api.nvim_buf_get_lines(id, 0, lineCount, false))

    log.info("Game:on_buffer_update lineCount", lineCount, #self.right)
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

function Game:_setEditable(editable)
    self.editable = editable
    if not self.bufh[1] then
        return
    end

    vim.api.nvim_buf_set_option(self.bufh[1], "modifiable", editable)
    vim.api.nvim_buf_set_option(self.bufh[2], "modifiable", editable)
end

function Game:_createOrResizeWindow()
    local w = vim.fn.nvim_win_get_width(0)
    local h = vim.fn.nvim_win_get_height(0)

    local width = math.floor(w / 2) - 2
    local height = h - 2
    local rcConfig1 = { row = 1, col = 1 }

    local rcConfig2 = { row = 1, col = width + 2 }

    local config = {
        style = "minimal",
        relative = "win",
        width = width,
        height = height
    }

    if not self.bufh then
        self.bufh = {vim.fn.nvim_create_buf(false, true),
            vim.fn.nvim_create_buf(false, true)}

        vim.api.nvim_buf_attach(self.bufh[1], false, {
            on_lines=function(...)
                self:on_buffer_update(self.bufh[1], ...)
            end})

        self.keysPressed = {}

        -- TODO: How to measure undos?
        -- I think they are done in buf attach, we should be able to see the
        -- tick count of the current buffer.
        local namespace = vim.fn.nvim_create_namespace("vim-deathmatch")
        vim.register_keystroke_callback(function(keyCodePressed)

            local strCode = string.byte(keyCodePressed, 1)
            if strCode < 32 or strCode >= 128 then
                return
            end

            if self.state == states.editing then
                table.insert(self.keysPressed, keyCodePressed)
            end

            if self.state == states.ended then
                vim.register_keystroke_callback(nil, namespace)
            end
        end, namespace)
    end

    if not self.winId then
        self.winId = {
            vim.api.nvim_open_win(self.bufh[1], true,
                vim.tbl_extend("force", config, rcConfig1)),
            vim.api.nvim_open_win(self.bufh[2],
                false, vim.tbl_extend("force", config, rcConfig2)),
        }
        log.info("Game:_createOrResizeWindow: new windows", vim.inspect(self.winId))
    else
        log.info("Game:_createOrResizeWindow: resizing windows", vim.inspect(rcConfig1))
        vim.api.nvim_win_set_config(
            self.bufh[1], vim.tbl_extend("force", config, rcConfig1))
        vim.api.nvim_win_set_config(
            self.bufh[2], vim.tbl_extend("force", config, rcConfig2))
    end
end

function Game:_writeBuffer(bufh, msg)

    if not self.bufh then
        return
    end

    if msg == nil then
        return
    end

    local editable = self.editable
    self:_setEditable(true)
    log.info("Game:_writeBuffer", #msg, bufh, msg)

    if type(msg) ~= "table" then
        msg = {msg}
    end

    vim.api.nvim_buf_set_lines(bufh, 0, #msg - 1, false, msg)
    self:_setEditable(editable)
end

local function createEmpty(count)
    local lines = {}
    for idx = 1, count, 1 do
        lines[idx] = ""
    end

    return lines
end

function Game:_clearBuffer(bufh)
    local editable = self.editable
    self:_setEditable(true)
    emptyLines = createEmpty(vim.api.nvim_buf_line_count(bufh))
    vim.api.nvim_buf_set_lines(bufh, 1, #emptyLines, false, emptyLines)
    self:_setEditable(editable)
end

return Game

