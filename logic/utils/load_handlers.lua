local skynet = require "skynet"
local log = require "log"
local ff = require "filefinder"
local path_mgr = require "filepathmgr"

local logic = "logic/handler"
local root = path_mgr.appendslash(skynet.getenv("root"))
local path_prefix = path_mgr.appendslash(root .. logic)

local function load_handlers(paths)
	local handlers = {}
	local files = ff.search(path_prefix, paths, "lua")
	for _,file in ipairs(files) do
		local basename = path_mgr.basename(file)
		local root_path_len = string.len(root)
		local rfile = path_mgr.trans2luapath(file:sub(root_path_len+1))
		log("rfile: %s.", rfile)
		if path_mgr.prefix(basename) ~= "init" then
			local hinfo = require(rfile)
			handlers[hinfo.cmd] = hinfo
		end
	end
	return handlers
end

return load_handlers
