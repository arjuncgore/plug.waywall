local log = require("plug.log")
local plugin = require("plug.plugin")
local utils = require("plug.utils")
local globals = require("plug.globals")
local types = require("plug.types")

local M = {}

M.loaded_plugins = {}

--- @type Logger
Log = log.Logger:new()

--- @param dir string
local function __setup_dir(dir)
	local command = 'ls -a "' .. globals.WAYWALL_CONFIG_DIR .. dir .. '"'
	local handle = io.popen(command)
	if not handle then
		Log:error("setup dir failed: popen failed")
		return
	end
	for filename in handle:lines() do
		if filename == "." or filename == ".." then
			goto continue
		end
		if filename:sub(-#".lua") ~= ".lua" then
			Log:debug("setup dir: skip non lua file")
			goto continue
		end
		--- @type table<string, any> | nil
		filename = filename:sub(0, -#".lua" - 1)
		Log:debug("setup dir: load spec: " .. dir .. "." .. filename)
		local spec, err = utils.Prequire(dir .. "." .. filename)
		if not spec then
			Log:error("setup dir: failed to load spec: " .. err)
			goto continue
		end
		local err2 = plugin.load_from_spec(spec)
		if err2 then
			Log:error("setup dir: failed to load plugin: " .. err2)
			goto continue
		end
		M.loaded_plugins[#M.loaded_plugins + 1] = spec
		Log:debug("setup dir: loaded plugin: " .. spec.name)
		::continue::
	end
end

--- @param plugins table<string, any>[]
local function __setup_plugins(plugins)
	for _, spec in ipairs(plugins) do
		local err = plugin.load_from_spec(spec)
		if err then
			Log:error("setup plugins: failed to load plugin: " .. err)
			goto continue
		end
		M.loaded_plugins[#M.loaded_plugins + 1] = spec
		Log:debug("setup plugins: loaded plugin: " .. spec.name)
		::continue::
	end
end

--- @param opts SetupOpts
function M.setup(opts)
	Log:debug("setup start")
	if opts.dir then
		Log:debug("setup dir")
		__setup_dir(opts.dir)
	elseif opts.plugins then
		Log:debug("setup plugins")
		__setup_plugins(opts.plugins)
	else
		Log:error("setup failed: no dir or plugins")
	end
	Log:debug("setup end")
end

--- @param opts UpdateOpts
--- @return boolean
function M.update(opts)
	Log:debug("update start")
	if not opts.name then
		Log:error("update failed: no name")
		return false
	end

	local success, err = plugin.update_from_name(opts.name)
	if not success then
		Log:error("update failed: " .. err)
		return false
	end

	return true
end

--- @return boolean
function M.update_all()
	Log:debug("update all start")
	for _, spec in ipairs(M.loaded_plugins) do
		local success, err = spec:update()
		if not success then
			Log:error("update all failed: " .. err)
			return false
		end
	end
	return true
end

return M
