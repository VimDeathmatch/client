local log = require("vim-deathmatch.print")

local Buffer = {}

local function createEmpty(count)
    local lines = {}
    for idx = 1, count, 1 do
        lines[idx] = ""
    end

    return lines
end

function Buffer:new(onBufferUpdate, onKeystroke)
    local config = {
        onBufferUpdate = onBufferUpdate,
        onKeystroke = onKeystroke,
    }

    self.__index = self
    return setmetatable(config, self)
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

        if self.onKeystroke(keyCodePressed) == false then
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

local modes = {
    auto = 1,
    predefined = 2,
}

function getOtherIdx(idx)
    return idx == 1 and 2 or 1
end

function getWidth(w, config, idx)
    local computedW = w - 2 * config.padding
    if config.count == 1 then
        print("XXXX getWidth", w, computedW)
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

function getConfig(w, h, idx, config)
    local outConfig = {
        style = "minimal",
        relative = "win",
        width = getWidth(w, config, idx),
        height = h - config.padding * 2,
        row = config.padding,
        col = idx == 1 and config.padding or (getWidth(w, config, getOtherIdx(idx)) + 1 + config.padding),
    }
    print("XXXX", vim.inspect(outConfig))
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

    local vimStats = vim.api.nvim_list_uis()[1]
    local w = vimStats.width
    local h = vimStats.height

    local config1 = getConfig(w, h, 1, windowConfig)
    local config2 = getConfig(w, h, 2, windowConfig)

    if not self.bufh then
        self.bufh = {vim.fn.nvim_create_buf(false, true),
            vim.fn.nvim_create_buf(false, true)}

        self:_attachListeners(self.bufh[1], 1)
    end

    if not self.winId then
        self.winId = {
            vim.api.nvim_open_win(self.bufh[1], true, config1),
            vim.api.nvim_open_win(self.bufh[2], false, config2),
        }
        log.info("Buffer:_createOrResizeWindow: new windows", vim.inspect(self.winId))
    else

        log.info("Buffer:_createOrResizeWindow: resizing windows", vim.inspect(rcConfig1))
        vim.api.nvim_win_set_config(self.winId[1], config1)
        vim.api.nvim_win_set_config(self.winId[2], config2)
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

function Buffer:write(idx, msg)

    if msg == nil then
        return
    end

    local editable = self.editable or false
    self:setEditable(true)

    if type(msg) ~= "table" then
        msg = {msg}
    end

    vim.api.nvim_buf_set_lines(self.bufh[idx], 0, #msg - 1, false, msg)
    self:setEditable(editable)
end

function Buffer:clear()
    for idx = 1, #self.bufh do
        local bufh = self.bufh[idx]
        emptyLines = createEmpty(vim.api.nvim_buf_line_count(bufh))
        vim.api.nvim_buf_set_lines(bufh, 0, #emptyLines - 1, false, emptyLines)
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
end



function Buffer:getBufferContents(idx)
    local lineCount = vim.api.nvim_buf_line_count(self.bufh[idx])
    vim.api.nvim_buf_get_lines(id, 0, lineCount, false)
end

return Buffer
