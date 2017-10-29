local skynet = require "skynet"
local log = require "log"
local proto = require "protocol"
-- local retcode = require "logic.retcode"

local function response(source, pb, session, cmd, protoname)
    return function (resp)
        local data = pb.encode(protoname, resp)
		--[[
        local function strtohex(str)
            local len = str:len()
            local fmt = "0X"
            for i=1,len do
                fmt = fmt .. string.format("%02x", str:byte(i))
            end
            return fmt
        end
        log("response protobuf encode data: %s.", strtohex(data))
		--]]
        --[[
		local ok, data = pcall(pb.encode, protoname, resp)
		if not ok then
			log("response protobuf encode error!")
			return
		end
        --]]
		local r = proto.serialize(session, cmd, data)
		if not r then
			log("protocol serialization error!")
			return
		end
		skynet.send(source, "lua", "response", session, r)
    end
end

return response
