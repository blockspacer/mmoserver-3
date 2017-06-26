
local Vector3 = Vector3

require "Common/basic/LuaObject"
require "Common/basic/Timer"

--超出此时间间隔不更新即从仇恨列表移除
local HatredValueClearInterval = GetConfig("common_fight_base").Parameter[58].Value
--除玩家外仇恨因子
local HatredFactor = GetConfig("common_parameter_formula").Parameter[6].Parameter
--仇恨值计算公式
local HatredFormulaStr = GetConfig("common_parameter_formula").Formula[8].Formula		--仇恨值计算公式,a伤害系数，b治疗系数，c职业系数
HatredFormulaStr =  "return function (a, b,c) return "..HatredFormulaStr.." end"
local HatredFormula = loadstring(HatredFormulaStr)()
local SortInterval = 0.5

local HatredManager = ExtendClass()

function HatredManager:__ctor(owner,escapeDistance,scopeDistance,attackType)
	-- 所有者
	self.owner = owner
	self.hatredList = {}
	self.escapeDistance = escapeDistance
    self.scopeDistance = scopeDistance
    self.attackType = attackType
    self.sortTimer = Timer.Repeat(SortInterval,function()
        self:SortHatredList()
    end,0)
end

local function RemoveSortTimer(self)
    if self.sortTimer ~= nil then
        Timer.Remove(self.sortTimer)
        self.sortTimer = nil
    end
end

local function AddToHatredList(self,uid,hatred)
    table.insert(self.hatredList,{uid=uid,hatred_value=hatred,last_refresh_time = os.time(),is_stealthy=false,is_lampoon=false})
    if self.owner == nil then
        return
    end
    local entity = self.owner:GetEntityManager().GetPuppet(uid)
    if entity ~= nil then
        entity:startFightStateTimer(self.owner)
        self.owner:startFightStateTimer(entity)
    end
    self.owner:HatredChanged()
end

--直接设置仇恨值
function HatredManager:SetEntityHatred(uid,value)
    if self.owner == nil then
        return
    end
    if self.owner:IsDied() == true then
        return
    end
	local hatred = value
	local is_add = false
	for i=#self.hatredList,1,-1 do
		if self.hatredList[i].uid == uid then
			self.hatredList[i].hatred_value = hatred
			self.hatredList[i].last_refresh_time = os.time()
			is_add = true
		end
	end
	if is_add == false then
        AddToHatredList(self,uid,hatred)
    end
    self:SortHatredList()
end

--获取最大仇恨值
function HatredManager:GetMaxHatredValue()
	local result = 0
	for i=#self.hatredList,1,-1 do
		if self.hatredList[i].hatred_value > result then
			result = self.hatredList[i].hatred_value
		end
	end
	return result
end

--设置仇恨对象隐身
function HatredManager:SetHatredEntityStealthy(uid)
    if self.owner == nil then
        return
    end
    if self.owner:IsDied() == true then
        return
    end
	for i=#self.hatredList,1,-1 do
		if self.hatredList[i].uid == uid then
			self.hatredList[i].is_stealthy = true
		end
    end
    self:SortHatredList()
end

--获取对某对象仇恨值
function HatredManager:GetEntityHatredValue(uid)
	for i=#self.hatredList,1,-1 do
		if self.hatredList[i].uid == uid then
			return self.hatredList[i].hatred_value
		end
    end
    return 0
end

function HatredManager:UpdateDamageHatred(damage,attacker)
    if self.owner:IsDied() == true then
        return
    end
    if attacker == nil then
        return 
    end

	local factor = HatredFactor
	if attacker.entityType == EntityType.Hero or attacker.entityType == EntityType.Dummy then
		local vocation_config = GetConfig('system_login_create').RoleModel[attacker.data.vocation]
		if vocation_config ~= nil then
			factor = vocation_config.hatred
		end
	end
	factor = factor / 100
	local hatred = HatredFormula(damage,0,factor)
	local is_add = false
    for i=#self.hatredList,1,-1 do
        if self.hatredList[i].uid == attacker.uid then
            self.hatredList[i].hatred_value = self.hatredList[i].hatred_value + hatred
            self.hatredList[i].last_refresh_time = os.time()
            is_add = true
        end
    end
    if is_add == false then
        AddToHatredList(self,attacker.uid,hatred)
    end
end

function HatredManager:UpdateCureHatred(cure,curer)
    if self.owner:IsDied() == true then
        return
    end
    if curer == nil then
        return 
    end
    
	local curer_index = 0
	for i=#self.hatredList,1,-1 do
		if self.hatredList[i].uid == curer.uid then
			curer_index = i
		end
	end

	--不在仇恨列表里治疗不用加仇恨值
	if curer_index == 0 then
		return
	end

	local factor = HatredFactor
	if curer.entityType == EntityType.Hero or curer.entityType == EntityType.Dummy then
		local vocation_config = GetConfig('system_login_create').RoleModel[curer.data.vocation]
		if vocation_config ~= nil then
			factor = vocation_config.hatred
		end
	end
	factor = factor / 100
	local hatred = HatredFormula(0,cure,factor)
	self.hatredList[curer_index].hatred_value = self.hatredList[curer_index].hatred_value + hatred
	self.hatredList[curer_index].last_refresh_time = os.time()
end

local function CheckHatredEntityValid(self,index,current_time)
    if self.owner == nil then
        return false
    end

    --长时间仇恨值没有更新
    if current_time - self.hatredList[index].last_refresh_time > HatredValueClearInterval then
        return false
    end
    local entity = self.owner:GetEntityManager().GetPuppet(self.hatredList[index].uid)
    --已不再此场景
    if entity == nil then
        return false
    end
    --已死亡
    if entity:IsDied() then
        return false
    end
    --超出范围
    if not Vector3.InDistance(entity:GetPosition(),self.owner:GetBornPosition(), self.escapeDistance) then
        return false
    end
end

--增加巡逻范围的人物和宠物仇恨值
local function CheckEntityScopeDistance(self)
    if self.owner == nil then
        return
    end
    if self.owner:IsDied() then
        return
    end

    local pupets = self.owner:AOIQueryPuppets(function(v)
        if v.uid ~= self.owner.uid and self.owner:IsEnemy(v) then
            if Vector3.InDistance(v:GetPosition(),self.owner:GetPosition(), self.scopeDistance) and 
                Vector3.InDistance(v:GetPosition(),self.owner:GetBornPosition(), self.escapeDistance) then
                return true
            end
        end
        return false
    end)

    for _,puppet in pairs(pupets) do
        local is_add = true
        for j=1,#self.hatredList,1 do
            if puppet.uid == self.hatredList[j].uid then
                is_add = false
                self.hatredList[j].hatred_value = self.hatredList[j].hatred_value + 1
                self.hatredList[j].last_refresh_time = os.time()
                break
            end
        end
        if is_add == true then
            AddToHatredList(self,puppet.uid,1)
        end
    end
end

function HatredManager:SortHatredList()
	local current_time = os.time()
    local is_remove = false
	for i=#self.hatredList,1,-1 do
        if CheckHatredEntityValid(self,i,current_time) == false then
            table.remove(self.hatredList,i)
            is_remove = true
        end
    end

    if self.attackType == 1 then
        CheckEntityScopeDistance(self)
    end

    if is_remove then
        self.owner:HatredChanged()
    end

	if #self.hatredList < 2 then
		return
	end
	table.sort(self.hatredList,function(a,b)
        --隐身效果优先
        if a.is_stealthy == true then
            return false
        elseif b.is_stealthy == true then
            return true
        elseif a.lampoon == true and b.lampoon == true then
            --都是嘲讽比较仇恨值
            return b.hatred_value < a.hatred_value
        elseif a.lampoon == true then
            return true
        elseif b.lampoon == true then
            return false
        else
            --都是嘲讽比较仇恨值
		    return b.hatred_value < a.hatred_value
        end
	end)
end

function HatredManager:GetCurrentHatredEntity()
	if #self.hatredList == 0 then
		return nil
    end
    if self.owner == nil then
        return nil
    end
	local current_time = os.time()
	for i=1,#self.hatredList,1 do
		repeat
            if CheckHatredEntityValid(self,i,current_time) == false then
                break
            end
            if self.hatredList[i].is_stealthy == true then
                break
            end
			return self.owner:GetEntityManager().GetPuppet(self.hatredList[i].uid)
		until(true)
	end
	return nil
end

function HatredManager:ClearAllHatred()
    self.hatredList = {}
end

function HatredManager:Destroy()
    RemoveSortTimer(self)
end

function HatredManager:IsInHatredList(uid)
    if #self.hatredList == 0 then
		return false
    end
    if self.owner == nil then
        return false
    end
    if self.owner:IsDied() == true then
        return false
    end
    for i=1,#self.hatredList,1 do
		if self.hatredList[i].uid == uid then
            return true
        end
    end
    return false
end

function HatredManager:IsHatredListEmpty()
    if #self.hatredList == 0 then
		return true
    end
    return false
end

function HatredManager:SetLampoon(uid,value)
    for i=1,#self.hatredList,1 do
        if self.hatredList[i].uid == uid then
            self.hatredList[i].lampoon = value
            break
        end
    end
end

function HatredManager:AddHatredValue(uid,value)
    local in_list = false
    for i=1,#self.hatredList,1 do
        if self.hatredList[i].uid == uid then
            self.hatredList[i].hatred_value = self.hatredList[i].hatred_value + value
            self.hatredList[i].last_refresh_time = os.time()
            in_list = true
            break
        end
    end
    if in_list == false then
        AddToHatredList(self,uid,value)
    end
end

function HatredManager:GetHatredListUids()
    local uids = {}
    for i=1,#self.hatredList,1 do
        table.insert(uids,self.hatredList[i].uid)
    end
    return uids
end

function HatredManager:Clear()
    self.owner = nil
    self.hatredList = nil
    self.escapeDistance = nil
    self.scopeDistance = nil
    self.attackType = nil
    RemoveSortTimer(self)
    self.sortTimer = nil
end


return HatredManager