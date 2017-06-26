#ifndef __NET_MODULE_H__
#define __NET_MODULE_H__

// -------------------------------------------------------------------------
//    @FileName         :    NetModule.h
//    @Author           :    houontherun@gmail.com
//    @Date             :    2016-11-1
//    @Module           :    
// -------------------------------------------------------------------------

#include <stdint.h>

#include "INet.h"



class NetModule
{
public:
	NetModule();
	~NetModule();

	bool InitAsClient(const char* strIP, const uint16_t port);

	bool InitAsServer(const uint32_t dwMaxClient, const uint16_t port);

	bool Tick();

	void OnReceiveNetPackage(const uint32_t sock,  const char* data, const DATA_LENGTH_TYPE dataLength);

	void OnSocketNetEvent(const uint32_t sock, const NET_EVENT eEvent, INet* net);

	void KeepAlive();

	bool SendData(const char* data, const DATA_LENGTH_TYPE dataLength, const uint32_t sock);

	template<typename BaseType>
	bool AddReceiveCallBack(BaseType* pBase, void (BaseType::*handleRecieve)(const int,  const char*, const DATA_LENGTH_TYPE))
	{
		NET_RECEIVE_FUNCTOR functor = std::bind(handleRecieve, pBase, std::placeholders::_1, std::placeholders::_2, std::placeholders::_3);
		NET_RECEIVE_FUNCTOR_PTR functorPtr(new NET_RECEIVE_FUNCTOR(functor));

		return AddReceiveCallBack(functorPtr);
	}

	bool AddReceiveCallBack(const NET_RECEIVE_FUNCTOR_PTR& cb)
	{
		m_ReceiveCallBack = cb;
		return true;
	}

	template<typename BaseType>
	bool AddEventCallBack(BaseType* pBase, void (BaseType::*handler)(const int, const NET_EVENT, INet*))
	{
		NET_EVENT_FUNCTOR functor = std::bind(handler, pBase, std::placeholders::_1, std::placeholders::_2, std::placeholders::_3);
		NET_EVENT_FUNCTOR_PTR functorPtr(new NET_EVENT_FUNCTOR(functor));

		return AddEventCallBack(functorPtr);
	}

	bool AddEventCallBack(const NET_EVENT_FUNCTOR_PTR& cb)
	{
		m_listEventCallback.push_back(cb);
		return true;
	}

	INet* GetNet()
	{
		return m_net;
	}

	bool CloseSession(int sock)
	{
		return m_net->CloseSocketSession(sock);
	}
private:
	INet* m_net;
;
	int64_t m_lastTime;
	std::list<NET_EVENT_FUNCTOR_PTR> m_listEventCallback;
	//NET_EVENT_FUNCTOR_PTR m_EventCallback;
	NET_RECEIVE_FUNCTOR_PTR m_ReceiveCallBack;
};

#endif