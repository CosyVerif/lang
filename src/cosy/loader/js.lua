if #setmetatable ({}, { __len = function () return 1 end }) ~= 1
then
  error "Cosy requires Lua >= 5.2 to run."
end

return function (options)

  options = options or {}
  local loader = {}
  for k, v in pairs (options) do
    loader [k] = v
  end

  local global   = _G or _ENV

  loader.home    = "/"
  loader.prefix  = "/"
  loader.js      = global.js

  local modules  = setmetatable ({}, { __mode = "kv" })
  loader.request = function (url, allow_yield)
    local request = loader.js.new (loader.js.global.XMLHttpRequest)
    local co      = loader.scheduler and loader.scheduler.running ()
    if allow_yield and co then
      request:open ("GET", url, true)
      request.onreadystatechange = function ()
        if request.readyState == 4 then
          loader.scheduler.wakeup (co)
        end
      end
      request:send (nil)
      loader.scheduler.sleep (-math.huge)
    else
      request:open ("GET", url, false)
      request:send (nil)
    end
    if request.status == 200 then
      return request.responseText, request.status
    else
      return nil, request.status
    end
  end
  table.insert (package.searchers, 2, function (name)
    local url = "/lua/" .. name
    local result, err = loader.request (url)
    if not result then
      error (err)
    end
    return load (result, url)
  end)
  loader.require = require
  loader.load    = function (name)
    if modules [name] then
      return modules [name]
    end
    local module   = loader.require (name) (loader) or true
    modules [name] = module
    return module
  end

  loader.coroutine = loader.require "coroutine.make" ()
  loader.logto     = true
  loader.scheduler = {
    _running  = nil,
    waiting   = {},
    ready     = {},
    coroutine = loader.coroutine,
    timeout   = {},
  }
  function loader.scheduler.running ()
    return loader.scheduler._running
  end
  function loader.scheduler.addthread (f, ...)
    local co = loader.scheduler.coroutine.create (f)
    loader.scheduler.ready [co] = {
      parameters = { ... },
    }
    if loader.scheduler.co and coroutine.status (loader.scheduler.co) == "suspended" then
      coroutine.resume (loader.scheduler.co)
    end
  end
  function loader.scheduler.removethread (co)
    if loader.scheduler.timeout [co] then
      loader.js.global:clearTimeout (loader.scheduler.timeout [co])
    end
    loader.scheduler.waiting [co] = nil
    loader.scheduler.ready   [co] = nil
    loader.scheduler.timeout [co] = nil
  end
  function loader.scheduler.sleep (time)
    time = time or -math.huge
    local co = loader.scheduler.running ()
    if time > 0 then
      loader.scheduler.timeout [co] = loader.js.global:setTimeout (function ()
        loader.js.global:clearTimeout (loader.scheduler.timeout [co])
        loader.scheduler.timeout [co] = nil
        loader.scheduler.waiting [co] = nil
        loader.scheduler.ready   [co] = true
        if coroutine.status (loader.scheduler.co) == "suspended" then
          coroutine.resume (loader.scheduler.co)
        end
      end, time * 1000)
    end
    if time ~= 0 then
      loader.scheduler.waiting [co] = true
      loader.scheduler.ready   [co] = nil
      loader.scheduler.coroutine.yield ()
    end
  end
  function loader.scheduler.wakeup (co)
    loader.js.global:clearTimeout (loader.scheduler.timeout [co])
    loader.scheduler.timeout [co] = nil
    loader.scheduler.waiting [co] = nil
    loader.scheduler.ready   [co] = true
    coroutine.resume (loader.scheduler.co)
  end
  function loader.scheduler.loop ()
    loader.scheduler.co = coroutine.running ()
    while true do
      for to_run, t in pairs (loader.scheduler.ready) do
        if loader.scheduler.coroutine.status (to_run) == "suspended" then
          loader.scheduler._running = to_run
          local ok, err = loader.scheduler.coroutine.resume (to_run, type (t) == "table" and table.unpack (t.parameters))
          loader.scheduler._running = nil
          if not ok then
            loader.js.global.console:log (err)
          end
        end
      end
      for co in pairs (loader.scheduler.ready) do
        if loader.scheduler.coroutine.status (co) == "dead" then
          loader.scheduler.waiting [co] = nil
          loader.scheduler.ready   [co] = nil
        end
      end
      if  not next (loader.scheduler.ready  )
      and not next (loader.scheduler.waiting) then
        loader.scheduler.co = nil
        return
      elseif not next (loader.scheduler.ready) then
        coroutine.yield ()
      end
    end
  end

  loader.load "cosy.string"

  return loader

end
