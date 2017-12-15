local mgr = {}

local function find_last_symbol(str, symbol)
    local rstr = str:reverse()
    local pos = rstr:find(symbol, 1, true)
    if pos == nil then
        pos = str:len() + 1
    end
    return str:len() + 1 - pos
end

function mgr.suffix(file)
    assert(file and type(file) == "string", 
		"path_mgr suffix function need a string arg, got " .. type(file))
    return string.sub(file, find_last_symbol(file, ".") + 1)
end

function mgr.prefix(file)
    assert(file and type(file) == "string", 
		"path_mgr prefix function need a string arg, got " .. type(file))
    return string.sub(file, 1, find_last_symbol(file, ".") - 1)
end

function mgr.trans2luapath(path)
    assert(path and type(path) == "string", 
		"path_mgr trans2luapath function need a string arg, got " .. type(path))
    local ret = string.gsub(path, "//", ".")
    ret = string.gsub(ret, "/", ".")
    return ret
end

function mgr.append_slash(path)
    assert(path and type(path) == "string", 
		"path_mgr append slash function need a string arg, got " 
		.. type(path))
	local ret
	local len = path:len()
	if path:byte(len) ~= '/' then
		ret = path .. '/'
	end
	return ret
end

function mgr.remove_last_slash(path)
    assert(path and type(path) == "string", 
		"path_mgr append slash function need a string arg, got " 
		.. type(path))
	local ret = path
	local len = path:len()
	if path:byte(len) == '/' then
		ret = ret:sub(1, -2)
	end
	return ret
end

function mgr.basename(path)
    assert(path and type(path) == "string", 
		"path_mgr basename function need a string arg, got " 
		.. type(path))
	local rpath = mgr.remove_last_slash(path)
	return string.sub(rpath, find_last_symbol(rpath, "/") + 1)
end

return mgr
