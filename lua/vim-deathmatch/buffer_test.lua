for k in pairs(package.loaded) do
    if k:match("^vim%-deathmatch") then
        package.loaded[k] = nil
    end
end
local timeBetwixt = 1000

local log = require("vim-deathmatch.print")
local Buffer = require("vim-deathmatch.buffer")


function case3()
    local buf = Buffer:new(
        function(idx)
            log.info("XXXX Case 3: Buffer:new#onBufferChange", idx)
        end,

        function(keyStroke)
            log.info("XXXX Case 3: Buffer:new#onKeystroke", keyStroke)
        end
    )
    buf:createOrResize({
        count = 1,
        padding = 10,
    })

    buf:write(1, "hello world")

    vim.defer_fn(function()
        buf:destroy()
    end, timeBetwixt)
end

function case2()
    local buf = Buffer:new(
        function(idx)
            log.info("XXXX Case 2: Buffer:new#onBufferChange", idx)
        end,

        function(keyStroke)
            log.info("XXXX Case 2: Buffer:new#onKeystroke", keyStroke)
        end
    )
    buf:createOrResize({
        count = 2,
        padding = 2,
        dim = {nil, {
            width = 15
        }}
    })

    buf:write(1, "hello world")

    vim.defer_fn(function()
        buf:destroy()
        case3()
    end, timeBetwixt)
end

function case1()
    local buf = Buffer:new(
        function(idx)
            log.info("XXXX Buffer:new#onBufferChange", idx)
        end,

        function(keyStroke)
            log.info("XXXX Buffer:new#onKeystroke", keyStroke)
        end
    )

    buf:createOrResize({
        count = 2,
        padding = 2,
    })

    buf:write(1, "hello world")
    vim.defer_fn(function()
        buf:destroy()
        case2()
    end, timeBetwixt)

end

case1()




