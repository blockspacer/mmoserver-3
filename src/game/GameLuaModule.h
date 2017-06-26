#ifndef _GAME_LUAMODULE_H_
#define _GAME_LUAMODULE_H_

#include "LuaModule.h"
#include "IGameServer.h"
#include "message/LuaMessage.pb.h"
#include "common.h"

class GameLuaModule
{
  public:
    GameLuaModule();

    ~GameLuaModule();

    bool Init(std::string luaPath);
    // 由子类注册lua所需要的函数
    bool RegisterFunction();

    bool AfterInit();

    void Tick(int tid);

    void OnEntityLuaMessage(const SESSIONID clientSessionID, const char *message, const DATA_LENGTH_TYPE messageLength);

  private:
	  int32_t GenerateTimerID();

  private:
    int32_t m_nTimerID; //与lua层交互的定时器ID
};

#endif