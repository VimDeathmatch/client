for k in pairs(package.loaded) do
    if k:match("^vim%-deathmatch") then
        package.loaded[k] = nil
    end
end

local log = require("vim-deathmatch.print")
local Buffer = require("vim-deathmatch.buffer")

local buf = Buffer:new({
    onBufferChange = function(idx)
        log.info("XXXX Buffer:new#onBufferChange", idx)
    end
})

buf:createOrResizeBuffer(2)

buf:write(1, "hello world")





