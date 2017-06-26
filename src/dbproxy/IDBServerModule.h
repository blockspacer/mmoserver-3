#ifndef __I_DBServer_MODULE_H__
#define __I_DBServer_MODULE_H__

#include "message.h"

class IDBServerModule
{
public:
	virtual ~IDBServerModule() {}

	virtual void SendResultBack(const SERVERID clientSessionID, const MESSAGEID messageID, IMessage * message) = 0;
	virtual void SendResultBack(const SERVERID clientSessionID, const MESSAGEID messageID, const char* data, const DATA_LENGTH_TYPE dataLength) = 0;
};


#endif // !__I_DBServer_MODULE_H__




