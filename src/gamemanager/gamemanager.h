#pragma once
// -------------------------------------------------------------------------
//    @FileName         ：    gamemanager.h
//    @Author           ：    hou(houontherun@gmail.com)
//    @Date             ：    2017-02-24
//    @Module           ：    GameManager
//    @Desc             :     管理服务
// -------------------------------------------------------------------------
#ifndef _GAME_MANAGER_H_
#define _GAME_MANAGER_H_

#include "common.h"
#include "LogModule.h"
#include "gamemanager_servermodule.h"
#include "ServerConfigure.h"
#include "timemeter.h"
#include "Timer.h"

class GameManager
{
  public:
    GameManager(std::string servername) : m_serverName(servername), m_serverState(SERVER_STATE_CREATE) {}
    ~GameManager(){};

    bool Init(std::string pszConfigPath);
    bool Tick();
    bool Run();
    bool OnServerCreate();
    bool OnServerStart();
    bool OnServerStop();
    bool OnServerClose();
	ILogModule* GetLogModule();
	bool IsWorking();

public:
    int GetServerState();
    void SetServerState(int state);

  private:
    SERVERID m_serverID;
    std::string m_serverName;
    int m_serverState;
    uint32_t m_idleCount;
    LogModule m_logModule;
    GameManagerServerModule m_gamemanagerServerModule;
	bool m_IsWorking;
};

#endif