#ifndef _LOG_MODULE_H_
#define _LOG_MODULE_H_

#include "ILogModule.h"

class LogModule: public ILogModule
{
public:

	LogModule():m_loglevel(1){};
	virtual ~LogModule() {}

	virtual bool Init(std::string logPath, int level);
	virtual bool Shut();

	virtual bool BeforeShut();
	virtual bool AfterInit();

	virtual bool Execute();

	///////////////////////////////////////////////////////////////////////
	virtual void LogStack();

	virtual bool LogDebugFunctionDump( const int nMsg, const std::string& strArg, const char* func = "", const int line = 0);
	virtual bool ChangeLogLevel(const std::string& strLevel);

	virtual bool Log(const LOG_LEVEL nll, const char* data);
	virtual bool Log(const LOG_LEVEL nll, const char* format, ...);
	virtual bool Log(const LOG_LEVEL nll, const char* functionname, const char* format, ...);
	virtual bool Log(const LOG_LEVEL nll, const char* filename, int line,const char* functionname,  const char* format, ...);

	static bool CheckLogFileExist(const char* filename);
	static void rolloutHandler(const char* filename, std::size_t size);

private:
	static unsigned int idx;
	uint64_t mnLogCountTotal;
	int m_loglevel;
};

#endif