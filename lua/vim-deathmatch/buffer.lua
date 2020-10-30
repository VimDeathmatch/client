local log = require("vim-deathmatch.print")

local Buffer = {}

function Buffer:new(winId, bufh)
    local config = {
        winId = winId,
        bufh = bufh,
    }

    self.__index = self
    return setmetatable(config, self)
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

return Buffer
