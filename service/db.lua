local skynet = require "skynet"
local redis = require "skynet.db.redis"
local log = require "log"
local retcode = require "logic.retcode"
local cjson = require "cjson"

local CMD = {}

local db
local PLAYER = "player:"

local player_info = {}

function CMD.launch_player(uid)
	local player = player_info[uid]
	if player ~= nil then
		return retcode.SUCCESS, player
	end

	local key = PLAYER .. string.format("%d", uid)
	local player_str = db:get(key)
	if player_str == nil then
	    return retcode.ACCOUNT_PLAYER_NOT_EXIST
	end
	player = cjson.decode(player_str)

    player_info[uid] = player
    return retcode.SUCCESS, player
end

function CMD.changename(id, name)
    if player_info[id] == nil then
        return retcode.PLAYER_NOT_LOGIN
    end
    player_info[id].name = name
    local player_str = cjson.encode(player_info[id])
    local key = PLAYER .. string.format("%d", id)
    local ret = db:set(key, player_str)
    if ret == nil then
        return retcode.CHANGE_PLAYER_NAME_DB_ERR
    end
    return retcode.SUCCESS
end

skynet.init( function ()
	db = redis.connect {
		host = "127.0.0.1" ,
		port = 6379 ,
		db = 0 ,
	}
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
	    log("Unknown db Command : [%s]", cmd)
	    skynet.response()(false)
	end
    end)
end)
