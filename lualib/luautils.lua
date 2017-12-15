local log  = require "log"

local utils = {}

-- copytable
local copytable
copytable = function (st)  
    local tab = {}  
    for k, v in pairs(st or {}) do  
        if type(v) ~= "table" then  
            tab[k] = v  
        else  
            tab[k] = copytable(v)  
        end  
    end  
    return tab  
end 
utils.copytable = copytable

-- logtable
local logtable
logtable = function (t, indent)
    indent = indent or "  "
    for name,val in pairs(t) do
        log("%sname: %s, val: %s", indent, name, val)
        if type(val) == "table" then
            logtable(val, indent .. "  ")
        end
    end
end
utils.logtable = logtable

-- strToTable and tableToStr
local function load_back(data)
	local errmsg
	data, errmsg = load(data)
	return data, errmsg
end

local function write(tBuffer, value)
	tBuffer[#tBuffer+1] = value
end

local function serialstring(tBuffer, sValue)
	write(tBuffer, string.format("%q", sValue))
end

local serialtable
local serialize

serialtable = function (tBuffer, tData, tParsed)
	if tParsed[tData] then
		local sInfo = string.format("recursive table %s",tostring(tData))
		error(sInfo)
    else
        tParsed[tData] = true
    end

	-- serialize contents
	write(tBuffer,"{")
	for key, val in pairs(tData) do
		write(tBuffer, "[")
		serialize(tBuffer, key, tParsed)
		write(tBuffer, "]=")
		serialize(tBuffer, val, tParsed)
		write(tBuffer, ",")
	end
	write(tBuffer, "}")
end

serialize = function (tBuffer, valueObj, tParsed)
	local sValueType = type(valueObj)
	if sValueType == "nil" or sValueType == "boolean" or sValueType == "number" then
		write(tBuffer, tostring(valueObj))
	elseif sValueType == "string" then
		serialstring(tBuffer, valueObj)
	elseif sValueType == "table" then
		serialtable(tBuffer, valueObj, tParsed)
	else
		error("unable to serialize a "..type)
	end
end


local function tableToStr(tData)
	assert(type(tData) == "table", "tData is not a table, got " .. type(tData) .. "|" .. tostring(tData))

	local tBuffer = {}
	local tParsed = {}
	serialtable(tBuffer, tData, tParsed)
	local sValue = table.concat(tBuffer)
	return sValue
end


local function strToTable(sValue)
	-- body
	assert(type(sValue) == "string", "sValue is not a string")
	local tValue = assert(load_back("return " .. sValue))()

	assert(type(tValue) == "table", "tValue is not a table, got" .. type(tValue))
	return tValue
end

utils.str_to_table = strToTable
utils.table_to_str = tableToStr

return utils
