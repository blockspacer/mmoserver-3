#include "AOIProxyManager.h"
#include "AOIProxy.h"
#include "AOIScene.h"

bool AOIProxyManager::Init()
{
	m_maxProxyID = MAX_PROXY_ID;
	for (ProxyID pid = 1; pid < m_maxProxyID; pid++)
	{
		m_UseableIndex.push_back(pid);
	}
	m_AOIProxyVector2.resize(m_maxProxyID);
	return true;
}

//AOIProxy * AOIProxyManager::GenerateAOIProxy(ENTITYID entityid)
//{
//	ProxyID pid = INVALID_PROXY_ID;
//	std::map<ENTITYID, ProxyID>::iterator it = m_EntityID2ProxyIDMap.find(entityid);
//	if (it != m_EntityID2ProxyIDMap.end())
//	{
//		// 已经为entityID 分配过 ProxyID
//		pid = it->second;
//		if (m_AOIProxyVector[pid])
//		{
//			return m_AOIProxyVector[pid];
//		}
//		_xerror("EntityID %s and ProxyID %d in GenerateAOIProxy but failed find Proxy", entityid.c_str(), pid);
//	}
//
//	if (pid == INVALID_PROXY_ID)
//	{
//		pid = GenerateAOIProxyID();
//		if (pid == INVALID_PROXY_ID)
//		{
//			_xerror("Failed GenerateAOIProxyID");
//			return nullptr;
//		}
//	}
//
//	AOIProxy* pAoiProxy = new AOIProxy(pid);
//	if (!pAoiProxy)
//	{
//		_xerror("Failed new AOIProxy of pid %d and entityid %s", pid, entityid.c_str());
//		RecycleAOIProxyID(pid);
//		return nullptr;
//	}
//
//	m_EntityID2ProxyIDMap[entityid] = pid;
//	m_AOIProxyVector[pid] = pAoiProxy;
//	return pAoiProxy;
//}

std::shared_ptr<AOIProxy> AOIProxyManager::GenerateAOIProxy(ENTITYID entityid)
{
	ProxyID pid = INVALID_PROXY_ID;
	std::map<ENTITYID, ProxyID>::iterator it = m_EntityID2ProxyIDMap.find(entityid);
	if (it != m_EntityID2ProxyIDMap.end())
	{
		// 已经为entityID 分配过 ProxyID
		pid = it->second;
		if (m_AOIProxyVector2[pid])
		{
			return m_AOIProxyVector2[pid];
		}
		_xerror("EntityID %s and ProxyID %d in GenerateAOIProxy but failed find Proxy", entityid.c_str(), pid);
	}

	if (pid == INVALID_PROXY_ID)
	{
		pid = GenerateAOIProxyID();
		if (pid == INVALID_PROXY_ID)
		{
			_xerror("Failed GenerateAOIProxyID");
			return nullptr;
		}
	}

	std::shared_ptr<AOIProxy> proxy = std::make_shared<AOIProxy>(pid);
	if (!proxy)
	{
		_xerror("Failed create AOIProxy of pid %d and entityid %s", pid, entityid.c_str());
		RecycleAOIProxyID(pid);
		return nullptr;
	}

	m_EntityID2ProxyIDMap[entityid] = pid;
	m_AOIProxyVector2[pid] = proxy;
	return proxy;
}

void AOIProxyManager::DestroyAOIProxy(ProxyID proxyid)
{
	std::shared_ptr<AOIProxy> proxy = m_AOIProxyVector2[proxyid];
	if (!proxy)
	{
		_xerror("ProxyID %d is None in m_AOIProxyVector in DestroyAOIProxy", proxyid);
		return;
	}


	if (proxy->GetScene() != nullptr)
	{
		std::shared_ptr<IScene> scene= proxy->GetScene();
		scene->OnLeave(proxy.get());
	}

	ENTITYID entityid = proxy->EntityID();
	m_AOIProxyVector2[proxyid].reset();
	RecycleAOIProxyID(proxyid);
	m_EntityID2ProxyIDMap.erase(entityid);
}

//AOIProxy* AOIProxyManager::GetAOIProxy(ProxyID proxyID)
//{
//	AOIProxy* proxy = m_AOIProxyVector[proxyID];
//	if (!proxy)
//	{
//		return nullptr;
//	}
//	return proxy;
//}
//
//
//AOIProxy* AOIProxyManager::GetAOIProxy(ENTITYID entityid)
//{
//	ProxyID pid = GetProxyIDByEntityID(entityid);
//	if (pid == INVALID_PROXY_ID)
//	{
//		_info("Failed find proxy id of entityid %s", entityid.c_str());
//		return nullptr;
//	}
//
//	AOIProxy* proxy = GetAOIProxy(pid);
//	if (!proxy)
//	{
//		_warn("Failed find proxy of pid %d", pid);
//		return nullptr;
//	}
//
//	return proxy;
//}

std::shared_ptr<AOIProxy> AOIProxyManager::GetAOIProxy(ProxyID proxyID)
{
	std::shared_ptr<AOIProxy> proxy = m_AOIProxyVector2[proxyID];
	if (!proxy)
	{
		return nullptr;
	}
	return proxy;
}


std::shared_ptr<AOIProxy> AOIProxyManager::GetAOIProxy(ENTITYID entityid)
{
	ProxyID pid = GetProxyIDByEntityID(entityid);
	if (pid == INVALID_PROXY_ID)
	{
		_info("Failed find proxy id of entityid %s", entityid.c_str());
		return nullptr;
	}

	return GetAOIProxy(pid);
}

void AOIProxyManager::DestroyAOIProxy(ENTITYID entityid)
{
	std::map<ENTITYID, ProxyID>::iterator it = m_EntityID2ProxyIDMap.find(entityid);
	if (it == m_EntityID2ProxyIDMap.end())
	{
		_warn("Failed get proxyid of entityid %s", entityid.c_str());
		return;
	}

	ProxyID pid = it->second;
	DestroyAOIProxy(pid);
}


ProxyID AOIProxyManager::GetProxyIDByEntityID(const ENTITYID& entityid)
{
	auto it = m_EntityID2ProxyIDMap.find(entityid);
	if (it != m_EntityID2ProxyIDMap.end())
	{
		return it->second;
	}
	return INVALID_PROXY_ID;
}



ProxyID AOIProxyManager::GenerateAOIProxyID()
{
	if (m_UseableIndex.empty())
	{
		_xerror("AOIProxyIDPoll is empty");
		return INVALID_PROXY_ID;
	}

	ProxyID pid = m_UseableIndex.front();
	if (pid > m_maxProxyID)
	{
		_xerror("ProxyID %d is large than maxID %d", pid, m_maxProxyID);
		return INVALID_PROXY_ID;
	}
	if (m_AOIProxyVector2[pid])
	{
		_xerror("ProxyID %d is not empty in m_AOIProxyVector", pid);
		return INVALID_PROXY_ID;
	}
	m_UseableIndex.pop_front();
	return pid;
}

void AOIProxyManager::RecycleAOIProxyID(ProxyID pid)
{
	if (m_AOIProxyVector2[pid])
	{
		_xerror("ProxyID %d to Recycle is not empty in m_AOIProxyVector", pid);
		return;
	}
	m_UseableIndex.push_back(pid);
}
