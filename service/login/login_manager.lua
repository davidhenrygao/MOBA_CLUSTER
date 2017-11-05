local skynet = require "skynet"
require "skynet.manager"
local gateserver = require "snax.gateserver"
local netpack = require "skynet.netpack"
local cluster = require "skynet.cluseter"

local log = require "log"

local balance
local worker_list = {}

local connection = {}	-- fd -> connection : { fd , client, agent , ip, mode }
local forwarding = {}	-- agent -> connection

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
}

local handler = {}

function handler.open(source, conf)
	local workers = conf.workers or 8
	for i=1,workers do
		table.insert(worker_list, skynet.newservice("login_worker"), i)
	end
	balance = 1

	-- open cluster
	cluster.register(".login", skynet.self())
	cluster.open("login")
end

function handler.connect(fd, addr)
	local worker = balance % #worker_list
	balance = balance + 1
	local c = {
		fd = fd,
		ip = addr,
		worker = worker_list[worker],
	}
	connection[fd] = c
	log("client[%s] connected: fd[%d], dispatch to worker[%d]", 
		addr, fd, worker)
end

function handler.message(fd, msg, sz)
	-- recv a package, forward it
	local c = connection[fd]
	local worker = c.worker
	if agent then
		skynet.redirect(agent, c.client, "client", 1, msg, sz)
	else
		skynet.send(watchdog, "lua", "socket", "data", fd, netpack.tostring(msg, sz))
	end
end

local function unforward(c)
	if c.agent then
		forwarding[c.agent] = nil
		c.agent = nil
		c.client = nil
	end
end

local function close_fd(fd)
	local c = connection[fd]
	if c then
		unforward(c)
		connection[fd] = nil
	end
end

function handler.disconnect(fd)
	close_fd(fd)
	skynet.send(watchdog, "lua", "socket", "close", fd)
end

function handler.error(fd, msg)
	close_fd(fd)
	skynet.send(watchdog, "lua", "socket", "error", fd, msg)
end

function handler.warning(fd, size)
	skynet.send(watchdog, "lua", "socket", "warning", fd, size)
end

local CMD = {}

function CMD.forward(source, fd, client, address)
	local c = assert(connection[fd])
	unforward(c)
	c.client = client or 0
	c.agent = address or source
	forwarding[c.agent] = c
	gateserver.openclient(fd)
end

function CMD.accept(source, fd)
	local c = assert(connection[fd])
	unforward(c)
	gateserver.openclient(fd)
end

function CMD.kick(source, fd)
	gateserver.closeclient(fd)
end

function handler.command(cmd, source, ...)
	local f = assert(CMD[cmd])
	return f(source, ...)
end

gateserver.start(handler)
