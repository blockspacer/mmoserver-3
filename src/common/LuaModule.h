#ifndef _LUAMODULE_H_
#define _LUAMODULE_H_


#include "ILuaModule.h"
#include "LogModule.h"
#include "Singleton.h"

class LuaModule :public Singleton<LuaModule>
{
public:
	LuaModule();

	~LuaModule();

	bool Init(std::string luaPath);

	void Release();

	bool LoadFile(const char* szFileName);

	bool RunMemory(const char* pLuaData, int nDataLen, std::string& err);

	bool RunFunction(const char* szFunName, CLuaParam* pInParam, int nInNum, CLuaParam* pOutParam, int nOutNum);

	bool Reload();

	lua_State* GetLuaState();

	bool IsThisMoudle(void *L)
	{
		return m_pLuaState == L;
	}
	int32_t CreateTimer(const uint64_t interval, const int mode);

	void DestroyTimer(int32_t tid);

	void LuaOnTimer(int timerid);
	lua_State*				m_pLuaState;

	bool IsReady();

	void ShowDebugInfo();

private:
	bool m_isReady;
	uint64_t lastTickTime;
};



#endif