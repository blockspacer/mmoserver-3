--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2016/11/23 0023
-- Time: 20:11
-- To change this template use File | Settings | File Templates.
--

local common_item = GetConfig("common_item")
local common_char_chinese = GetConfig("common_char_chinese")

local table_text = common_char_chinese.TableText
local itemconfigs = common_item.Item

local function GetItemName(id)
    local itemconfig = itemconfigs[id];
    if itemconfig ~= nil then
        if itemconfig.Name ~= 0 then
            return table_text[itemconfig.Name].NR
        else
            return itemconfig.Name1
        end
    end
    return ""
end

local function GetItemDescription(id)
    local itemconfig = itemconfigs[id];
    if itemconfig ~= nil then
        if itemconfig.Description ~= 0 then
            return table_text[itemconfig.Name].NR
        else
            return itemconfig.Description1
        end
    end
    return ""
end

local function GetChineseName( id )
    if id and id ~= '0' and id ~= '' then
        if table_text[id] then
            return table_text[id].NR
        else
            return ''
        end
    else
        return ''
    end
end

return {
    GetItemName = GetItemName,
    GetItemDescription = GetItemDescription,
    GetChineseName = GetChineseName
}