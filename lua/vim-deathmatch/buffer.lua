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

function Buffer:createOrResize(count, padding)
    if self.bufh and #self.bufh ~= count then
        self:destroy()
    end

    local vimStats = vim.api.nvim_list_uis()[1]
    local w = vimStats.width
    local h = vimStats.height

    local width = math.floor(w / count) - padding
    local height = h - 2
    local rcConfig1 = { row = 1, col = 1 }
    local rcConfig2 = { row = 1, col = width + padding }

    local config = {
        style = "minimal",
        relative = "win",
        width = width,
        height = height
    }

    if not self.bufh then
        self.bufh = {vim.fn.nvim_create_buf(false, true),
            vim.fn.nvim_create_buf(false, true)}

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
                print("Very special line")
                vim.register_keystroke_callback(nil, namespace)
            end
        end, namespace)

        vim.api.nvim_buf_attach(self.bufh[1], false, {
            on_lines=function(...)
                self.onBufferUpdate(1, ...)
            end
        })

    end

    if not self.winId then
        self.winId = {
            vim.api.nvim_open_win(self.bufh[1], true,
                vim.tbl_extend("force", config, rcConfig1)),
            vim.api.nvim_open_win(self.bufh[2],
                false, vim.tbl_extend("force", config, rcConfig2)),
        }
        log.info("Buffer:_createOrResizeWindow: new windows", vim.inspect(self.winId))
    else

        log.info("Buffer:_createOrResizeWindow: resizing windows", vim.inspect(rcConfig1))
        vim.api.nvim_win_set_config(
            self.winId[1], vim.tbl_extend("force", config, rcConfig1))
        vim.api.nvim_win_set_config(
            self.winId[2], vim.tbl_extend("force", config, rcConfig2))
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
