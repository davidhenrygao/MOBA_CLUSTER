local lfs = require "lfs"
local log = require "log"
local path_mgr = require "filepathmgr"

local filefinder = {}

local search_help
search_help = function (prefix_path, path, file_suffix_name)
	local realpath = path_mgr.append_slash(prefix_path) .. path
	local find_files = {}
	local find_paths = {}
	local attrs, err = lfs.attributes(realpath)
	if not attrs then
		log("In path[%s], lfs attributes function error: %s.", 
			realpath, err)
		return false
	end
	if attrs.mode == "file" 
		and path_mgr.suffix(realpath) == file_suffix_name then
		table.insert(find_files, realpath)
	end
	if attrs.mode == "directory" then
		for f in lfs.dir(realpath) do
			local new_path = path_mgr.append_slash(realpath) .. f
			attrs, err = lfs.attributes(new_path)
			repeat
				if not attrs then
					log("In path[%s], lfs attributes function error: %s.", 
						new_path, err)
					return false
				end
				if attrs.mode == "file" 
					and path_mgr.suffix(f) == file_suffix_name then
					table.insert(find_files, new_path)
				end
				if attrs.mode == "directory" then
					table.insert(find_paths, new_path)
				end
			until true
		end
	end

	return true, find_files, find_paths
end

function filefinder.search(prefix_path, file_paths, file_suffix_name, recursive)
	assert(prefix_path and type(prefix_path) == "string")
	assert(file_paths and type(file_paths) == "table")
	assert(file_suffix_name and type(file_suffix_name) == "string")
	local files = {}
	local paths = {}
	for _,path in ipairs(file_paths) do
		table.insert(paths, path)
	end
	while #paths ~= 0 do
		local path = paths[1]
		table.remove(paths, 1)
		local ok, find_files, find_paths = 
			search_help(prefix_path, path, file_suffix_name)
		assert(ok, "filefinder search failed!")
		for _,find_file in ipairs(find_files) do
			table.insert(files, find_file)
		end
		if recursive then
			for _,find_path in ipairs(find_paths) do
				table.insert(paths, find_path)
			end
		end
	end
	return files
end

return filefinder
