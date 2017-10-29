local mgr = {}

local function find_fixpoint(str)
    local rstr = str:reverse()
    local pos = rstr:find(".", 1, true)
    if pos == nil then
        pos = str:len() + 1
    end
    return str:len() + 1 - pos
end

function mgr.suffix(file)
    assert(file and type(file) == "string", 
	"path_mgr suffix function need a string arg, got " .. type(file))
    return string.sub(file, find_fixpoint(file) + 1)
end

function mgr.prefix(file)
    assert(file and type(file) == "string", 
	"path_mgr prefix function need a string arg, got " .. type(file))
    return string.sub(file, 1, find_fixpoint(file) - 1)
end

function mgr.trans2luapath(path)
    assert(path and type(path) == "string", 
	"path_mgr trans2luapath function need a string arg, got " .. type(path))
    local ret = string.gsub(path, "//", ".")
    ret = string.gsub(ret, "/", ".")
    return ret
end

return mgr
