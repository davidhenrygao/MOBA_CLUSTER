local skynet = require "skynet"
local cmd = require "proto.cmd"

local function execute_f(req, resp_f)
    local servertime = skynet.time()
    resp_f({cur_timestamp = servertime,})
end

return {
    cmd = cmd.HEARTBEAT, 
    handler = execute_f,
	req = "protocol.c2s_heartbeat",
	resp = "protocol.s2c_heartbeat",
}
