local log = require("vim-deathmatch.print")

local Buffer = {}
local REQUIRED_WIDTH = 80
local REQUIRED_HEIGHT = 24
local ns = vim.api.nvim_create_namespace("vdm-buffer")

local modes = {
    auto = 1,
    predefined = 2,
}

local function createEmpty(count)
    local lines = {}
    for idx = 1, count, 1 do
        lines[idx] = ""
    end

    return lines
end

local function getOtherIdx(idx)
    return idx == 1 and 2 or 1
end

local function getWidth(w, config, idx)
    local computedW = w - 2 * config.padding
    if config.count == 1 then
        return computedW
    end

    computedW = computedW - 1

    local mode = modes.auto
    for i = 1, #config.dim do
        if config.dim[i] and config.dim[i].width ~= nil then
            mode = modes.predefined
        end
    end

    if mode == modes.auto then
        return math.floor(computedW / config.count)
    end

    local dim = config.dim[idx] or {}
    return dim.width or (computedW - config.dim[getOtherIdx(idx)].width)
end

function Buffer:new(onBufferUpdate, onKeystroke)
    local config = {
        onBufferUpdate = onBufferUpdate,
        onKeystroke = onKeystroke,
        marks = {},
        bufh = {},
        winId = {},
    }

    self.__index = self
    return setmetatable(config, self)
end

function Buffer:getBufferDimensions(idx)
    local vimStats = vim.api.nvim_list_uis()[1]
    local w = vimStats.width

    return {
        width = getWidth(w, self.lastWindowConfig, idx),
        height = vimStats.height - self.lastWindowConfig.padding * 2,
    }
end

function Buffer:focus(idx)
    vim.schedule(function()
        if self.winId and vim.api.nvim_win_is_valid(self.winId[1]) then
            vim.api.nvim_set_current_win(self.winId[1])
        end
    end)
end

function Buffer:_attachListeners(bufh, idx)
    -- TODO: How to measure undos?
    -- I think they are done in buf attach, we should be able to see the
    -- tick count of the current buffer.
    local namespace = vim.fn.nvim_create_namespace("vim-deathmatch")
    vim.register_keystroke_callback(function(keyCodePressed)
        local strCode = string.byte(keyCodePressed, 1)
        if strCode < 32 or strCode >= 128 then
            return
        end

        if self.onKeyStroke and self.onKeystroke(keyCodePressed) == false then
            vim.register_keystroke_callback(nil, namespace)
        end
    end, namespace)

    vim.api.nvim_buf_attach(bufh, false, {
        on_lines=function(...)
            if self.onBufferUpdate then
                self.onBufferUpdate(idx, ...)
            end
        end
    })

end

function getConfig(w, h, idx, config)
    local outConfig = {
        style = "minimal",
        relative = "win",
        width = getWidth(w, config, idx),
        height = h - config.padding * 2,
        row = config.padding,
        col = idx == 1 and config.padding or (getWidth(w, config, getOtherIdx(idx)) + 1 + config.padding),
    }
    return outConfig
end

--[[
--{
--  count: number,
--  padding: number,
--  dim: [{
--    width: undefined, number
--    height: undefined, number
--  }]
--}
--]]
function Buffer:createOrResize(windowConfig)
    if self.bufh and #self.bufh ~= count then
        self:destroy()
    end

    if not windowConfig["dim"] then
        windowConfig["dim"] = {}
    end

    self.lastWindowConfig = windowConfig

    local vimStats = vim.api.nvim_list_uis()[1]
    local w = vimStats.width
    local h = vimStats.height

    for idx = 1, windowConfig.count do
        local config = getConfig(w, h, idx, windowConfig)

        if #self.bufh < windowConfig.count then
            table.insert(self.bufh, vim.fn.nvim_create_buf(false, true))
            table.insert(self.marks, {})

            if idx == 1 then
                self:_attachListeners(self.bufh[1], 1)
            end
        end

        if #self.winId < windowConfig.count then
            log.info("Buffer:createWindow ", idx, vim.inspect(config))
            table.insert(self.winId, vim.api.nvim_open_win(self.bufh[idx], idx == 1, config))
        else
            log.info("Buffer:resizeWindow ", idx, vim.inspect(config))
            vim.api.nvim_win_set_config(self.winId[idx], config)
        end
    end
end

function Buffer:setFiletype(filetype)
    for idx = 1, #self.bufh do
        vim.api.nvim_buf_set_option(self.bufh[idx], "filetype", filetype)
    end
end

function Buffer:setEditable(editable)
    self.editable = editable
    for idx = 1, #self.bufh do
        vim.api.nvim_buf_set_option(self.bufh[idx], "modifiable", editable)
    end
end

function Buffer:_modifyBuffer(cb)
    local editable = self.editable or false
    self:setEditable(true)
    ok, msg = pcall(cb)

    if not ok then
        log.error("Buffer#_modifyBuffer", msg)
    end

    self:setEditable(editable)
end

function Buffer:write(idx, msg)

    if msg == nil then
        return
    end

    if type(msg) ~= "table" then
        msg = {msg}
    end

    self:_modifyBuffer(function()
        vim.api.nvim_buf_set_lines(self.bufh[idx], 0, #msg - 1, false, msg)
    end)
end

function Buffer:clear()
    for idx = 1, #self.bufh do
        local bufh = self.bufh[idx]
        self:_modifyBuffer(function()
            vim.api.nvim_buf_set_lines(bufh, 0, -1, false, {})
        end)
    end
end
function Buffer:hasWindowId(winId)
    local found = false
    for idx = 1, #self.winId do
        found = found or self.winId[idx] == winId
    end
    return found
end

function Buffer:destroy()
    log.info("onWinClose", vim.inspect(self.winId), vim.inspect(self.bufh))

    local namespace = vim.fn.nvim_create_namespace("vim-deathmatch")
    vim.register_keystroke_callback(nil, namespace)

    for idx = 1, #self.winId do
        local wId = self.winId[idx]
        if vim.api.nvim_win_is_valid(wId) then
            vim.api.nvim_win_close(wId, true)
        end
    end

    for idx = 1, #self.bufh do
        if self.bufh[idx] ~= nil then
            vim.api.nvim_buf_delete(self.bufh[idx], {force = true})
        end
    end

    self.bufh = {}
    self.winId = {}
    self.marks = {}
end

function Buffer:removeAllExtMarks(idx)
    if not self.marks[idx] then
        return
    end

    for mi = 1, #self.marks[idx] do
        vim.api.nvim_buf_del_extmark(self.bufh[idx], ns, self.marks[idx][mi])
    end

    self.marks[idx] = {}
end

function Buffer:setExtMark(idx, line, col)
    if not self.marks[idx] then
        return
    end

    local mark = vim.api.nvim_buf_set_extmark(self.bufh[idx], ns, line, col, {})
    table.insert(self.marks[idx], mark)
end

function Buffer:getMarks(idx)
    local marks = {}
    local buf = self.bufh[idx]
    local markSet = self.marks[idx]


    if not markSet or not buf then
        return marks
    end

    for mi = 1, #markSet do
        local foundMark = vim.api.nvim_buf_get_extmark_by_id(buf, ns, markSet[mi], {})
        table.insert(marks, foundMark)
    end

    return marks
end

function Buffer:getBufferContents(idx)
    local lineCount = vim.api.nvim_buf_line_count(self.bufh[idx])
    return vim.api.nvim_buf_get_lines(id, 0, lineCount, false)
end

return {
    isWindowValid = function()
        local vimStats = vim.api.nvim_list_uis()[1]
        return vimStats.width >= REQUIRED_WIDTH and
            vimStats.height >= REQUIRED_HEIGHT
    end,
    Buffer = Buffer
}
