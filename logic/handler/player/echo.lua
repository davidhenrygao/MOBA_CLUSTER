local retcode = require "logic.retcode"
local cmd = require "proto.cmd"

local function execute_f(req, resp_f)
	local player = req.playerinfo
	local msg = assert(req.args.msg)
	local echo_msg = player.name .. "[" .. string.format("%d", player.id) .. "] say: " .. msg
	local s2c_echo = {
		msg = echo_msg,
	}
	resp_f(s2c_echo)
end

return {
    cmd = cmd.ECHO, 
    handler = execute_f,
	protoname = "player.c2s_echo",
	resp_protoname = "player.s2c_echo",
}
