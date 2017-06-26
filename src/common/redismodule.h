#pragma once
#ifndef _REDIS_MODULE_H_
#define _REDIS_MODULE_H_

#ifdef _ASYN_REDIS

#include <string>
#include "common.h"
#include "Singleton.h"
#include "LuaModule.h"

#ifdef _LINUX
#include "event2/event.h"
#include "hiredis.h"
#include "async.h"
#include "adapters/libevent.h"
#endif

enum RedisState {
	RedisState_DISCONNECT = 0,
	RedisState_CONNECTED,
};

class RedisModule : public Singleton<RedisModule>
{
public:
	RedisModule() {}
	~RedisModule() {}

	bool Init();

	void Tick();

	int DoCommand(void* callback, void* callback_param, const char *command, ...);

	int Command(uint32_t callbackid, std::string command);

	void SetState(int state);

	bool IsConnected();
private:
#ifdef _LINUX
	struct event_base* m_eventBase;
	struct redisAsyncContext* m_conn;
#endif
	std::string m_redisIP;
	int m_redisPort;
	int m_callbackid;
	int m_state;
};

#endif //!_ASYN_REDIS

#endif // !_REDIS_MODULE
