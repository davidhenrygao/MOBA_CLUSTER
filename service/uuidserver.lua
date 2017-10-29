local skynet = require "skynet"
local redis = require "skynet.db.redis"
local log = require "log"

local db
local PLAYER_UUID_COUNTER = "player_uuid_counter"

local CMD = {}

function CMD.get_player_uuid()
	uuid = db:get(PLAYER_UUID_COUNTER)
	db:INCR(PLAYER_UUID_COUNTER)
	return tonumber(uuid)
end

skynet.init( function ()
	db = redis.connect {
		host = "127.0.0.1" ,
		port = 6379 ,
		db = 0 ,
	}
	db:setnx(PLAYER_UUID_COUNTER, 1)
end)

skynet.start( function ()
    skynet.dispatch("lua", function (session, source, cmd, ...)
        local func = CMD[cmd]
	if func then
	    if session == 0 then
	        func(...)
	    else
		skynet.ret(skynet.pack(func(...)))
	    end
	else
	    log("Unknown uuidserver Command : [%s]", cmd)
	    skynet.response()(false)
	end
    end)
end)
