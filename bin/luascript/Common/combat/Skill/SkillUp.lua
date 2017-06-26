---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/11/17
-- desc： SkillUp

-- 技能升级效果，因为 要提前加载，并且计算，所以增加了一个单例类
---------------------------------------------------

require "Common/basic/LuaObject"


local function CreateSkillUp()
    local self = CreateObject()
 
 	self.skill_para = {}

    self.Init = function()
    	local config = GetConfig("growing_skill")
    	for k,v in ipairs( config.SkillUp ) do
    		--print( "v.SkillID, v.lv_lower", v.SkillID, v.lv_lower)
    		if self.skill_para[v.SkillID] == nil then
    			self.skill_para[v.SkillID] = {}
    			self.skill_para[v.SkillID].now_level = v.lv_lower
    			for i = 1,4 do
    				self.skill_para[v.SkillID]["up"..tostring(i)] = v["Para"..tostring(i)]
    				self.skill_para[v.SkillID]["Para"..tostring(i)] = {}
    				self.skill_para[v.SkillID]["Para"..tostring(i)][1] = 0
    			end
    		else
    			for level = self.skill_para[v.SkillID].now_level+1, v.lv_lower do
    				for i = 1,4 do
    					self.skill_para[v.SkillID]["Para"..tostring(i)][level] = 
    						self.skill_para[v.SkillID]["Para"..tostring(i)][level - 1] 
    						+ 
    						self.skill_para[v.SkillID]["up"..tostring(i)]
    				end
    			end

    			self.skill_para[v.SkillID].now_level = v.lv_lower
    			for i = 1,4 do
    				self.skill_para[v.SkillID]["up"..tostring(i)] = v["Para"..tostring(i)]
    			end
    		end

    	end

    	--[[for k,v in pairs(self.skill_para) do
    		for i = 1,80 do
    			print('skill:', k, ' level:', i, 'para1', v['Para1'][i], 'para2', v['Para2'][i])
    		end
    	end]]
    end

    self.GetSkillPara = function(skill_id, level, index)
    	if self.skill_para[skill_id] then
            if self.skill_para[skill_id]["Para"..tostring(index)][level] then
    	        return self.skill_para[skill_id]["Para"..tostring(index)][level]
            else
                return 0
            end
    	end
	end

    self.Init()

    return self
end

SkillUp = SkillUp or CreateSkillUp()

