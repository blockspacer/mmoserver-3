#ifndef __I_LOG_MODULE_H__
#define __I_LOG_MODULE_H__


#include <string>

enum LOG_LEVEL
{
	LOG_LEVEL_TRACE = 1,
	LOG_LEVEL_DEBUG = 2,
	LOG_LEVEL_INFO = 3,
	LOG_LEVEL_WARN = 4,
	LOG_LEVEL_ERROR = 5,
	LOG_LEVEL_FATAL = 6,
};

class ILogModule
{
public:
	virtual ~ILogModule() {}
	virtual bool Log(const LOG_LEVEL nll, const char* format, ...) = 0;
	virtual bool Log(const LOG_LEVEL nll, const char* functionname, const char* format, ...) = 0;
	virtual bool Log(const LOG_LEVEL nll, const char* filename, int line, const char* functionname,  const char* format, ...) = 0;
};

void SetLogListen(ILogModule* listener);

ILogModule* GetLogModule();


#ifdef _LINUX
#define _trace(f, ...)	            {GetLogModule()->Log(LOG_LEVEL_TRACE, __FUNCTION__, f, ##__VA_ARGS__);}
#define _debug(f, ...)	            {GetLogModule()->Log(LOG_LEVEL_DEBUG, __FUNCTION__, f, ##__VA_ARGS__);}
#define _info(f, ...)	            {GetLogModule()->Log(LOG_LEVEL_INFO, __FUNCTION__, f, ##__VA_ARGS__ );}
#define _warn(f, ...)	            {GetLogModule()->Log(LOG_LEVEL_WARN, __FILE__, __LINE__, __FUNCTION__, f, ##__VA_ARGS__);}
#define _xerror(f, ...)	            {GetLogModule()->Log(LOG_LEVEL_ERROR,  __FILE__, __LINE__,__FUNCTION__,  f, ##__VA_ARGS__);}
#define _fatal(f, ...)	            {GetLogModule()->Log(LOG_LEVEL_FATAL,  __FILE__, __LINE__,__FUNCTION__,  f, ##__VA_ARGS__);}
#else
#define _trace(f, ...)	            {GetLogModule()->Log(LOG_LEVEL_TRACE, __FUNCTION__, f, __VA_ARGS__);}
#define _debug(f, ...)	            {GetLogModule()->Log(LOG_LEVEL_DEBUG, __FUNCTION__, f, __VA_ARGS__);}
#define _info(f, ...)	            {GetLogModule()->Log(LOG_LEVEL_INFO, __FUNCTION__, f, __VA_ARGS__ );}
#define _warn(f, ...)	            {GetLogModule()->Log(LOG_LEVEL_WARN, __FILE__, __LINE__, __FUNCTION__, f, __VA_ARGS__);}
#define _xerror(f, ...)	            {GetLogModule()->Log(LOG_LEVEL_ERROR,  __FILE__, __LINE__,__FUNCTION__,  f, __VA_ARGS__);}
#define _fatal(f, ...)	            {GetLogModule()->Log(LOG_LEVEL_FATAL,  __FILE__, __LINE__,__FUNCTION__,  f, __VA_ARGS__);}
#endif

#endif