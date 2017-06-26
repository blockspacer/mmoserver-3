--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/1/20 0020
-- Time: 17:46
-- To change this template use File | Settings | File Templates.
--

local common_char_chinese = require "data/common_char_chinese"
local flog = require "basic/log"

local function get_back_text(id)
    if common_char_chinese.BackText[id] == nil then
        return ""
    end
    return common_char_chinese.BackText[id].NR
end

local function get_table_text(id)
    if common_char_chinese.TableText[id] == nil then
        return ""
    end
    return common_char_chinese.TableText[id].NR
end

local TEXT_NAME_TO_ID = {}

local function get_configed_ui_text(text_name, ...)
    local text_id = TEXT_NAME_TO_ID[text_name]
    if text_id == nil then
        flog("error", "get_configed_text fail "..tostring(text_name))
        return
    end
    local ui_tex = common_char_chinese.UIText[text_id].NR
    return string.format(ui_tex, ...)
end


local function reload()
    TEXT_NAME_TO_ID = {
        election_remaining_time = 1135111,
        start_country_total_buff = 1135121,
        start_halo_skill = 1135122,
        start_country_call_together = 1135117,
        start_country_shop_discount = 1135124,
        salary_is_paid = 1135126,
    }
end

reload()

return{
    get_back_text = get_back_text,
    get_table_text = get_table_text,
    reload = reload,
    get_configed_ui_text = get_configed_ui_text,
}

