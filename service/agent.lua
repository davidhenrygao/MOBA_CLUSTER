local skynet = require "skynet"
local log = require "log"
local response = require "response"
local handle = require "logic.player"
local retcode = require "logic.retcode"
local command = require "proto.cmd"
local pb = require "protobuf"

local host = ...

local db

local CMD = {}

local player_info

local player_username

function CMD.kick()
	skynet.fork( function ()
		skynet.exit()
	end)
end

function CMD.launch(dest, username, sess, cmd, uid)
	local err
	local s2c_launch = {
		code = retcode.SUCCESS,
	}
	err, player_info = skynet.call(db, "lua", "launch_player", uid)
	if err ~= retcode.SUCCESS then
		log("Player(%d) agent launch failed!", uid)
		s2c_launch.code = err
		return false
	end
	local resp_f = response(dest, pb, sess, cmd, "login.s2c_launch")
	s2c_launch.player = player_info
	resp_f(s2c_launch)

	player_username = username
	return true
end

function CMD.conn_abort()
	skynet.call(host, "lua", "conn_abort", player_username)
	return
end

local function logout(source, sess, req_cmd, msg)
	local s2c_logout = {
		code = retcode.SUCCESS,
	}
	local resp_f = response(source, pb, sess, req_cmd, "player.s2c_logout")
	resp_f(s2c_logout)

	skynet.call(host, "lua", "logout", player_username)
	log("reach here.")
	skynet.exit()
end

function CMD.dispatch(source, sess, req_cmd, msg)
	if req_cmd == command.LOGOUT then
		logout(source, sess, req_cmd, msg)
		return
	end

	local handleinfo = handle[req_cmd]
	if handleinfo == nil then
		log("Unknown agent service's command : [%d]", req_cmd)
		-- add error response later.
		return
	end
	local protoname = assert(handleinfo.protoname)
	local resp_protoname = assert(handleinfo.resp_protoname)
	local f = assert(handleinfo.handler)
	local args = pb.decode(protoname, msg)

	local resp_f = response(source, pb, sess, req_cmd, resp_protoname)
	local req = {
		source = source,
		session = sess,
		cmd = req_cmd,
		args = args,
		playerinfo = player_info
	}
	f(req, resp_f)
end

skynet.init( function ()
	db = skynet.queryservice("db")

	-- use lfs to load later.
	local files = {
		"login/launch.pb",
		"player/echo.pb",
		"player/logout.pb",
	}
	for _,file in ipairs(files) do
		pb.register_file(skynet.getenv("root") .. "proto/" .. file)
	end
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
	    log("Unknown agent Command : [%s]", cmd)
	    skynet.response()(false)
	end
    end)
end)
