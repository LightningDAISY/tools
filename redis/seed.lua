if not KEYS[1] or not KEYS[2]then
	return "USAGE: redis-cli --eval seed.lua {FROM NUMBER} {TO NUMBER} {DATABASE NUMBER}"
end

local result = ''

if KEYS[3] and KEYS[3]:len() then
	redis.call("SELECT", KEYS[3])
end

for i=tonumber(KEYS[1]),tonumber(KEYS[2]),1 do
	redis.call("SET", "EXAMPLE" .. i, i)
	result = result .. "SET EXAMPLE" .. i .. ' ' .. i .. " "
end

return(result)
