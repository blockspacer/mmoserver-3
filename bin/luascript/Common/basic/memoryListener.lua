

require "Common/basic/Timer"

local listener = {}

local objRef = {}
setmetatable(objRef, {__mode = "kv"}) 

local timer = nil
local interval = 20

local log = function(str)
	print(str)
end

local printMem = function()
	collectgarbage('collect')
	collectgarbage('collect')
	collectgarbage('collect')
	local c = collectgarbage('count')
	log("----- lua mem:" .. math.floor(c) .. "kb ----- ")
end

local printRef = function()
	collectgarbage('collect')
	collectgarbage("collect")
	collectgarbage("collect")

	log('------------------ object -------------')
	local total = 0
    local leakageNum = 0
	for k, v in pairs(objRef) do
		local item = string.split(v, '|')
		local time = item[1]
		local tag = item[2]
		-- for test
		if SceneManager.GetEntityManager().GetPuppet(k.uid) == nil then
			log('-------- object not free. table:' ..tostring(k) .. ' tag=' .. tag .. ' uid=' .. k.uid .. ' entitytype=' .. k.entityType .. ' name=' .. (k.name or 'noname') .. ' --------')
			_G.findObjectInGlobal(k)
            leakageNum = leakageNum + 1
            if leakageNum > 5 then
                log('未打印全部')
                break
            end
		else
			-- log('-- unit ok uid=' .. k.uid .. ' entitytype=' .. k.entityType .. ' name=' .. (k.name or 'noname'))
		end
		total = total + 1
	end

	log('----- object total num:' .. total .. ' -----')
	-- for tag, num in pairs(tagsNum) do
	-- 	log('tag:' .. tag .. ' num:' .. num)
	-- end
	-- log('-------------\r\n')
end

-- local writeFile = function(filename, str)
-- 	local file = io.open(filename, "w")
-- 	assert(file)
-- 	file:write(str)
-- 	file:close()
-- end

-- local tickNum = 0
-- local tick = function()
-- 	tickNum = tickNum + 1
-- 	log('第' .. (tickNum * interval) .. '秒')
-- 	-- collectgarbage("step")
-- 	-- printMem()
-- 	printRef()
-- end
-- listener.start = function()
-- 	if not timer then
-- 		timer = Timer.RepeatForever(interval, tick)
-- 	end	
-- end

listener.add = function(obj, tag)
	if obj and type(obj) == 'table' then
		objRef[obj] = os.time() .. '|' .. (tag or 'nil')
	end
end
listener.printRef = printRef
listener.printMem = printMem

-- find object 
local findedObjMap = nil   
function _G.findObject(obj, findDest)  
    if findDest == nil then  
        return false  
    end  
    if findedObjMap[findDest] ~= nil then  
        return false  
    end  
    findedObjMap[findDest] = true  
  
    local destType = type(findDest)  
    if destType == "table" then  
        if findDest == _G.CMemoryDebug then  
            return false  
        end  
        for key, value in pairs(findDest) do  
            if key == obj or value == obj then  
                log("Finded Object key=" .. tostring(key) .. ' value=' .. tostring(value))  
                return true  
            end  
            if findObject(obj, key) == true then  
                log("table key")  
                return true  
            end  
            if findObject(obj, value) == true then  
                log("key:["..tostring(key).."]")  
                return true  
            end  
        end  
    elseif destType == "function" then  
        local uvIndex = 1  
        while true do  
            local name, value = debug.getupvalue(findDest, uvIndex)  
            if name == nil then  
                break  
            end  
            if findObject(obj, value) == true then  
                log("upvalue name:["..tostring(name).."]")  
                return true  
            end  
            uvIndex = uvIndex + 1  
        end  
    end  
    return false  
end  
  
function _G.findObjectInGlobal(obj)  
    findedObjMap = {}  
    setmetatable(findedObjMap, {__mode = "k"})  
    _G.findObject(obj, _G)  
end  
return listener