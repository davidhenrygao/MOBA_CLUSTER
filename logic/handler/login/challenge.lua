local cmd = require "proto.cmd"

return {
    cmd = cmd.LOGIN_CHALLENGE, 
	resp = "protocol.s2c_challenge",
}
