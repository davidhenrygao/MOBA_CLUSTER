local skynet = require "skynet"
local log = require "log"
local lfs = require "lfs"
local path_mgr = require "logic.utils.path_mgr"

local logic = "logic"
local root = skynet.getenv("root") .. logic .. "/"

local function load_handlers(paths)
	local path
	local file
	local hinfo
	local handlers = {}
	for _,p in ipairs(paths) do
		path = root .. p
		local attrs, err = lfs.attributes(path)
		repeat
			if not attrs then
				log("In path[%s], lfs attributes function error: %s.", 
					path, err)
				break
			end
			if attrs.mode == "file" and path_mgr.suffix(p) == "lua" then
				file = path_mgr.trans2luapath(logic .. "/" .. path_mgr.prefix(p))
				hinfo = require(file)
				handlers[hinfo.cmd] = hinfo
			end
			if attrs.mode == "directory" then
				for f in lfs.dir(path) do
					local new_path = path .. "/" .. f
					attrs, err = lfs.attributes(new_path)
					repeat
						if not attrs then
							log("In path[%s], lfs attributes function error: %s.", 
								new_path, err)
							break
						end
						if attrs.mode == "file" and path_mgr.prefix(f) ~= "init" 
							and path_mgr.suffix(f) == "lua" then
							file = path_mgr.trans2luapath(
								logic .. "/" .. p .. "/" .. path_mgr.prefix(f))
							--log("after trans2luapath file is : %s.", file)
							hinfo = require(file)
							handlers[hinfo.cmd] = hinfo
						end
					until true
				end
			end
		until true
	end

	return handlers
end

return load_handlers
