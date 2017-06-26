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
	uint16_t SerialNumber;				// ��ˮ�ţ���ֹ�������
	uint16_t ServiceType;               // �������ͱ�ʶ
	uint16_t MessageID;					// ��Ϊ��Ϣ��
	ClientMessageHead()
	{
		memset(this, 0, sizeof(*this));
	}
};

#define DATA_LENGTH_TYPE uint32_t
// �������ĳ��ȣ������ְ����� 
#define NET_HEAD_LENGTH  sizeof(uint32_t) 
// ��Ϣ���ĳ���
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

// ������Ϣ����������Ϣ������Ҫ�����Ϣͷ
struct ServerMessageHead
{
	uint16_t ServiceType;
	SERVERID SrcServerID;//������Ϣ�ķ�����ID����ת�������¼
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