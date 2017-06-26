#ifndef _DB_LUAMODULE_H_
#define _DB_LUAMODULE_H_

#include "LuaModule.h"

class DBLuaModule :public LuaModule
{
public:
	DBLuaModule();

	~DBLuaModule();

	bool RegisterFunction();

	bool AfterInit()
	{
		return true;
	}
	/* 创建定时器
	*/
	virtual int32_t CreateTimer(const uint64_t timevel, const int mode);

	/* 销毁定时器
	*/
	virtual void DestroyTimer(int32_t tid) {}
};






#endif