
#define GLOG_NO_ABBREVIATED_SEVERITIES
#include <stdarg.h>
#include "LogModule.h"
#include "easylogging++.h"

INITIALIZE_EASYLOGGINGPP

static ILogModule* g_logModule = nullptr;

void SetLogListen(ILogModule* listener)
{
	g_logModule = listener;
}

ILogModule* GetLogModule()
{
	return g_logModule;
}

void Log(const LOG_LEVEL nll, const char* format, ...)
{
	if (!g_logModule)
	{
		return;
	}
	char szBuffer[1024 * 10] = { 0 };

	va_list args;
	va_start(args, format);
	vsnprintf(szBuffer, sizeof(szBuffer) - 1, format, args);
	va_end(args);

	g_logModule->Log(nll, format, szBuffer);
}

unsigned int LogModule::idx = 0;

bool LogModule::CheckLogFileExist(const char* filename)
{
	std::stringstream stream;
	stream << filename << "." << ++idx;
	std::fstream file;
	file.open(stream.str(), std::ios::in);
	if (file)
	{
		return CheckLogFileExist(filename);
	}

	return false;
}

void LogModule::rolloutHandler(const char* filename, std::size_t size)
{
	std::stringstream stream;
	if (!CheckLogFileExist(filename))
	{
		stream << filename << "." << idx;
		rename(filename, stream.str().c_str());
	}
}


bool LogModule::Init(std::string logFilePath, int level)
{
	m_loglevel = level;
	mnLogCountTotal = 0;

	el::Loggers::addFlag(el::LoggingFlag::StrictLogFileSizeCheck);
	el::Loggers::addFlag(el::LoggingFlag::DisableApplicationAbortOnFatalLog);

	//el::Configurations conf(logPath);
	//el::Loggers::reconfigureAllLoggers(conf);
	//el::Helpers::installPreRollOutCallback(rolloutHandler);

	el::Configurations defaultConf;
	
	defaultConf.setToDefault();

	defaultConf.setGlobally(el::ConfigurationType::Format, "[%level|%datetime]|%msg");

	defaultConf.setGlobally( el::ConfigurationType::Filename, logFilePath);

	defaultConf.setGlobally(el::ConfigurationType::ToFile, "true");

#ifdef _LINUX
	defaultConf.setGlobally(el::ConfigurationType::ToStandardOutput, "false");
#else
	defaultConf.setGlobally(el::ConfigurationType::ToStandardOutput, "true");
#endif // _LINUX

	defaultConf.setGlobally(el::ConfigurationType::PerformanceTracking, "true");

	defaultConf.setGlobally(el::ConfigurationType::MillisecondsWidth, "3");

	defaultConf.setGlobally(el::ConfigurationType::MaxLogFileSize, "50000000");

	defaultConf.setGlobally(el::ConfigurationType::LogFlushThreshold, "0");

	//defaultConf.set(el::Level::Info, el::ConfigurationType::Format, "%datetime %level %msg");

	el::Loggers::reconfigureLogger("default", defaultConf);
	el::Helpers::installPreRollOutCallback(rolloutHandler);
	return true;
}

bool LogModule::Shut()
{
	el::Helpers::uninstallPreRollOutCallback();

	return true;
}

bool LogModule::BeforeShut()
{
	return true;

}

bool LogModule::AfterInit()
{
	return true;

}

bool LogModule::Execute()
{
	return true;

}

bool LogModule::Log(const LOG_LEVEL nll, const char* format, ...)
{
	if (nll < m_loglevel)
	{
		return true;
	}
	mnLogCountTotal++;

	char szBuffer[1024 * 10] = { 0 };

	va_list args;
	va_start(args, format);
	vsnprintf(szBuffer, sizeof(szBuffer) - 1, format, args);
	va_end(args);

	switch (nll)
	{

	case LOG_LEVEL::LOG_LEVEL_TRACE:
		LOG(TRACE) << szBuffer;
		break;
	case LOG_LEVEL::LOG_LEVEL_DEBUG:
		LOG(DEBUG) << szBuffer;
		break;
	case LOG_LEVEL::LOG_LEVEL_INFO:
		LOG(INFO) << szBuffer;
		break;
	case LOG_LEVEL::LOG_LEVEL_WARN:
		LOG(WARNING) << szBuffer;
		break;
	case LOG_LEVEL::LOG_LEVEL_ERROR:
		LOG(ERROR) << szBuffer;
		break;
	case LOG_LEVEL::LOG_LEVEL_FATAL:
		LOG(FATAL) << szBuffer;
		break;
	default:
		LOG(TRACE) << szBuffer;
		break;
	}

	return true;
}


bool LogModule::Log(const LOG_LEVEL nll, const char* functionname, const char* format, ...)
{
	if (nll < m_loglevel)
	{
		return true;
	}
	char szBuffer[1024 * 10] = { 0 };

	va_list args;
	va_start(args, format);
	vsnprintf(szBuffer, sizeof(szBuffer) - 1, format, args);
	va_end(args);

	switch (nll)
	{

	case LOG_LEVEL::LOG_LEVEL_TRACE:
		LOG(TRACE) << functionname << " | " << szBuffer ;
		break;
	case LOG_LEVEL::LOG_LEVEL_DEBUG:
		LOG(DEBUG) << functionname << " | " << szBuffer;
		break;
	case LOG_LEVEL::LOG_LEVEL_INFO:
		LOG(INFO) << functionname << " | " << szBuffer;
		break;
	case LOG_LEVEL::LOG_LEVEL_WARN:
		LOG(WARNING) << functionname << " | " << szBuffer;
		break;
	case LOG_LEVEL::LOG_LEVEL_ERROR:
		LOG(ERROR) << functionname << " | " << szBuffer;
		break;
	case LOG_LEVEL::LOG_LEVEL_FATAL:
		LOG(FATAL) << functionname << " | " << szBuffer;
		break;
	default:
		LOG(TRACE) << functionname << " | " << szBuffer;
		break;
	}

	return true;
}


bool LogModule::Log(const LOG_LEVEL nll, const char* filename, int line, const char* functionname, const char* format, ...)
{
	if (nll < m_loglevel)
	{
		return true;
	}
	char szBuffer[1024 * 10] = { 0 };

	va_list args;
	va_start(args, format);
	vsnprintf(szBuffer, sizeof(szBuffer) - 1, format, args);
	va_end(args);

	switch (nll)
	{

	case LOG_LEVEL::LOG_LEVEL_TRACE:
		LOG(TRACE) << functionname << " | " << szBuffer << " | " << filename << " line:" << line;
		break;
	case LOG_LEVEL::LOG_LEVEL_DEBUG:
		LOG(DEBUG) << functionname << " | " << szBuffer << " | " << filename << " line:" << line;
		break;
	case LOG_LEVEL::LOG_LEVEL_INFO:
		LOG(INFO) << functionname << " | " << szBuffer << " | " << filename << " line:" << line;
		break;
	case LOG_LEVEL::LOG_LEVEL_WARN:
		LOG(WARNING) << functionname << " | " << szBuffer << " | " << filename << " line:" << line;
		break;
	case LOG_LEVEL::LOG_LEVEL_ERROR:
		LOG(ERROR) << functionname << " | " << szBuffer << " | " << filename << " line:" << line;
		break;
	case LOG_LEVEL::LOG_LEVEL_FATAL:
		LOG(FATAL) << functionname << " | " << szBuffer << " | " << filename << " line:" << line;
		break;
	default:
		LOG(TRACE) << functionname << " | " << szBuffer << " | " << filename << " line:" << line;
		break;
	}
	return true;
}

bool LogModule::Log(const LOG_LEVEL nll, const char* data)
{
	if (nll < m_loglevel)
	{
		return true;
	}
	mnLogCountTotal++;

	switch (nll)
	{

	case LOG_LEVEL::LOG_LEVEL_TRACE:
		LOG(TRACE) << data;
		break;
	case LOG_LEVEL::LOG_LEVEL_DEBUG:
		LOG(DEBUG) << data;
		break;
	case LOG_LEVEL::LOG_LEVEL_INFO:
		LOG(INFO) << data;
		break;
	case LOG_LEVEL::LOG_LEVEL_WARN:
		LOG(WARNING) << data;
		break;
	case LOG_LEVEL::LOG_LEVEL_ERROR:
		LOG(ERROR) << data;
		break;
	case LOG_LEVEL::LOG_LEVEL_FATAL:
		LOG(FATAL) << data;
		break;
	default:
		LOG(TRACE) << data;
		break;
	}

	return true;
}

void LogModule::LogStack()
{
}



bool LogModule::LogDebugFunctionDump(  const int nMsg, const std::string& strArg, const char* func /*= ""*/, const int line /*= 0*/)
{
	return true;
}

bool LogModule::ChangeLogLevel(const std::string& strLevel)
{
	//el::Level logLevel = el::LevelHelper::convertFromString(strLevel.c_str());
	//el::Logger* pLogger = el::Loggers::getLogger("default");
	//if (NULL == pLogger)
	//{
	//	return false;
	//}

	//el::Configurations* pConfigurations = pLogger->configurations();
	//el::base::TypedConfigurations* pTypeConfigurations = pLogger->typedConfigurations();
	//if (NULL == pConfigurations)
	//{
	//	return false;
	//}

	//// log级别为debug, info, warning, error, fatal(级别逐渐提高)
	//// 当传入为info时，则高于(包含)info的级别会输出
	//// !!!!!! NOTICE:故意没有break，请千万注意 !!!!!!
	//switch (logLevel)
	//{
	//case el::Level::Fatal:
	//{
	//	el::Configuration errorConfiguration(el::Level::Error, el::ConfigurationType::Enabled, "false");
	//	pConfigurations->set(&errorConfiguration);
	//}
	//case el::Level::Error:
	//{
	//	el::Configuration warnConfiguration(el::Level::Warning, el::ConfigurationType::Enabled, "false");
	//	pConfigurations->set(&warnConfiguration);
	//}
	//case el::Level::Warning:
	//{
	//	el::Configuration infoConfiguration(el::Level::Info, el::ConfigurationType::Enabled, "false");
	//	pConfigurations->set(&infoConfiguration);
	//}
	//case el::Level::Info:
	//{
	//	el::Configuration debugConfiguration(el::Level::Debug, el::ConfigurationType::Enabled, "false");
	//	pConfigurations->set(&debugConfiguration);

	//}
	//case el::Level::Debug:
	//	break;
	//default:
	//	break;
	//}

	//el::Loggers::reconfigureAllLoggers(*pConfigurations);
	//Log(LOG_LEVEL::LOG_LEVEL_INFO, "[Log] Change log level", strLevel, __FUNCTION__, __LINE__);
	return true;
}
