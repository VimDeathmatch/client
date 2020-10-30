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
    if not self.bufh then
        return
    end

    vim.api.nvim_buf_set_option(self.bufh, "modifiable", editable)
end

function Buffer:write(idx, msg)

    if not self.bufh or self.bufh ~= idx then
        return
    end

    if msg == nil then
        return
    end

    local editable = self.editable
    self:setEditable(true)

    if type(msg) ~= "table" then
        msg = {msg}
    end

    vim.api.nvim_buf_set_lines(self.bufh, 0, #msg - 1, false, msg)

    self:setEditable(editable)
end

return Buffer
