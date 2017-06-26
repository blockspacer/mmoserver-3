#include "LuaModule.h"
#include "baseluafunction.h"
#include "lua-hiredis.h"
#include "lfs.h"
#include "md5.h"

static int traceback(lua_State *L) {
	if (!lua_isstring(L, 1))  /* 'message' not a string? */
		return 1;  /* keep it intact */
	lua_getfield(L, LUA_GLOBALSINDEX, "debug");
	if (!lua_istable(L, -1)) {
		lua_pop(L, 1);
		return 1;
	}
	lua_getfield(L, -1, "traceback");
	if (!lua_isfunction(L, -1)) {
		lua_pop(L, 2);
		return 1;
	}
	lua_pushvalue(L, 1);  /* pass error message */
	lua_pushinteger(L, 2);  /* skip this function and traceback */
	lua_call(L, 2, 1);  /* call debug.traceback */
	return 1;
}

int lua_pcallwithtraceback(lua_State* L, int nargs, int nret) {
	/* calculate stack position for message handler */
	int hpos = lua_gettop(L) - nargs;
	int ret = 0;
	/* push custom error message handler */
	lua_pushcfunction(L, traceback);
	/* move it before function and arguments */
	lua_insert(L, hpos);
	/* call lua_pcall function with custom handler */
	ret = lua_pcall(L, nargs, nret, hpos);
	/* remove custom error message handler from stack */
	lua_remove(L, hpos);
	/* pass return value of lua_pcall */
	return ret;
}

/* 构造函数
*/
LuaModule::LuaModule() : m_pLuaState(nullptr), m_isReady(false), lastTickTime(0)
{
}

/* 析构函数
*/
LuaModule::~LuaModule()
{

}


/* 创建
*/
bool LuaModule::Init(std::string luaPath)
{
	m_pLuaState = lua_open();
	if (m_pLuaState == NULL)
	{
		return false;
	}

	luaL_openlibs(m_pLuaState);

	luaopen_basefunction(m_pLuaState);
	luaopen_hiredis(m_pLuaState);
	luaopen_lfs(m_pLuaState);
	luaopen_md5_core(m_pLuaState);
	//if (!LoadFile(luaPath.c_str()))
	//{
	//	_xerror("Failed loadluafile %s", luaPath.c_str());
	//	return false;
	//}
	m_isReady = true;
	return true;
}

/* 释放
*/
void LuaModule::Release()
{
	if (m_pLuaState != NULL)
	{
		lua_close(m_pLuaState);
		m_pLuaState = NULL;
	}
	delete this;
}


/* 加载一个lua文件
*/
bool LuaModule::LoadFile(const char* szFileName)
{
	_info("will loadfile");
	if (szFileName == NULL)
	{
		return false;
	}
	int top = lua_gettop(m_pLuaState);

	try
	{
		int nResult = luaL_loadfile(m_pLuaState, szFileName);
		if (nResult == 0)
		{
			//nResult = lua_pcall(m_pLuaState, 0, 0, 0);
			nResult = lua_pcallwithtraceback(m_pLuaState, 0, 0);
			if (nResult == 0)
			{
				lua_settop(m_pLuaState, top);
				return true;
			}
		}
	}
	catch (...)
	{
		const char* pszErrInfor = lua_tostring(m_pLuaState, -1);
		_xerror(pszErrInfor);
	}

	const char* pszErrInfor = lua_tostring(m_pLuaState, -1);
	_xerror(pszErrInfor);
	lua_settop(m_pLuaState, top);
	return false;
}

/* 执行一段内存里lua
*/
bool LuaModule::RunMemory(const char* luaText, int luaTextLength, std::string& err)
{
	if (!IsReady())
	{
		return true;
	}
	if (luaText == NULL || luaTextLength <= 0)
	{
		return false;
	}

	int top = lua_gettop(m_pLuaState);
	int nResult = luaL_loadbuffer(m_pLuaState, luaText, luaTextLength, "bc__MemoryLua__20015");
	if (nResult == 0)
	{
		//nResult = lua_pcall(m_pLuaState, 0, 0, 0);
		nResult = lua_pcallwithtraceback(m_pLuaState, 0, 0);
		if (nResult == 0)
		{
			lua_settop(m_pLuaState, top);
			return true;
		}
	}

	const char* pszErrInfor = lua_tostring(m_pLuaState, -1);
	err = pszErrInfor;
	_xerror("Failed RunMemory %s", pszErrInfor);
	lua_settop(m_pLuaState, top);
	return false;
}

/* 调用一个lua函数
*/
bool LuaModule::RunFunction(const char* szFunName, CLuaParam* pInParam, int nInNum, CLuaParam* pOutParam, int nOutNum)
{
	if (!IsReady())
	{
		return true;
	}

	uint64_t now = GetNowTimeMille();
	if (lastTickTime + 10000 < now)
	{
		ShowDebugInfo();
		lastTickTime = now;
	}

	int top = lua_gettop(m_pLuaState);
	try
	{
		lua_getglobal(m_pLuaState, szFunName);
		if (!lua_isfunction(m_pLuaState, -1))
		{
			_xerror("Failed find function %s", szFunName);
			lua_settop(m_pLuaState, top);
			return false;
		}

		for (int i = 0; i < nInNum; i++)
		{
			int nValueType = pInParam[i].GetType();
			switch (nValueType)
			{
			case SD_NUMBER:
			{
				lua_pushnumber(m_pLuaState, (int64_t)pInParam[i]);
			}
			break;
			case SD_DOUBLE:
			{
				lua_pushnumber(m_pLuaState, (double)pInParam[i]);
			}
			break;
			case SD_STRING:
			{
				lua_pushstring(m_pLuaState, (const char*)pInParam[i]);
			}
			break;
			case SD_LSTRING:
			{
				lua_pushlstring(m_pLuaState, (const char*)pInParam[i], pInParam[i].GetLength());
			}
			break;
			case SD_POINTER:
			{
				lua_pushlightuserdata(m_pLuaState, (void *)pInParam[i]);
			}
			break;
			default:
			{
				_xerror("Failed Call Function %s ，Reson  input %d Type Error %d", szFunName, i, nValueType);
				lua_settop(m_pLuaState, top);
				return false;
			}
			}
		}

		// 调用执行
		//int nResult = lua_pcall(m_pLuaState, nInNum, nOutNum, 0);
		int nResult = lua_pcallwithtraceback(m_pLuaState, nInNum, nOutNum);
		if (nResult == 0)
		{
			int n = 0;
			for (n = nOutNum - 1; n >= 0; n--)
			{
				int nValueType = pOutParam[n].GetType();
				switch (nValueType)
				{
				case SD_NUMBER:
				{
					pOutParam[n] = (int64_t)lua_tonumber(m_pLuaState, -1);
					lua_pop(m_pLuaState, 1);
				}
				break;
				case SD_DOUBLE:
				{
					pOutParam[n] = (double)lua_tonumber(m_pLuaState, -1);
					lua_pop(m_pLuaState, 1);
				}
				break;
				case SD_STRING:
				{
					pOutParam[n] = (const char*)lua_tostring(m_pLuaState, -1);
					lua_pop(m_pLuaState, 1);
				}
				break;
				case SD_POINTER:
				{
					pOutParam[n] = (void*)lua_topointer(m_pLuaState, -1);
					lua_pop(m_pLuaState, 1);
				}
				break;
				default:
				{
					_xerror("Failed Call Function %s ，Reson  output %d Type Error", szFunName, n);
					lua_settop(m_pLuaState, top);
					return false;
				}
				}
			}

			lua_settop(m_pLuaState, top);
			return true;
		}

	}
	catch (std::exception& e)
	{
		_xerror("Exception Error %s", e.what());
	}
	catch (...)
	{
		_xerror("Failed RunFunction, Exception Happen");
	}

	const char* pszErrInfor = lua_tostring(m_pLuaState, -1);
	_xerror("Failed Call Function %s ，Reason: %s", szFunName, pszErrInfor);
	lua_settop(m_pLuaState, top);
	return false;
}


bool LuaModule::Reload()
{
	if (!IsReady())
	{
		return true;
	}
	_info("Will Do Reload");
	return RunFunction("OnScriptReload", nullptr, 0, nullptr, 0);
}

lua_State* LuaModule::GetLuaState()
{
	return m_pLuaState;
}

int32_t LuaModule::CreateTimer(const uint64_t interval, const int mode)
{
	int next_intevel = (mode == 0 ? 0 : interval);
	return CTimerMgr::Instance()->CreateTimer(0, this, &LuaModule::LuaOnTimer, interval, next_intevel);
}

void LuaModule::DestroyTimer(int32_t tid)
{
	CTimerMgr::Instance()->DestroyTimer(tid);
}

void LuaModule::LuaOnTimer(int timerid)
{
	CLuaParam params[1];
	params[0] = timerid;
	if (!RunFunction("CppCallLuaTimer", params, 1, NULL, 0))
	{
		_xerror("Failed Call CppCallLuaTimer");
	}
}

bool LuaModule::IsReady()
{
	return m_isReady;
}

void LuaModule::ShowDebugInfo()
{
	int memoryUseInLua = lua_gc(m_pLuaState, LUA_GCCOUNT, 0);
	_info("TheMemoryUseInLua is %d", memoryUseInLua);
}

