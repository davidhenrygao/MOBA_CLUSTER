--[[
-- This file define the cmd code between client and server.
--]]

local CMD = {
-- 0-99 common use
    HEARTBEAT = 1,
    ECHO = 2,
	LOGOUT = 3,

-- 100-199 login server use
    LOGIN_CHALLENGE = 100,
    LOGIN_EXCHANGEKEY= 101,
    LOGIN_HANDSHAKE = 102,
    LOGIN = 103,
    LOGIN_LAUNCH = 104,
}

return CMD
