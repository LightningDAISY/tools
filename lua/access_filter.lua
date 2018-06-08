#! /usr/bin/env lua
local redisHostname = "127.0.0.1"
local redisPort     = 6379
local redisSchema   = "2"
local logFilePath   = "/var/www/proxy/logs/app.log"

local redis = require "resty.redis"
local red = redis:new()

function writeLog(str)
	local fp = assert(io.open(logFilePath, 'a'))
	fp:write(str .. "\n")
	fp:close()
end

function redisTest(red)
	ok, err = red:set("dog", "an animal")
	if not ok then
    	writeLog("failed to set dog: " .. err)
		ngx.exit()
    end

	local res, err = red:get("dog")
    if not res then
    	writeLog("failed to get dog: " .. err)
    	ngx.exit()
    end

	return true
end

function connectNewRedis()
	local ok, err = red:connect(redisHostname, redisPort)
	if not ok then
		writeLog("cannot connect the redis " .. redisHostname .. ":" .. redisPort)
		writeLog(err)
		ngx.exit()
	end
end

function runFilters(red)
	-- filters begin
	writeLog("Accessed " .. ngx.var.remote_addr .. " " .. ngx.var.http_user_agent)
	-- filters end
end

function main()
	ok, err = red:select(redisSchema)
	if not ok then
		connectNewRedis()
		ok, err = red:select(redisSchema)
		if not ok then
    		writeLog("cannot select " .. redisSchema .. " " .. err)
			ngx.exit()
		end
	end
	--redisTest(red)
	--runFilters(red)

	--ngx.redirect("https://yahoo.co.jp/", HTTP_MOVED_TEMPORARILY)
	ngx.exit()
	--return ngx.OK
end

return main()

--[[
	#
	# nginx.conf
	#
    location / {
        access_by_lua_file /var/www/libs/lua/access_filter.lua;
 		....
	}

--]]--

