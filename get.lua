local _M = {}

local cuturl = require("cuturl")
local resty_md5 = require "resty.md5"
local resty_str = require "resty.string"

local get_and_sub = function(redis, subject, details)
  -- atomically (wrapped in multi+exec) read state for [details] keys in $subject
  -- NOTE: This leaves redis in a SUBSCRIBE state - use redis:read_reply() to read
  local initial_states = {}
  redis:multi()
  for i = 1, #details do
    -- queue up GETs in multi
    redis:get(details[i])
  end
  for i = 1, #details do
    -- list subscriptions
    redis:subscribe(details[i])
  end
  -- exec queued items
  local queued_items = redis:exec()
  for i = 1, #details do
    -- pull out the responses to the GETs
    initial_states[i] = queued_items[i]
  end
  return initial_states
end

_M.subscribe = function(redis)

  local subject, details = cuturl.sub(ngx.var.uri)
  local initial_states = get_and_sub(redis, subject, details)
  for i = 1, #initial_states do
    ngx.say(initial_states)
  end
  ngx.flush()
  
  local err = nil
  local res

  while not err do
    res, err = redis:read_reply()
    if res then
      ngx.say(res[3])
      ngx.flush()
    else
      if err == "timeout" then
        ngx.log(ngx.ERR, "TIMEOUT")
        break
      else
        ngx.log(ngx.ERR, "OTHER ERROR")
        ngx.log(ngx.ERR, err)
        break
      end
    end
  end
end

_M.poll = function(redis)
  
  
  local subject, details = cuturl.sub(ngx.var.uri)
  local initial_states = get_and_sub(redis, subject, details)
 
  local md5 = resty_md5:new()
  for i = 1, #initial_states do
    -- pull out the responses to the GETs
    md5:update(initial_states[i])
  end
  local digest = md5:final()
  local content_etag = str.to_hex(digest)
  local consumer_etag = ngx.var.http_if_none_match
  -- check etag
  -- check last modified
  
  -- check if none match
  -- check if modified since
end

return _M
