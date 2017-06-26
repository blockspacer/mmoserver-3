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
	std::string      listenIP;            //����IP
	std::string      connectIP;           //�ṩ�������������ӵ�IP      
	int32_t          listenPort;  
	int32_t          consolePort;
	bool             isBanClient;         //�Ƿ��ֹ��ҵ�½
	uint32_t         maxClients;          //�����ض������
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
	std::shared_ptr<ServerHolder>  m_gamemanager;     //��¼��������SDK��֤��ѡ�ǣ����ݽ�ɫ��Ϣ���䲻ͬ��game����
	DBConfig* m_dbConfig;
	

private:
	std::map<SERVERID, int>      m_allServerID;     //����Ƿ����ظ���ID
	std::string					 m_logConf;			//��־�����ļ�
	std::string m_configPath;
	
};


#endif // !_SERVER_CONFIG_H_
