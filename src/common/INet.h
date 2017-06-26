#ifndef __I_NET_H__
#define __I_NET_H__

// -------------------------------------------------------------------------
//    @FileName         :    INet.h
//    @Author           :    houontherun@gmail.com
//    @Date             :    2016-11-1
//    @Module           :   
//
// -------------------------------------------------------------------------


#include <cstring>
#include <errno.h>
#include <stdio.h>
#include <signal.h>
#include <stdint.h>
#include <iostream>
#include <map>

#ifndef _MSC_VER
#include <netinet/in.h>
# ifdef _XOPEN_SOURCE_EXTENDED
#  include <arpa/inet.h>
# endif
#include <sys/socket.h>
#endif

#include <vector>
#include <functional>
#include <memory>
#include <list>
#include <vector>
#include <event2/bufferevent.h>
#include <event2/buffer.h>
#include <event2/listener.h>
#include <event2/util.h>
#include <event2/thread.h>
#include <event2/event_compat.h>
#include <assert.h>

#ifdef _MSC_VER
#include <windows.h>
#else
#include <unistd.h>
#endif
#include "common.h"
#include "message.h"

enum NET_EVENT
{
	NET_EVENT_EOF = 0x10,        
	NET_EVENT_ERROR = 0x20,      
	NET_EVENT_TIMEOUT = 0x40,   
	NET_EVENT_CONNECTED = 0x80,  
};



class INet;

typedef std::function<void(const int sock, const char* data, const DATA_LENGTH_TYPE dataLength)> NET_RECEIVE_FUNCTOR;
typedef std::shared_ptr<NET_RECEIVE_FUNCTOR> NET_RECEIVE_FUNCTOR_PTR;

typedef std::function<void(const int sock, const NET_EVENT event, INet* net)> NET_EVENT_FUNCTOR;
typedef std::shared_ptr<NET_EVENT_FUNCTOR> NET_EVENT_FUNCTOR_PTR;

typedef std::function<void(int severity, const char* msg)> NET_EVENT_LOG_FUNCTOR;
typedef std::shared_ptr<NET_EVENT_LOG_FUNCTOR> NET_EVENT_LOG_FUNCTOR_PTR;

class SocketSession;

class INet
{
public:
	INet()
	{
		m_sendMessageTotalCount = 0;
		m_sendMessageTotalBytes = 0;
		m_receiveMessageTotalCount = 0;
		m_receiveMessageTotalBytes = 0;
		m_sendCountTick = 0;
		m_recvCountTick = 0;
		m_sendLengthTick = 0;
		m_recvLengthTick = 0;
		m_tickCount = 0;
	}

	virtual ~INet() {}

	virtual bool Tick() = 0;

	virtual void Initialization(const char* strIP, const unsigned short nPort) = 0;

	virtual int Initialization(const unsigned int nMaxClient, const unsigned short nPort, const int nCpuCount = 4) = 0;

	virtual bool Final() = 0;

	virtual bool CloseSocketSession(const int sock) = 0;

	virtual SocketSession* GetSocketSession(const int sock) = 0;
	
	virtual bool AddSocketSession(const int sock, SocketSession* session) = 0;

	virtual bool IsServer() = 0;

	virtual bool Log(int severity, const char* msg) = 0;

	virtual bool SendMsg(const char* msg, const uint32_t dataLength, const int sock) = 0;

	virtual const char* GetPollName() = 0;

	int m_sendMessageTotalCount;
	int m_sendMessageTotalBytes;

	int m_receiveMessageTotalCount;
	int m_receiveMessageTotalBytes;

	int m_sendCountTick;
	int m_recvCountTick;
	int m_sendLengthTick;
	int m_recvLengthTick;

	int m_tickCount;
};


#endif
