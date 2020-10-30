local log = require("vim-deathmatch.print")
local Buffer = require("vim-deathmatch.buffer")

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
    self.buffer:write(1, "Waiting for server response...")
    self.buffer:setEditable(false)
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

function Game:isRunning()
    return self.bufh ~= nil
end

function Game:on_buffer_update(id, ...)
    log.info("Game:on_buffer_update", id, self.state, not self.buffer.editable)
    if not self.buffer.editable then
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
    self.buffer:setEditable(editable)
end

function Game:_createOrResizeWindow()

    local vimStats = vim.api.nvim_list_uis()[1]
    local w = vimStats.width
    local h = vimStats.height

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
            self.winId[1], vim.tbl_extend("force", config, rcConfig1))
        vim.api.nvim_win_set_config(
            self.winId[2], vim.tbl_extend("force", config, rcConfig2))
    end

    if not self.buffer then
        self.buffer = Buffer:new(self.winId, self.bufh)
    end
end

function Game:focus()
    vim.schedule(function()
        if self.winId and vim.api.nvim_win_is_valid(self.winId[1]) then
            vim.api.nvim_set_current_win(self.winId[1])
        end
    end)
end

return Game

