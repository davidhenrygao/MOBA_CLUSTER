local skynet = require "skynet"
require "skynet.manager"
local gateserver = require "snax.gateserver"
local netpack = "skynet.netpack"
local cluster = require "skynet.cluseter"
local driver = require "skynet.socketdriver"

local log = require "log"
local utils = require "luautils"

local worker_list = {}

local connection = {}	-- fd -> connection : { id , ip, worker, }

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	pack = skynet.pack,
}

local handler = {}

function handler.open(source, conf)
	local workers = conf.workers or 8
	for i=1,workers do
		local worker = skynet.newservice("login_worker", i, skynet.self())
		table.insert(worker_list, worker)
	end

	-- open cluster
	cluster.register(".login", skynet.self())
	cluster.open("login")
end

-- Note: fd is an increase id in skynet c socket, not the 'fd' in the os.
function handler.connect(fd, addr)
	local idx = fd % #worker_list
	local c = {
		id = fd,
		ip = addr,
		worker = worker_list[idx],
	}
	connection[fd] = c
	log("client[%s] connected: fd[%d], dispatch to worker[%d]", 
		addr, fd, idx)
	local ret = skynet.call(c.worker, "lua", "open_connection", c.id)
	if ret == 0 then
		gateserver.openclient(fd)
		skynet.send(c.worker, "lua", "init_connection", c.id)
	else
		log("worker(%d) open_connection(fd:%d) error(%d).", c.worker, fd, ret)
		gateserver.closeclient(fd)
	end
end

function handler.message(fd, msg, sz)
	-- recv a package, forward it
	local c = connection[fd]
	local worker = c.worker
	-- Note! Must use netpack.tostring to free memory alloc by netpack.filter!
	-- Because the reciever will only free the memory alloc by skynet.pack in skynet.send.
	-- If you use skynet.redirect( in service/gate.lua ), the reciever will free it.
	skynet.send(worker, "client", c.id, netpack.tostring(msg, sz))
end

local function close_fd(fd)
	local c = connection[fd]
	if c then
		skynet.call(c.worker, "lua", "close_connection", c.id)
		connection[fd] = nil
	end
end

function handler.disconnect(fd)
	log("connection(%d) close.", fd)
	close_fd(fd)
end

function handler.error(fd, msg)
	log("connection(%d) error(%s).", fd, msg)
	close_fd(fd)
end

function handler.warning(fd, size)
	log("connection(%d) warning: send buffer size: %d.", fd, size)
end

local CMD = {}

-- TODO: Seperate it to gate_mgr server.
-- This is a simple load balance implementation, can be improved in the future.
function CMD.register_gate(conf)
	
end

function CMD.kick(source, fd)
	gateserver.closeclient(fd)
end

function CMD.response(fd, msg)
	assert(fd and msg)
	log("Response to connection(%d): [%s].", fd, utils.strtohex(msg))
	driver.send(fd, msg)
end

function handler.command(cmd, source, ...)
	local f = assert(CMD[cmd])
	return f(source, ...)
end

gateserver.start(handler)
