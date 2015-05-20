local version = tonumber (_VERSION:match "Lua%s*(%d%.%d)")
if version < 5.1
or (version == 5.1 and type (_G.jit) ~= "table") then
  error "Cosy requires Luajit >= 2 or Lua >= 5.2 to run."
end

local Loader = {}

function Loader.__index (_, key)
  return require ("cosy." .. key)
end

function Loader.__call (_, key)
  return require (key)
end

local loader = setmetatable ({}, Loader)

if _G.js then
  package.loaded ["cosy.loader"] = loader
  loader.loadhttp = function (url)
    local co, sync = coroutine.running ()
    if not sync then
      local level = 1
      repeat
        local info = debug.getinfo (level, "Sn")
        if info and info.what == "C" then
          sync = true
          break
        end
        level = level + 1
      until not info
    end
    local request = _G.js.new (_G.js.global.XMLHttpRequest)
    request:open ("GET", url, not sync)
    local result, err
    request.onreadystatechange = function (event)
      if request.readyState == 4 then
        if request.status == 200 then
          result = request.responseText
        else
          err    = event.target.status
        end
        if not sync then
          coroutine.resume (co)
        end
      end
    end
    if sync then
      _G.js.global.console:log ("XMLHttpRequest is used in synchronous mode for: " .. url)
      request:send (nil)
    else
      request:send (nil)
      coroutine.yield ()
    end
    if result then
      return result
    else
      error (err)
    end
  end
  table.insert (package.searchers, 2, function (name)
    local url = "/lua/" .. name
    local result, err
    result, err = loader.loadhttp (url)
    if not result then
      error (err)
    end
    return load (result, url)
  end)
  loader.hotswap   = require "hotswap" .new {}
else
  loader.scheduler = require "copas.ev"
  loader.scheduler.make_default ()
  loader.hotswap   = require "hotswap.ev" .new {
    loop = loader.scheduler._loop,
  }
end

do
  package.preload.bit32 = function ()
    loader.logger.warning {
      _       = "fixme",
      message = "global bit32 is created for lua-websockets",
    }
    _G.bit32         = require "bit"
    _G.bit32.lrotate = _G.bit32.rol
    _G.bit32.rrotate = _G.bit32.ror
    return _G.bit32
  end

  _G.require = function (name)
    return loader.hotswap.require (name)
  end

  require "cosy.string"
end

return loader
