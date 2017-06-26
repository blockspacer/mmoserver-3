#include <set>
#include <vector>
#include <map>
#include <list>
#include <stdint.h>
#include <math.h>
#include "IProxyModuel.h"
#include "common.h"

class IClientProxy;

class AOIProxyManager
{
public:
	bool       Init();

	// 根据entityid获取一个AOIProxy，如果没有则创建一个
	//AOIProxy*  GenerateAOIProxy(ENTITYID entityid);
	std::shared_ptr<AOIProxy> GenerateAOIProxy(ENTITYID entityid);

	void       DestroyAOIProxy(ENTITYID entityid);

	void       DestroyAOIProxy(ProxyID proxyid);

	std::shared_ptr<AOIProxy> GetAOIProxy(ProxyID proxyID);
	std::shared_ptr<AOIProxy> GetAOIProxy(ENTITYID entityid);

	//AOIProxy*  GetAOIProxy(ProxyID proxyID);
	//AOIProxy*  GetAOIProxy(ENTITYID entityid);

	ProxyID    GetProxyIDByEntityID(const ENTITYID& entityid);
	
private:
	ProxyID    GenerateAOIProxyID();

	void       RecycleAOIProxyID(ProxyID pid);

private:
	uint32_t                          m_maxProxyID;
	std::map<ENTITYID, ProxyID>       m_EntityID2ProxyIDMap;

	std::vector<std::shared_ptr<AOIProxy>> m_AOIProxyVector2;
	std::list<uint32_t>               m_UseableIndex;
};