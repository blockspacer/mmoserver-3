#ifndef _BASE_LUA_FUNCTION_H_
#define _BASE_LUA_FUNCTION_H_

extern "C"
{
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
}

#include "ILogModule.h"
#include "Timer.h"
#include "LuaModule.h"
#include "Timer.h"

// _info
static int lua_info(lua_State *L)
{
	size_t n = 0;
	const char* text = luaL_checklstring(L, 1, &n);
	if (!text) return 0;
	GetLogModule()->Log(LOG_LEVEL_INFO, text);
	return 0;
}

// _warn
static int lua_warn(lua_State *L)
{
	size_t n = 0;
	const char* text = luaL_checklstring(L, 1, &n);
	if (!text) return 0;
	GetLogModule()->Log(LOG_LEVEL_WARN, text);
	return 0;
}

// _error
static int lua_xerror(lua_State *L)
{
	size_t n = 0;
	const char* text = luaL_checklstring(L, 1, &n);
	if (!text) return 0;
	GetLogModule()->Log(LOG_LEVEL_ERROR, text);
	return 0;
}

// _print
static int lua_trace(lua_State *L)
{
	size_t n = 0;
	const char* text = luaL_checklstring(L, 1, &n);
	if (!text) return 0;
	GetLogModule()->Log(LOG_LEVEL_TRACE, text);
	return 0;
}

static int lua_fatal(lua_State *L)
{
	size_t n = 0;
	const char* text = luaL_checklstring(L, 1, &n);
	if (!text) return 0;
	GetLogModule()->Log(LOG_LEVEL_FATAL, text);
	return 0;
}

static int lua_debug(lua_State *L)
{
	size_t n = 0;
	const char* text = luaL_checklstring(L, 1, &n);
	if (!text) return 0;
	_debug(text);
	return 0;
}

// 逻辑操作：与
static int lua_and(lua_State *L)
{
	lua_pushnumber(L, luaL_checkint(L, 1) & luaL_checkint(L, 2));
	return 1;
}

// 逻辑操作：或
static int lua_or(lua_State *L)
{
	lua_pushnumber(L, luaL_checkint(L, 1) | luaL_checkint(L, 2));
	return 1;
}

// 逻辑操作：异或
static int lua_xor(lua_State *L)
{
	lua_pushnumber(L, luaL_checkint(L, 1) ^ luaL_checkint(L, 2));
	return 1;
}

// 逻辑操作：取反
static int lua_not(lua_State *L)
{
	lua_pushnumber(L, ~luaL_checkint(L, 1));
	return 1;
}

// 逻辑操作：左移
static int lua_lshift(lua_State *L)
{
	lua_pushnumber(L, luaL_checkint(L, 1) << luaL_checkint(L, 2));
	return 1;
}

// 逻辑操作：右移
static int lua_rshift(lua_State *L)
{
	lua_pushnumber(L, luaL_checkint(L, 1) >> luaL_checkint(L, 2));
	return 1;
}

#define luaL_checkuint(L,n)	((unsigned int)luaL_checknumber(L, n))

// 逻辑操作：无符号左移
static int lua_ulshift(lua_State *L)
{
	lua_pushnumber(L, luaL_checkuint(L, 1) << luaL_checkint(L, 2));
	return 1;
}

// 逻辑操作：无符号右移
static int lua_urshift(lua_State *L)
{
	lua_pushnumber(L, luaL_checkuint(L, 1) >> luaL_checkint(L, 2));
	return 1;
}

// 位操作：get
static int lua_getbit(lua_State *L)
{
	lua_pushnumber(L, (luaL_checkuint(L, 1) >> luaL_checkint(L, 2)) & 0x01);
	return 1;
}

// 位操作：set
static int lua_setbit(lua_State *L)
{
	lua_pushnumber(L, luaL_checkuint(L, 1) | (1 << luaL_checkint(L, 2)));
	return 1;
}

// 位操作：reset
static int lua_resetbit(lua_State *L)
{
	lua_pushnumber(L, luaL_checkuint(L, 1) & (~(1 << luaL_checkint(L, 2))));
	return 1;
}


static int lua_get_now_time_mille(lua_State *L)
{
	uint64_t tmp = GetNowTimeMille();
	lua_pushnumber(L, tmp);
	return 1;
}

static int lua_get_now_time_second(lua_State *L)
{
	uint64_t tmp = GetNowTimeSecond();
	lua_pushnumber(L, tmp);
	return 1;
}

static int lua_set_now_time_second(lua_State *L)
{
#ifdef _DEBUG
	uint32_t time_set = luaL_checknumber(L, 1);
	uint64_t now = GetNowTimeSecond();
	int offset = time_set - now;
	SetTimeOffset(offset);
#endif
	return 0;
}

static int lua_system_type(lua_State *L)
{
#ifdef _LINUX
	lua_pushlstring(L, "linux", sizeof("linux")-1);
#else
	lua_pushlstring(L, "windows", sizeof("windows") - 1);
#endif
	return 1;
}

// 创建定时器
static int lua_create_timer(lua_State *L)
{
	uint64_t  interal = static_cast<uint64_t>(luaL_checknumber(L, 1));
	int  mode = static_cast<int>(luaL_checknumber(L, 2));

	int32_t tid = LuaModule::Instance()->CreateTimer(interal, mode);

	lua_pushnumber(L, tid);
	return 1;
}



// 销毁定时器
static int lua_destory_timer(lua_State *L)
{
	uint32_t  tid = static_cast<uint32_t>(luaL_checknumber(L, 1));
	LuaModule::Instance()->DestroyTimer(tid);
	return 0;
}



extern "C" void luaopen_basefunction(lua_State* L)
{
	lua_register(L, "_info", lua_info);
	lua_register(L, "_warn", lua_warn);
	lua_register(L, "_error", lua_xerror);
	lua_register(L, "_debug", lua_debug);
	lua_register(L, "_trace", lua_trace);
	lua_register(L, "_fatal", lua_fatal);

	lua_register(L, "_and", lua_and);
	lua_register(L, "_or", lua_or);
	lua_register(L, "_xor", lua_xor);
	lua_register(L, "_not", lua_not);
	lua_register(L, "_lshift", lua_lshift);
	lua_register(L, "_rshift", lua_rshift);
	lua_register(L, "_ulshift", lua_ulshift);
	lua_register(L, "_urshift", lua_urshift);
	lua_register(L, "_getbit", lua_getbit);
	lua_register(L, "_setbit", lua_setbit);
	lua_register(L, "_resetbit", lua_resetbit);

	lua_register(L, "_get_now_time_mille", lua_get_now_time_mille);
	lua_register(L, "_get_now_time_second", lua_get_now_time_second);
	lua_register(L, "_set_now_time_second", lua_set_now_time_second);
	lua_register(L, "_system_type", lua_system_type);
	lua_register(L, "_create_timer", lua_create_timer);
	lua_register(L, "_destory_timer", lua_destory_timer);
}

#endif // !_BASE_LUA_FUNCTION_H_