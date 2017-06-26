---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： 护盾

--增加【xx属性】*【参数1】的护盾 
---------------------------------------------------
local constant = require "Common/constant"
local attrib_id_to_name = constant.PROPERTY_INDEX_TO_NAME
require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffShield = ExtendClass(Buff)

function BuffShield:__ctor(scene, buff_id, data)
    self.work_independent = true
end

function BuffShield:rechargeShield(data)
    local fix_data = self.buff_data.FixedPara[1]
    self.shield = 0
    if fix_data then
        local attribute_name = attrib_id_to_name[fix_data]
        if self.owner[attribute_name] and self.owner[attribute_name]() then
            self.shield = self.owner[attribute_name]() * self:GetPara(1) / 10000
        end
    end
    
end

-- buff被添加到单位上时
function BuffShield:OnAdd()
    Buff.OnAdd(self)
    self:rechargeShield(self.data)
    self.owner:AddStatus('Shield', self)
end

-- buff被删除的时候
function BuffShield:OnRemove()
    Buff.OnRemove(self)
    self.owner:RemoveStatus('Shield', self)
end

-- 护盾统一使用这个函数
function BuffShield:ChangeTakeDamage(damage)
    damage = damage - self.shield
    if damage >= 0 then
        print('承受伤害:', self.shield)
        self.shield = 0
        self.owner.skillManager:RemoveBuff(self)
        return damage
    else
        print('承受伤害:', damage)
        self.shield = -damage
        return 0
    end
end

function BuffShield:OnCover(data)
    local res = Buff.OnCover(self, data)
    if res then
        self:rechargeShield(data)
    end
end

return BuffShield
