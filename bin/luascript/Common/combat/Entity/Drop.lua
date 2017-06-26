---------------------------------------------------
-- auth： panyinglong
-- date： 2016/11/15
-- desc： 副本掉落品
---------------------------------------------------
local Vector3 = Vector3

local CreateDropBehavior = require "Logic/Entity/Behavior/DropBehavior"

local msg_pack
if not GRunOnClient then
	msg_pack = require "basic/message_pack"
end

local parameterScheme = GetConfig("common_parameter_formula")
local Toy = require "Common/combat/Entity/Toy"
local Drop = ExtendClass(Toy)
local dropScale  = 0.5  --正常比例

-- 物体，移动不受navmesh约束
function Drop:__ctor(scene, data)
	self.entityType = EntityType.Drop
	if not GRunOnClient then
		self.create_proxy_flag = true
		self.data.property = {[14] = 0}
	end

	self.autoPickTime = data.create_time + parameterScheme.Parameter[29].Parameter	-- 自动拾取时间
	self.pickDistance = parameterScheme.Parameter[28].Parameter/100					-- 拾取物品最大距离	
	self.protectTime = data.create_time + parameterScheme.Parameter[30].Parameter	-- 组队物品掉落，所属权保护时间，单位（秒）
	self.disappearTime = data.create_time + parameterScheme.Parameter[31].Parameter -- 消失的时间

	self.canPick = true
end

function Drop:Born()
	Toy.Born(self)
	self.behavior = CreateDropBehavior(self)
end

function Drop:OnDestroy()
	Toy.OnDestroy(self)
end

function Drop:GetClientNeedInfo()
	local data = {}
    data.entity_id = self.data.entity_id
    data.owner_id = self.data.owner_id	-- 如果是个人的话，owner_id 就是个人的actor_id，如果是队伍的话，owner_id 就是team_id
    data.is_team = self.data.is_team	-- 是否是队伍
    data.item_id = self.data.item_id
    data.count = self.data.count
    data.create_time = self.data.create_time
    data.entity_type = self.entityType
    data.create_x = math.floor((self.data.create_x or 0) * 100)
    data.create_y = math.floor((self.data.create_y or 0)* 100)
    data.create_z = math.floor((self.data.create_z or 0)* 100)
	return msg_pack.pack(data)
end

return Drop
