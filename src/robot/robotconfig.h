#pragma once
#ifndef _CLIENT_CONFIG_H_
#define _CLIENT_CONFIG_H_

#include "common.h"
#include "json.hpp"
using json = nlohmann::json;

#define MAX_CONFIG_BUFFER 100*1024 

class RobotConfigure
{
public:
	RobotConfigure() {}
	~RobotConfigure() {}

	bool Init(std::string configPath,std::string clientName);

private:
	bool LoadJsonFile();

public:
	std::string ConnectIP;
	int ConnectPort;
	int MaxClientCount;

	std::string LuaPath;
	std::string LogFilePath;
	std::string m_clientName;
	uint32_t m_nClientID;
	int LogLevel;

private:
	std::string m_configPath;
};

#endif // !_CLIENT_CONFIG_H_
