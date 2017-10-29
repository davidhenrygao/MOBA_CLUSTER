local load_handlers = require "logic.utils.load_handlers"

local paths = {
    "player", 
--    "common",
}
local handlers = load_handlers(paths)

return handlers
