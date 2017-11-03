local skynet = require "skynet"
require "skynet.manager"

skynet.start(function()
	skynet.error("Login server start")
	--skynet.uniqueservice("protoloader")
	if not skynet.getenv "daemon" then
		skynet.newservice("console")
	end
	local debug_console_port = assert(skynet.getenv("debug_console_port"))
	skynet.newservice("debug_console",debug_console_port)

	-- TODO: Seperate it from login sever.
	skynet.uniqueservice("uuidserver")

	-- TODO: Seperate it to login center server.
	local login_manager = skynet.newservice("login_manager")
	skynet.name(".manager", login_manager)
	skynet.call(login_manager, "lua", "open", {
		address = skynet.getenv("ip"),
		port = skynet.getenv("port"),
		maxclient = skynet.getenv("maxclient") or 4096,
	})

	skynet.exit()
end)
