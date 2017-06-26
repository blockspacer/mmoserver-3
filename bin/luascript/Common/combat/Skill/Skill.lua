---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： Skill
---------------------------------------------------

require "Common/combat/Skill/SkillManager"


local SceneObject = require "Common/basic/SceneObject2"
local Skill = ExtendClass(SceneObject)

local config = GetConfig("growing_skill")

function Skill:__ctor(scene, skill_id, data)
    
    local skill_data = config.Skill[tonumber(skill_id)]

    -- skill_name
	self.skill_id = skill_id
	self.skill_name = skill_id

	-- 所有者
	self.owner = data.owner
	-- 技能等级
    self.level = data.level or 1
	-- 技能当前槽位
	self.slot_id = data.slot_id
	-- 图标
	self.Icon = 'SkillIcons/'..skill_data.Icon
	--print(self.skill_id, ' icon:', self.Icon)
	-- 逻辑类型
	self.skill_type = tostring(skill_data.logicID)
	-- 默认物理攻击
	if skill_data.DamageType == 2 then
		self.damage_mode = AttackMode.Magic
	else
		self.damage_mode = AttackMode.Physic
	end
	-- 默认不无视 闪避
	self.ignore_miss = false
	-- 目标 防御 加成（一般是削减）
	self.target_defence_percent = 1
	-- 自身 暴击 加成
	self.self_crit_percent = 1
	
	self.param = skill_data
	self.skill_data = skill_data

	self:SetParamData()

	-- 剩余冷却时间
	self.cd_left = 0
	-- 前摇时间
	local duration_time = tonumber(skill_data.Durationtime)
	if duration_time then
		self.cast_start_time = duration_time / 1000
	else
		for tmp_time in string.gmatch(skill_data.Durationtime, 'A|(%d+)') do 
			self.cast_start_time = tmp_time / 1000
		end
	end
	
	-- ShokeID
	self.ShockID = skill_data.ShockID
	self.ShockTime = skill_data.ShockTime

	self.Bullet = skill_data.Bullet

	-- 施法时间
	if skill_data and skill_data.Castingtime >= 0 then
		self.cast_channel_time = skill_data.Castingtime / 1000
	end
	-- 目标类型
	self.cast_target_type = CastTargetType.CAST_TARGET_NONE
	-- 当前技能阶段
	self.cur_skill_stage = SkillStage.SKILL_UNSTARTED
	-- 是否是被动技能
	self.passive_skill = false
	-- 耗魔
	self.NeedMp = skill_data.NeedMp
	-- 是否可以被打断
	self.can_break = skill_data.CanBreak == 1
	-- 弹道是否打主人
	self.bullet_hit_master = false
	-- 弹道是否打地板
	self.bullet_hit_location = false
end

function Skill:SetParamData()
	-- 冷却时间 和 施法距离直接读表
	if self.param then
		self.cd = self.param.CD / 1000
		self.common_cd = self.param.CommonCD / 1000
		self.cast_distance = self.param.Distance

		for angle, radius in string.gmatch(self.param.SkillRange, 'A|a=(%d+)|r=(%d+)') do 
			self.area_angle = tonumber(angle)
			self.area_radius = tonumber(radius)
			if self.area_angle ~= 360 then
				self.area_type = EnumUnitsAreaType.Sector
			else
				self.area_type = EnumUnitsAreaType.Circle
			end
		end

		for height, width in string.gmatch(self.param.SkillRange, 'B|%[(%d+),(%d+)%]') do
			self.area_height = tonumber(height)
			self.area_width = tonumber(width) 
			self.area_type = EnumUnitsAreaType.Rectangle
		end
		--print(self.area_angle, self.area_radius, self.area_height, self.area_width)
	else
		self.cd = self.cd or 1
		self.common_cd = self.common_cd or 0
		self.cast_distance = self.cast_distance or 1
	end
end

function Skill:GetRangeParams()
	if self.area_type ~= nil then
		return 
		{
            area_type = self.area_type,
            angle = self.area_angle,
            radius = self.area_radius,
            width = self.area_width,
            height = self.area_height,
        }
	end

	return nil
end

function Skill:GetPara(index)

	local para = SkillAPI.GetSkillPara(self.skill_id, index, self.level)

	for _, buff in pairs(self.owner.skillManager.buffs) do
		--print(buff.buff_name)
		if type(buff.ChangeSkillPara) == 'function' then 
			--print(buff.buff_name, 'OnTakeDamage')
			para = buff:ChangeSkillPara(para, self.skill_id, index)
		end
	end

	return para
end

-- skill被添加到单位上时
function Skill:OnAdd()
	self:AddListener()
end

function Skill:AddListener()
	self.owner.eventManager.event.AddListener('OnTakeDamage', self.OnTakeDamage, self)
end

function Skill:RemoveListener()
	self.owner.eventManager.event.RemoveListener('OnTakeDamage', self.OnTakeDamage, self)
end

-- 主人被伤害的时候
function Skill:OnTakeDamage(damage, attacker, spell_name, event_type)
end

-- 带Server标志，表示这个函数只能在服务器或者单击模式运行
function Skill:Server_OnBulletHit(target)
	if not GRunOnClient then
		self:OnBulletHit(target)
	end
end

function Skill:OnBulletHit(target)
end

-- 带Server标志，表示这个函数只能在服务器或者单击模式运行
function Skill:Server_OnBulletHitLocation(location)
	if not GRunOnClient then
		self:OnBulletHitLocation(location)
	end
end

function Skill:OnBulletHitLocation(location)
end


-- skill被删除的时候
function Skill:OnRemove()
	self:RemoveListener()
end

function Skill:BreakSkill()
end

-- 如果是联机，就不执行 数值逻辑部分
function Skill:TryOnCastStart(data)
	self:OnEnterCD()
	SkillAPI.ReduceMp(self.owner, self.NeedMp)
    -- 当前技能阶段
	self.cur_skill_stage = SkillStage.SKILL_CAST_START

	if not GRunOnClient then
		self:OnCastStart(data)
	end
end
-- skill开始施法
function Skill:OnCastStart(data)
end

function Skill:TryOnCastChannel(data)
	-- 当前技能阶段
	self.cur_skill_stage = SkillStage.SKILL_CAST_CHANNEL

	if not GRunOnClient then
		self:OnCastChannel(data)
	end
end

-- skill施法中
function Skill:OnCastChannel(data)

end

function Skill:TryOnCastFinish(data)
	-- 当前技能阶段
	self.cur_skill_stage = SkillStage.SKILL_CAST_FINISH

	if not GRunOnClient then
		self:OnCastFinish(data)
	end
end

-- skill施法结束
function Skill:OnCastFinish(data)

end

-- skill tick,主要用来更新冷却时间
function Skill:OnTick(interval)

	if GRunOnClient and UnityEngine.Application.isEditor then
		self:SetParamData()
	end

    if self.cd_left > 0.00001 then
    	self.cd_left = self.cd_left - interval
    	if self.cd_left < 0.00001 then
    		self:OnCDReady()
    	end
    end
end

-- 进入CD
function Skill:OnEnterCD()

    if GRunOnClient then
        require "Logic/GoldenFingerManager"
        if not GoldenFingerManager.NoCDMode then
		    self.cd_left = self.cd
		    self.owner.skillManager.common_cd_left = self.common_cd
	    end
    else
        self.cd_left = self.cd
		self.owner.skillManager.common_cd_left = self.common_cd
    end
    
end

-- 让技能进入冷却状态
function Skill:SetFullCD()
	self.cd_left = self.cd
end

-- 刷新CD
function Skill:RefreshCD()
	self.cd_left = 0
	--print(self.skill_id,'刷新CD')
end

function Skill:IsInCD()
	if not GRunOnClient and (
		self.owner.entityType == EntityType.Dummy or 
		self.owner.entityType == EntityType.Pet) then
		if self.cd_left >= 0.5 then
			return true
		else
			return false
		end
	else
		if self.cd_left >= 0.00001 then
			return true
		else
			return false
		end

	end
end

function Skill:OnCDReady()
	-- 当前技能阶段
	self.cur_skill_stage = SkillStage.SKILL_UNSTARTED
end

-- 这个函数主要是 AI要使用，判断是否满足条件，来释放这个技能
function Skill:IsFillCondition()
    return true
end

function Skill:GetSkillType()
	return self.skill_type
end

return Skill
