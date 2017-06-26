#pragma once
#ifndef __EXCEPTION__HEAD__
#define __EXCEPTION__HEAD__

#ifdef _WIN32
#pragma warning (disable:4786)
#pragma warning (disable:4503)
#endif

#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>
#include <string>
#include <string.h>

//自定义异常类
class MyException
{
public:
	MyException(int nCode, const std::string& strMsg);
	MyException(int nCode, const char* pszMsg);
	~MyException();

public:
	inline int GetCode() const
	{
		return m_nCode;
	}

	inline std::string GetMsg() const
	{
		return m_strMsg;
	}

private:
	int m_nCode;
	std::string m_strMsg;

};


inline void ThrowException(int n, const std::string& s)
{
	throw MyException(n, s);
}


extern void ThrowException(int n, const char* s, ...);


#endif