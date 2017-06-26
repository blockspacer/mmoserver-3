#include "exception.h"

MyException::MyException(int nCode, const std::string& strMsg)
	:m_nCode(nCode), m_strMsg(strMsg)
{
}


MyException::MyException(int nCode, const char* pszMsg)
	: m_nCode(nCode), m_strMsg(pszMsg)
{
}

MyException::~MyException()
{

}


void ThrowException(int n, const char* pszMsg, ...)
{
	char szTmp[512];
	memset(szTmp, 0, sizeof(szTmp));
	va_list ap;
	va_start(ap, pszMsg);
	vsnprintf(szTmp, sizeof(szTmp) - 1, pszMsg, ap);
	va_end(ap);

	throw MyException(n, szTmp);
}