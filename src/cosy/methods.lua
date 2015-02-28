-- Methods
-- =======

-- This module defines the methods exposed by CosyVerif.
-- Methods use the standard [JSON Web Tokens](http://jwt.io/) to authenticate users.
-- Each method takes two parameters: the decoded token contents,
-- and the request itself.
-- 
-- The `cosy.methods` module returns a table containing several variants
-- of the API:
--
-- * `cosy.methods.Localized` exports them as library functions to be used within
--   the server. The `request` parameter is juste a plain table that is
--   automatically converted to a `Request`. Responses and errors are localized
--   using the locale chosen by the user.
--
-- Internally, the module makes use of `cosy.data` to represent its data,
-- and `redis` to store and retrieve them. Any data or subdata can have
-- an expiration date (either handled by `redis` or by `cosy.data`). After
-- expiration, its value and subdata disappear.

-- The `Methods` table contains all available methods.
local Methods  = {}
-- The `Token` table contains utility functions for JSON Web Tokens.
local Token    = {}
-- The `Utility` table contains the `Redis.transaction` function.
local Redis  = {}
-- The `Parameters` table contains several types of parameters, and defines
-- for each one several checking functions.
local Parameters = {}

-- Dependencies
-- ------------
--
-- This module depends on the following modules:
                      require "cosy.string"
local Platform      = require "cosy.platform"
local Configuration = require "cosy.configuration" .whole
local Internal      = require "cosy.configuration" .internal

-- Methods
-- -------
--
-- Methods use the standard [JSON Web Tokens](http://jwt.io/) to authenticate users.
-- Each method takes two parameters: the decoded token contents,
-- and the request parameters.

-- In order to run the methods, we first have to load some dependencies:
--
-- * the `Platform` (here in test mode);
-- * the `Methods` (localized);
-- * the `Configuration`, with some predefined values, and a reduced expiration
--   delay to reduce the time taken by the tests.
--
--    > Configuration = require "cosy.configuration" .whole
--    > Platform      = require "cosy.platform"
--    > Methods       = require "cosy.methods".Localized
--    > Configuration.data.password.time        = 0.001 -- second
--    > Configuration.token.secret              = "secret"
--    > Configuration.token.algorithm           = "HS256"
--    > Configuration.server.name               = "CosyTest"
--    > Configuration.server.email              = "test@cosy.org"
--    > Configuration.expiration.account        = 2 -- second
--    > Configuration.expiration.validation     = 2 -- second
--    > Configuration.expiration.authentication = 2 -- second
--    ...
--    (...)

-- ### User Creation

function Methods.create_user (_, request)
  -- User creation requires several parameters in its `request`:
  --
  -- * a `username`, that is unique on the server;
  -- * a `password`, that is used to authenticate the user;
  -- * an `email` address, where the validation token is sent.
  request.required = {
    username        = Parameters.username,
    password        = Parameters.password,
    email           = Parameters.email,
  }

  -- Some other parameters are optional:
  --
  -- a `name`, as the user wants it;
  -- a `locale`, that is used to localize all the messages sent back to the user;
  -- a `license_digest`, that corresponds to the license accepted by the user.
  request.optional = {
    name            = Parameters.name,
    locale          = Parameters.locale,
    license_digest  = Parameters.license_digest,
  }

  -- Parameters are checked before going further in the method.
  -- On error, the method raises an error containing the original `request`,
  -- the `reasons` for the failure, and the functions used to check the
  -- parameters.
  Parameters.check (request)

  -- The test below checks that errors are correcly reported:
  --
  --    > local response = Methods.create_user (nil, {
  --    >   username       = nil,
  --    >   password       = true,
  --    >   email          = "username_domain.org",
  --    >   name           = 1,
  --    >   license_digest = "",
  --    >   locale         = "anything",
  --    > })
  --    > print (Platform.table.representation (response))
  --    ...
  --    error: {_="check:error",reasons={...},request={...}}
  --    (...)

  local validation = Token.validation.new  (request)
  local new_token  = Platform.token.encode (validation)
  Redis.transaction ({
    email = Configuration.redis.key.email._ % { email    = request.email    },
    token = Configuration.redis.key.token._ % { token    = new_token        },
    data  = Configuration.redis.key.user._  % { username = request.username },
  }, function (p)
    if p.email then
      error {
        _     = "create-user:email-exists",
        email = request.email,
      }
    end
    if p.data then
      error {
        _        = "create-user:username-exists",
        username = request.username,
      }
    end
    assert (not p.token)
    local expire_at = Platform.time () + Configuration.expiration.account._
    p.data = {
      type        = "user",
      status      = "validation",
      username    = request.username,
      email       = request.email,
      password    = Platform.password.hash (request.password),
      name        = request.name,
      locale      = request.locale or Configuration.locale.default._,
      license     = request.license_digest,
      expire_at   = expire_at,
      access      = {
        public = true,
      },
      contents    = {},
    }
    p.email = {
      expire_at = expire_at,
    }
    p.token = {
      expire_at = expire_at,
    }
  end)
  Redis.transaction ({
    data = Configuration.redis.key.user._ % { username = request.username },
  }, function (p)
    Platform.email.send {
      locale  = p.data.locale,
      from    = {
        _     = "email:new_account:from",
        name  = Configuration.server.name._,
        email = Configuration.server.email._,
      },
      to      = {
        _     = "email:new_account:to",
        name  = p.data.name,
        email = p.data.email,
      },
      subject = {
        _          = "email:new_account:subject",
        servername = Configuration.server.name._,
        username   = p.data.username,
      },
      body    = {
        _          = "email:new_account:body",
        username   = p.data.username,
        validation = new_token,
      },
    }
  end)
end
--    >  local response = Methods.create_user (nil, {
--    >   username       = "username",
--    >   password       = "password",
--    >   email          = "username@domain.org",
--    >   name           = "User Name",
--    >   license_digest = "d41d8cd98f00b204e9800998ecf8427e",
--    > })
--    > print (Platform.table.representation (response))
--    ...
--    {_="method:success",locale="en",success=true}
--    > print (Platform.table.representation (Platform.email.last_sent))
--    ...
--    {body={"email:new_account:body",username="username",validation="?{old_token}"},from={"email:new_account:from",email="test@cosy.org",name="CosyTest"},locale="en",subject={"email:new_account:subject",servername="CosyTest",username="username"},to={"email:new_account:to",email="username@domain.org",name="User Name"}}
--    (...)

--    >  local response = Methods.create_user (nil, {
--    >   username       = "username",
--    >   password       = "password",
--    >   email          = "username@domain.org",
--    >   name           = "User Name",
--    >   license_digest = "d41d8cd98f00b204e9800998ecf8427e",
--    > })
--    ...
--    error: {email="username@domain.org",status="create-user:email-exists"}
--    (...)

--    >  local response = Methods.create_user (nil, {
--    >   username       = "othername",
--    >   password       = "password",
--    >   email          = "username@domain.org",
--    >   name           = "User Name",
--    >   license_digest = "d41d8cd98f00b204e9800998ecf8427e",
--    > })
--    ...
--    error: {email="username@domain.org",status="create-user:email-exists"}
--    (...)

--    >  local response = Methods.create_user (nil, {
--    >   username       = "username",
--    >   password       = "password",
--    >   email          = "othername@domain.org",
--    >   name           = "User Name",
--    >   license_digest = "d41d8cd98f00b204e9800998ecf8427e",
--    > })
--    ...
--    error: {status="create-user:username-exists",username="username"}
--    (...)

--    >  os.execute("sleep 2")
--    > local response = Methods.create_user (nil, {
--    >   username       = "username",
--    >   password       = "password",
--    >   email          = "username@domain.org",
--    >   name           = "User Name",
--    >   license_digest = "d41d8cd98f00b204e9800998ecf8427e",
--    > })
--    > print (Platform.table.representation (response))
--    > print (Platform.table.representation (Platform.email.last_sent))
--    ...
--    {locale="en",success=true}
--    {body={"email:new_account:body",username="username",validation="?{token}"},from={"email:new_account:from",email="test@cosy.org",name="CosyTest"},locale="en",subject={"email:new_account:subject",servername="CosyTest",username="username"},to={"email:new_account:to",email="username@domain.org",name="User Name"}}
--    (...)


function Methods.validate_user (token)
  if token.type ~= "validation" then
    error {
      _ = "validate-user:failure",
    }
  end
  local authentication_token
  local raw_token = Token.raw [token]
  Redis.transaction ({
    email = Configuration.redis.key.email._ % { email    = token.email    },
    token = Configuration.redis.key.token._ % { token    = raw_token      },
    data  = Configuration.redis.key.user._  % { username = token.username },
  }, function (p)
    if not p.data
    or not p.email
    or not p.token
    or p.data.type   ~= "user"
    or p.data.status ~= "validation"
    then
      error {
        _ = "validate-user:failure",
      }
    end
    p.data.expire_at  = nil
    p.data.validation = nil
    p.email.expire_at = nil
    p.token           = nil
    authentication_token = Token.authentication (p.data)
  end)
  return {
    _     = "validate_user:success",
    token = Platform.token.encode (authentication_token),
  }
end
--    >  local response = Methods.validate_user ("!{token}")
--    > print (Platform.table.representation (response))
--    {locale="en",success=true}
--    (...)

--    >  local response = Methods.validate_user ("!{token}")
--    > print (Platform.table.representation (response))
--    error: {status="validate-user:failure"}
--    (...)

--    >  local response = Methods.validate_user ("d41d8cd98f00b204e9800998ecf8427e")
--    > print (Platform.table.representation (response))
--    error: {reason="Invalid token",status="token:error"}
--    (...)


-- Parameters
-- ----------

function Parameters.check (request)
  local reasons  = {}
  local required = request.required
  if required then
    for key, parameter in pairs (required) do
      local value = request [key]
      if value == nil then
        reasons [#reasons+1] = {
          _   = "check:missing",
          key = key,
        }
      else
        for _, f in ipairs (parameter) do
          local ok, reason = f (request)
          if not ok then
            reasons [#reasons+1] = reason
            break
          end
        end
      end
    end
  end
  local optional = request.optional
  if optional then
    for key, parameter in pairs (optional) do
      local value = request [key]
      if value ~= nil then
        for _, f in ipairs (parameter) do
          local ok, reason = f (request)
          if not ok then
            reasons [#reasons+1] = reason
            break
          end
        end
      end
    end
  end
  if #reasons ~= 0 then
    error {
      _       = "check:error",
      reasons = reasons,
      request = request,
    }
  end
end

setmetatable (Parameters, {
  __index = function ()
    assert (false)
  end,
})

function Parameters.new_string (key)
  Internal.data [key] .min_size._ = 0
  Internal.data [key] .max_size._ = math.huge
  Parameters [key] = {}
  Parameters [key] [1] = function (request)
    return  type (request [key]) == "string"
        or  nil, {
              _   = "check:is-string",
              key = key,
            }
  end
  Parameters [key] [2] = function (request)
    return  #(request [key]) >= Configuration.data [key] .min_size._
        or  nil, {
              _     = "check:min-size",
              key   = key,
              count = Configuration.data [key] .min_size._,
            }
  end
  Parameters [key] [3] = function (request)
    return  #(request [key]) <= Configuration.data [key] .max_size._
        or  nil, {
              _     = "check:max-size",
              key   = key,
              count = Configuration.data [key].max_size._,
            }
  end
  return Parameters [key]
end

Parameters.new_string "username"
Parameters.username [#(Parameters.username) + 1] = function (request)
  request.username = request.username:trim ()
  return  request.username:find "^%w+$"
      or  nil, {
            _        = "check:username:alphanumeric",
            username = request.username,
          }
end

Parameters.new_string "password"

Parameters.new_string "email"
Parameters.email [#(Parameters.email) + 1] = function (request)
  request.email = request.email:trim ()
  local pattern = "^.*@[%w%.%%%+%-]+%.%w%w%w?%w?$"
  return  request.email:find (pattern)
      or  nil, {
            _     = "check:email:pattern",
            email = request.email,
          }
end

Parameters.new_string "name"

Parameters.new_string "locale"
Internal.data.locale.min_size = 2
Internal.data.locale.max_size = 5
Parameters.locale [#(Parameters.locale) + 1] = function (request)
  request.locale = request.locale:trim ()
  return  request.locale:find "^%a%a$"
      or  request.locale:find "^%a%a_%a%a$"
      or  nil, {
            _      = "check:locale:pattern",
            locale = request.locale,
          }
end

Parameters.new_string "validation"

Parameters.new_string "license_digest"
Internal.data.license_digest.min_size = 32
Internal.data.license_digest.max_size = 32
Parameters.license_digest [#(Parameters.license_digest) + 1] = function (request)
  request.license_digest = request.license_digest:trim ()
  local pattern = "^%x+$"
  return  request.license_digest:find (pattern)
      or  nil, {
            _              = "check:license_digest:pattern",
            license_digest = request.license_digest,
          }
end


-- Token
--------

Token.raw = setmetatable ({}, { __mode = "kv" })

Token.validation = {}

function Token.validation.new (data)
  local now = Platform.time ()
  return {
    contents = {
      type     = "validation",
      username = data.username,
      email    = data.email,
    },
    iat      = now,
    nbf      = now - 1,
    exp      = now + Configuration.expiration.validation._,
    iss      = Configuration.server.name._,
    aud      = nil,
    sub      = "cosy:validation",
    jti      = Platform.digest (tostring (now + Platform.random ())),
  }
end

Token.authentication = {}

function Token.authentication.new (data)
  local now = Platform.time ()
  return {
    contents = {
      type     = "authentication",
      username = data.username,
    },
    iat      = now,
    nbf      = now - 1,
    exp      = now + Configuration.expiration.authentication._,
    iss      = Configuration.server.name._,
    aud      = nil,
    sub      = "cosy:authentication",
    jti      = Platform.md5.digest (tostring (now + Platform.random ())),
  }
end

-- Utility
-- -------

Redis = {
  pool = {
    created = {},
    free    = {},
  }
}

Internal.redis.key = {
  user  = "user:%{username}",
  email = "email:%{email}",
  token = "token:%{token}",
}

Internal.redis.retry._ = 5

local RwTable = {
  Current  = {},
  Modified = {},
  Within   = {},
}

function RwTable.new (t)
  return setmetatable ({
    [RwTable.Current ] = t,
    [RwTable.Modified] = {},
    [RwTable.Within  ] = false,
  }, RwTable)
end

function RwTable.__index (t, key)
  local found = t [RwTable.Current] [key]
  if type (found) ~= "table" then
    return found
  else
    local within = t [RwTable.Within] or key
    return setmetatable ({
      [RwTable.Current ] = found,
      [RwTable.Modified] = t [RwTable.Modified],
      [RwTable.Within  ] = within,
    }, RwTable)
  end
end

function RwTable.__newindex (t, key, value)
  local within = t [RwTable.Within] or key
  t [RwTable.Modified] [within] = true
  t [RwTable.Current ] [key   ] = value
end

function Redis.transaction (keys, f)
  local client
  while true do
    client = pairs (Redis.pool.free) (Redis.pool.free)
    if client then
      Redis.pool.free [client] = nil
      break
    end
    if #Redis.pool.created < Configuration.redis.pool_size._ then
      if Platform.redis.is_fake then
        client = Platform.redis.connect ()
      else
        local socket    = require "socket"
        local coroutine = require "coroutine.make" ()
        local host      = Configuration.redis.host._
        local port      = Configuration.redis.port._
        local database  = Configuration.redis.database._
        local skt       = Platform.scheduler:wrap (socket.tcp ())
                          :connect (host, port)
        client = Platform.redis.connect {
          socket    = skt,
          coroutine = coroutine,
        }
        client:select (database)
      end
      Redis.pool.created [#Redis.pool.created + 1] = client
      break
    else
      Platform.scheduler:pass ()
    end
  end
  local ok, result = pcall (client.transaction, client, {
    watch = keys,
    cas   = true,
    retry = Configuration.redis.retry_,
  }, function (redis)
    local data = {}
    for name, key in pairs (keys) do
      if redis:exists (key) then
        data [name] = Platform.json.decode (redis:get (key))
      end
    end
    local rw = RwTable.new (data)
    f (rw, client)
    redis:multi ()
    for name in pairs (rw [RwTable.Modified]) do
      local key   = keys [name]
      local value = data [name]
      if value == nil then
        redis:del (key)
      else
        redis:set (key, Platform.json.encode (value))
        if type (value) == "table" and value.expire_at then
          redis:expireat (key, value.expire_at)
        else
          redis:persist (key)
        end
      end
    end
  end)
  Redis.pool.free [client] = true
  if ok then
    return result
  else
    error (result)
  end
end

--[==[

function Methods.license (session, t)
  local parameters = {
    locale = Parameters.locale,
  }
  Backend.localize (session, t)
  Backend.check    (session, t, parameters)
  local license = Platform.i18n.translate ("license", {
    locale = session.locale
  }):trim ()
  local license_md5 = Platform.md5.digest (license)
  return {
    license = license,
    digest  = license_md5,
  }
end

function Methods.authenticate (session, t)
  local parameters = {
    username = Parameters.username,
    password = Parameters.password,
    ["license?"] = Parameters.license,
  }
  Backend.localize (session, t)
  Backend.check    (session, t, parameters)
  session.username = nil
  Backend.pool.transaction ({
    data = "/%{username}" % {
      username = t.username,
    }
  }, function (p)
    local data = p.data
    if not data then
      error {
        status = "authenticate:non-existing",
      }
    end
    if data.type ~= "user" then
      error {
        status = "authenticate:non-user",
      }
    end
    session.locale = data.locale or session.locale
    if data.validation_key then
      error {
        status = "authenticate:non-validated",
      }
    end
    if not Platform.password.verify (t.password, data.password) then
      error {
        status = "authenticate:erroneous",
      }
    end
    if Platform.password.is_too_cheap (data.password) then
      Platform.logger.debug {
        "authenticate:cheap-password",
        username = t.username,
      }
      data.password = Platform.password.hash (t.password)
    end
    local license = Platform.i18n.translate ("license", {
      locale = session.locale
    }):trim ()
    local license_md5 = Platform.md5.digest (license)
    if license_md5 ~= data.accepted_license then
      if t.license and t.license == license_md5 then
        data.accepted_license = license_md5
      elseif t.license and t.license ~= license_md5 then
        error {
          status   = "license:oudated",
          username = t.username,
          digest   = license_md5,
        }
      else
        error {
          status   = "license:reject",
          username = t.username,
          digest   = license_md5,
        }
      end
    end
  end)
  session.username = t.username
end

function Methods.reset_user (session, t)
end

function Methods:delete_user (t)
end

function Methods.metadata (session, t)
end

function Methods:create_project (t)
end

function Methods:delete_project (t)
end

function Methods:create_resource (t)
end

function Methods:delete_resource (t)
end

function Methods:list (t)
end

function Methods:update (t)
end

function Methods:edit (t)
end

function Methods:patch (t)
end


-- 




function Backend.localize (session, t)
  local locale
  if type (t) == "table" and t.locale then
    locale = t.locale
  elseif session.locale then
    locale = session.locale
  else
    locale = Configuration.locale.default._
  end
  session.locale = locale
end

function Backend.check (session, t, parameters)
  for key, parameter in pairs (parameters) do
    local optional = key:find "?$"
    if optional then
      key = key:sub (1, #key-1)
    end
    local value = t [key]
    if value == nil and not optional then
      error {
        status     = "check:error",
        reason     = Platform.i18n.translate ("check:missing", {
           locale = session.locale,
           key    = key,
         }),
        parameters = parameters,
      }
    elseif value ~= nil then
      for _, f in ipairs (parameter) do
        local ok, r = f (session, t)
        if not ok then
          error {
            status     = "check:error",
            reason     = r,
            parameters = parameters,
          }
        end
      end
    end
  end
end


--]==]

local Exported = {}

do
  Exported.Localized = {}
  local function wrap (method)
    return function (raw_token, request)
      local token
      if raw_token then
        local ok, res = pcall (Platform.token.decode, raw_token)
        if ok then
          token = res
          Token.raw [token] = raw_token
        else
          error {
            _      = "token:error",
            reason = res:match "%s*([^:]*)$",
          }
        end
      end
      local response = method (token, request)
      if response == nil then
        response = {
          _ = "method:success",
        }
      end
      response.success = true
      response.locale  = (token and token.locale)
                      or Configuration.locale.default._
      return response
    end
  end
  for k, v in pairs (Methods) do
    Exported.Localized [k] = wrap (v)
  end
end

return Exported