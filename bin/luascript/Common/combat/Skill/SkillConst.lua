---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： SkillManager
---------------------------------------------------

-- 伤害类型
DamageType = 
{
	Miss = 1,
	Crit = 2,
	Block = 3,
	Puncture = 4, 
	Normal = 5,
}

-- buff类型
BuffType = 
{
	-- 增益buff
	Positive = 1,
	-- 减益buff
	Negative = 2,
	-- 控制型buff
	Control = 4,
	-- 不可驱散
	Undispersed = 8,
}

BuffEffectType =
{
	Coexist = 1,
	Mutex = 2,
}

AttackMode = 
{
	Physic = 1,
	Magic = 2,
}

-- 技能的目标类型
CastTargetType = 
{
	-- 无目标
	CAST_TARGET_NONE = 1,
	-- 对敌方释放
	CAST_TARGET_UNIT = 2,
	-- 对某个位置释放
	CAST_TARGET_LOCATION = 4,
	-- 对友方释放
	CAST_TARGET_ALLY = 8,
}

-- 技能槽位
SlotIndex = 
{
	Slot_Attack = 0,
	Slot_Skill1 = 1,
	Slot_Skill2 = 2,
	Slot_Skill3 = 3,
	Slot_Skill4 = 4,
	Slot_Skill5 = 5,
	-- 装备槽位从100开始
	Slot_Equipment1 = 100,
	Slot_Equipment2 = 101,
	Slot_Equipment3 = 102,
	Slot_Equipment4 = 103,
	Slot_Equipment5 = 104,
	Slot_Equipment6 = 105,

	Slot_OfficeSkill = 201,
}

-- 选取单位的范围类型
EnumUnitsAreaType = 
{
	Circle = 0, 
	Rectangle = 1,
	Sector = 2,
}

SkillStage = 
{
	SKILL_UNSTARTED = 1, 	-- 未释放
	SKILL_CAST_START = 2,   -- 前摇
	SKILL_CAST_CHANNEL = 3, -- 施法中
	SKILL_CAST_FINISH = 4,  -- 施法结束
}
