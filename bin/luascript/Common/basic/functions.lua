
local scene_func 

if not GRunOnClient then
    scene_func = require "scene/scene_func"
end

local string_len = string.len
local string_byte = string.byte


function string.split(s, delim)
    if type(delim) ~= "string" or string.len(delim) <= 0 then
        return
    end

    local start = 1
    local t = {}
    while true do
    	local pos = string.find (s, delim, start, true) -- plain find
        if not pos then
          break
        end

        table.insert (t, string.sub (s, start, pos - 1))
        start = pos + string.len (delim)
    end
    table.insert (t, string.sub (s, start))

    return t
end
function string.trim(s) 
    return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

function IsNil(uobj)
    return uobj == nil or uobj:Equals(nil)
end

function RecycleObject(go)
    if IsNil(go) then
        return
    end
    return ObjectPoolManager.RecycleObject(go)
end

function timeFromSeconds(seconds)
    local t = seconds
    local day = math.floor(t/86400)
    t = t - day * 86400

    local hou = math.floor(t/3600)
    t = t - 3600 * hou

    local min = math.floor(t/60)
    t = t - 60 * min

    local sec = math.floor(t)
    return { d = day, h = hou, m = min, s = sec}
end
-- 格式如: 12:06:45，不到1小时则如：06:45
function TimeToStr(seconds)
    local t = timeFromSeconds(seconds)

    local timeStr = ''
    if t.h > 0 then
        timeStr = t.h .. ":"
    end
    timeStr = timeStr .. string.format("%02d", t.m) .. ":" .. string.format("%02d", t.s)
    return timeStr
end

-- 文本
local textTable = GetConfig('common_char_chinese')
local uitext = textTable.UIText
local tabletext = textTable.TableText
function uiText(id)
    if uitext[id] then
        return uitext[id].NR
    else
        return ""
    end
end
function tableText(id)
    if tabletext[id] then
        return tabletext[id].NR
    else
        return ""
    end
end

function string.utf8len(input)
    local len  = string_len(input)
    local left = len
    local cnt  = 0
    local arr  = {0, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc}
    while left ~= 0 do
        local tmp = string_byte(input, -left)
        local i   = #arr
        while arr[i] do
            if tmp >= arr[i] then
                left = left - i
                break
            end
            i = i - 1
        end
        cnt = cnt + 1
    end
    return cnt
end

function GetRandomBornPos(scene, pos, random_size)
    local new_x = pos.x + (math.random()*2-1) * random_size
    local new_z = pos.z + (math.random()*2-1) * random_size
    local legal_pos, res = scene:GetNearestPolyOfPoint(
        {
        x = new_x,
        y = pos.y,
        z = new_z,
        })
    if res then
        return legal_pos
    else
        return pos
    end
end

local function get_now_time_mille()
    if GRunOnClient then
        return 0
    else
        return scene_func.get_now_time_mille()
    end
end

return {
    get_now_time_mille = get_now_time_mille
}
