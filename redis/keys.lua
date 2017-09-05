if not KEYS[1] then
	return "USAGE: redis-cli --eval keys.lua {EXAMPLE*} {DATABASE NUMBER}"
end

local result = ''

if KEYS[2] and KEYS[2]:len() then
	redis.call("SELECT", KEYS[2])
end

local keys = redis.call('KEYS', KEYS[1])

for i,value in ipairs(keys) do
	result = result .. value .. ' '
end

if result:len() > 0 then
	return('matched ' .. result)
else
	return(KEYS[1] .. ' is not matched.')
end

--[[

# 'XX*' is key-pattern like "KEYS XX*"
CLI: redis-cli --eval remove.lua XX*

]]--
