#ifndef __MONGOMODULE_H__
#define __MONGOMODULE_H__

#ifdef _WIN32
#include <winsock2.h>
#endif

#include "mongo/client/dbclient.h"
#include "common.h"
#include "message.h"

class MongoModule
{
public:
	MongoModule();
	~MongoModule();

	bool Init();

	mongo::DBClientConnection&  GetDBConnection() { return m_dbconn; }

	void InsertOpreation(SERVERID src, const char * message, const DATA_LENGTH_TYPE messageLength);

	void UpdateOpearation(SERVERID src, const char * message, const DATA_LENGTH_TYPE messageLength);

	void FindOneOperation(SERVERID src, const char * message, const DATA_LENGTH_TYPE messageLength);

	void FindNOperation(SERVERID src, const char * message, const DATA_LENGTH_TYPE messageLength);

	void FindAndModifyOperation(SERVERID src, const char * message, const DATA_LENGTH_TYPE messageLength);

private:
	mongo::DBClientConnection    m_dbconn;
	std::string                  m_dbname;
	std::string m_dbAddress;
	std::string m_dbName;
	std::string m_dbUser;
	std::string m_dbPwd;

};



#endif
