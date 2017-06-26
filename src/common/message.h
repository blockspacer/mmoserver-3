#ifndef __MSG_H__
#define __MSG_H__


#include <stdint.h>
#include <string.h>

#include "common.h"
#include <google/protobuf/message.h>
#include <google/protobuf/stubs/common.h>
typedef ::google::protobuf::Message IMessage;

#define GLOBAL_SERVER_ID    100



#pragma pack(push, 1)

struct ClientMessageHead
{
	uint16_t SerialNumber;				// 流水号，防止发包外挂
	uint16_t ServiceType;               // 服务类型标识
	uint16_t MessageID;					// 行为消息码
	ClientMessageHead()
	{
		memset(this, 0, sizeof(*this));
	}
};

#define DATA_LENGTH_TYPE uint32_t
// 数据流的长度，用作分包处理 
#define NET_HEAD_LENGTH  sizeof(uint32_t) 
// 消息包的长度
#define CLIENT_MESSAGE_HEAD_LENGTH sizeof(ClientMessageHead)

struct EntityMessageHead
{
	SESSIONID ClientSessionID;
	CLIENTID ClientID;
	MESSAGEID MessageID;

	EntityMessageHead()
	{
		memset(this, 0, sizeof(*this));
	}
};
#define ENTITY_MESSAGE_HEAD_LENGTH sizeof(EntityMessageHead)

// 内网消息，内网内消息流动需要这个消息头
struct ServerMessageHead
{
	uint16_t ServiceType;
	SERVERID SrcServerID;//发出消息的服务器ID，中转服不会记录
	SERVERID DstServerID;     
	ServerMessageHead()
	{
		memset(this, 0, sizeof(*this));
	}
};

#define SERVER_MESSAGE_HEAD_LENGTH sizeof(ServerMessageHead)

struct ClientProxy
{
	CLIENTID     ClientID;
	SERVERID     GateID;
	SESSIONID    ClientSessionID;

	ClientProxy() {
		memset(this, 0, sizeof(*this));
	}
};


struct GMMessageHead
{
	int AdminSock;
	MESSAGEID MessageID;

	GMMessageHead()
	{
		memset(this, 0, sizeof(*this));
	}
};
#define GM_MESSAGE_HEAD_LENGTH sizeof(GMMessageHead)


uint16_t GetPackServerMessageHeadLength();
#pragma pack(pop)

#endif