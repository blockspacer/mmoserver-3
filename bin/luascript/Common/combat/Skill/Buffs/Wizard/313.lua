---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： BuffTest
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
require "Common/combat/Skill/Buff"

local buff_name = '313'

local function CreateBuffLocal(data)
	local self = CreateBuff(buff_name, data)
    local base = self.base();

    -- 增益 型buff
    self.buff_type = BuffType.Positive

    self.last_time = data.last_time
    self.DamagePlusPercent = data.DamagePlusPercent

    -- buff覆盖应该做的处理，譬如更新持续时间，或者是buff层数
    self.OnCover = function(data)
        base.OnCover(data)
        self.RefreshRemainTime()
    end
	return self
end

BuffLib[buff_name] = CreateBuffLocal