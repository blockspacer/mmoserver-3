---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： SkillManager
---------------------------------------------------
require "Common/basic/LuaObject"
require "Common/basic/Bit"
require "Common/basic/table"
local TickObject = require "Common/basic/TickObject"
require "Common/basic/Timer"
local constant = require "Common/constant"
local SyncManager = require "Common/SyncManager"


BuffLib = {}

local config = GetConfig("growing_skill")

local BuffManager = ExtendClass(TickObject)

function BuffManager:__ctor(scene, owner)
	-- 所有者
	self.owner = owner
	self.buffs = {}
	self.buff_effects = {}
end

function BuffManager:AddBuffFromSkill(buff_id, skill)
	return self:AddBuff(buff_id, 
		{
        owner = self.owner,
        source = skill.owner, 
        skill = skill,
        level = skill.level,
        })
end
	
-- 添加buff
function BuffManager:AddBuff(buff_id, data)
	if self.owner:IsDied() or self.owner:IsDestroy() then
		return 
	end
	if buff_id == '0' or buff_id == '' then
		return
	end
	-- 同步 buff到 客户端
	SyncManager.SC_AddBuff( self.owner, buff_id, data)

	if data == nil then
		data = {}
	end
	data.owner = self.owner
	--默认1级
	data.level = data.level or 1
	data.source = data.source or self.owner -- 如果没有设定来源是谁，就设定是自己

	local buff_data = config.Buff[tonumber(buff_id)]
	if buff_data == nil then
		error('Cant find buff:'..buff_id)
		return 
	end
	local buff_class = require("Common/combat/Skill/Buffs/Common/"..buff_data.class)

	-- 删除 互斥的 Buff
	local pass = self:RemoveMutexBuff(buff_id)
	if not pass then
		return nil
	end

	local exist_buff = self:IfExistBuff(buff_id, data.source)
	if exist_buff then
		exist_buff:OnCover(data)
	else
		exist_buff = buff_class(self.scene, buff_id, data)
		table.insert(self.buffs, exist_buff)
		exist_buff:OnAdd()
	end
	self:AddBuffEffect(exist_buff)

	-- 更新EntityInfo
	self.owner:NeedCalcProperty()
	self.owner:UpdateAOIInfo()

	return exist_buff
end

-- 删除Buff
function BuffManager:RemoveBuff(buff)
	
	self:RemoveBuffByIDAndSource(buff.buff_id, buff.source)

	-- 同步
	SyncManager.SC_RemoveBuff( self.owner, buff)
end

function BuffManager:RemoveBuffByIDAndSource(buff_id, source)
	local exist_buff, index = self:IfExistBuff(buff_id, source)
	if exist_buff then
		self:RemoveBuffEffect(exist_buff)
		exist_buff:OnRemove()
		table.remove(self.buffs, index)
	end

	-- 更新属性
	self.owner:NeedCalcProperty()
	self.owner:UpdateAOIInfo()
end

-- 删除 互斥的 Buff
function BuffManager:RemoveMutexBuff(buff_id)
	local buff_data = config.Buff[tonumber(buff_id)]
	local buff_class = require("Common/combat/Skill/Buffs/Common/"..buff_data.class)
	local tmp = buff_class(self.scene, buff_id, {})
	-- 霸体 免疫一切 减益 控制
	if 	self:FindBuffByClass('SuperArmor') and 
		bit:_and(tmp.buff_type, BuffType.Negative) > 0 and 
		bit:_and(tmp.buff_type, BuffType.Control) > 0 then
		return false
	end
		
	-- 如果产生一个 状态类 buff
	if buff_data.type ~= 0 then
		-- 如果是建筑物就不能添加
		if self.owner.GetElementSceneType and self.owner:GetElementSceneType() == constant.ENTITY_TYPE_COUNTRY_ARCHER_TOWER then
			return false
		end
		local buff = self:GetStatusBuff()
		if buff == nil or buff.buff_id == buff_id then
			return true
		else
			if buff_data.PRI > buff.PRI then
				self:RemoveBuff(buff)
				return true
			elseif buff_data.PRI < buff.PRI then
				return false
			else
				if buff_data.time / 1000 > buff.remain_time then
					self:RemoveBuff(buff)
					return true
				else
					return false
				end
			end
		end
	end
	
	return true
end

function BuffManager:GetStatusBuff()
	for _, buff in pairs(self.buffs) do
		if buff.type ~= 0 then
			return buff
		end
	end
	return nil
end

-- 驱散buff
function BuffManager:DisperseBuff(buff_type, num)

	local same_type_buffs = {}
	for buff_id, buff in pairs(self.buffs) do
		if 	bit:_and(buff.buff_type, buff_type) > 0 and 
			bit:_and(buff.buff_type, BuffType.Undispersed) == 0 then
			table.insert(same_type_buffs, buff)
	    end
	end

	local need_delete = table.randomPickMulti(same_type_buffs, num)

	for _,buff in pairs(need_delete) do
		self:RemoveBuff(buff)
	end
end

-- 查找Buff
function BuffManager:FindBuff(buff_id)
	return self:FindBuffByID(buff_id)
end

-- 是否有相同buff要覆盖
function BuffManager:IfExistBuff(buff_id, source)
	local buff_data = config.Buff[tonumber(buff_id)]

	if buff_data == nil then
		print('error, cant find buff_id = ', buff_id)
		return nil
	end
	if buff_data.public == 1 then
		return self:FindBuffByID(buff_id)
	else
		return self:FindBuffByIDUnderSource(buff_id, source)
	end
end

function BuffManager:FindBuffByID(buff_id)
	for index, buff in pairs(self.buffs) do
		if buff.buff_id == buff_id then
			return buff, index
		end
	end
	return nil
end

function BuffManager:FindBuffByIDUnderSource(buff_id, source)
	if source == nil then
		return nil
	end
	for index, buff in pairs(self.buffs) do
		if buff.source.uid == source.uid and 
			buff.buff_id == buff_id then
			return buff, index
		end
	end
	return nil
end

-- 查找某一类buff
function BuffManager:FindBuffByClass(buff_class)
	for index, buff in pairs(self.buffs) do
		if buff.class == buff_class then
			return buff, index
		end
	end
	return nil
end

	-- Tick
function BuffManager:Tick(interval)
	--print("-------BuffManager Tick--------")
	for i = table.getn(self.buffs), 1, -1 do
		local buff = self.buffs[i]
		buff:OnTick(interval)
		if (buff.remain_time < 0) then
			self:RemoveBuff(buff)
		end
	end
end

function BuffManager:ClearBuff()

	for i = table.getn(self.buffs), 1, -1 do
		if self.buffs[i].Buff_cleanup ~= 0 then 
			self:RemoveBuff(self.buffs[i])
		end
	end
	--self.buffs = {}
end
	-- buffmanager被销毁，一般就是这个单位被删除的时候
function BuffManager:OnDestroy()
	for i = table.getn(self.buffs), 1, -1 do
		self:RemoveBuff(self.buffs[i])
	end
	self.buffs = nil
end

function BuffManager:AddBuffEffect(buff)
	if buff.buff_effect_type == BuffEffectType.Mutex then
		if self.buff_effects[buff.buff_effect_pri] then
			local oldbuff = self:FindBuffByID(self.buff_effects[buff.buff_effect_pri].buff_id)
			if oldbuff then
				self:RemoveBuffEffect(oldbuff)
			end
		end
		self.buff_effects[buff.buff_effect_pri] = {}
		self.buff_effects[buff.buff_effect_pri].buff_id = buff.buff_id
	end
	if buff.buff_effect ~= '0' and buff.buff_effect ~= '' then
		self.owner:RemoveEffect(buff.buff_effect)
		self.owner:AddEffect(buff.buff_effect, buff.EffectLocation)
	end
end

function BuffManager:RemoveBuffEffect(buff)

	if buff.buff_effect_type == BuffEffectType.Coexist then
		if buff.buff_effect ~= '0' and buff.buff_effect ~= '' then
			self.owner:RemoveEffect(buff.buff_effect)
		end
		return 
	end

	if self.buff_effects[buff.buff_effect_pri] then
		if self.buff_effects[buff.buff_effect_pri].buff_id == buff.buff_id then
			if buff.buff_effect ~= '0' and buff.buff_effect ~= '' then
				self.owner:RemoveEffect(buff.buff_effect)
			end
			self.buff_effects[buff.buff_effect_pri] = nil
		end
		-- 否则早就被删除了
	end
	
end

-- 增加获取PublicBuffInfo的接口，用来做AOI
function BuffManager:GetPublicBuffInfo()
	local info = {}
	for index, buff in ipairs(self.buffs) do
		if buff.public == 1 then
			local tmp = {
				buff_id = buff.buff_id,
				count = buff.count,
				remain_time = math.floor(buff.remain_time * 1000)
			}
			table.insert(info, tmp)
		end
	end
	return info
end

function BuffManager:GetSceneRemainBuffInfo()
	local info = {}
	for index, buff in pairs(self.buffs) do
		if buff:IfRemain() then
			local tmp = {
				buff_id = buff.buff_id,
				count = buff.count,
				end_time = math.floor((_get_now_time_second() + buff.remain_time)* 1000),
				remain_time = math.floor(buff.remain_time * 1000)
			}

			table.insert(info, tmp)
		end
	end
	return info
end

return BuffManager