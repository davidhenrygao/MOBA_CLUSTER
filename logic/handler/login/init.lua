local load_handlers = require "logic.utils.load_handlers"

local paths = {
    "common",
	"login",
}
local handlers = load_handlers(paths)

return handlers
