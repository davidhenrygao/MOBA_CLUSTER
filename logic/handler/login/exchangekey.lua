--local skynet = require "skynet"
local crypt = require "skynet.crypt"
local log = require "log"
local cmd = require "proto.cmd"
local errcode = require "logic.retcode"
--local utils = require "luautils"

local function execute_f(ctx)
	local c2s_exchangekey = assert(ctx.args)
	local response = assert(ctx.response)
	local s2c_serverkey = {
		code = errcode.SUCCESS,
	}
	local clientkey = crypt.base64decode(c2s_exchangekey.clientkey)
	--log("clientkey: %s.\n", utils.strtohex(clientkey))
	if #clientkey ~= 8 then
		log("client key is not 8 byte length, got %d byte length.", #clientkey)
		s2c_serverkey.code = errcode.LOGIN_CLIENT_KEY_LEN_ILLEGAL
		response(s2c_serverkey)
		return false
	end
	local serverkey = crypt.randomkey()
	--log("serverkey: %s.\n", utils.strtohex(serverkey))
	s2c_serverkey.serverkey = crypt.base64encode(crypt.dhexchange(serverkey))
	--[[
	log("client will recieve serverkey: %s.\n", 
		utils.strtohex(crypt.dhexchange(serverkey)))
	--]]
	response(s2c_serverkey)
	return true
end

return {
    cmd = cmd.LOGIN_EXCHANGEKEY, 
    handler = execute_f,
	req = "protocol.c2s_exchangekey",
	resp = "protocol.s2c_exchangekey",
}
