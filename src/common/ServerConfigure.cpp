#include "ServerConfigure.h"
#include <fstream>


bool ServerConfigure::Init(std::string configPath)
{
	m_configPath = configPath;
	bool ret = false;
	try
	{
		ret = LoadJsonFile();
	}
	catch (const std::exception& e)
	{
		printf("Exception : %s",e.what());
		ret = false;
	}
	catch (...)
	{
		printf("Exception Happen in LoadJsonFile");
		ret = false;
	}
	assert(ret);
	return ret;
}

std::shared_ptr<ServerHolder> ServerConfigure::GetServerHolder(int serverid, int servertype)
{
	switch (servertype)
	{
	case SERVER_TYPE_GATE:
		if (m_gateServers.find(serverid) != m_gateServers.end())
		{
			return m_gateServers.find(serverid)->second;
		}
		break;
	case SERVER_TYPE_GAME:
		if (m_gameServers.find(serverid) != m_gameServers.end())
		{
			return m_gameServers.find(serverid)->second;
		}
		break;
	case SERVER_TYPE_FIGHT:
		if (m_fightServers.find(serverid) != m_fightServers.end())
		{
			return m_fightServers.find(serverid)->second;
		}
		break;
	case SERVER_TYPE_DB:
		if (m_dbServers.find(serverid) != m_dbServers.end())
		{
			return m_dbServers.find(serverid)->second;
		}
		break;
	case SERVER_TYPE_GAMEMANAGER:
		return m_gamemanager;
		break;
	default:
		break;
	}
	return std::shared_ptr<ServerHolder>();
}

int ServerConfigure::GetServerType(SERVERID serverid)
{
	if (m_allServerID.find(serverid) != m_allServerID.end())
	{
		return m_allServerID.find(serverid)->second;
	}
	return SERVER_TYPE_NONE;
}


void ServerConfigure::GetServersOfType(int serverType, std::set<SERVERID>& servers)
{
	for (auto it = m_allServerID.begin(); it != m_allServerID.end(); ++it)
	{
		if (serverType == it->second)
		{
			servers.insert(it->first);
		}
	}
}

SERVERID ServerConfigure::GetServerID(std::string serverName)
{
	for (auto it = m_allServerID.begin(); it != m_allServerID.end(); ++it)
	{
		auto server = GetServerHolder(it->first, it->second);
		if (!server)
		{
			printf("Config Error ID %d type %d", it->first, it->second);
			//assert(false);
			return INVALID_SERVER_ID;
		}
		if (server->serverName == serverName)
		{
			return server->serverID;
		}
	}
	return INVALID_SERVER_ID;
}

DBConfig ServerConfigure::GetDBConfig()
{
	return *m_dbConfig;
}

bool ServerConfigure::CheckServerID(uint32_t serverID, int serverType)
{
	if (m_allServerID.find(serverID) != m_allServerID.end())
	{
		assert(!"Repeat ServerID");
		return false;
	}
	m_allServerID[serverID] = serverType;
	return true;
}

bool ServerConfigure::LoadJsonFile()
{
	std::ifstream  in_stream(m_configPath.c_str(), std::ios::binary);
	if (!in_stream)
	{
		assert(!"Failed read configure file");
		return false;
	}

	std::string buffer;
	buffer.resize(MAX_CONFIG_BUFFER);
	in_stream.read(const_cast<char*>(buffer.data()), buffer.size());

	json configure = json::parse(buffer.c_str());

	if (!LoadGameManagerConfigure(configure))
	{
		assert(!"Failed LoadGameManagerConfigure");
		return false;
	}

	if (!LoadGateConfigure(configure))
	{
		assert(!"Failed LoadGateConfigure");
		return false;
	}

	if (!LoadFightConfigure(configure))
	{
		assert(!"Failed LoadFightConfigure");
		return false;
	}

	if (!LoadGameConfigure(configure))
	{
		assert(!"Failed LoadGameConfigure");
		return false;
	}

	if (!LoadDBConfigure(configure))
	{
		assert(!"Failed LoadDBConfigure");
		return false;
	}

	return true;
}

bool ServerConfigure::LoadGameManagerConfigure(json& config)
{
	json& gamemanager = config["gamemanager"];
	if (!CheckServerID(gamemanager["id"], SERVER_TYPE_GAMEMANAGER))
	{
		throw std::logic_error("ServerID repeat");
		assert(!"Failed CheckServerID");
	}
	m_gamemanager = std::make_shared<ServerHolder>();
	m_gamemanager->serverID = gamemanager["id"];
	m_gamemanager->serverName = "gamemanager";
	m_gamemanager->listenPort = gamemanager["port"];
	m_gamemanager->consolePort = gamemanager["console_port"];
	const std::string listenIP = gamemanager["listen_ip"];
	m_gamemanager->listenIP = listenIP;
	const std::string connectIP = gamemanager["connect_ip"];
	m_gamemanager->connectIP = connectIP;
	m_gamemanager->serverType = SERVER_TYPE_GAMEMANAGER;
	const std::string logFilePath = gamemanager["log_path"];
	m_gamemanager->logFilePath = logFilePath;
	m_gamemanager->logLevel = gamemanager["log_level"];

	return true;
}

bool ServerConfigure::LoadGateConfigure(json& config)
{
	json& allGate = config["gate"];
	for (json::iterator it = allGate.begin(); it != allGate.end(); it++)
	{
		json& gateConfig = it.value();
		if (!CheckServerID(gateConfig["id"], SERVER_TYPE_GATE))
		{
			throw std::logic_error("ServerID repeat");
			assert(!"Failed CheckServerID");
		}

		std::shared_ptr<ServerHolder> gate = std::make_shared<ServerHolder>();
		gate->serverID = gateConfig["id"];
		gate->serverName = it.key();
		gate->listenPort = gateConfig["port"];
		gate->consolePort = gateConfig["console_port"];
		const std::string listenIP = gateConfig["listen_ip"];
		gate->listenIP = listenIP;
		const std::string connectIP = gateConfig["connect_ip"];
		gate->connectIP = connectIP;
		gate->serverType = SERVER_TYPE_GATE;
		const std::string logFilePath = gateConfig["log_path"];
		gate->logFilePath = logFilePath;
		gate->logLevel = gateConfig["log_level"];

		m_gateServers[gate->serverID] = gate;
	}
	return true;
}

bool ServerConfigure::LoadFightConfigure(json& config)
{
	json& allFight = config["fight"];
	for (json::iterator it = allFight.begin(); it != allFight.end(); it++)
	{
		json& fightConfig = it.value();
		if (!CheckServerID(fightConfig["id"], SERVER_TYPE_FIGHT))
		{
			throw std::logic_error("ServerID repeat");
			assert(!"Failed CheckServerID");
		}

		std::shared_ptr<ServerHolder> fight = std::make_shared<ServerHolder>();
		fight->serverID = fightConfig["id"];
		fight->serverName = it.key();
		fight->listenPort = fightConfig["port"];
		fight->consolePort = fightConfig["console_port"];
		const std::string listenIP = fightConfig["listen_ip"];
		fight->listenIP = listenIP;
		const std::string connectIP = fightConfig["connect_ip"];
		fight->connectIP = connectIP;
		const std::string luaPath = fightConfig["lua_path"];
		fight->luaPath = luaPath;
		fight->serverType = SERVER_TYPE_FIGHT;
		const std::string logFilePath = fightConfig["log_path"];
		fight->logFilePath = logFilePath;
		fight->logLevel = fightConfig["log_level"];

		m_fightServers[fight->serverID] = fight;
	}
	return true;
}

bool ServerConfigure::LoadGameConfigure(json& config)
{
	json& allGame = config["game"];
	for (json::iterator it = allGame.begin(); it != allGame.end(); it++)
	{
		json& gameConfig = it.value();
		if (!CheckServerID(gameConfig["id"], SERVER_TYPE_GAME))
		{
			throw std::logic_error("ServerID repeat");
			assert(!"Failed CheckServerID");
		}

		std::shared_ptr<ServerHolder> game = std::make_shared<ServerHolder>();
		game->serverID = gameConfig["id"];
		game->serverName = it.key();
		game->listenPort = gameConfig["port"];
		game->consolePort = gameConfig["console_port"]; 
		const std::string listenIP = gameConfig["listen_ip"];
		game->listenIP = listenIP;
		const std::string connectIP = gameConfig["connect_ip"];
		game->connectIP = connectIP;
		game->serverType = SERVER_TYPE_GAME;
		const std::string logFilePath = gameConfig["log_path"];
		game->logFilePath = logFilePath;
		game->logLevel = gameConfig["log_level"];
		const std::string luaPath = gameConfig["lua_path"];
		game->luaPath = luaPath;
		const std::string dbname = gameConfig["db"];
		game->dbname = dbname;

		m_gameServers[game->serverID] = game;
	}
	return true;
}

bool ServerConfigure::LoadDBConfigure(json& config)
{
	json& allDBProxy = config["dbproxy"];
	for (json::iterator it = allDBProxy.begin(); it != allDBProxy.end(); it++)
	{
		json& dbConfig = it.value();
		if (!CheckServerID(dbConfig["id"], SERVER_TYPE_DB))
		{
			throw std::logic_error("ServerID repeat");
			assert(!"Failed CheckServerID");
		}

		std::shared_ptr<ServerHolder> dbproxy = std::make_shared<ServerHolder>();
		dbproxy->serverID = dbConfig["id"];
		dbproxy->serverName = it.key();
		dbproxy->listenPort = dbConfig["port"];
		dbproxy->consolePort = dbConfig["console_port"];
		const std::string listenIP = dbConfig["listen_ip"];
		dbproxy->listenIP = listenIP;
		const std::string connectIP = dbConfig["connect_ip"];
		dbproxy->connectIP = connectIP;
		dbproxy->serverType = SERVER_TYPE_DB;
		const std::string logFilePath = dbConfig["log_path"];
		dbproxy->logFilePath = logFilePath;
		dbproxy->logLevel = dbConfig["log_level"];

		m_dbServers[dbproxy->serverID] = dbproxy;
	}

	m_dbConfig = new DBConfig;
	json& mongoConfig = config["mongo"];
	const std::string address1 = mongoConfig["address"];
	m_dbConfig->Address = address1 ;
	const std::string dbname1 = mongoConfig["dbname"];
	m_dbConfig->DBName = dbname1;
	const std::string username1 = mongoConfig["username"];
	m_dbConfig->UserName = username1;
	const std::string pwd1 = mongoConfig["pwd"];
	m_dbConfig->UserPassword = pwd1;
	return true;
}
