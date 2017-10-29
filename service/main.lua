local skynet = require "skynet"
require "skynet.manager"

skynet.start(function()
	skynet.error("Login server start")
	--skynet.uniqueservice("protoloader")
	if not skynet.getenv "daemon" then
		skynet.newservice("console")
	end
	skynet.newservice("debug_console",8000)

	skynet.uniqueservice("uuidserver")

	local loginserver = skynet.newservice("login_manager")
	skynet.name(".manager", loginserver)

	local gateserver = skynet.newservice("gate")
	skynet.call(gateserver, "lua", "start", {
		name = "gate1",
	})
	
	skynet.exit()
end)
