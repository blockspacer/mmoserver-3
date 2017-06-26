#ifndef __I_DB_CLIENT_MODULE_H__
#define __I_DB_CLIENT_MODULE_H__

#include <set>
#include "common.h"
// -------------------------------------------------------------------------
//    @FileName         :    IGameClientModule.h
//    @Author           :    houontherun@gmail.com
//    @Date             :    2016-11-1
//    @Module           :    
//
// -------------------------------------------------------------------------

class IDBClientModule
{
public:
	virtual ~IDBClientModule() {}

	virtual void SendDataToDBProxy(const int serverID, const int messageID, const char* data, const DATA_LENGTH_TYPE dataLength) = 0;

	virtual void SendMessageToDBProxy(const int serverID, const int messageID, IMessage* message) = 0;

};

#endif
