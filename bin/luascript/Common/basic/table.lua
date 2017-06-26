local log = require "basic/log"
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
            table.remove(t, i)
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

--打印表中所有数据(仅可用于单层表)
function table.printAll(t , name)
    local string = nil
    if name == nil then
        name = "table"
    end

    string = name.." : "
    if table.isEmptyOrNil(t) then
        string = string.."nil"
    else
        for i, v in ipairs(t) do
            string = string..v.." , "
        end
    end
    flog("table/syzDebug" , string)
end


function table.toString(data, title)
    function space(deep) 
        local s = ''
        for i = 1, deep do
            s = s .. '    '
        end
        return s
    end

    function tableToString(t, d)
        local s = "\r\n" .. space(d) .. "{";
        for k, v in pairs(t) do
            local ty = type(v)
            if ty == 'table' then                   
                s = s .. '\r\n' .. space(d + 1) .. k .. ' = ' .. tableToString(v, d + 2)
            elseif ty == 'boolean' or ty == 'number' or ty == 'string' then
                s = s .. '\r\n' .. space(d + 1) .. k .. ' = ' .. tostring(v) .. ','
            end
        end
        s = s ..'\r\n'.. space(d) .. "},"
        return s
    end

    local str = "----" .. (title or "") .. "-----"
    str = str .. tableToString(data, 1)
    str = str .. '\r\n -----end -----'
    return str
end

function table.print(data, title)
    if type(data) == 'table' then
        local str = table.toString(data, title)
        print(str)
    else
        print(data)
    end
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
            table.insert(table_base , table_insert[i])
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
-- 随机删除表里面的某几个(一般为key-value表)
function table.randomDeleteMulti(t, num)
    local need_delete = table.randomPickMulti(t, num)
    table.deleteMultiKV(t, need_delete)
end

-- key-value表 随机选择多个
function table.randomPickMulti(t, num)

    local count = 0
    for k,v in pairs(t) do
        count = count + 1
    end

    if count <= num then
        return t
    end

    local tmp = {}
    for k, v in pairs(t) do 
        table.insert(tmp, k)
    end

    local randoms = {}
    for i = 1, num, 1 do 
        local rand_index = math.random(table.getn(tmp))
        table.insert(randoms, tmp[rand_index])
        table.remove(tmp, rand_index)
    end

    local pick = {}
    for i, k in ipairs(randoms) do 
        pick[k] = t[k]
    end

    return pick
end

-- key-value table删除多个元素 
function table.deleteMultiKV(t, kvs)
    for k, v in pairs(kvs) do 
        t[k] = nil
    end
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
function table.serialize(tablevalue)
    if type(tablevalue) ~= "table" then
        return tostring(tablevalue)
    end

    -- 记录表中各项
    local container = {}
    for k, v in pairs(tablevalue) do
        -- 序列化key
        local keystr = nil
        if type(k) == "string" then
            keystr = string.format("%s", k)
        elseif type(k) == "number" then
            keystr = string.format("[%d]", k)
        else
            return nil
        end

        -- 序列化value
        local valuestr = nil
        if type(v) == "string" then
            valuestr = string.format("\"%s\"", tostring(v))
        elseif type(v) == "number" or type(v) == "boolean" then
            valuestr = tostring(v)
        elseif type(v) == "table" then
            valuestr = table.serialize(v)
        end

        if valuestr ~= nil then
            table.insert(container, string.format("%s=%s", keystr, valuestr))
        end
    end
    return string.format("{%s}", table.concat(container, ","))
end

--表的增量更新, 只更新number, string, bool, table类型
function table.update(base, update)
    if type(base) ~= 'table' or type(update) ~= 'table' then
        return
    end

    for k, v in pairs(update) do
        if type(v) == 'number' or type(v) == 'string' or type(v) == 'boolean' then
            base[k] = v
        elseif type(v) == 'table' then
            if not base[k] then
                base[k] = v
            else
                table.update(base[k], v)
            end
        end
    end
end
