---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： Buff
---------------------------------------------------

require "Common/basic/Bit"
require "Common/basic/Timer"
require "Common/combat/Skill/SkillConst"


local SceneObject = require "Common/basic/SceneObject2"
local Buff = ExtendClass(SceneObject)

local config = GetConfig("growing_skill")

function Buff:__ctor(scene, buff_id, data)
    --print('__ctor:', buff_id, 'level', data.level)
    local buff_data = config.Buff[tonumber(buff_id)]

    self.data = data
    self.buff_data = buff_data
    -- owner
    self.owner = data.owner
    -- 来源
    self.source = data.source
    -- timer
    self.timer = nil
    -- buff名称
    self.buff_id = buff_id
    -- buff作用间隔
    self.pulse_interval = 0.2
    -- buff持续时间
    if buff_data.time < 0 then
        self.last_time = 100000000
    else
        self.last_time = buff_data.time / 1000
    end
    -- buff层数
    if buff_data.number == 0 then
        self.max_count = 1
    else
        self.max_count = buff_data.number
    end
    -- buff层数
    self.count = 1
    -- buff类型
    self.buff_type = 0
    -- buff等级
    self.level = data.level or 1
    -- 是否公共buff
    self.public = buff_data.public
    -- 1，2，3，4类型
    self.type = buff_data.type
    -- 优先级
    self.PRI = buff_data.PRI
    -- 类别
    self.class = buff_data.class
    -- Icon
    if buff_data.Icon ~= '0' and buff_data.Icon ~= '' then
        self.Icon = buff_data.Icon
    end
    -- IconPRI
    self.IconPRI = buff_data.IconPRI

    if buff_data.clear ~= 1 then
        self:AddProperty(BuffType.Undispersed)
    end

    -- buffEffectType 处理
    if buff_data.EffectType == 'A' then
        self:AddProperty(BuffType.Positive)
    elseif buff_data.EffectType == 'B=1' then
        self:AddProperty(BuffType.Negative)
    else
        self:AddProperty(bit:_or(BuffType.Negative, BuffType.Control))
    end

    -- BuffEffectPRI
    if buff_data.EffectPRI == 'A' then
        self.buff_effect_type = BuffEffectType.Coexist
    else
        self.buff_effect_type = BuffEffectType.Mutex
        for pri in string.gmatch(buff_data.EffectPRI, 'B=(%d+)') do
            self.buff_effect_pri = pri
        end
    end

    -- BuffEffect
    self.buff_effect = buff_data.EffectName
    self.EffectLocation = buff_data.EffectLocation
    self.Buff_cleanup = buff_data.Buff_cleanup

    -- 是否独立工作
    self.work_independent = false
end

function Buff:IfRemain()
    if self.owner:IsDied() then
        return (self.last_time > 60) and (self.Buff_cleanup == 0)
    end

    return (self.last_time > 60)
end

function Buff:AddProperty(property)
    self.buff_type = bit:_or(self.buff_type, property)
end

function Buff:GetPara(index, key)
    return SkillAPI.GetBuffPara(self.buff_id, index, self.level, self.count, key)
end

function Buff:GetParaInTable(index, key)
    return self:GetPara(index, key)
end

-- buff被添加到单位上时
function Buff:OnAdd()
    self:AddListener()

    self:OnPulse()
     -- buff剩余时间
    self:RefreshRemainTime()
    self.timer = self:GetTimer().Repeat(self.pulse_interval, self.OnPulse, self)
end

function Buff:AddListener()
    self.owner.eventManager.event.AddListener('OnTakeDamage', self.OnTakeDamage, self)
    self.owner.eventManager.event.AddListener('OnCauseDamage', self.OnCauseDamage, self)
end

function Buff:RemoveListener()
    self.owner.eventManager.event.RemoveListener('OnTakeDamage', self.OnTakeDamage, self)
    self.owner.eventManager.event.RemoveListener('OnCauseDamage', self.OnCauseDamage, self)
end

function Buff:OnTakeDamage(damage, attacker, skill_id, event_type)
end

function Buff:OnCauseDamage(damage, victim, skill_id, event_type)
end

-- buff被删除的时候
function Buff:OnRemove()
    self:RemoveListener()
    
    self:GetTimer().Remove(self.timer)
    self.timer = nil
end

-- buff tick,主要用来更新remaining 时间, 更新相关属性
function Buff:OnTick(interval)
    --print("-------Buff OnTick---------")
    self.remain_time = self.remain_time - interval
end

-- buff起作用
function Buff:OnPulse()
    
end

function Buff:RefreshRemainTime()
    self.remain_time = self.last_time
end

-- buff覆盖应该做的处理，譬如更新持续时间，或者是buff层数
function Buff:OnCover(data)
-- TODO buff的叠加跟public有关，等下来写写
    -- 如果是等级比较高的buff，就更新等级
    --print('data.level')
    --print(data.level)
    --print('self.level')
    --print(self.level)
    if data.level > self.level then
        self.level = data.level
        self.count = 1
        self:RefreshRemainTime()
    -- 如果等级小的，直接忽略
    elseif data.level < self.level then
        return false
    else
        if self.max_count > self.count then
            self.count = self.count + 1
        end
        self:RefreshRemainTime()
    end
    return true
end

-- 护盾统一使用这个函数
function Buff:OnTakeDamage(damage)
    return damage
end

return Buff
