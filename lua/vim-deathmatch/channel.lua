local log = require("vim-deathmatch.print")

local states = {
    waitingForConnection = 0,
    waitingForLength = 1,
    waitingForType = 2,
    waitingForData = 3,
    ended = 4,
}


local Channel = {}
function getIp(host)
    local results = vim.loop.getaddrinfo(host)
    local actualAddr = nil

    for idx = 1, #results do
        local res = results[idx]
        if res.family == "inet" and res.socktype == "stream" then
            actualAddr = res.addr
        end
    end

    return actualAddr
end

function Channel:new()
    self.__index = self

    local channel = setmetatable({
        idx = 0,
        state = states.waitingForConnection,
        temporaryContents = nil,
    }, self)

    return channel
end

function Channel:setCallback(cb)
    self.callback = function(...)
        log.info("Channel:setCallback", ...)
        cb(...)
    end
end

local function format(data, msgType)
    return string.format("%d:%s:%s", #data, msgType, data)
end

function Channel:send(msgType, msg)
    if self.state == states.waitingForConnection then
        log.info("Cannot send message until we have a connection!!", msg, msgType)
        return
    end

    if not msg then
        msg = ""
    end

    if type(msg) == "table" then
        msg = vim.fn.json_encode(msg)
    end

    local msgOut = format(msg, msgType)
    log.info("Channel:send", msgOut)

    self.client:write(msgOut)
end

function Channel:store(data)
    if self.temporaryContents then
        data = self.temporaryContents .. data
    end

    self.temporaryContents = data
    return data
end

function Channel:get(data)
    if self.temporaryContents then
        data = self.temporaryContents .. data
        self.temporaryContents = nil
    end
    return data
end

function Channel:getStoredMessageLength()
    if self.temporaryContents then
        return #self.temporaryContents
    end
    return 0
end

function Channel:processMessageToLength(data, idx, total)
    log.info("processMessageToLength", data, idx, total)
    local remaining = total - self:getStoredMessageLength()
    if #data >= remaining then
        return true, remaining, self:get(data:sub(idx, #data))
    end
    return false, #data - idx, self:store(data:sub(idx, #data))
end

function Channel:processMessageToToken(data, idx, token)
    log.info("processMessageToToken", idx, token, data)
    local endIdx = string.find(data, ":", idx, true)
    log.info("processMessageToToken endIdx", endIdx)

    if endIdx == nil then
        log.info("processMessageToToken unableToFindToken")
        self:store(data)
        return false, #data - idx
    end

    local consumedAmount = (endIdx - idx) + 1
    log.info("processMessageToToken consumedAmount", consumedAmount)
    local token = self:get(data:sub(idx, endIdx - 1))
    log.info("processMessageToToken token", token)

    return true, consumedAmount, token
end

function Channel:processMessage(data)
    if data == nil then
        return
    end

    local currentIdx = 1
    while currentIdx <= #data do
        log.info("processMessage:", currentIdx, #data)

        if self.state == states.waitingForLength then
            log.info("processMessage#waitingForLength")
            local completed, consumedAmount, token =
                self:processMessageToToken(data, currentIdx, ":")

            currentIdx = currentIdx + consumedAmount
            log.info("processMessage#waitingForLength", completed, currentIdx, consumedAmount, token)

            if completed then
                self.currentMsgLength = tonumber(token)
                self.state = states.waitingForType
            end

        elseif self.state == states.waitingForType then
            local completed, consumedAmount, token =
                self:processMessageToToken(data, currentIdx, ":")

            currentIdx = currentIdx + consumedAmount

            log.info("processMessage#waitingForType", completed, currentIdx, consumedAmount, token)
            if completed then
                self.currentMsgType = token
                self.state = states.waitingForData
            end

        elseif self.state == states.waitingForData then
            local completed, consumedAmount, token =
                self:processMessageToLength(data, currentIdx, self.currentMsgLength)

            log.info("processMessage#waitingForData", completed, currentIdx, consumedAmount, token)
            if completed then
                local msgType = self.currentMsgType

                self.currentMsgType = nil
                self.currentMsgLength = nil

                currentIdx = currentIdx + consumedAmount
                if self.callback ~= nil then
                    self.callback(msgType, token)
                end

                self.state = states.waitingForLength
            end
        else
            log.info("Error we found ourself in a weird state?????", self.state)
        end
    end
end

function Channel:onWinClose()
    if self.client == nil then
        return
    end

    local state = self.state
    self.state = states.ended
    if state == states.waitingForConnection then
        return
    end

    self.client:shutdown()
    self.client:close()
    self.client = nil
end

function Channel:open(host, port, callback)
    self.client = vim.loop.new_tcp()
    local count = 0
    local ip = getIp(host)

    local connected = false
    local failed = false

    self.client:connect(ip, port, function (err)
        connected = true
        if failed then
            return
        end

        if err ~= nil then
            callback(err)
            return
        end

        if self.state == states.ended then
            self:onWinClose()
            return
        end

        self.state = states.waitingForLength
        self.client:read_start(vim.schedule_wrap(function(err, chunk)
            if chunk == nil then
                self:onWinClose()
            end
            self:processMessage(chunk)
        end))

        callback(nil);
    end)

    vim.fn.timer_start(10000, function()
        failed = true
        if not connected then
            callback("Unable to connect to deathmach.theprimeagen.tv:42069")
        end
    end)
end

return Channel


