--------------------------------------------------------------------
-- 文件名:	db_mongo.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/11/22
-- 描  述:	mongo 数据库交互
--------------------------------------------------------------------

--local user_manage = require "login_server/user_manage"
local get_callback_id = require("idmanager").get_callback_id
local flog = require "basic/log"

local callback_hash = {}

local function _print_function_info(func)
    local info = debug.getinfo(func)
    flog("info", info.source.." line: "..info.linedefined)
end

local function db_insert_doc(user_param, callback, collection_name, data)
    flog("info", "db_insert_doc "..collection_name)
    _print_function_info(callback)

    local callback_id = get_callback_id()
    callback_hash[callback_id] = {user_param = user_param, callback = callback }
    data = _bson_encode(data)
    _insert_doc(collection_name,  data , callback_id)
end

local function db_find_one(user_param, callback, collection_name, query, fields)
    flog("info", "db_find_one "..collection_name)
    _print_function_info(callback)

    local callback_id = get_callback_id()
    callback_hash[callback_id] = {user_param = user_param, callback = callback }
    query = _bson_encode(query)
    fields = _bson_encode(fields)
    _find_one(collection_name, query, fields, callback_id)
    flog("info","db_find_one callback_id "..callback_id)
    return callback_id
end

local function db_find_n(user_param, callback, collection_name, query, fields)
    flog("info", "db_find_n "..collection_name)
    _print_function_info(callback)
    local callback_id = get_callback_id()
    callback_hash[callback_id] = {user_param = user_param, callback = callback }
    query = _bson_encode(query)
    fields = _bson_encode(fields)
    _find_n(collection_name, query, fields, callback_id)
    return callback_id
end

-- 更新数据
-- upsert 如果没有是否添加
-- multi  是否修改多条数据
local function db_update_doc(user_param, callback, collection_name, query, fields, upsert, multi)
    _print_function_info(callback)
    local callback_id = get_callback_id()
    flog("info", string.format("db_update_doc %s %d", collection_name, callback_id))
    callback_hash[callback_id] = {user_param = user_param, callback = callback }
    query = _bson_encode(query)
    fields = _bson_encode(fields)
    _update_doc(collection_name, query, fields, upsert, multi, callback_id)
end

-- 更新数据
-- query 查询
-- update 更新字段
-- upsert 如果没有是否添加
-- fields 返回字段
local function db_find_and_modify(user_param, callback, collection_name, query,update, fields, upsert)
    local callback_id = get_callback_id()
    callback_hash[callback_id] = {user_param = user_param, callback = callback }
    query = _bson_encode(query)
    update = _bson_encode(update)
    fields = _bson_encode(fields)
    _find_and_modify(collection_name, query, update,fields, upsert, callback_id)
    return callback_id
end

-- 插入数据回复
function DBInsertReply(callback_id,  status )
    flog("info", "DBInsertReply "..callback_id)
    local callback_info = callback_hash[callback_id]
    if callback_info == nil then
        flog("error", "DBUpdateReply: no callback_id "..callback_id)
    end
    _print_function_info(callback_info.callback)
    callback_info.callback(callback_info.user_param, status)
    callback_hash[callback_id] = nil
end

-- 查询数据
function DBFindOneReply(callback_id, status, doc)
    flog("info", "DBFindOneReply "..callback_id)
    local callback_info = callback_hash[callback_id]
    if callback_info == nil then
        flog("error", "DBFindOneReply: no callback_id "..callback_id)
    end
    _print_function_info(callback_info.callback)
    doc = _bson_decode(doc)
    doc._id = nil
    callback_info.callback(callback_info.user_param, status, doc,callback_id)
    callback_hash[callback_id] = nil
end

-- 查询数据
function DBFindNReply(callback_id, status, docs)
    flog("info", "DBFindNReply "..callback_id)
    local callback_info = callback_hash[callback_id]
    if callback_info == nil then
        flog("error", "DBFindNReply: no callback_id "..callback_id)
    end
    _print_function_info(callback_info.callback)
    local decode_docs = {}
    for i, doc in pairs(docs) do
        decode_docs[i] = _bson_decode(doc)
        decode_docs[i]._id = nil
    end

    callback_info.callback(callback_info.user_param, status, decode_docs,callback_id)
    callback_hash[callback_id] = nil
end

-- 更新数据
function DBUpdateReply(callback_id,  status )
    flog("info", "DBUpdateReply "..callback_id)
    local callback_info = callback_hash[callback_id]
    if callback_info == nil then
        flog("error", "DBUpdateReply: no callback_id "..callback_id)
    end
    _print_function_info(callback_info.callback)
    callback_info.callback(callback_info.user_param, status)
    callback_hash[callback_id] = nil
end

-- 查询更新数据
function DBFindAndModifyReply(callback_id, status, doc)
    flog("info", "DBFindAndModifyReply "..callback_id)
    local callback_info = callback_hash[callback_id]
    if callback_info == nil then
        flog("error", "DBFindAndModifyReply: no callback_id "..callback_id)
    end
    _print_function_info(callback_info.callback)
    doc = _bson_decode(doc)
    doc._id = nil
    callback_info.callback(callback_info.user_param, status, doc,callback_id)
    callback_hash[callback_id] = nil
end

return
{
    db_insert_doc = db_insert_doc,
    db_find_one = db_find_one,
    db_update_doc = db_update_doc,
    db_find_n = db_find_n,
    db_find_and_modify=db_find_and_modify,
}