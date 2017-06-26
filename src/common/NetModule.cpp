#include "NetModule.h"
#include "Net.h"

NetModule::NetModule():m_net(NULL)
{
}


NetModule::~NetModule()
{
	if (m_net) {
		m_net->Final();
	}
	delete m_net;
	m_net = NULL;
}

bool NetModule::InitAsClient(const char * strIP, const uint16_t connectPort)
{
	m_net = new Net(this, &NetModule::OnReceiveNetPackage, &NetModule::OnSocketNetEvent);
	m_net->Initialization(strIP, connectPort);
	return true;
}

bool NetModule::InitAsServer(const uint32_t dwMaxClient, const uint16_t listenPort)
{
	m_net = new Net(this, &NetModule::OnReceiveNetPackage, &NetModule::OnSocketNetEvent);
	return m_net->Initialization(dwMaxClient, listenPort);
}



bool NetModule::Tick()
{
	if (!m_net)
	{
		return false;
	}

	KeepAlive();

	return m_net->Tick();
}

void NetModule::OnReceiveNetPackage(const uint32_t sock, const char * message, const DATA_LENGTH_TYPE dataLength)
{

	//for (std::list<NET_RECEIVE_FUNCTOR_PTR>::iterator it = m_listReceiveCallBackList.begin(); it != m_listReceiveCallBackList.end(); ++it)
	//{
	//	NET_RECEIVE_FUNCTOR_PTR& pFunPtr = *it;
	//	NET_RECEIVE_FUNCTOR* pFunc = pFunPtr.get();
	//	pFunc->operator()(sock, message, dataLength);
	//}
	NET_RECEIVE_FUNCTOR* pFunc = m_ReceiveCallBack.get();
	pFunc->operator()(sock, message, dataLength);
}


void NetModule::OnSocketNetEvent(const uint32_t sock, const NET_EVENT eEvent, INet * net)
{
	for (std::list<NET_EVENT_FUNCTOR_PTR>::iterator it = m_listEventCallback.begin(); it != m_listEventCallback.end(); ++it)
	{
		NET_EVENT_FUNCTOR_PTR& pFunPtr = *it;
		NET_EVENT_FUNCTOR* pFunc = pFunPtr.get();
		pFunc->operator()(sock, eEvent, net);
	}
	//NET_EVENT_FUNCTOR* pFunc = m_EventCallback.get();
	//pFunc->operator()(sock, eEvent, net);
}

void NetModule::KeepAlive()
{
	return ;
}

bool NetModule::SendData(const char* data, const DATA_LENGTH_TYPE dataLength, const uint32_t sock)
{
	m_net->SendMsg(data,dataLength, sock);
	return true;
}
