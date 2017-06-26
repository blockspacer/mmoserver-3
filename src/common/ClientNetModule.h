// -------------------------------------------------------------------------
//    @FileName         :   NetClientModule.h
//    @Author           :    houontherun@gmail.com
//    @Date             :    2016-11-01
//    @Module           :    
//
// -------------------------------------------------------------------------


#ifndef __CLIENT_NET_MODULE_H__
#define __CLIENT_NET_MODULE_H__

#include <iostream>
#include "NetModule.h"
#include "MapEx.h"
#include "common.h"


enum ConnectDataState
{
	DISCONNECT,
	CONNECTING,
	NORMAL,
	RECONNECT,
};

struct ConnectData
{
	ConnectData()
	{
		nPort = 0;
		strName = "";
		strIP = "";
		eServerType = SERVER_TYPE_NONE;
		eState = ConnectDataState::DISCONNECT;
		mnLastActionTime = 0;
	}

	SERVERID    serverID;
	SERVER_TYPE eServerType;
	std::string strIP;
	int nPort;
	std::string strName;
	ConnectDataState eState;
	uint64_t mnLastActionTime;

	NF_SHARE_PTR<NetModule> mxNetModule;
};

class ClientNetModule {
public:
	ClientNetModule()
	{
		m_clientCount = 0;
	}

	virtual bool Init()
	{
		AddEventCallBack(this, &ClientNetModule::OnSocketEvent);

		return true;
	}

	virtual bool AfterInit()
	{
		return true;
	}

	virtual bool BeforeShut()
	{
		return true;
	}

	virtual bool Shut()
	{
		return true;
	}

	virtual bool Tick()
	{
		ProcessExecute();
		ProcessAddNetConnect();

		return true;
	}

	template<typename BaseType>
	int AddReceiveCallBack(BaseType* pBase, void (BaseType::*handleRecieve)(const int,  const char*, const DATA_LENGTH_TYPE))
	{
		NET_RECEIVE_FUNCTOR functor = std::bind(handleRecieve, pBase, std::placeholders::_1, std::placeholders::_2, std::placeholders::_3);
		NET_RECEIVE_FUNCTOR_PTR functorPtr(new NET_RECEIVE_FUNCTOR(functor));

		mxCallBackList.push_back(functorPtr);

		return false;
	}

	template<typename BaseType>
	bool AddEventCallBack(BaseType* pBase, void (BaseType::*handler)(const int, const NET_EVENT, INet*))
	{
		NET_EVENT_FUNCTOR functor = std::bind(handler, pBase, std::placeholders::_1, std::placeholders::_2, std::placeholders::_3);
		NET_EVENT_FUNCTOR_PTR functorPtr(new NET_EVENT_FUNCTOR(functor));

		mxEventCallBack.push_back(functorPtr);

		return true;
	}

	void AddServer(const ConnectData& info)
	{
		m_tempNetList.push_back(info);
	}

	void DelServer(const SERVERID serverid)
	{
		for (auto it = m_tempNetList.begin(); it != m_tempNetList.end(); ++it)
		{
			if (it->serverID == serverid)
			{
				m_tempNetList.erase(it);
				break;
			}
		}

		m_serverMap.RemoveElement(serverid);
	}

	////////////////////////////////////////////////////////////////////////////////

	void SendByServerID(const int serverID, const char* data, const uint32_t dataLength)
	{
 		NF_SHARE_PTR<ConnectData> server = m_serverMap.GetElement(serverID);
		if (server)
		{
			NF_SHARE_PTR<NetModule> pNetModule = server->mxNetModule;
			if (pNetModule.get())
			{
				pNetModule->SendData(data, dataLength, 0);
			}
		}
	}

	void SendToAllServer(const char* msg, const uint32_t dataLength)
	{
		NF_SHARE_PTR<ConnectData> pServer = m_serverMap.First();
		while (pServer)
		{
			NF_SHARE_PTR<NetModule> pNetModule = pServer->mxNetModule;
			if (pNetModule.get())
			{
				pNetModule->SendData(msg, dataLength, 0);
			}

			pServer = m_serverMap.Next();
		}
	}


	////////////////////////////////////////////////////////////////////////////////

	NF_SHARE_PTR<ConnectData> GetServerNetInfo(const int nServerID)
	{
		return m_serverMap.GetElement(nServerID);
	}

	MapEx<int, ConnectData>& GetServerList()
	{
		return m_serverMap;
	}



	NF_SHARE_PTR<ConnectData> GetServerNetInfo(const INet* net)
	{
		int nServerID = 0;
		for (NF_SHARE_PTR<ConnectData> pData = m_serverMap.First(nServerID); pData != NULL; pData = m_serverMap.Next(nServerID))
		{
			if (pData->mxNetModule.get() && net == pData->mxNetModule->GetNet())
			{
				return pData;
			}
		}

		return NF_SHARE_PTR<ConnectData>(NULL);
	}


protected:

	void InitCallBacks(ConnectData* pServerData)
	{
		//add event callback
		std::list<NET_EVENT_FUNCTOR_PTR>::iterator itEventCB = mxEventCallBack.begin();
		for (; mxEventCallBack.end() != itEventCB; ++itEventCB)
		{
			pServerData->mxNetModule->AddEventCallBack(*itEventCB);
		}

		std::list<NET_RECEIVE_FUNCTOR_PTR>::iterator itCB = mxCallBackList.begin();
		for (; mxCallBackList.end() != itCB; ++itCB)
		{
			pServerData->mxNetModule->AddReceiveCallBack(*itCB);
		}
	}


	void ProcessExecute()
	{
		ConnectData* pServerData = m_serverMap.FirstNude();
		while (pServerData)
		{
			switch (pServerData->eState)
			{
			case ConnectDataState::DISCONNECT:
			{
				if (NULL != pServerData->mxNetModule)
				{
					pServerData->mxNetModule = nullptr;
					pServerData->eState = ConnectDataState::RECONNECT;
				}
			}
			break;
			case ConnectDataState::CONNECTING:
			{
				if (pServerData->mxNetModule)
				{
					pServerData->mxNetModule->Tick();
				}
			}
			break;
			case ConnectDataState::NORMAL:
			{
				if (pServerData->mxNetModule)
				{
					pServerData->mxNetModule->Tick();

					KeepState(pServerData);
				}
			}
			break;
			case ConnectDataState::RECONNECT:
			{
				if ((pServerData->mnLastActionTime + 3) >= GetNowTimeSecond())
				{
					break;
				}

				if (nullptr != pServerData->mxNetModule)
				{
					pServerData->mxNetModule = nullptr;
				}

				pServerData->eState = ConnectDataState::CONNECTING;
				pServerData->mxNetModule = NF_SHARE_PTR<NetModule>(NF_NEW NetModule());
				pServerData->mxNetModule->InitAsClient(pServerData->strIP.c_str(), pServerData->nPort);

				InitCallBacks(pServerData);
			}
			break;
			default:
				break;
			}

			pServerData = m_serverMap.NextNude();
		}
	}

	void KeepReport(ConnectData* pServerData) {};
	void LogServerInfo(const std::string& strServerInfo) {};

	int GetConnectedCount()
	{
		int nServerID = 0;
		int connectedCount = 0;
		for (NF_SHARE_PTR<ConnectData> connectData = m_serverMap.First(nServerID); connectData != NULL; connectData = m_serverMap.Next(nServerID))
		{
			if (connectData->eState == ConnectDataState::NORMAL)
			{
				connectedCount++;
			}
		}

		return connectedCount;
	}

private:
	virtual void LogServerInfo()
	{
		LogServerInfo("This is a client, begin to print Server Info----------------------------------");

		ConnectData* pServerData = m_serverMap.FirstNude();
		while (nullptr != pServerData)
		{
			std::ostringstream stream;
			stream << "Type: " << pServerData->eServerType << " ProxyServer ID: " << pServerData->serverID << " State: " << pServerData->eState << " IP: " << pServerData->strIP << " Port: " << pServerData->nPort;

			LogServerInfo(stream.str());

			pServerData = m_serverMap.NextNude();
		}

		LogServerInfo("This is a client, end to print Server Info----------------------------------");
	};

	void KeepState(ConnectData* pServerData)
	{
		if (pServerData->mnLastActionTime + 10 > GetNowTimeSecond())
		{
			return;
		}

		pServerData->mnLastActionTime = GetNowTimeSecond();

		KeepReport(pServerData);
		LogServerInfo();
	}

	void OnSocketEvent(const int fd, const NET_EVENT eEvent, INet* net)
	{
		if (eEvent & BEV_EVENT_CONNECTED)
		{
			OnConnected(fd, net);
		}
		else
		{
			OnDisConnected(fd, net);
		}
	}

	int OnConnected(const int fd, INet* net)
	{
		NF_SHARE_PTR<ConnectData> connectData = GetServerNetInfo(net);
		if (connectData)
		{
			connectData->eState = ConnectDataState::NORMAL;
			m_clientCount++;
		}

		return 0;
	}

	int OnDisConnected(const int fd, INet* net)
	{
		NF_SHARE_PTR<ConnectData> connectData = GetServerNetInfo(net);
		if (connectData)
		{
			connectData->eState = ConnectDataState::DISCONNECT;
			connectData->mnLastActionTime = GetNowTimeSecond();
			m_clientCount--;
		}

		return 0;
	}

	void ProcessAddNetConnect()
	{
		std::list<ConnectData>::iterator it = m_tempNetList.begin();
		for (; it != m_tempNetList.end(); ++it)
		{
			const ConnectData& xInfo = *it;
			NF_SHARE_PTR<ConnectData> xServerData = m_serverMap.GetElement(xInfo.serverID);
			if (nullptr == xServerData)
			{
				xServerData = NF_SHARE_PTR<ConnectData>(NF_NEW ConnectData());

				xServerData->serverID = xInfo.serverID;
				xServerData->eServerType = xInfo.eServerType;
				xServerData->strIP = xInfo.strIP;
				xServerData->strName = xInfo.strName;
				xServerData->eState = ConnectDataState::CONNECTING;
				xServerData->nPort = xInfo.nPort;
				xServerData->mnLastActionTime = GetNowTimeSecond();

				xServerData->mxNetModule = NF_SHARE_PTR<NetModule>(NF_NEW NetModule());
				xServerData->mxNetModule->InitAsClient(xServerData->strIP.c_str(), xServerData->nPort);

				InitCallBacks(xServerData.get());

				m_serverMap.AddElement(xInfo.serverID, xServerData);
			}
		}

		m_tempNetList.clear();
	}

private:
	MapEx<int, ConnectData> m_serverMap;  
	std::list<ConnectData> m_tempNetList;

	std::list<NET_EVENT_FUNCTOR_PTR> mxEventCallBack;
	std::list<NET_RECEIVE_FUNCTOR_PTR> mxCallBackList;
	int m_clientCount;
};
#endif
