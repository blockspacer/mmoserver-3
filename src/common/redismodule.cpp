#ifdef _ASYN_REDIS

#include "redismodule.h"
#include "ILuaModule.h"

#if defined (__cplusplus)
extern "C" {
#endif

#include <lua.h>
#include <lauxlib.h>

#if defined (__cplusplus)
}
#endif

#ifdef _LINUX


#define LUAHIREDIS_VERSION     "lua-hiredis 0.2.1"
#define LUAHIREDIS_COPYRIGHT   "Copyright (C) 2011—2013, lua-hiredis authors"
#define LUAHIREDIS_DESCRIPTION "Bindings for hiredis Redis-client library"

#define LUAHIREDIS_CONN_MT   "lua-hiredis.connection"
#define LUAHIREDIS_CONST_MT  "lua-hiredis.const"
#define LUAHIREDIS_STATUS_MT "lua-hiredis.status"

#define LUAHIREDIS_MAXARGS (256)

#define LUAHIREDIS_KEY_NIL "NIL"

static int lconst_tostring(lua_State * L)
{
	/*
	* Assuming we have correct argument type.
	* Should be reasonably safe, since this is a metamethod.
	*/
	luaL_checktype(L, 1, LUA_TTABLE);
	lua_getfield(L, 1, "name"); /* TODO: Do we need fancier representation? */

	return 1;
}

/* const API */
static const struct luaL_Reg CONST_MT[] =
{
	{ "__tostring", lconst_tostring },

	{ NULL, NULL }
};

static int push_new_const(
	lua_State * L,
	const char * name,
	size_t name_len,
	int type
)
{
	luaL_checkstack(L, 3, "too many constants");

	/* We trust that user would not change these values */

	lua_createtable(L, 0, 2);
	lua_pushlstring(L, name, name_len);
	lua_setfield(L, -2, "name");
	lua_pushinteger(L, type);
	lua_setfield(L, -2, "type");

	if (luaL_newmetatable(L, LUAHIREDIS_CONST_MT))
	{
		luaL_register(L, NULL, CONST_MT);
		lua_pushvalue(L, -1);
		lua_setfield(L, -2, "__index");
		lua_pushliteral(L, LUAHIREDIS_CONST_MT);
		lua_setfield(L, -2, "__metatable");
	}

	lua_setmetatable(L, -2);

	return 1;
}

static int push_reply(lua_State * L, redisReply * pReply)
{
	switch (pReply->type)
	{
	case REDIS_REPLY_STATUS:
		luaL_checkstack(L, 2, "not enough stack to push reply");

		lua_pushvalue(L, lua_upvalueindex(1)); /* M (module table) */
		lua_getfield(L, -1, "status"); /* status = M.status */
		lua_remove(L, -2); /* Remove module table from stack */

		lua_pushlstring(L, pReply->str, pReply->len); /* name */
		lua_gettable(L, -2); /* status[name] */

		lua_remove(L, -2); /* Remove status table from stack */

		break;

	case REDIS_REPLY_ERROR:
		/* Not caching errors, they are (hopefully) not that common */
		push_new_const(L, pReply->str, pReply->len, REDIS_REPLY_ERROR);
		break;

	case REDIS_REPLY_INTEGER:
		luaL_checkstack(L, 1, "not enough stack to push reply");
		lua_pushinteger(L, pReply->integer);
		break;

	case REDIS_REPLY_NIL:
		luaL_checkstack(L, 2, "not enough stack to push reply");
		lua_pushvalue(L, lua_upvalueindex(1)); /* module table */
		lua_getfield(L, -1, LUAHIREDIS_KEY_NIL);
		lua_remove(L, -2); /* module table */
		break;

	case REDIS_REPLY_STRING:
		luaL_checkstack(L, 1, "not enough stack to push reply");
		lua_pushlstring(L, pReply->str, pReply->len);
		break;

	case REDIS_REPLY_ARRAY:
	{
		unsigned int i = 0;

		luaL_checkstack(L, 2, "not enough stack to push reply");

		lua_createtable(L, pReply->elements, 0);

		for (i = 0; i < pReply->elements; ++i)
		{
			/*
			* Not controlling recursion depth:
			* if we parsed the reply somehow,
			* we hope to be able to push it.
			*/

			push_reply(L, pReply->element[i]);
			lua_rawseti(L, -2, i + 1); /* Store sub-reply */
		}

		break;
	}

	default: /* should not happen */
		return luaL_error(L, "command: unknown reply type: %d", pReply->type);
	}

	/*
	* Always returning a single value.
	* If changed, change REDIS_REPLY_ARRAY above.
	*/
	return 1;
}

void commandCallback(redisAsyncContext *c, void *r, void *privdata) {
	redisReply *reply = (redisReply *)r;
	uint32_t* callbackid = static_cast<uint32_t*>(privdata);
	if (!(*callbackid))
	{
		// callbackid ==0, 不需要回调
		return;
	}
	if (reply == nullptr)
	{
		return;
	}
	lua_State* L = LuaModule::Instance()->GetLuaState();
	int top = lua_gettop(L);

	lua_getglobal(L, "OnRedisReply");
	if (!lua_isfunction(L, -1))
	{
		_xerror("Failed call OnRedisReply function because of failed find function");
		lua_settop(L, top);
		return;
	}
	lua_pushnumber(L, *callbackid);

	push_reply(L, reply);

	int ret = lua_pcallwithtraceback(L, 2, 0);
	if (ret)
	{
		const char* pszErrInfor = lua_tostring(L, -1);
		_xerror("Failed call OnRedisReply and reason is ", pszErrInfor);
		lua_settop(L, top);
	}
}

void connectCallback(const redisAsyncContext *c, int status) {
	if (status != REDIS_OK) {
		printf("Error: %s\n", c->errstr);
		return;
	}
	printf("Connected...\n");
	RedisModule::Instance()->SetState(RedisState_CONNECTED);
}

void disconnectCallback(const redisAsyncContext *c, int status) {
	if (status != REDIS_OK) {
		printf("Error: %s\n", c->errstr);
		return;
	}
	printf("Disconnected...\n");
	RedisModule::Instance()->SetState(RedisState_DISCONNECT);
}
#endif


bool RedisModule::Init()
{
#ifdef _LINUX
	m_redisIP = "121.43.96.134";
	m_redisPort = 6379;
	m_eventBase = event_base_new();
	if (!m_eventBase)
	{
		return false;
	}
	m_conn = redisAsyncConnect("121.43.96.134", 6379);
	if (m_conn->err)
	{
		//_xerror("Failed connect redis %s", m_conn->err);
		//return false;
	}
	redisLibeventAttach(m_conn, m_eventBase);
	redisAsyncSetConnectCallback(m_conn, connectCallback);
	redisAsyncSetDisconnectCallback(m_conn, disconnectCallback);
#endif
	//TODO 需要等到连接上再返回
	return true;
}

void RedisModule::Tick()
{
#ifdef _LINUX
	if (!m_eventBase)
	{
		_xerror("event_base is null");
		return ;
	}
	//  @return 0 if successful, -1 if an error occurred, or 1 if we exited because
	//	no events were pending or active.
	int ret = event_base_loop(m_eventBase, EVLOOP_ONCE | EVLOOP_NONBLOCK);
	if (ret == 0)
	{
		// event happen
	}
	else if (ret == 1)
	{
		// no event happen
	}
	else
	{
		_warn("error in event_base_loop");
	}
#endif
}

int RedisModule::DoCommand(void * callback, void * callback_param, const char * command, ...)
{
	// 生成callbackid，然后对应callback放到map，然后统一的回调
	return 0;
}

int RedisModule::Command(uint32_t callbackid, std::string command)
{
#ifdef _LINUX
	//redisAsyncFormattedCommand(m_conn, commandCallback, (void*)&callbackid, "set a b", sizeof("set a b"));
	uint32_t* d = new uint32_t;
	*d = callbackid;
	redisAsyncCommand(m_conn, commandCallback, (void*)d, "INCR houhou");
#endif // _LINUX	
	return 0;
}

void RedisModule::SetState(int state)
{
	m_state = state;
}

bool RedisModule::IsConnected()
{
	return m_state == RedisState_CONNECTED;
}

RedisModule* g_redisModule;
void SetGlobalRedisModuel(RedisModule* p)
{
	g_redisModule = p;
}

#endif