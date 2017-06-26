#pragma once
#ifndef _LUA_REDIS_FUNCTION_H_
#define _LUA_REDIS_FUNCTION_H_

extern "C"
{
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
}
#include "common.h"
#include "redismodule.h"

// 执行一个redis指令
static int lua_redis_command(lua_State *L)
{
	size_t len;
	const char* data = luaL_checklstring(L, 1, &len);
	std::string command(data, len);
	uint32_t callbackid = static_cast<uint32_t>(luaL_checknumber(L, 2));

	bool ret = RedisModule::Instance()->Command(callbackid, command);
	lua_pushboolean(L, ret);
	return 1;
}

extern "C" void luaopen_redisfunction(lua_State* L)
{
	lua_register(L, "_redis_command", lua_redis_command);
}

#endif