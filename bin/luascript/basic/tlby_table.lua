local ipairs = ipairs
local table_insert = table.insert
local table_remove = table.remove
local table_concat = table.concat
local pairs = pairs
local next = next
local tostring = tostring
local type = type
local string_format = string.format

--------------------------------
--  在一个数组中删除多个元素
-- @param t 目标数组
-- @param removingArr 要删除的多个元素所组成的数组
function table.removeMultiple(t, removingArr)
    local removingHash = {}
    for _, r in ipairs(removingArr) do
        removingHash[r] = true
    end

    for i = #t, 1, -1 do
        if removingHash[t[i]] then
            table_remove(t, i)
        end
    end
end

--判断表是否为空
function table.isEmptyOrNil(t)
    if t==nil or next(t) == nil then
        return true
    end
    return false
end

---------------------------
--将一个表不重复地插入另一个表(仅可用于单层表)
function table.insertTableWithoutRepeat(table_base , table_insert)
    local baseHash = {}
    for _, r in ipairs(table_base) do
        baseHash[r] = true
    end

    for i = 1 , #table_insert do
        if baseHash[table_insert[i]] ~= true then
            table_insert(table_base , table_insert[i])
        end
    end

end

-------------------------
--复制一个表(深度拷贝，可用于嵌套表)
--支持循环引用
function table.copy(root)
    if root == nil then
        return nil
    end
    local clone_root = {}
    local cache = {[root] = clone_root}
    local function step_copy(t, clone_table)
        for i , member in pairs(t) do
            if cache[member] then
                clone_table[i] = cache[member]
            else
                if type(member) == "table" then
                    local clone_member = {}
                    cache[member] = clone_member
                    step_copy(member, clone_member)
                    clone_table[i] = clone_member
                else
                    clone_table[i] = member
                end
            end
        end
        return clone_table
    end
    step_copy(root, clone_root)
    return clone_root
end


-------------------------
--从表中获取一个值，如果获取不到，则返回默认值
function table.get(t, index, default)
    if t == nil or type(t) ~= "table"  then
        return nil
    end

    if t[index] == nil then
        return default
    else
        return t[index]
    end
end

-------------------------
--把表序列化为字符串方便输出
local function table_serialize(tablevalue)
    if type(tablevalue) ~= "table" then
        return tostring(tablevalue)
    end

    -- 记录表中各项
    local container = {}
    for k, v in pairs(tablevalue) do
        -- 序列化key
        local keystr = nil
        if type(k) == "string" then
            keystr = string_format("%s", k)
        elseif type(k) == "number" then
            keystr = string_format("%d", k)
        else
            return nil
        end

        -- 序列化value
        local valuestr = nil
        if type(v) == "string" then
            valuestr = string_format("\"%s\"", tostring(v))
        elseif type(v) == "number" or type(v) == "boolean" then
            valuestr = tostring(v)
        elseif type(v) == "table" then
            valuestr = table_serialize(v)
        end

        if valuestr ~= nil then
            table_insert(container, string_format("%s=%s", keystr, valuestr))
        end
    end
    return string_format("{%s}", table_concat(container, ","))
end
table.serialize = table_serialize

-- 获取离散table的成员数目
function table.getnum(t)
    t = t or {}
    local num = 0
    for i,v in pairs(t) do
        num = num + 1
    end
    return num
end