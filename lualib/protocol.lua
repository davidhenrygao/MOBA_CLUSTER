local proto = {}

proto.serialize = function (sess, cmd, data)
	assert(sess and type(sess) == "number" 
		and cmd and type(cmd) == "number"
		and data and type(data) == "string")
	-- TODO calc checksum
	local checksum = 0
	local fmt = ">I2 >I4 >s2 >I4"
	local ret = string.pack(fmt, sess, cmd, data, checksum)
	return ret
end

proto.unserialize = function (msg)
	assert(msg, "unserialization args is nil")
	local fmt = ">I2 >I4 >s2 >I4"
	local sess, cmd, data, checksum = string.unpack(fmt, msg)
	-- TODO verify checksum
	return sess, cmd, data, checksum
end

return proto
