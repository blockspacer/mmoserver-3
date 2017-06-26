#ifndef _I_LUAMODULE_H_
#define _I_LUAMODULE_H_

#ifdef _WIN32 
// 为了阻止VS检查strncpy不安全
#pragma warning (disable : 4996)
#endif // !_WIN32



#include <string>
#include <string.h>
extern "C"
{
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
}
// 脚本数据类型定义
enum
{
	SD_NUMBER = 0,				// 数字类型
	SD_DOUBLE,					// 浮点数据类型
	SD_STRING,					// 字符串类型
	SD_POINTER,					// 用户定义数据类型
	SD_LSTRING,					// 长字符串，包括0
	SD_MAXID,					// 最大类型
};

// Lua参数对象定义
class CLuaParam
{
	enum { TEXT_SIZE = 256 };
	int64_t		nNumber;				// 数值
	double		dNumber;				// 浮点数
	size_t		nTextLen;				// 动态字符串长度
	char*		pszText;				// 动态字符串
	char		szText[TEXT_SIZE];		// 静态字符串
	void*		pUserData;				// 用户定义数据类型
	int			nValueType;				// 参数类型

public:
	CLuaParam()
	{
		nValueType = SD_NUMBER;
		nNumber = 0;
		dNumber = 0.0f;
		nTextLen = 0;
		pszText = NULL;
		pUserData = NULL;
		memset(szText, 0, sizeof(szText));
	}

	~CLuaParam()
	{
		if (pszText != NULL)
		{
			delete[] pszText;
			pszText = NULL;
		}
	}

	bool SetType(int nType)
	{
		if (nType < 0 || nType >= SD_MAXID)
		{
			return false;
		}
		nValueType = nType;
		return true;
	}

	int GetType()
	{
		return nValueType;
	}

	size_t GetLength()
	{
		return nTextLen;
	}

	void operator = (int nValue)
	{
		nValueType = SD_NUMBER;
		nNumber = nValue;
	}
	void operator = (uint16_t nValue)
	{
		nValueType = SD_NUMBER;
		nNumber = nValue;
	}
	void operator = (uint32_t nValue)
	{
		nValueType = SD_NUMBER;
		nNumber = nValue;
	}
	void operator = (uint64_t nValue)
	{
		nValueType = SD_NUMBER;
		nNumber = nValue;
	}
	void operator = (int64_t nValue)
	{
		nValueType = SD_NUMBER;
		nNumber = nValue;
	}
	void operator = (double nValue)
	{
		nValueType = SD_DOUBLE;
		dNumber = nValue;
	}


	void operator = (const char* str)
	{
		nValueType = SD_STRING;
		if (str == NULL)
		{
			return;
		}
		if (pszText != NULL)
		{
			delete[] pszText;
			pszText = NULL;
		}
		size_t len = strlen(str);
		if (len >= TEXT_SIZE)
		{
			pszText = new char[len + 1];
			strncpy(pszText, str, len + 1);
		}
		else
		{
			strncpy(szText, str, sizeof(szText));
		}
		nTextLen = len;
	}

	void operator = (std::string str)
	{
		nValueType = SD_LSTRING;

		if (pszText != NULL)
		{
			delete[] pszText;
			pszText = NULL;
		}
		size_t len = str.length();
		if (len >= TEXT_SIZE)
		{
			pszText = new char[len + 1];
			memcpy(pszText, str.data(), len);
		}
		else
		{
			memcpy(szText, str.data(), len);
		}
		nTextLen = len;
	}


	void operator = (void * pValue)
	{
		nValueType = SD_POINTER;
		pUserData = pValue;
	}

	operator int(void)
	{
		return (int)nNumber;
	}

	operator uint16_t(void)
	{
		return (uint16_t)nNumber;
	}

	operator uint32_t(void)
	{
		return (uint32_t)nNumber;
	}

	operator uint64_t(void)
	{
		return nNumber;
	}

	operator int64_t(void)
	{
		return nNumber;
	}

	operator double(void)
	{
		return dNumber;
	}

	operator const char*(void)
	{
		return (pszText == NULL) ? szText : pszText;
	}

	operator void *(void)
	{
		return pUserData;
	}
};



int lua_pcallwithtraceback(lua_State* L, int nargs, int nret);

struct ILuaModule
{
public:
	virtual ~ILuaModule() {}

	// 加载一个lua文件
	virtual bool LoadFile(const char* szFileName) = 0;

	// 执行一段内存里lua
	virtual bool RunMemory(const char* pLuaData, int nDataLen, std::string& err) = 0;

	// 调用一个lua函数
	virtual bool RunFunction(const char* szFunName, CLuaParam* pInParam, int nInNum, CLuaParam* pOutParam, int nOutNum) = 0;

	virtual int32_t CreateTimer(const uint64_t timevel, const int mode) = 0;

	virtual void DestroyTimer(int32_t tid) = 0;

	virtual bool IsThisMoudle(void *L) = 0;

	virtual lua_State* GetLuaState() = 0;
};

#endif