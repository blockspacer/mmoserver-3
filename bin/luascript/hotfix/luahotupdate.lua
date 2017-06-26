local lfs = lfs
local system_type = _system_type()
require "md5.md5"
local sumhexa = md5.sumhexa
local string_format = string.format
local table_insert = table.insert
local table_concat = table.concat
local tostring = tostring
local type = type
local pairs = pairs
local ipairs = ipairs
local _info = _info
local next = next
local debug_getupvalue = debug.getupvalue
local debug_getmetatable = debug.getmetatable
local debug_setupvalue = debug.setupvalue

local HU = {}

function HU.FailNotify(...)
	if HU.NotifyFunc then HU.NotifyFunc(...) end
end
function HU.DebugNofity(...)
	if HU.DebugNofityFunc then HU.DebugNofityFunc(...) end
end

local function GetWorkingDir()
	if HU.WorkingDir == nil then
	    local p = lfs.currentdir()

	    HU.WorkingDir = p
	end
	return HU.WorkingDir
end

local function Normalize(path)
    path = GetWorkingDir()..path
    path = string.gsub(path, "\\", "/") 
    return path
end

local function step_init_file_map(root_path, work_path)
    for entry in lfs.dir(root_path) do
        if entry ~= '.' and entry ~= '..' then
            local path = root_path .. '/' .. entry
            local attr = lfs.attributes(path)
            assert(type(attr) == 'table')

            if attr.mode == 'directory' then
                step_init_file_map(path, work_path)
            else
                local FileName = string.match(entry,"(.*)%.lua")
                local path_length = #path
                local suffix = string.sub(path, path_length-3, path_length)
                if FileName ~= nil and suffix == ".lua" then
                    local luapath = string.sub(path, #work_path+2, path_length-4)

                    if HU.FileMap[luapath] == nil then
                        HU.FileMap[luapath] = {}
                    end
                    table.insert(HU.FileMap[luapath], {SysPath = path, LuaPath = luapath})
                end
            end
        end
    end
end

function HU.InitFileMap(RootPath)
    for _, rootpath in pairs(RootPath) do
		rootpath = Normalize(rootpath)
        step_init_file_map(rootpath, rootpath)
    end
end

function HU.InitFakeTable()
	local meta = {}
	HU.Meta = meta
	local function FakeT() return setmetatable({}, meta) end
	local function EmptyFunc() end
	local function pairs() return EmptyFunc end  
	local function setmetatable(t, metaT)
		HU.MetaMap[t] = metaT 
		return t
	end
	local function require(LuaPath)
		if not HU.RequireMap[LuaPath] then
			local FakeTable = FakeT()
			HU.RequireMap[LuaPath] = FakeTable
		end
		return HU.RequireMap[LuaPath]
	end
	function meta.__index(t, k)
		if k == "setmetatable" then
			return setmetatable
		elseif k == "pairs" or k == "ipairs" then
			return pairs
		elseif k == "next" then
			return EmptyFunc
		elseif k == "require" then
			return require
		else
			local FakeTable = FakeT()
			rawset(t, k, FakeTable)
			return FakeTable 
		end
	end
	function meta.__newindex(t, k, v) rawset(t, k, v) end
	function meta.__call() return FakeT(), FakeT(), FakeT() end
	function meta.__add() return meta.__call() end
	function meta.__sub() return meta.__call() end
	function meta.__mul() return meta.__call() end
	function meta.__div() return meta.__call() end
	function meta.__mod() return meta.__call() end
	function meta.__pow() return meta.__call() end
	function meta.__unm() return meta.__call() end
	function meta.__concat() return meta.__call() end
	function meta.__eq() return meta.__call() end
	function meta.__lt() return meta.__call() end
	function meta.__le() return meta.__call() end
	function meta.__len() return meta.__call() end
	return FakeT
end

function HU.InitProtection()
	HU.Protection = {}
	HU.Protection[setmetatable] = true
	HU.Protection[pairs] = true
	HU.Protection[ipairs] = true
	HU.Protection[next] = true
	HU.Protection[require] = true
	HU.Protection[HU] = true
	HU.Protection[HU.Meta] = true
	HU.Protection[math] = true
	HU.Protection[string] = true
	HU.Protection[table] = true
    HU.Protection[UnityEngine.Quaternion] = true
    HU.Protection[UnityEngine.Vector2] = true
    HU.Protection[UnityEngine.Vector3] = true
    HU.Protection[UnityEngine.Vector4] = true
end

function HU.AddFileFromHUList()
	package.loaded[HU.UpdateListFile] = nil
	local FileList = require (HU.UpdateListFile)
	HU.ALL = false
	HU.HUMap = {}
	for _, file in pairs(FileList) do
		if file == "_ALL_" then
			HU.ALL = true
			for k, v in pairs(HU.FileMap) do
				for _, path in pairs(v) do
					HU.HUMap[path.LuaPath] = path.SysPath  	
				end
			end
			return
		end
		if HU.FileMap[file] then
			for _, path in pairs(HU.FileMap[file]) do
				HU.HUMap[path.LuaPath] = path.SysPath  	
			end
		else
			HU.FailNotify("HotUpdate can't not find "..file)
		end
	end
end

function HU.ErrorHandle(e)
	HU.FailNotify("HotUpdate Error\n"..tostring(e))
	HU.ErrorHappen = true
end

function HU.BuildNewCode(SysPath, LuaPath)
	io.input(SysPath)
	local NewCode = io.read("*all")
	if HU.ALL and HU.OldCode[SysPath] == nil then
		HU.OldCode[SysPath] = NewCode
		return
	end
	if HU.OldCode[SysPath] == NewCode then
		io.input():close()
		return false
	end
	HU.DebugNofity(SysPath)
	io.input(SysPath)  
	local chunk = "--[["..LuaPath.."]] "
	chunk = chunk..NewCode	
	io.input():close()
	local NewFunction = loadstring(chunk)
	if not NewFunction then 
  		HU.FailNotify(SysPath.." has syntax error.")  	
  		collectgarbage("collect")
  		return false
	else
		HU.FakeENV = HU.FakeT()
		HU.MetaMap = {}
		HU.RequireMap = {}
		setfenv(NewFunction, HU.FakeENV)
		local NewObject
		HU.ErrorHappen = false
		xpcall(function () NewObject = NewFunction() end, HU.ErrorHandle)
		if not HU.ErrorHappen then 
			HU.OldCode[SysPath] = NewCode
			return true, NewObject
		else
	  		collectgarbage("collect")
			return false
		end
	end
end

function HU.Travel_G()
	local visited = {}
	visited[HU] = true
	local function f(t)
		if (type(t) ~= "function" and type(t) ~= "table") or visited[t] or HU.Protection[t] then return end
		visited[t] = true
		if type(t) == "function" then
		  	for i = 1, math.huge do
				local name, value = debug_getupvalue(t, i)
				if not name then break end
				if type(value) == "function" then
                    local funcs = HU.ChangedFuncList[value]
                    if funcs ~= nil then
                        debug_setupvalue(t, i, funcs[2])
                    end
				end
				f(value)
			end
		elseif type(t) == "table" then
			f(debug_getmetatable(t))
			local changeIndexs = {}
			for k,v in pairs(t) do
				f(k); f(v);
				if type(v) == "function" then
                    local funcs = HU.ChangedFuncList[v]
                    if funcs ~= nil then
                        t[k] = funcs[2]
                    end
				end
				if type(k) == "function" then
                    local funcs = HU.ChangedFuncList[k]
                    if funcs ~= nil then
                        changeIndexs[#changeIndexs+1] = k
                    end
				end
			end
			for _, index in ipairs(changeIndexs) do
				local funcs = HU.ChangedFuncList[index]
				t[funcs[2]] = t[funcs[1]] 
				t[funcs[1]] = nil
			end
		end
	end
	
	f(_G)
	local registryTable = debug.getregistry()
	for _, funcs in ipairs(HU.ChangedFuncList) do
		for k, v in pairs(registryTable) do
			if v == funcs[1] then
				registryTable[k] = funcs[2]
			end
		end
	end
	for _, funcs in ipairs(HU.ChangedFuncList) do
		if funcs[3] == "HUDebug" then
            funcs[4]:HUDebug()
        end
	end
end

function HU.ReplaceOld(OldObject, NewObject, LuaPath, From, Deepth)
	if type(OldObject) == type(NewObject) then
		if type(NewObject) == "table" then
			HU.UpdateAllFunction(OldObject, NewObject, LuaPath, From, "") 
		elseif type(NewObject) == "function" then
			HU.UpdateOneFunction(OldObject, NewObject, LuaPath, nil, From, "")
		end
	end
end

local function table_isEmptyOrNil(t)
    if t==nil or next(t) == nil then
        return true
    end
    return false
end

function HU.HotUpdateCode(LuaPath, SysPath)
	--local OldObject = package.loaded[LuaPath]
    local OldObject = require(LuaPath)
	if OldObject ~= nil then
		HU.VisitedSig = {}
		HU.ChangedFuncList = {}
		local Success, NewObject = HU.BuildNewCode(SysPath, LuaPath)
		if Success then
			HU.ReplaceOld(OldObject, NewObject, LuaPath, "Main", "")
			for LuaPath, NewObject in pairs(HU.RequireMap) do
				local OldObject = package.loaded[LuaPath]
				HU.ReplaceOld(OldObject, NewObject, LuaPath, "Main_require", "")
			end
			setmetatable(HU.FakeENV, nil)
			HU.UpdateAllFunction(HU.ENV, HU.FakeENV, " ENV ", "Main", "")
			if not table_isEmptyOrNil(HU.ChangedFuncList) then
				HU.Travel_G()
			end
			collectgarbage("collect")
		end
	elseif HU.OldCode[SysPath] == nil then 
		io.input(SysPath)
		HU.OldCode[SysPath] = io.read("*all")
		io.input():close()
	end
end

function HU.ResetENV(object, name, From, Deepth)
	local visited = {}
	local function f(object, name)
		if not object or visited[object] then return end
		visited[object] = true
		if type(object) == "function" then
			HU.DebugNofity(Deepth.."HU.ResetENV", name, "  from:"..From)
			xpcall(function () setfenv(object, HU.ENV) end, HU.FailNotify)
		elseif type(object) == "table" then
			HU.DebugNofity(Deepth.."HU.ResetENV", name, "  from:"..From)
			for k, v in pairs(object) do
				f(k, tostring(k).."__key", " HU.ResetENV ", Deepth.."    " )
				f(v, tostring(k), " HU.ResetENV ", Deepth.."    ")
			end
		end
	end
	f(object, name)
end

function HU.UpdateUpvalue(OldFunction, NewFunction, Name, From, Deepth)
	HU.DebugNofity(Deepth.."HU.UpdateUpvalue", Name, "  from:"..From)
	local OldUpvalueMap = {}
	local OldExistName = {}
	for i = 1, math.huge do
		local name, value = debug_getupvalue(OldFunction, i)
		if not name then break end
		OldUpvalueMap[name] = value
		OldExistName[name] = true
	end
	for i = 1, math.huge do
		local name, value = debug_getupvalue(NewFunction, i)
		if not name then break end
		if OldExistName[name] then
			local OldValue = OldUpvalueMap[name]
			if type(OldValue) ~= type(value) then
				debug_setupvalue(NewFunction, i, OldValue)
			elseif type(OldValue) == "function" then
				HU.UpdateOneFunction(OldValue, value, name, nil, "HU.UpdateUpvalue", Deepth.."    ")
			elseif type(OldValue) == "table" then
				HU.UpdateAllFunction(OldValue, value, name, "HU.UpdateUpvalue", Deepth.."    ")
				debug_setupvalue(NewFunction, i, OldValue)
			else
				debug_setupvalue(NewFunction, i, OldValue)
			end
		else
			HU.ResetENV(value, name, "HU.UpdateUpvalue", Deepth.."    ")
		end
	end
end 

function HU.UpdateOneFunction(OldObject, NewObject, FuncName, OldTable, From, Deepth)
	if HU.Protection[OldObject] or HU.Protection[NewObject] then return end
	if OldObject == NewObject then return end
	local signature = tostring(OldObject)..tostring(NewObject)
	if HU.VisitedSig[signature] then return end
	HU.VisitedSig[signature] = true
	HU.DebugNofity(Deepth.."HU.UpdateOneFunction "..FuncName.."  from:"..From)
	if pcall(debug.setfenv, NewObject, getfenv(OldObject)) then
		HU.UpdateUpvalue(OldObject, NewObject, FuncName, "HU.UpdateOneFunction", Deepth.."    ")
		HU.ChangedFuncList[OldObject] = {OldObject, NewObject, FuncName, OldTable}
	end
end

function HU.UpdateAllFunction(OldTable, NewTable, Name, From, Deepth)
	if HU.Protection[OldTable] or HU.Protection[NewTable] then return end
	if OldTable == NewTable then return end
	local signature = tostring(OldTable)..tostring(NewTable)
	if HU.VisitedSig[signature] then return end
	HU.VisitedSig[signature] = true
	HU.DebugNofity(Deepth.."HU.UpdateAllFunction "..Name.."  from:"..From)
	for ElementName, Element in pairs(NewTable) do
		local OldElement = OldTable[ElementName]
		if type(Element) == type(OldElement) then
			if type(Element) == "function" then
				HU.UpdateOneFunction(OldElement, Element, ElementName, OldTable, "HU.UpdateAllFunction", Deepth.."    ")
			elseif type(Element) == "table" then
				HU.UpdateAllFunction(OldElement, Element, ElementName, "HU.UpdateAllFunction", Deepth.."    ")
            elseif type(Element) == "string" or type(Element) == "number" then
                OldTable[ElementName] = Element
			end
		elseif OldElement == nil then
            if type(Element) == "function" then
			    if pcall(setfenv, Element, HU.ENV) then
				    OldTable[ElementName] = Element
			    end
            else
                OldTable[ElementName] = Element
            end
		end
	end
	local OldMeta = debug_getmetatable(OldTable)
	local NewMeta = HU.MetaMap[NewTable]
	if type(OldMeta) == "table" and type(NewMeta) == "table" then
		HU.UpdateAllFunction(OldMeta, NewMeta, Name.."'s Meta", "HU.UpdateAllFunction", Deepth.."    ")
	end
end

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
            keystr = string_format("[\"%s\"]", k)
        elseif type(k) == "number" then
            keystr = string_format("[%d]", k)
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

local function write_to_hash_file()
    local hash_str = table_serialize(HU.Md5Hash)
    hash_str = "return "..hash_str
    local file = io.open(HU.Md5FileName, "w")
    assert(file)
    file:write(hash_str)
    file:close()
end


function HU.Init(UpdateListFile, RootPath, FailNotify, ENV, md5_name)
	HU.UpdateListFile = UpdateListFile
	HU.HUMap = {}
	HU.FileMap = {}
	HU.NotifyFunc = FailNotify
	HU.OldCode = {}
	HU.ChangedFuncList = {}
	HU.VisitedSig = {}
	HU.FakeENV = nil
	HU.ENV = ENV or _G
	HU.InitFileMap(RootPath)
	HU.FakeT = HU.InitFakeTable()
	HU.InitProtection()
	HU.ALL = false
    HU.Md5FileName = md5_name
    local md5_file = loadfile(md5_name)
    if md5_file ~= nil then
        HU.Md5Hash = md5_file()
    else
        HU.Md5Hash = {}
    end
    for k, v in pairs(HU.FileMap) do
        for _, path in pairs(v) do
            local LuaPath = path.LuaPath
            local SysPath = path.SysPath
            local code_file = io.open(SysPath, "r")
            local code_str = code_file:read("*a")
            code_file:close()
            local file_md5 = sumhexa(code_str)
            HU.Md5Hash[LuaPath] = file_md5
        end
    end

    write_to_hash_file()
end


function HU.Update()
	HU.AddFileFromHUList()
	for LuaPath, SysPath in pairs(HU.HUMap) do
        repeat
            if LuaPath == "basic/message_pack" then
                break
            end

            local code_file = io.open(SysPath, "r")
            local code_str = code_file:read("*a")
            code_file:close()
            local file_md5 = sumhexa(code_str)

            if HU.Md5Hash[LuaPath] == file_md5 then
                break
            end
            _info(LuaPath)
            HU.HotUpdateCode(LuaPath, SysPath)
            HU.Md5Hash[LuaPath] = file_md5
        until(true)
    end
    write_to_hash_file()
end

return HU
