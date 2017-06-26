#ifndef __GATE_LUAMODULE_H_
#define __GATE_LUAMODULE_H_

#include "LuaModule.h"
#include "common.h"
#include "message.h"

class FightLuaModule
{
public:
	FightLuaModule();

	~FightLuaModule();

	bool Init(std::string luaPath);

	bool AfterInit();

	bool RegisterFunction();

	void OnClientLuaMessage(const SESSIONID clientSessionID, const char * data, const DATA_LENGTH_TYPE dataLength);

	void OnGameServerLuaMessage(const SERVERID gameid, const char * data, const DATA_LENGTH_TYPE dataLength);

};

#endif