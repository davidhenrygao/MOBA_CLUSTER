local skynet = require "skynet"
local log = require "log"
local pb = require "protobuf"
local ff = require "filefinder"

local CMD = {}

function CMD.load(conf)
	local prefix_path = conf.prefix_path or skynet.getenv("root")
	local file_paths = assert(conf.file_paths)
	local files = ff.search(prefix_path, file_paths, "pb")
	for _,file in ipairs(files) do
		pb.register_file(file)
	end
end

function CMD.getproto()
	return pb.getP()
end

skynet.start( function ()
	skynet.dispatch("lua", function (sess, source, cmd, ...)
		local f = CMD[cmd]
		if f then
			skynet.ret(skynet.pack(f(...)))
		else
			log("Unknown proto manager's command: %s.", cmd)
			skynet.response()(false)
		end
	end)
end)
