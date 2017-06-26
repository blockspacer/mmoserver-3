#ifndef __I_GAME_CLIENT_MODULE_H__
#define __I_GAME_CLIENT_MODULE_H__

#include <set>
#include "common.h"
#include "message.h"
// -------------------------------------------------------------------------
//    @FileName         :    IGameClientModule.h
//    @Author           :    houontherun@gmail.com
//    @Date             :    2016-11-1
//    @Module           :    接口文件
//
// -------------------------------------------------------------------------

class IGameClientModule
{
public:
	virtual ~IGameClientModule(){}

	virtual void GetAllValidGameServer(std::set<SERVERID>& outServers) = 0;

	virtual void SendEntityMessage(SESSIONID sid, SERVERID gameid, ClientMessageHead* head, const char * data, const DATA_LENGTH_TYPE dataLength) = 0;
	virtual void SendMessageToGameServer(const int gameid, const int serviceType, IMessage* message) = 0;
	virtual void SendDataToGameServer(const int gameid, const int serviceType, const char * data, const DATA_LENGTH_TYPE dataLength, const SERVERID srcGameID = 0) = 0;
	virtual void NotifyClientConnectionClose(const SESSIONID clientSession, const SERVERID gameid) = 0;
	virtual void BroadcastDataToAllGame(const SERVERID srcID, const int messageType, const char* data, const DATA_LENGTH_TYPE dataLength) = 0;
};

#endif
