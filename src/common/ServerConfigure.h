#pragma once
#ifndef _SERVER_CONFIG_H_

#include "common.h"
#include "Singleton.h"
#include "json.hpp"
using json = nlohmann::json;

#define MAX_CONFIG_BUFFER 100*1024 


struct ServerHolder
{
	uint32_t         serverID;            
	std::string      serverName;
	std::string      listenIP;            //监听IP
	std::string      connectIP;           //提供给其他进程连接的IP      
	int32_t          listenPort;  
	int32_t          consolePort;
	bool             isBanClient;         //是否禁止玩家登陆
	uint32_t         maxClients;          //最多承载多少玩家
	std::string luaPath;
	std::string logFilePath;
	int logLevel;
	int serverType;
	std::string dbname;

	ServerHolder() {
		memset(this, 0, sizeof(*this));
	}
};

struct DBConfig
{
	std::string Address;
	std::string DBName;
	std::string UserName;
	std::string UserPassword;

	DBConfig() {
		Address = "";
		DBName = "";
		UserName = "";
		UserPassword = "";
	}
};

typedef std::map<uint32_t, std::shared_ptr<ServerHolder>> MapServerInfo;

class ServerConfigure:public Singleton<ServerConfigure>
{
public:
	ServerConfigure() {}
	~ServerConfigure() {}

	bool Init(std::string configPath);
	std::shared_ptr<ServerHolder> GetServerHolder(int serverid, int servertype);
	int GetServerType(SERVERID serverid);
	void GetServersOfType(int serverType, std::set<SERVERID>& servers);
	SERVERID GetServerID(std::string serverName);
	DBConfig GetDBConfig();

private:
	bool CheckServerID(uint32_t  serverID, int serverType);
	bool LoadJsonFile();
	bool LoadGameManagerConfigure(json& config);
	bool LoadGateConfigure(json& config);
	bool LoadFightConfigure(json& config);
	bool LoadGameConfigure(json& config);
	bool LoadDBConfigure(json& config);

public:
	MapServerInfo                m_gameServers;      
	MapServerInfo                m_gateServers;       
	MapServerInfo                m_fightServers;       
	MapServerInfo                m_dbServers;       
	std::shared_ptr<ServerHolder>  m_gamemanager;     //登录服，负责SDK验证及选角，根据角色信息分配不同的game进程
	DBConfig* m_dbConfig;
	

private:
	std::map<SERVERID, int>      m_allServerID;     //检查是否有重复的ID
	std::string					 m_logConf;			//日志配置文件
	std::string m_configPath;
	
};


#endif // !_SERVER_CONFIG_H_
