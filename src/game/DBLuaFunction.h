#ifndef _DB_LUA_FUNCTION_H_
#define _DB_LUA_FUNCTION_H_

extern "C"
{
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
}

#include "IGameServer.h"
#include "ILogModule.h"
#include "message/dbmongo.pb.h"




static int lua_insert_doc(lua_State *L)
{
	size_t len = 0;
	std::string tablename(luaL_checklstring(L, 1, &len));
	const uint8_t * data = (const uint8_t *)lua_touserdata(L, 2);
	if (data == nullptr)
	{
		_xerror("lua_insert_doc: data is null");
		return -1;
	}
	int32_t length = get_length(data);
	std::string doc((const char*)data, length);

	uint32_t callbackid = static_cast<uint32_t>(luaL_checknumber(L, 3));

	InsertDocRequest request;
	request.set_db("tlbytest");
	request.set_collection(tablename);
	request.set_doc(doc);
	request.set_callback_id(callbackid);

	GlobalDBClientModule->SendMessageToDBProxy(GlobalGameServer->GetServerID(), dbproxy::DBSERVICE_INSERT_DOC, &request);
	return 0;
}

static int lua_find_doc(lua_State *L)
{
	size_t len = 0;
	std::string tablename(luaL_checklstring(L, 1, &len));

	const uint8_t * query = (const uint8_t *)lua_touserdata(L, 2);
	if (query == nullptr)
	{
		_xerror("lua_find_doc: query is null");
		return -1;
	}
	int32_t length = get_length(query);
	std::string query_with0((const char*)query, length);

	const uint8_t * field = (const uint8_t *)lua_touserdata(L, 3);
	if (field == nullptr)
	{
		_xerror("lua_find_doc: field is null");
		return -1;
	}
	length = get_length(field);
	std::string field_with0((const char*)field, length);

	uint32_t callbackid = static_cast<uint32_t>(luaL_checknumber(L, 4));

	FindDocRequest request;
	request.set_db("tlbytest");
	request.set_collection(tablename);
	request.set_query(query_with0);
	request.set_fields(field_with0);
	request.set_callback_id(callbackid);

	GlobalDBClientModule->SendMessageToDBProxy(GlobalGameServer->GetServerID(), dbproxy::DBSERVICE_FIND_ONE_DOC, &request);
	return 0;
}

static int lua_find_n_doc(lua_State *L)
{
	size_t len = 0;
	std::string tablename(luaL_checklstring(L, 1, &len));

	const uint8_t * query = (const uint8_t *)lua_touserdata(L, 2);
	if (query == nullptr)
	{
		_xerror("lua_find_doc: query is null");
		return -1;
	}
	int32_t length = get_length(query);
	std::string query_with0((const char*)query, length);

	const uint8_t * field = (const uint8_t *)lua_touserdata(L, 3);
	if (field == nullptr)
	{
		_xerror("lua_find_doc: field is null");
		return -1;
	}
	length = get_length(field);
	std::string field_with0((const char*)field, length);

	uint32_t callbackid = static_cast<uint32_t>(luaL_checknumber(L, 4));

	FindDocRequest request;
	request.set_db("tlbytest");
	request.set_collection(tablename);
	request.set_query(query_with0);
	request.set_fields(field_with0);
	request.set_callback_id(callbackid);

	GlobalDBClientModule->SendMessageToDBProxy(GlobalGameServer->GetServerID(), dbproxy::DBSERVICE_FIND_N_DOC, &request);
	return 0;
}

static int lua_update_doc(lua_State *L)
{
	size_t len = 0;
	std::string tablename(luaL_checklstring(L, 1, &len));
	//const char* query = luaL_checklstring(L, 2, &len);
	//std::string query_with0(query, len);
	//const char* field = luaL_checklstring(L, 3, &len);
	//std::string field_with0(field, len);

	const uint8_t * query = (const uint8_t *)lua_touserdata(L, 2);
	if (query == nullptr)
	{
		_xerror("lua_update_doc: query is null");
		return -1;
	}
	int32_t length = get_length(query);
	std::string query_with0((const char*)query, length);

	const uint8_t * field = (const uint8_t *)lua_touserdata(L, 3);
	if (field == nullptr)
	{
		_xerror("lua_update_doc: field is null");
		return -1;
	}
	length = get_length(field);
	std::string field_with0((const char*)field, length);

	bool upsert(luaL_checkinteger(L, 4));
	bool multi(luaL_checkinteger(L, 5));
	int32_t callbackid = static_cast<int32_t>(luaL_checknumber(L, 6));

	UpdateDocRequest request;
	request.set_db("tlbytest");
	request.set_collection(tablename);
	request.set_query(query_with0);
	request.set_fields(field_with0);
	request.set_upsert(upsert);
	request.set_multi(multi);
	request.set_callback_id(callbackid);

	GlobalDBClientModule->SendMessageToDBProxy(GlobalGameServer->GetServerID(), dbproxy::DBSERVICE_UPDATE_DOC, &request);
	return 0;
}

static int lua_find_and_modify(lua_State *L)
{

	size_t len = 0;
	std::string tablename(luaL_checklstring(L, 1, &len));

	const uint8_t * query = (const uint8_t *)lua_touserdata(L, 2);
	if (query == nullptr)
	{
		_xerror("lua_find_and_modify: query is null");
		return -1;
	}
	int32_t length = get_length(query);
	std::string query_with0((const char*)query, length);

	const uint8_t * updates = (const uint8_t *)lua_touserdata(L, 3);
	if (updates == nullptr)
	{
		_xerror("lua_find_and_modify: update is null");
		return -1;
	}
	length = get_length(updates);
	std::string updates_with0((const char*)updates, length);

	const uint8_t * field = (const uint8_t *)lua_touserdata(L, 4);
	if (field == nullptr)
	{
		_xerror("lua_find_and_modify: field is null");
		return -1;
	}
	length = get_length(field);
	std::string field_with0((const char*)field, length);



	bool upsert(luaL_checkinteger(L, 5));
	uint32_t callbackid = static_cast<uint32_t>(luaL_checknumber(L, 6));


	FindAndModifyDocRequest request;
	request.set_db("tlbytest");
	request.set_collection(tablename);
	request.set_query(query_with0);
	request.set_fields(field_with0);
	request.set_update(updates_with0);
	request.set_upsert(upsert);
	request.set_callback_id(callbackid);
	request.set_new_(true);

	GlobalDBClientModule->SendMessageToDBProxy(GlobalGameServer->GetServerID(), dbproxy::DBSERVICE_FIND_AND_MODIFY_DOC, &request);
	return 0;
}

extern "C" void luaopen_dbfunc(lua_State* L)
{
	lua_register(L, "_insert_doc", lua_insert_doc);
	lua_register(L, "_find_one", lua_find_doc);
	lua_register(L, "_find_n", lua_find_n_doc);
	lua_register(L, "_update_doc", lua_update_doc);
	lua_register(L, "_find_and_modify", lua_find_and_modify);
}
#endif