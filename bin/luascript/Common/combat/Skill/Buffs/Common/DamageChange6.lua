---------------------------------------------------
-- auth： wupeifeng
-- date： 2017/02/06
-- desc： 伤害：抵挡x次伤害  



--[[
承担主人所受【参数1万分比】的伤害
]]



---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
require "Common/combat/Skill/Buff"

local Buff = require "Common/combat/Skill/Buff"

local DamageChange6 = ExtendClass(Buff)

function DamageChange6:__ctor(scene, buff_id, data)

end

-- 接受伤害时统一使用这个函数
function DamageChange6:ChangeTakeDamage(damage, skill, attacker)

    local tmp = damage * self:GetPara(1) / 10000
    if self.data.source then
        SkillAPI.MinusHp(self.data.source, tmp, attacker)
    end

    return damage - tmp
end


return DamageChange6

