#ifndef __SOCKET_SESSION_H__
#define __SOCKET_SESSION_H__

// -------------------------------------------------------------------------
//    @FileName         :    SocketSession.h
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

class INet;

class SocketSession
{
public:
	SocketSession(INet* net, int32_t fd, sockaddr_in& addr, bufferevent* pBev)
	{
		m_sock = fd;
		m_needRemove = false;
		m_gameServerID = 0;

		m_net = net;

		m_bev = pBev;
		memset(&sin, 0, sizeof(sin));
		sin = addr;
		m_ip = inet_ntoa(sin.sin_addr);
		m_port = ntohs(sin.sin_port);
		m_isWorking = false;
		m_country = 0;
	}

	virtual ~SocketSession()
	{
	}

	int AddBuff(const char* data, size_t dataLength)
	{
		m_recvBuff.append(data, dataLength);

		return (int)m_recvBuff.length();
	}

	int CopyBuffTo(char* data, uint32_t start, uint32_t dataLength)
	{
		if (start + dataLength > m_recvBuff.length())
		{
			return 0;
		}

		memcpy(data, m_recvBuff.data() + start, dataLength);

		return dataLength;
	}

	size_t RemoveBuff(uint32_t start, uint32_t dataLength)
	{
		if (start < 0)
		{
			return 0;
		}

		if (start + dataLength > m_recvBuff.length())
		{
			return 0;
		}

		m_recvBuff.erase(start, dataLength);

		return m_recvBuff.length();
	}

	const char* GetBuff()
	{
		return m_recvBuff.data();
	}

	size_t GetBuffLen() const
	{
		return m_recvBuff.length();
	}

	bufferevent* GetBuffEvent()
	{
		return m_bev;
	}

	INet* GetNet()
	{
		return m_net;
	}

	bool SendData(const char* data, const DATA_LENGTH_TYPE dataLength)
	{
		if (m_bev != nullptr)
		{
			if (bufferevent_write(m_bev, data, dataLength) == 0)
			{
				return true;
			}
		}
		return false;
	}

	bool NeedRemove()
	{
		return m_needRemove;
	}

	void SetNeedRemove(bool b)
	{
		m_needRemove = b;
	}

	int GetSock()
	{
		return m_sock;
	}

	void SetSessionID(const SESSIONID sid)
	{
		m_sessionID = sid;
	}

	const SESSIONID GetSessionID()
	{
		return m_sessionID;
	}

	void SetGameServer(SERVERID gameServerID)
	{
		m_gameServerID = gameServerID;
	}

	const SERVERID  GetGameServer()
	{
		return m_gameServerID;
	}

	std::string GetIP()
	{
		return m_ip;
	}

	int GetPort()
	{
		return m_port;
	}

	bool GetWorkState()
	{
		return m_isWorking;
	}

	void SetWorkState(bool work)
	{
		m_isWorking = work;
	}

	void SetDeviceID(const std::string& deviceid)
	{
		m_deviceid = deviceid;
	}

	const std::string& GetDeviceID()
	{
		return m_deviceid;
	}

	void SetCountry(int country)
	{
		m_country = country;
	}

	int GetCountry()
	{
		return m_country;
	}

private:
	sockaddr_in sin;
	int m_port;
	std::string m_ip;
	bufferevent* m_bev;
	std::string m_recvBuff;                

	SERVERID m_gameServerID;                 
	SESSIONID m_sessionID;             
	INet* m_net;                 
									 
	int m_sock;                        
	bool m_needRemove;
	bool m_isWorking;
	std::string m_deviceid;
	int m_country;
};


#endif
