local skynet = require "skynet"
local socket = require "skynet.socket"
local crypt = require "skynet.crypt"
local log = require "log"
local errcode = require "logic.retcode"

-- constant
local TIMER_INTERVAL = 500

local CMD = {}
local data = {}
local conns = {}
local login_account_info = {}

local function accept_cb(fd, ip)
	log("%s accept connection[%d] from ip[%s]", data.name, fd, ip)
	local conn = skynet.newservice("connection")
	skynet.call(conn, "lua", "start", {
		fd = fd,
		host = skynet.self(),
		dest = data.launchserver,
	})
	conns[conn] = fd
end

--[[
local function timer_func()
    skynet.timeout(TIMER_INTERVAL, timer_func)
    for conn,_ in pairs(conns) do
        skynet.send(conn, "lua", "selfcheck")
    end
end
--]]

function CMD.start(conf)
    assert(conf and type(conf) == "table")
    assert(data.fd == nil, "gate already start")
    local ip = skynet.getenv("ip") or conf.ip or "127.0.0.1"
    local port = skynet.getenv("gate_port") or conf.port or 10000
    data.fd = socket.listen(ip, port)
    data.ip = ip
    data.port = port
	data.name = assert(conf.name)

	local loginmanager = skynet.localname(".manager")
	skynet.call(loginmanager, "lua", "register_gate", data.name, skynet.self())

    socket.start(data.fd, accept_cb)
    --skynet.timeout(TIMER_INTERVAL, timer_func)
    log("gate start: listen ip[%s]:port[%d]", ip, port)
end

local internal_id = 1
function CMD.login(account, uid, secret)
	local subid = crypt.hashkey(crypt.randomkey() .. account .. tostring(internal_id))
	internal_id = internal_id + 1
	local username = string.format("%s@%s", 
		crypt.base64encode(account), crypt.base64encode(subid))
	skynet.call(data.launchserver, "lua", "login", account, subid, username, uid, secret)
	local server_addr = data.ip .. ":" .. tostring(data.port)
	login_account_info[account] = {
		username = username,
		subid = subid,
		uid = uid,
		secret = secret,
	}
	return errcode.SUCCESS, subid, server_addr
end

function CMD.logout(account)
	local loginmanager = skynet.localname(".manager")
	skynet.call(loginmanager, "lua", "logout", account)
end

function CMD.kick(account)
	local account_info = login_account_info[account]
	if account_info == nil then
		return
	end
	skynet.call(data.launchserver, "lua", "kick", account_info.username)
end

function CMD.close_conn(conn_info)
    assert(conn_info and conn_info.conn)
    conns[conn_info.conn] = nil
end

function CMD.force_close_conn(conn)
	assert(conn)
	if conns[conn] ~= nil then
		skynet.send(conn, "lua", "force_close")
		conns[conn] = nil
	end
end

skynet.init( function ()
end)

skynet.start( function ()
	data.launchserver = skynet.newservice("launchserver", skynet.self())
	skynet.uniqueservice("db")

    skynet.dispatch("lua", function (_, _, cmd, ...)
        local func = CMD[cmd]
	if func then
	    skynet.ret(skynet.pack(func(...)))
	else
	    log("Unknown gate Command : [%s]", cmd)
	    skynet.response()(false)
	end
    end)
end)
