#ifndef __AOI_MODULE_H__
#define __AOI_MODULE_H__

#include "IProxyModuel.h"
#include "AOIProxyManager.h"
#include "AOIScene.h"
#include "Scene.h"
#include "Timer.h"
#include "Singleton.h"
#include "common.h"

class ProxyModule:public IProxyModule//, public Singleton<ProxyModule>
{
public:
	ProxyModule():m_lastTickTimeMilli(0) {}

	virtual ~ProxyModule() {}

	bool Init();

	bool CreateDungeonScene(uint32_t sceneID, std::string mapName);

	bool AddAOIScene(uint32_t sceneID, uint32_t radius, float minX, float maxX, float minZ, float maxZ, std::string mapName);

	void DestroyAOIScene(uint32_t sceneID);

	void Tick(int timeid);

	ProxyID CreateAOIProxy(ENTITYID entityID, uint32_t entityType, std::string& entityInfo, SESSIONID sessionID, uint32_t viewRadius, float speed);

	ProxyID CreateClientProxy();

	ProxyID CreateNpcProxy();

	void    DestroyAOIProxy(ENTITYID entityID);

	void    DestroyAOIProxy(ProxyID pid);

	//AOIProxy*   GetAOIProxy(ProxyID ProxyID);
	std::shared_ptr<AOIProxy> GetAOIProxy(ProxyID ProxyID);

	std::shared_ptr<IScene> GetScene(uint32_t sceneID);

	void EntityMove(const SESSIONID clientSessionID, const char * message, const DATA_LENGTH_TYPE messageLength);

	void EntityStopMove(const SESSIONID clientSessionID, const char * message, const DATA_LENGTH_TYPE messageLength);

	void EntityForceMove(const SESSIONID clientSessionID, const char * message, const DATA_LENGTH_TYPE messageLength);

	void EntityTurnDirection(const SESSIONID clientSessionID, const char * message, const DATA_LENGTH_TYPE messageLength);

	void ProcessPing(const SESSIONID clientSessionID, const char * message, const DATA_LENGTH_TYPE messageLength);

	void ProcessPingBack(const SESSIONID clientSessionID, const char * message, const DATA_LENGTH_TYPE messageLength);

	ClientSessionInfo* GetClientSessionInfo(const SESSIONID clientSessionID);

	uint64_t GetServerTimeOfClientTime(const SESSIONID clientSessionID, const uint64_t clientTime);

private:
	//std::map<uint32_t, IScene*>     m_AOISceneMap;
	std::map<uint32_t, std::shared_ptr<IScene>>     m_AOISceneMap2;
	AOIProxyManager                   m_AOIProxyManager;
	SEND_MESSAGE_HANDLER            m_sendMessage;
	std::map<SESSIONID, ClientSessionInfo> m_clientSessionInfo;
	uint64_t m_lastTickTimeMilli;
};


#endif // !__AOI_MODULE_H__

