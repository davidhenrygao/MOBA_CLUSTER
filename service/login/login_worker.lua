local skynet = require "skynet"
local log = require "log"
local message = require "message"
local socket = require "skynet.socket"
local crypt = require "skynet.crypt"
local pb = require "protobuf"
local net = require "netpackage"
local protocol = require "protocol"
local cmd = require "proto.cmd"
local errcode = require "logic.retcode"
local cjson = require "cjson"

local handlers = require "logic.handler.login"

local id, source = ...

local connection = {}  -- connection[cid] = { cid, stage, tick, sess, challenge,}

local Context = {}

local function read_cmd_msg(fd, expect_cmd, protostr)
	local sess
	local req_cmd
	local data
	local ok
	local msg
	local result
	local err
	ok, msg = net.read(fd)
	if not ok then
		log("cmd[%d] netpackage read failed: connection[%d] aborted.", 
			expect_cmd, fd)
		return false
	end
	ok, sess, req_cmd, data = protocol.unserialize(msg)
	if not ok then
		log("cmd[%d] Connection[%d] protocol unserialize error.", 
			expect_cmd, fd)
		return false
	end
	if req_cmd ~= expect_cmd then
		log("Expect cmd[%d], get cmd[%d].", expect_cmd, req_cmd)
		return false
	end
	result, err = pb.decode(protostr, data)
	if err ~= nil then
		log("cmd[%d] protobuf decode error: %s.", expect_cmd, err)
		return false
	end
	Context[fd].session = sess
	Context[fd].time = skynet.time()
	Context[fd].cmd = req_cmd
	return true, result
end

----[[
local function strtohex(str)
	local len = str:len()
	local fmt = "0X"
	for i=1,len do
		fmt = fmt .. string.format("%02x", str:byte(i))
	end
	return fmt
end
--]]

local function write_cmd_msg(fd, proto_cmd, protostr, orgdata)
	local data = pb.encode(protostr, orgdata)
	local msg = protocol.serialize(Context[fd].session, proto_cmd, data)
	net.write(fd, msg)
end

local function handshake(fd)
	local data
	local ok
	local msg
	local result

	-- send challenge
	local challenge = crypt.randomkey()
	local s2c_challenge = {
		challenge = crypt.base64encode(challenge),
	}
	data = pb.encode("login.s2c_challenge", s2c_challenge)
	msg = protocol.serialize(0, cmd.LOGIN_CHALLENGE, data)
	net.write(fd, msg)

	-- exchange key
	ok, result = read_cmd_msg(fd, cmd.LOGIN_EXCHANGEKEY, "login.c2s_exchangekey")
	if not ok then
		return false
	end
	local s2c_serverkey = {
		code = errcode.SUCCESS,
	}
	local clientkey = crypt.base64decode(result.clientkey)
	log("clientkey: %s.\n", strtohex(clientkey))
	if #clientkey ~= 8 then
		log("client key is not 8 byte length, got %d byte length.", #clientkey)
		s2c_serverkey.code = errcode.LOGIN_CLIENT_KEY_LEN_ILLEGAL
		write_cmd_msg(fd, cmd.LOGIN_EXCHANGEKEY, "login.s2c_exchangekey", s2c_serverkey)
		return false
	end
	local serverkey = crypt.randomkey()
	log("serverkey: %s.\n", strtohex(serverkey))
	s2c_serverkey.serverkey = crypt.base64encode(crypt.dhexchange(serverkey))
	log("client will recieve serverkey: %s.\n", strtohex(crypt.dhexchange(serverkey)))
	write_cmd_msg(fd, cmd.LOGIN_EXCHANGEKEY, "login.s2c_exchangekey", s2c_serverkey)

	-- handshake
	local secret = crypt.dhsecret(clientkey, serverkey)
	log("secret: %s.\n", strtohex(secret))
	log("base64(secret) : %s.\n", crypt.base64encode(secret))
	ok, result = read_cmd_msg(fd, cmd.LOGIN_HANDSHAKE, "login.c2s_handshake")
	if not ok then
		return false
	end
	local v = crypt.base64decode(result.encode_challenge)
	local hmac = crypt.hmac64_md5(challenge, secret)
	local s2c_handshake = {
		code = errcode.SUCCESS,
	}
	if v ~= hmac then
		s2c_handshake.code = errcode.LOGIN_HANDSHAKE_FAILED
		write_cmd_msg(fd, cmd.LOGIN_HANDSHAKE, "login.s2c_handshake", s2c_handshake)
		return false
	end
	write_cmd_msg(fd, cmd.LOGIN_HANDSHAKE, "login.s2c_handshake", s2c_handshake)

	Context[fd].secret = secret
	return true
end

local function dblogin(logininfo)
	local account = logininfo.openid
	local account_info
	local account_info_str
	local player
	local player_str
	local key
	local ret = db:hexists(ACCOUNT, account)
	if ret == 0 then
		-- register
		local uuidserver = skynet.queryservice("uuidserver")
		local uid = skynet.call(uuidserver, "lua", "get_player_uuid")
		account_info = {
			uid = uid,
			platformid = logininfo.platformid,
			openid = account,
			unionid = logininfo.unionid,
		}
		account_info_str = cjson.encode(account_info)
		ret = db:hset(ACCOUNT, account, account_info_str)
		if ret == 0 then
			return errcode.REGISTER_DB_ERR
		end
		local name
		if logininfo.nickname == "" then
			name = "player" .. tostring(os.time())
		else
			name = logininfo.nickname
		end
		player = {
			id = account_info.uid, 
			name = name,
			headimgurl = logininfo.headimgurl,
			level = 1,
			gold = 0,
			exp = 0,
		}
		player_str = cjson.encode(player)
		key = PLAYER .. tostring(account_info.uid)
		ret = db:setnx(key, player_str)
		if ret == 0 then
			return errcode.CREATE_PLAYER_DB_ERR
		end
	else
		-- login
		account_info_str = db:hget(ACCOUNT, account)
		account_info = cjson.decode(account_info_str)
	end
	return errcode.SUCCESS, account_info.uid
end

local function login(fd)
	local ok
	local result
	local secret = Context[fd].secret

	-- login 
	ok, result = read_cmd_msg(fd, cmd.LOGIN, "login.c2s_login")
	if not ok then
		return false
	end
	local s2c_login = {
		code = errcode.SUCCESS,
	}

	local openid = result.openid
	--[[
	local etoken = crypt.base64decode(result.token)
	local tokenstr = crypt.desdecode(secret, etoken)
	local token, platform = tokenstr:match("([^@]+)@(.+)")
	token = crypt.base64decode(token)
	platform = crypt.base64decode(platform)
	-- 去第三方验证token
	-- 暂时直接将token@platform作为Account存储
	--]]
	local login_manager = skynet.localname(".manager")
	local err, gate = skynet.call(login_manager, "lua", "prelogin", openid)
	if err ~= errcode.SUCCESS then
		s2c_login.code = err
		write_cmd_msg(fd, cmd.LOGIN, "login.s2c_login", s2c_login)
		return false
	end
	local uid 
	err, uid = dblogin(result)
	if err ~= errcode.SUCCESS then
		skynet.call(login_manager, "lua", "loginfailed", openid)
		s2c_login.code = err
		write_cmd_msg(fd, cmd.LOGIN, "login.s2c_login", s2c_login)
		return false
	end
	local subid
	local server_addr
	err, subid, server_addr = skynet.call(gate, "lua", "login", openid, uid, secret)
	if err ~= errcode.SUCCESS then
		skynet.call(login_manager, "lua", "loginfailed", openid)
		s2c_login.code = err
		write_cmd_msg(fd, cmd.LOGIN, "login.s2c_login", s2c_login)
		return false
	end
	skynet.call(login_manager, "lua", "login", openid, gate)
	s2c_login.info = {
		subid = crypt.base64encode(subid),
		server_addr = crypt.base64encode(server_addr),
	}
	write_cmd_msg(fd, cmd.LOGIN, "login.s2c_login", s2c_login)

	return true
end

local function handle(fd)
	Context[fd] = {
		session = 0,
		time = skynet.time(),
	}
	socket.start(fd)

	local ok = handshake(fd)
	if not ok then
		log("fd[%d] handshake failed!", fd)
		socket.close(fd)
		return
	end

	ok = login(fd)
	if not ok then
		log("fd[%d] login failed!", fd)
		socket.close(fd)
		return
	end

	socket.close(fd)
end

local login_stage_cmd_list = {
	cmd.LOGIN_EXCHANGEKEY,
	cmd.LOGIN_HANDSHAKE,
	cmd.LOGIN,
}

local CMD = {}

local function gen_response(cid, resp_encode)
	assert(cid)
	assert(resp_encode and type(resp_encode) == "funtion")
	return function (tdata)
		assert(tdata)
		local msg = resp_encode(tdata)
		skynet.send(source, "lua", "response", cid, msg)
	end
end

local function send_message(cid, command, tdata)
	assert(cid and command and tdata)
	local msg = message.push_encode(command, tdata)
	skynet.send(source, "lua", "response", cid, msg)
end

local function send_challenge(c)
	-- send challenge
	local challenge = crypt.randomkey()
	local s2c_challenge = {
		challenge = crypt.base64encode(challenge),
	}
	send_message(c.cid, cmd.LOGIN_CHALLENGE, s2c_challenge)

	c.challenge = challenge

	return 0
end

-- TODO: Create a connection pool
function CMD.open_connection(cid)
	assert(cid)
	local c = {
		cid = cid,
		stage = 1,
		tick = skynet.now(),
		sess = 1,
	}
	connection[cid] = c
	return 0
end

function CMD.init_connection(cid)
	assert(cid)
	local c = assert(connection[cid])
	send_challenge(c)
	c.tick = skynet.now()
	-- TODO: add to timer
end

function CMD.close_connection(cid)
	connection[cid] = nil
	return 0
end

local function unpack_cli_msg(msg, sz)
	local cid, smsg = skynet.unpack(msg, sz)
	assert(cid and smsg)
	local ok, sess, req_cmd, args, resp_encode = message.decode(smsg)
	if not ok then
		local err = sess
		log("Connection[%d] message decode error: %d", cid, err)
		if err == message.errcode.PROTO_UNSERIALIZATION_FAILED then
			err = errcode.PROTO_UNSERIALIZATION_FAILED
		elseif err == message.errcode.UNKNOWN_REQ_CMD then
			err = errcode.UNKNOWN_CMD
		elseif err == message.errcode.PB_DECODE_ERROR then
			err = errcode.PB_DECODE_ERROR
		end
		return cid, false, err
	end
	return cid, true, sess, req_cmd, args, resp_encode
end

local function dispatch_cli_msg(session, src, cid, result, ...)
	local code
	local c = assert(connection[cid], 
				string.format("Connection(%d) not found.", cid))
	if result == false then
		code = ...
		assert(code)
		local s2c_protocol_err = {
			code = code,
		}
		send_message(cid, cmd.PROTOCOL_ERR, s2c_protocol_err)
		-- close connection ?
	else
		local sess, req_cmd, args, resp_encode  = ...
		assert(sess and req_cmd and args)
		local response
		if resp_encode then
			response = gen_response(cid, resp_encode)
		end
		if req_cmd ~= cmd.HEARTBEAT and 
			req_cmd ~= login_stage_cmd_list[c.stage] then
			if response then
				response({code = errcode.LOGIN_CMD_ORDER_ERR,})
			end
			-- close connection ?
			return
		end
		local handler = handlers[req_cmd]
		assert(handler and handler.f)
		local f = handler.f
		-- check sess
		c.sess = sess + 1
		c.tick = skynet.now()
		local ctx = {
			conn = c,
			args = args,
			response = response,
		}
		f(ctx)
	end
end

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = unpack_cli_msg,
	dispatch = dispatch_cli_msg,
}

skynet.init( function ()
	message.init(handlers)
end)

skynet.start( function ()
	log("login worker(%d) start.", id)
	skynet.dispatch("lua", function (sess, src, command, ...)
		local f = CMD[command]
		if f then
			skynet.ret(skynet.pack(f(...)))
		else
			log("Unknown login worker's command: %s.", command)
			skynet.response()(false)
		end
	end)
end)
