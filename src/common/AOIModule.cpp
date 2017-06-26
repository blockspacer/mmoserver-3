#include "AOIModule.h"
#include "common.h"
#include "AOIProxy.h"
#include "message/LuaMessage.pb.h"

bool ProxyModule::Init()
{
	if (!m_AOIProxyManager.Init())
	{
		_xerror("Failed Init m_AOIProxyManager ");
		return false;
	}

	//CTimerMgr::Instance()->CreateTimer(0, this, &ProxyModule::Tick, 300, 300);
	SetGlobalProxyModuel(this);
	return true;
}

bool ProxyModule::CreateDungeonScene(uint32_t sceneID, std::string mapName)
{
	//DungeonScene* scene = new DungeonScene(sceneID);
	std::shared_ptr<DungeonScene> scene = std::make_shared<DungeonScene>(sceneID);
	if (!scene)
	{
		return false;
	}

	if (!scene->Init(mapName))
	{
		_xerror("Failed Init DungeonScene");
		//SAFE_DELETE(scene);
		return false;
	}

	m_AOISceneMap2[sceneID] = scene;
	return true;
}



bool ProxyModule::AddAOIScene(uint32_t sceneID, uint32_t radius,float minX, float maxX, float minZ, float maxZ, std::string mapName)
{
	//AOIScene* scene = new AOIScene(sceneID);
	std::shared_ptr<AOIScene> scene = std::make_shared<AOIScene>(sceneID);
	if (!scene)
	{
		_xerror("Failed Create AOIScene");
		return false;
	}
	if (!scene->Init(radius,  minX,  maxX,  minZ,  maxZ, mapName))
	{
		_xerror("Failed Init Scene");
		//SAFE_DELETE(scene);
		return false;
	}
	m_AOISceneMap2[sceneID] = scene;
	return true;
}

void ProxyModule::DestroyAOIScene(uint32_t sceneID)
{
	auto it = m_AOISceneMap2.find(sceneID);
	if (it == m_AOISceneMap2.end())
	{
		_xerror("The scene %d is not exist", sceneID);
		//assert(false);
		return;
	}

	std::shared_ptr<IScene> scene = it->second;
	if (!scene)
	{
		_xerror("The scene of sceneID %d is null",sceneID);
		m_AOISceneMap2.erase(sceneID);
		return;
	}

	scene->Final();
	//SAFE_DELETE(scene);
	m_AOISceneMap2.erase(sceneID);
}

void ProxyModule::Tick(int timeid)
{
	uint64_t now = GetNowTimeMille();
	if (now - m_lastTickTimeMilli < 300)
	{
		return;
	}
	m_lastTickTimeMilli = now;
	for (auto it = m_AOISceneMap2.begin(); it != m_AOISceneMap2.end(); it++)
	{
		if (it->second)
		{
			(it->second)->Tick(0);
		}	
	}
	return;
}

ProxyID ProxyModule::CreateAOIProxy(ENTITYID entityID, uint32_t entityType, std::string& entityInfo, SESSIONID sessionID, uint32_t viewRadius, float speed)
{
	std::shared_ptr<AOIProxy> proxy = m_AOIProxyManager.GenerateAOIProxy(entityID);
	if (!proxy)
	{
		_xerror("Failed get proxy of entityid ");
		return 0;
	}
	proxy->Init(entityID, entityType, viewRadius, entityInfo, sessionID, speed);
	return proxy->GetProxyID();
}

ProxyID ProxyModule::CreateClientProxy()
{
	return ProxyID();
}

ProxyID ProxyModule::CreateNpcProxy()
{
	return ProxyID();
}

void ProxyModule::DestroyAOIProxy(ENTITYID entityID)
{
	m_AOIProxyManager.DestroyAOIProxy(entityID);
}

void ProxyModule::DestroyAOIProxy(ProxyID pid)
{
	std::shared_ptr<AOIProxy> proxy = GetAOIProxy(pid);
	//AOIProxy* proxy = GetAOIProxy(pid);
	if (!proxy)
	{
		_xerror("destroy proxy %d is not exist", pid);
		//assert(false);
		return;
	}
	std::shared_ptr<IScene> scene = proxy->GetScene();
	if (scene)
	{
		_xerror("The proxy %d to destroy is still in scene %d", pid, scene->GetSceneID());
		//assert(false);
		return;
	}

	m_AOIProxyManager.DestroyAOIProxy(pid);
}

std::shared_ptr<AOIProxy> ProxyModule::GetAOIProxy(ProxyID proxyID)
{
	return m_AOIProxyManager.GetAOIProxy(proxyID);
}

std::shared_ptr<IScene> ProxyModule::GetScene(uint32_t sceneID)
{
	auto it = m_AOISceneMap2.find(sceneID);
	if (it != m_AOISceneMap2.end())
	{
		return it->second;
	}
	return nullptr;
}

void ProxyModule::EntityMove(const SESSIONID clientSessionID, const char * message, const DATA_LENGTH_TYPE messageLength)
{
	CS_CLIENT_MOVE request;
	if (!request.ParseFromArray(message, messageLength))
	{
		_xerror("GameServerModule::EntityMove request ParseFromArray error");
		return;
	}
	Point3D pos;
	pos.x = request.mypostion().destx();
	pos.y = request.mypostion().desty();
	pos.z = request.mypostion().destz();

	float rotation = request.mypostion().orientation();

	ENTITYID eid = request.mypostion().entityid();
	uint64_t servertime = GetServerTimeOfClientTime(clientSessionID, request.clienttime());
	if (servertime == 0)
	{
		//assert(false);
		return;
	}
	float speed = request.mypostion().speed();

	//Point3D predictPos;
	//predictPos.x = request.predictpostion().destx();
	//predictPos.y = request.predictpostion().desty();
	//predictPos.z = request.predictpostion().destz();

	uint32_t sceneID = request.sceneid();

	std::shared_ptr<AOIProxy> proxy = m_AOIProxyManager.GetAOIProxy(eid);
	if (!proxy)
	{
		return;
	}

	if (sceneID != proxy->GetSceneID())
	{
		_xerror("Wrong sceneID %d in Move %d", sceneID, proxy->GetSceneID());
		//assert(!"Wrong sceneID in Move");
		return;
	}

	proxy->SetPositionTime(servertime);
	proxy->SetSpeed(speed);

	//proxy->SetPredictPos(predictPos);
	//uint64_t predicttime = GetServerTimeOfClientTime(clientSessionID, request.predicttime());
	//if (predicttime == 0)
	//{
	//	assert(false);
	//	return;
	//}
	//proxy->SetPredictTime(predicttime);
	proxy->MoveTo(proxy->GetProxyID(), pos, rotation, servertime, speed);
	proxy->SetStatus(ProxyStatusMove);
}

void ProxyModule::EntityStopMove(const SESSIONID clientSessionID, const char * message, const DATA_LENGTH_TYPE messageLength)
{
	CS_STOP_MOVE request;
	if (!request.ParseFromArray(message, messageLength))
	{
		_xerror("GameServerModule::EntityStopMove request ParseFromArray error");
		//assert(false);
		return;
	}
	Point3D pos;

	pos.x = request.mypostion().destx();
	pos.y = request.mypostion().desty();
	pos.z = request.mypostion().destz();
	float rotation = request.mypostion().orientation();
	ENTITYID entityid = request.mypostion().entityid();

	std::shared_ptr<AOIProxy> proxy = m_AOIProxyManager.GetAOIProxy(entityid);
	if (!proxy)
	{
		return;
	}
	if (request.sceneid() != proxy->GetSceneID())
	{
		_xerror("Wrong sceneID %d of client in StopMove and server sceneID is %d", request.sceneid(), proxy->GetSceneID());
		//assert(false);
		return;
	}
	proxy->StopMove(pos, rotation);
}

void ProxyModule::EntityForceMove(const SESSIONID clientSessionID, const char * message, const DATA_LENGTH_TYPE messageLength)
{
	CS_FORCE_MOVE request;
	if (!request.ParseFromArray(message, messageLength))
	{
		_xerror("GameServerModule::EntityForceMove request ParseFromArray error");
		return;
	}
	Point3D pos;

	pos.x = request.destx();
	pos.y = request.desty();
	pos.z = request.destz();
	ENTITYID eid = request.entityid();

	std::shared_ptr<AOIProxy> proxy = m_AOIProxyManager.GetAOIProxy(eid);
	if (!proxy)
	{
		return;
	}

	if (request.sceneid() != proxy->GetSceneID())
	{
		_xerror("Wrong sceneID %d in ForceMove %d", request.sceneid(), proxy->GetSceneID());
		//assert(!"Wrong sceneID in ForceMove");
		return;
	}

	proxy->ForcePostion(pos);
}


void ProxyModule::EntityTurnDirection(const SESSIONID clientSessionID, const char * message, const DATA_LENGTH_TYPE messageLength)
{
	CS_TURN_DIRECTION request;
	if (!request.ParseFromArray(message, messageLength))
	{
		_xerror("GameServerModule::EntityTurnDirection request ParseFromArray error");
		return;
	}
	Point3D pos;
	pos.x = request.destx();
	pos.y = request.desty();
	pos.z = request.destz();
	float direction = request.direction();
	ENTITYID entityid = request.entityid();
	std::shared_ptr<AOIProxy> proxy = m_AOIProxyManager.GetAOIProxy(entityid);
	if (!proxy)
	{
		return;
	}
	proxy->SetDirection(direction);

	proxy->BroadcastTurnDirectionMessage();
}

void ProxyModule::ProcessPing(const SESSIONID clientSessionID, const char * message, const DATA_LENGTH_TYPE messageLength)
{
	CS_PING request;
	if (!request.ParseFromArray(message, messageLength))
	{
		_xerror("GameServerModule::ProcessMoveMessage request ParseFromArray error");
		return;
	}

	SC_PING_BACK reply;
	reply.set_clienttime(request.clienttime());
	reply.set_servertime(GetNowTimeMille());

	SendMessageToClient(clientSessionID, SERVER_MESSAGE_OPCODE_PING_BACK, &reply);
}

void ProxyModule::ProcessPingBack(const SESSIONID clientSessionID, const char * message, const DATA_LENGTH_TYPE messageLength)
{
	CS_PING_BACK_BACK request;
	if (!request.ParseFromArray(message, messageLength))
	{
		_xerror("Failed Parse CS_PING_BACK_BACK");
		return;
	}
	uint64_t now = GetNowTimeMille();
	int latency = (now - request.servertime()) / 2;

	if (latency > 100)
	{
		return;
	}

	//int delta = now - Latency - request.clienttime();
	auto it = m_clientSessionInfo.find(clientSessionID);
	if (it != m_clientSessionInfo.end())
	{
		ClientSessionInfo* client = &(it->second);
		if (latency < client->MinLatency)
		{
			client->DeltaTime = now - latency - request.clienttime();
			client->MinLatency = latency;
		}
		client->Latency = latency;
	}
	else
	{
		int delta = now - latency - request.clienttime();
		ClientSessionInfo newClient;
		newClient.SessionID = clientSessionID;
		newClient.Latency = latency;
		newClient.MinLatency = latency;
		newClient.DeltaTime = delta;
		m_clientSessionInfo[clientSessionID] = newClient;
	}
}


ClientSessionInfo* ProxyModule::GetClientSessionInfo(const SESSIONID clientSessionID)
{
	return nullptr;
}

uint64_t ProxyModule::GetServerTimeOfClientTime(const SESSIONID clientSessionID, const uint64_t clientTime)
{
	auto it = m_clientSessionInfo.find(clientSessionID);
	if (it == m_clientSessionInfo.end())
	{
		return 0;
	}
	int delta = it->second.DeltaTime;
	return (clientTime + delta);
}

IProxyModule*  g_proxyModule;

void SetGlobalProxyModuel(IProxyModule* p)
{
	g_proxyModule = p;
}