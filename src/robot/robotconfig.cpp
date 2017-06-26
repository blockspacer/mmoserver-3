#include "robotconfig.h"
#include <fstream>
#define _PRESS

bool RobotConfigure::Init(std::string configPath,std::string clientName)
{
//#ifdef _FIGHT
//	ConnectIP = "112.13.170.138";
//	ConnectPort = 4006;
//	MaxClientCount = 1;
//	LuaPath = "";
//	LogFilePath = "./fight_%datetime{%Y%M%d}.log";
//	LogLevel = 0;
//
//	return true;
//#endif // _FIGHT
//
//#ifdef _GAME
//	ConnectIP = "112.13.170.138";
//	ConnectPort = 4005;
//	MaxClientCount = 1;
//	LuaPath = "";
//	LogFilePath = "./game_%datetime{%Y%M%d}.log";
//	LogLevel = 0;
//
//	return true;
//#endif

//#ifdef _PRESS
	m_configPath = configPath;
	m_clientName = clientName;
	bool ret = false;
	try
	{
		ret = LoadJsonFile();
	}
	catch (const std::exception& e)
	{
		printf("Exception : %s", e.what());
		ret = false;
	}
	catch (...)
	{
		printf("Exception Happen in LoadJsonFile");
		ret = false;
	}
	assert(ret);
	return ret;
//#endif

}

bool RobotConfigure::LoadJsonFile()
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

	json allConfigure = json::parse(buffer.c_str());
	json& configure = allConfigure[m_clientName];

	m_nClientID = configure["id"];
	const std::string connectIP = configure["connect_ip"];
	ConnectIP = connectIP;
	ConnectPort = configure["port"];
	MaxClientCount = configure["max_client_count"];

	const std::string luaPath = configure["lua_path"];
	LuaPath = luaPath;

	const std::string logFilePath = configure["log_path"];
	LogFilePath = logFilePath;

	LogLevel = configure["log_level"];
	return true;
}
