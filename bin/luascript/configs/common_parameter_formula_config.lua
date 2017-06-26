--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/2/27 0027
-- Time: 9:32
-- To change this template use File | Settings | File Templates.
--

local common_parameter_formula = require "data/common_parameter_formula"
local const = require "Common/constant"

--战斗力公式。a=生命值，b=内力，c=攻击(物攻+法功)，d=防御(物防+法防)，e=对抗属性(命中，闪避等之和)。f=元素攻击，g=元素防御，h=控制抗性，i=忽略控制抗性，j=技能等级之和
local calculate_fight_power = loadstring("return function (a, b,c,d,e,f,g,h,i,j) return "..common_parameter_formula.Formula[10].Formula.." end")()
--装备评分。a=生命值，b=内力，c=攻击(物攻+法功)，d=防御(物防+法防)，e=对抗属性(命中，闪避等之和)。f=元素攻击，g=元素防御。
local calculate_equip_score = loadstring("return function (a, b,c,d,e,f,g) return "..common_parameter_formula.Formula[13].Formula.." end")()
--综合实力。a=人物战力，b=人物灵性，c=最高战力宠物战力和
local calculate_total_power = loadstring("return function (a, b,c,d,e,f,g) return "..common_parameter_formula.Formula[16].Formula.." end")()


local function get_recovery_drug_cd(type)
    if type == const.RECOVERY_DRUG_TYPE.actor_hp then
        return common_parameter_formula.Parameter[41].Parameter
    elseif type == const.RECOVERY_DRUG_TYPE.actor_mp then
        return common_parameter_formula.Parameter[42].Parameter
    elseif type == const.RECOVERY_DRUG_TYPE.pet_hp then
        return common_parameter_formula.Parameter[43].Parameter
    end
    return 20
end

local formula_str = require("data/common_parameter_formula").Formula[14].Formula      --每次杀人获得功勋=int[max（1，杀人获得威望^0.5*0.5）]
formula_str =  "return function (a) return "..formula_str.." end"
local feats_from_kill_formula = loadstring(formula_str)()

formula_str = require("data/common_parameter_formula").Formula[17].Formula      --队员组队经验 a=杀怪exp，b=组队人数
formula_str =  "return function (a, b) return "..formula_str.." end"
local team_member_get_exp = loadstring(formula_str)()

local SERVER_LEVEL_IN_COUNT_NUM = require("data/common_parameter_formula").Parameter[51].Parameter       --服务器等级=排行榜前500（即本参数）人平均等级+修正等级（读ID=52）
local SERVER_LEVEL_REVISE = require("data/common_parameter_formula").Parameter[52].Parameter             --服务器等级对应修正等级
local REFREASH_INTERVAL = require("data/common_parameter_formula").Parameter[50].Parameter * 60000   --排行榜刷新时间
local RANK_LIST_DISPLAY_NUMBER = require("data/common_parameter_formula").Parameter[48].Parameter    --排行榜显示数目
local RANK_LIST_NUMBER = require("data/common_parameter_formula").Parameter[49].Parameter    --排行榜后端计算数目
local HIDE_NAME_CD =  require("data/common_parameter_formula").Parameter[53].Parameter / 10    --隐姓埋名cd时间
local MIN_SERVER_LEVEL = require("data/common_parameter_formula").Parameter[55].Parameter       --服务器最小等级
local LINE_PLAYER_UPPER_LIMIT_A = require("data/common_parameter_formula").Parameter[32].Parameter        --服务器分线玩家数量上限
local LINE_PLAYER_UPPER_LIMIT_B = require("data/common_parameter_formula").Parameter[33].Parameter        --服务器分线玩家绝对数量上限
local LINE_PLAYER_UPPER_LIMIT_FLUENCY = LINE_PLAYER_UPPER_LIMIT_A*0.8                             --流畅上限
local DAILY_REFRESH_HOUR = require("data/common_parameter_formula").Parameter[37].Parameter
local DAILY_REFRESH_MIN = require("data/common_parameter_formula").Parameter[38].Parameter

return {
    get_recovery_drug_cd = get_recovery_drug_cd,
    calculate_fight_power = calculate_fight_power,
    calculate_equip_score = calculate_equip_score,
    feats_from_kill_formula = feats_from_kill_formula,
    calculate_total_power = calculate_total_power,
    team_member_get_exp = team_member_get_exp,

    SERVER_LEVEL_IN_COUNT_NUM = SERVER_LEVEL_IN_COUNT_NUM,
    SERVER_LEVEL_REVISE = SERVER_LEVEL_REVISE,
    REFREASH_INTERVAL = REFREASH_INTERVAL,
    RANK_LIST_DISPLAY_NUMBER = RANK_LIST_DISPLAY_NUMBER,
    RANK_LIST_NUMBER = RANK_LIST_NUMBER,
    HIDE_NAME_CD = HIDE_NAME_CD,
    MIN_SERVER_LEVEL = MIN_SERVER_LEVEL,
    LINE_PLAYER_UPPER_LIMIT_A = LINE_PLAYER_UPPER_LIMIT_A,
    LINE_PLAYER_UPPER_LIMIT_B = LINE_PLAYER_UPPER_LIMIT_B,
    LINE_PLAYER_UPPER_LIMIT_FLUENCY = LINE_PLAYER_UPPER_LIMIT_FLUENCY,
}