local skynet = require "skynet"
local protocol = require "protocol"
local log = require "log"

local pb
local cmd_pb_names

local M = {}

M.errcode = {
	PROTO_UNSERIALIZATION_FAILED = 1,
	UNKNOWN_REQ_CMD = 2,
	PB_DECODE_ERROR = 3,
}

function M.init(cmd_proto_names)
	local protomanager = skynet.queryservice("protomanager")
	local P = skynet.call(protomanager, "lua", "getP")
	debug.getregistry().PROTOBUF_ENV = P
	pb = require "protobuf"
	cmd_pb_names = cmd_proto_names
end

local function gen_resp_encode_func(sess, cmd)
	return function (tdata)
		local pb_name_tbl = cmd_pb_names[cmd]
		local data = pb.encode(pb_name_tbl.resp, tdata)
		return protocol.serialize(sess, cmd, data)
	end
end

function M.decode(msg)
	local ok, sess, cmd, data = pcall(protocol.unserialize, msg)
	if not ok then
		return false, M.errcode.PROTO_UNSERIALIZATION_FAILED
	end
	local pb_name_tbl = cmd_pb_names[cmd]
	if pb_name_tbl == nil or pb_name_tbl.req == nil then
		return false, M.errcode.UNKNOWN_REQ_CMD
	end
	local args, err = pb.decode(pb_name_tbl.req, data)
	if err ~= nil then
		log("cmd[%d] protobuf decode error: %s.", cmd, err)
		return false, M.errcode.PB_DECODE_ERROR
	end
	local resp_encode
	if pb_name_tbl.resp ~= nil then
		resp_encode = gen_resp_encode_func(sess, cmd)
	end
	return true, sess, cmd, args, resp_encode
end

function M.push_encode(cmd, tdata)
	local pb_name_tbl = assert(cmd_pb_names[cmd])
	local data = pb.encode(assert(pb_name_tbl.resp), tdata)
	local msg = protocol.serialize(0, cmd, data)
	return msg
end

return M
