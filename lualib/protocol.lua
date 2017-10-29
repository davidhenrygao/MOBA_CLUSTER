local log = require "log"

local proto = {}

proto.serialize = function (sess, cmd, data)
	assert(sess and type(sess) == "number" 
		and cmd and type(cmd) == "number"
		and data and type(data) == "string")
	-- TODO calc checksum
	local checksum = 0
	local fmt = ">I2 >I4 >s2 >I4"
	local ok, ret = pcall(string.pack, fmt, sess, cmd, data, checksum)
	if not ok then
		log("string pack error: %s", ret)
		return nil
	end
	return ret
end

proto.unserialize = function (msg)
	assert(msg, "unserialization args is nil")
	local fmt = ">I2 >I4 >s2 >I4"
	local ok, sess, cmd, data, checksum = pcall(string.unpack, fmt, msg)
	if not ok then
		local err = sess
		log("string unpack error: %s", err)
		return nil
	end
	-- TODO verify checksum
	return ok, sess, cmd, data, checksum
end

return proto
