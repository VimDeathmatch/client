local log = require("vim-deathmatch.print")

local Buffer = {}

local function createEmpty(count)
    local lines = {}
    for idx = 1, count, 1 do
        lines[idx] = ""
    end

    return lines
end

function Buffer:new(winId, bufh)
    local config = {
        winId = winId,
        bufh = bufh,
    }

    self.__index = self
    return setmetatable(config, self)
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

    local editable = self.editable
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

    for idx = 1, #self.winId do
        vim.api.nvim_win_close(self.winId[idx], true)
    end
end

function Buffer:getBufferContents(idx)
    local lineCount = vim.api.nvim_buf_line_count(self.bufh[idx])
    vim.api.nvim_buf_get_lines(id, 0, lineCount, false)
end

return Buffer
