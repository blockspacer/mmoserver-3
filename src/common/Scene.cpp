#include "Scene.h"
#include "AOIProxy.h"
#include "message/LuaMessage.pb.h"
#include "common.h"
#include "Timer.h"
#include "AOIScene.h"

bool DungeonScene::Init(std::string mapName)
{
	if (!m_detour.Init(mapName.c_str()))
	{
		_xerror("Failed init detour of scene %d and pathname %s", m_sceneID, mapName.c_str());
		return false;
	}

#ifdef _DEBUG
	m_debugTimerID = CTimerMgr::Instance()->CreateTimer(0, this, &DungeonScene::OnShowDebugInfo, 30000, 30000);
#endif // _DEBUG

	return true;
}

void DungeonScene::Tick(int timerid)
{
	if (m_isSuspend)
	{
		return;
	}
	for (auto it = m_AllProxys.begin(); it != m_AllProxys.end(); )
	{
		std::shared_ptr<AOIProxy> proxy = GlobalProxyModule->GetAOIProxy(*it);
		if (!proxy)
		{
			_debug("proxy is null but pid %d is still scene %d", *it, m_sceneID);
			//assert(false);
			m_AllProxys.erase(it++);
		}
		else
		{
			++it;
			proxy->Tick();
		}
	}
}

void DungeonScene::Final()
{
	// 通知所以残余的人离开场景，并不进行广播
	for (auto it = m_AllProxys.begin(); it != m_AllProxys.end();)
	{
		std::shared_ptr<AOIProxy> proxy = GlobalProxyModule->GetAOIProxy( *it);
		if (!proxy)
		{
			_debug("proxy is null but pid %d is still scene %d", *it, m_sceneID);
			//assert(false);
			m_AllProxys.erase(it++);
		}
		else
		{
			++it;
			proxy->LeaveScene();
		}
	}
	if (m_debugTimerID != 0)
	{
		CTimerMgr::Instance()->DestroyTimer(m_debugTimerID);
		m_debugTimerID = 0;
	}
}

bool DungeonScene::OnEnter(AOIProxy * proxy, const Point3D & dstPosition)
{
	if (!proxy)
	{
		return false;
	}
	ProxyID pid = proxy->GetProxyID();
	// 通知所有玩家有entity进入
	if (m_AllProxys.find(pid) != m_AllProxys.end())
	{
		_xerror("repeat register scene of scene %d proxy %d", m_sceneID, pid);
		//assert("false");
		return false;
	}

	ProxyIDSet me;
	me.insert(pid);
	
	proxy->NotifyClientCreateEntity(me);
	if (m_AllProxys.size() < 60)
	{
		proxy->OnEntityEnter(m_AllProxys);
	}
	else
	{
		ProxyIDSet drops;
		ProxyIDSet others;
		for (auto it = m_AllProxys.begin(); it != m_AllProxys.end(); ++it)
		{
			std::shared_ptr<AOIProxy> otherProxy = GlobalProxyModule->GetAOIProxy(*it);
			if (otherProxy)
			{
				if (otherProxy->EntityType() == 128)
				{
					drops.insert(*it);
				}
				else
				{
					others.insert(*it);
				}
			}
		}
		proxy->OnEntityEnter(others);
		proxy->OnEntityEnter(drops);
		_warn("EnterDungeon proxy count %d is too larger drop count %d other count %d", m_AllProxys.size(), drops.size(), others.size());
	}
	

	for (auto it = m_AllProxys.begin(); it != m_AllProxys.end(); ++it)
	{
		std::shared_ptr<AOIProxy> otherProxy = GlobalProxyModule->GetAOIProxy(*it);
		if (otherProxy)
		{
			otherProxy->OnEntityEnter(me);
		}
	}
	m_AllProxys.insert(pid);

	return true;
}

void DungeonScene::OnLeave(AOIProxy * proxy)
{
	// 通知所有玩家有entity退出
	if (!proxy)
	{
		return;
	}
	ProxyID pid = proxy->GetProxyID();
	if (m_AllProxys.find(pid) == m_AllProxys.end())
	{
		_xerror("proxy %d not in scene %d", pid, m_sceneID);
		//assert(false);
		return;
	}

	m_AllProxys.erase(pid);
	ProxyIDSet me;
	me.insert(pid);
	for (auto it = m_AllProxys.begin(); it != m_AllProxys.end(); ++it)
	{
		std::shared_ptr<AOIProxy> otherProxy = GlobalProxyModule->GetAOIProxy(*it);
		if (otherProxy)
		{
			otherProxy->OnEntityLeaveMe(me);
		}
	}

	proxy->OnEntityLeaveMe(m_AllProxys);
	proxy->NotifyClientDestroyEntity(me);
	return;
}

bool DungeonScene::Move(AOIProxy* proxy, const Point3D & dstPostion)
{
	// proxy更新位置，然后广播

	//proxy->SetPos(dstPostion);

	//SC_MOVE_SYNC moveMessage;
	//Position *pos = moveMessage.mutable_syncpostion()->Add();
	//pos->set_entityid(proxy->EntityID());
	//pos->set_destx(proxy->GetPostion().x);
	//pos->set_desty(proxy->GetPostion().y);
	//pos->set_destz(proxy->GetPostion().z);
	//pos->set_orientation(proxy->GetDirection());
	//pos->set_speed(proxy->GetSpeed());
	//moveMessage.set_servertime(GetNowTimeMille());
	//BroadcastToCareMe(SERVER_MESSAGE_OPCODE_MOVE, &moveMessage);
	return true;
}

void DungeonScene::GetEntitiesInCircle(const Point3D & center, float radius, unsigned char target_type_mask, ProxyID selfID, ProxyIDSet * out_vec)
{

}

void DungeonScene::GetEntitiesInShape(neox::h12map::Shape* shape, unsigned char target_type_mask, ProxyID selfID, ProxyIDSet* out_vec)
{
	neox::math3d::Point2F tmpPoint2d;
	shape->GetPosition(tmpPoint2d);
	Point3D shapeCenter(tmpPoint2d.x, 0, tmpPoint2d.y);
	for (auto it = m_AllProxys.begin(); it != m_AllProxys.end(); ++it)
	{
		std::shared_ptr<AOIProxy> targetProxy = GlobalProxyModule->GetAOIProxy(*it);
		if (!targetProxy)
		{
			_xerror("Failed get proxy");
			return;
		}
		neox::math3d::Point2F point2d(targetProxy->GetPosition().x, targetProxy->GetPosition().z);
		if (!shape->IsPointIn(point2d))
		{
			out_vec->insert(*it);
		}
	}
}

bool DungeonScene::GetHeight(float x, float z, float& y)
{
	return m_detour.GetHeight(x, z, y);
}

void DungeonScene::SetSuspendState(bool isSuspend)
{
	_info("Scene %d SetSuspendState %d", m_sceneID, isSuspend);
	m_isSuspend = isSuspend;
}

void DungeonScene::ExportAOIProxy(const Point3D & center, const int radius, const uint32_t targetTypeMask, ProxyIDSet * outProxySet)
{
	for (auto it = m_AllProxys.begin(); it != m_AllProxys.end(); ++it)
	{
		outProxySet->insert(*it);
	}
}

void DungeonScene::GetAllAOIProxy(const Point3D & center, const int radius, const uint32_t targetTypeMask, std::set<ENTITYID>& outProxySet)
{
}

int DungeonScene::GetSceneProxyCount()
{
	return m_AllProxys.size();
}

void DungeonScene::OnShowDebugInfo(int a)
{
	_debug("Scene has %d proxy in Scene %d", m_AllProxys.size(), m_sceneID);
}

WalkPath * DungeonScene::GetPath(const Point3D & start_pos, const Point3D & end_pos, bool straight_line)
{
	int length;
	const float* p = m_detour.GetPath(start_pos.x, start_pos.y, start_pos.z, end_pos.x, end_pos.y, end_pos.z, length);

	if (length < 2)
	{
		//_xerror("GetPath return float number %d is less than 3 should nerver happen", length);
		return nullptr;
	}

	WalkPath* w = new WalkPath;
	for (int i = 0; i < length; ++i)
	{
		w->push_back(Point3D(*(p + (i * 3 + 0)), *(p + (i * 3 + 1)), *(p + (i * 3 + 2))));
	}

	return w;
}

int DungeonScene::GetSceneID()
{
	return m_sceneID;
}

int DungeonScene::GetEntityCount()
{
	return 0;
}

void DungeonScene::BroadcastToCareMe(AOIProxy *proxy, MESSAGEID messageID, IMessage* message)
{
	// 遍历所有的client，然后进行广播
	for (auto it = m_AllProxys.begin(); it != m_AllProxys.end(); ++it)
	{
		std::shared_ptr<AOIProxy> other = GlobalProxyModule->GetAOIProxy(*it);
		if (other && other->EntityType()== ENTITY_TYPE_HERO && other.get() != proxy)
		{
			other->SendMessageToMe(messageID, message);
		}
	}
}

void DungeonScene::GetNearestPoly(float posX, float posY, float posZ, float * NearestPos)
{
	return m_detour.findNearestPoly(posX, posY, posZ, NearestPos);
}

