#include "DBLuaModule.h"

#include "DBLuaFunction.h"

/* ���캯��
*/
DBLuaModule::DBLuaModule() 
{
}

/* ��������
*/
DBLuaModule::~DBLuaModule()
{

}

bool DBLuaModule::RegisterFunction()
{
	return false;
}

int32_t DBLuaModule::CreateTimer(const uint64_t timevel, const int mode)
{
	return int32_t();
}


