local pl = {
	path = require 'pl.path';
}

local function ext(path)
	local ext = pl.path.extension(path)
	if ext then
		return ext:sub(2)
	end
end

local grequire = {
	load = {};
	cache = {};
	extensions = {};
}
function grequire.extensions.lua(path, module)
	local fn, err
	if _VERSION == 'Lua 5.1' then
		fn, err = loadfile(path)
	else
		fn, err = loadfile(path, 'bt', module.env)
	end
	if not fn then return nil, err end
	if _VERSION == 'Lua 5.1' then
		setfenv(fn, module.env)
	end
	return fn()
end
function grequire.load.string(path, str)
	if type(path) ~= 'string' then error('path is required') end
	if type(str) ~= 'string' then error('str is required') end
end
function grequire.resolve(base, path)
	path = pl.path.normcase(pl.path.normpath(path))
	local abs_path = pl.path.normcase(pl.path.normpath(pl.path.join(base, path)))
	local function try_path(path)
		if pl.path.isfile(path) and grequire.extensions[ext(path)] then
			return path
		end

		for ext, loader in pairs(grequire.extensions) do
			if pl.path.isfile(path .. '.' .. ext) then
				return path .. '.' .. ext
			end
		end
	end
	return try_path(abs_path) or try_path(pl.path.join(abs_path, 'index')) or try_path(pl.path.join(abs_path, 'init')) or (function()
		if path:match('^%.%.?/?$') or path:match('^%.%.?/') then return nil end

	end)()
end
function grequire.require(require, path)
	local module
	if grequire.cache[path] then
		module = grequire.cache[path]
	else
		local loader = grequire.extensions[ext(path)]
		module = grequire.genmodule(pl.path.dirname(path))
		module.exports, err = loader(path, module)
		if module.exports == nil and err then error(err) end
	end
	return module
end

function grequire.genmodule(base)
	local module = {
		load = grequire.load;
		cache = grequire.cache;
		extensions = grequire.extensions;
		base = base;
	}
	setmetatable(module, {__call = function(self, path)
		local rpath = grequire.resolve(module.base, path)
		if rpath then
			return grequire.require(module, rpath).exports
		else
			return _G.require(path)
		end
	end})
	function module.resolve(path)
		return grequire.resolve(module.base, path)
	end
	module.env = setmetatable({
		module = module;
		require = module;
	}, { __index = _G })
	return module
end

return function(base)
	if type(base) ~= 'string' then
		local info = debug.getinfo(2, 'S')
		if info.source:sub(1, 1) ~= '@' then error('bad location') end
		base = pl.path.normcase(pl.path.normpath(pl.path.join(pl.path.currentdir(), info.source:sub(2), '..')))
	end
	return grequire.genmodule(base)
end
