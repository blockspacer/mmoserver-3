#ifndef __GAMESERVER_H__
#define __GAMESERVER_H__

#include "ILogModule.h"
#include "IGameServer.h"
#include "GameServerModule.h"
#include "GameLuaModule.h"
#include "Timer.h"
#include "DBClientModule.h"
#include "NetModule.h"
#include "message.h"
#include "GameProxyModule.h"
#include "GameManagerClientModule.h"
#include "telnet.h"

class GameServer : public IGameServer
{
  public:
    GameServer(std::string servername) : m_serverID(0), m_serverName(servername), m_serverState(SERVER_STATE_CREATE), m_IsWorking(false){}
    ~GameServer(){};

    bool Init(std::string pszConfigPath);

	std::string GetConfigPath();

    bool CheckServerStart();

    bool Tick();

    bool InitClient();

    bool OnServerStart();

    bool Run();

    // 收到服务器停止的消息
    bool OnServerStop();

    bool OnServerClose();

	ILogModule *GetLogModule();

	IGameServerModule *GetGameServerModule();

	IDBClientModule *GetDBClientModule();

    IProxyModule *GetAOIModule();

	int GetServerState();

	void SetServerState(int state);

    void Check() {}

    bool InitAOIModule();

    std::string GetServerName();

	GameLuaModule *GetGameLuaModuel();

	SERVERID GetServerID();

	bool IsWorking();

	void ConsoleHandler(const int sock, const char* data, const DATA_LENGTH_TYPE dataLength);

private:
	void OnRunScript(ServerMessageHead *head, const int sock, const char *data, const DATA_LENGTH_TYPE dataLength);
	void OnRunGMLuaMessage(ServerMessageHead *head, const int sock, const char *data, const DATA_LENGTH_TYPE dataLength);
	void OnUpdateGameServerInfo(ServerMessageHead *head, const int sock, const char *data, const DATA_LENGTH_TYPE dataLength);

  private:
    SERVERID m_serverID;
    std::string m_serverName;
	std::string m_configPath;
    int m_serverState;
    uint32_t m_idleCount;
    LogModule m_logModule;
    GameLuaModule m_gameLuaModule;
    GameServerModule m_gameServerModule; //负责listen and accept 链接
    DBClientModule m_dbClientModule;
	GameManagerClientModule m_gamemanagerClient;
    GameProxyModule m_AOIModule; // 视野同步
    uint32_t m_totalTickCount;   // 总循环次数
    uint32_t m_deltaTickCount;   // 每n分钟循环次数
    uint64_t m_now;
	TelnetServer m_telnet;

	bool m_IsWorking;
};

#endif