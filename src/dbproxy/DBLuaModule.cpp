#include "DBLuaModule.h"

#include "DBLuaFunction.h"

/* 构造函数
*/
DBLuaModule::DBLuaModule() 
{
}

/* 析构函数
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


