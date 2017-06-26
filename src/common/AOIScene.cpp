#include "AOIScene.h"
#include "message/LuaMessage.pb.h"
#include "AOIProxy.h"
#include "Timer.h"

AOIScene::AOIScene(uint32_t sceneID) :m_sceneID(sceneID), m_debugTimerID(0)
{
}

bool AOIScene::Init(uint32_t radius, float minX, float maxX, float minZ, float maxZ, std::string mapName)
{
	m_radius = radius;

	m_minX = minX;
	m_maxX = maxX;
	m_minZ = minZ;
	m_maxZ = maxZ;

	uint32_t length = static_cast<uint32_t>(abs(m_maxX - m_minX));
	uint32_t width = static_cast<uint32_t>(abs(m_maxZ - m_minZ));
	uint32_t x_size = length % radius == 0 ? length / radius : length / radius + 1;
	m_XSize = x_size;
	uint32_t z_size = width % radius == 0 ? width / radius : width / radius + 1;
	m_ZSize = z_size;
	m_grids.resize(x_size);
	uint32_t index = 0;
	for (uint32_t i = 0; i < x_size; ++i)
	{
		m_grids[i].resize(z_size);
		for (uint32_t j = 0; j < z_size; ++j)
		{
			Grid& g = m_grids[i][j];
			g.m_index = index++;
			g.m_x_row = i;
			g.m_z_col = j;
			g.m_minX = m_minX + i * radius;
			g.m_maxX = m_minX + (i + 1)*radius;
			g.m_minZ = m_minZ + j * radius;
			g.m_maxZ = m_minZ + (j + 1)*radius;
		}
	}

	//std::string pathFile = "detour/main_city.nav";
	if (!m_detour.Init(mapName.c_str()))
	{
		_xerror("Failed init detour of scene %d and pathname %s", m_sceneID, mapName.c_str());
		return false;
	}
#ifdef _DEBUG
	m_debugTimerID = CTimerMgr::Instance()->CreateTimer(0, this, &AOIScene::OnShowDebugInfo, 100000, 100000);
#endif // _DEBUG
	return true;
}

void AOIScene::Tick(int timerid)
{
	for (auto it = m_AllProxys.begin(); it != m_AllProxys.end(); )
	{
		std::shared_ptr<AOIProxy> proxy = GetProxy(*it);
		if (!proxy)
		{
			_xerror("proxy is null but pid %d is still scene %d", *it, m_sceneID);
			//assert(false);
			m_AllProxys.erase(it++);
		}
		else
		{
			++it;
			proxy->Tick();
		}
	}

	return;
}

void AOIScene::Final()
{
	for (auto it = m_AllProxys.begin(); it != m_AllProxys.end();)
	{
		std::shared_ptr<AOIProxy> proxy = GetProxy(*it);
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

Grid * AOIScene::GetGridByPoint(const Point3D & pos)
{
	if (pos.x > m_maxX || pos.x < m_minX || pos.z > m_maxZ || pos.z < m_minZ)
	{
		_xerror("Position is overflow sceneID:%d,position(%f,%f)", m_sceneID, pos.x,pos.z)
		//assert(!"Position is overflow");
		return nullptr;
	}

	uint32_t x = static_cast<uint32_t>(abs(pos.x - m_minX));
	uint32_t z = static_cast<uint32_t>(abs(pos.z - m_minZ));
	x = x / m_radius;
	z = z / m_radius;

	Grid* p = &m_grids[x][z];
	if (pos.x >= p->m_minX && pos.x <= p->m_maxX && pos.z >= p->m_minZ && pos.z <= p->m_maxZ)
	{
		return p;
	}
	return  nullptr;
}


int AOIScene::GetSceneProxyCount()
{
	return m_AllProxys.size();
}

bool AOIScene::OnEnter(AOIProxy* proxy, const Point3D & pos)
{
	if (!proxy)
	{
		_xerror("proxy is null");
		return false;
	}
	Register(proxy->GetProxyID(), proxy);
	ProxyIDSet me;
	me.insert(proxy->GetProxyID());
	proxy->NotifyClientCreateEntity(me);
	Grid* newGrid = GetGridByPoint(pos);
	if (!newGrid)
	{
		_xerror("Failed GetGrid scene %d pos %f, %f, %f ProxyID %s and ProxyType %d", m_sceneID, pos.x, pos.y, pos.z, proxy->EntityID().c_str(), proxy->EntityType());
		return false;
	}
	UpdateGrid(proxy->GetProxyID(), nullptr, newGrid);
	return true;
}

void AOIScene::OnLeave(AOIProxy* proxy)
{
	if (!proxy)
	{
		_xerror("proxy is null");
		return;
	}
	Grid* oldGrid = GetGridByPoint(proxy->GetPosition());
	UpdateGrid(proxy->GetProxyID(), oldGrid, nullptr);
	Unregister(proxy->GetProxyID());
	ProxyIDSet me;
	me.insert(proxy->GetProxyID());
	proxy->NotifyClientDestroyEntity(me);
}

bool AOIScene::Move(AOIProxy *proxy, const Point3D& pos)
{
	if (!proxy)
	{
		_xerror("proxy is null");
		return false;
	}
	Point3D oldPosition = proxy->GetPosition();
	Grid* oldGrid = GetGridByPoint(oldPosition);

	Grid* newGrid = GetGridByPoint(pos);
	if (oldGrid != newGrid)
	{
		UpdateGrid(proxy->GetProxyID(), oldGrid, newGrid);
	}

	return true;
}

void AOIScene::ForcePosition(AOIProxy *proxy, const Point3D& pos)
{
	if (!proxy)
	{
		_xerror("proxy is null");
		return;
	}
	Point3D oldPosition = proxy->GetPosition();
	Grid* oldGrid = GetGridByPoint(oldPosition);
	if (!oldGrid)
	{
		_warn("Failed Get OldGrid of proxyType %d and ID %s", proxy->EntityType(), proxy->EntityID().c_str());
	}
	Grid* newGrid = GetGridByPoint(pos);
	if (!newGrid)
	{
		_warn("Failed Get NewGrid of proxyType %d and ID %s", proxy->EntityType(), proxy->EntityID().c_str());
	}
	if (oldGrid != newGrid)
	{
		UpdateGrid(proxy->GetProxyID(), oldGrid, newGrid);
	}

	//proxy->SetPos(pos);

	//SC_FORCE_MOVE reply;
	//reply.set_entityid(proxy->EntityID());
	//reply.set_destx(proxy->GetPostion().x);
	//reply.set_desty(proxy->GetPostion().y);
	//reply.set_destz(proxy->GetPostion().z);

	//BroadcastToCareMe(proxy, SERVER_MESSAGE_FORCE_POSITION, &reply);
}

bool AOIScene::UpdateGrid(ProxyID pid, Grid *oldGrid, Grid* newGrid)
{
	if (oldGrid == newGrid)
	{
		return true;
	}

	std::shared_ptr<AOIProxy> self = GetProxy(pid);
	if (!self)
	{
		_xerror("Failed get proxy in UpdateGrid should nerver happen In Scene %d", m_sceneID);
		//assert(!"Failed get proxy in UpdateGrid should nerver happen");
		return false;
	}

	self->SetGrid(newGrid);
	if (newGrid)
	{
		newGrid->m_xProxySet.insert(pid);
	}

	if (oldGrid)
	{
		oldGrid->m_xProxySet.erase(pid);
	}

	uint32_t view_radius = self->GetViewRadius();
	uint32_t size = view_radius % m_radius == 0 ? view_radius / m_radius : view_radius / m_radius + 1;
	GridSet old_grid_set;
	GridSet new_grid_set;
	int x = 0;
	int z = 0;
	if (oldGrid) {
		for (x = static_cast<int>(oldGrid->m_x_row - size); x <= static_cast<int>(oldGrid->m_x_row + size); ++x)
		{
			if (x < 0 || x >= static_cast<int>(m_XSize))
			{
				continue;
			}
			for (z = static_cast<int>(oldGrid->m_z_col - size); z <= static_cast<int>(oldGrid->m_z_col + size); ++z)
			{
				if (z < 0 || z >= static_cast<int>(m_ZSize))
				{
					continue;
				}
				Grid* pGrid = &m_grids[x][z];
				old_grid_set.insert(pGrid);
			}
		}
	}

	if (newGrid)
	{
		for (x = static_cast<int>(newGrid->m_x_row - size); x <= static_cast<int>(newGrid->m_x_row + size); ++x)
		{
			if (x < 0 || x >= static_cast<int>(m_XSize))
			{
				continue;
			}
			for (z = static_cast<int>(newGrid->m_z_col - size); z <= static_cast<int>(newGrid->m_z_col + size); ++z)
			{
				if (z < 0 || z >= static_cast<int>(m_ZSize))
				{
					continue;
				}
				Grid* pGrid = &m_grids[x][z];
				new_grid_set.insert(pGrid);
			}
		}
	}

	GridSet  leave_grid_set;
	for (GridSet::iterator it = old_grid_set.begin(); it != old_grid_set.end(); it++)
	{
		if (new_grid_set.find(*it) == new_grid_set.end())
		{
			leave_grid_set.insert(*it);
		}
	}

	GridSet  add_grid_set;
	for (GridSet::iterator it = new_grid_set.begin(); it != new_grid_set.end(); it++)
	{
		if (old_grid_set.find(*it) == old_grid_set.end())
		{
			add_grid_set.insert(*it);
		}
	}

	ProxyIDSet leave_proxy_set;
	for (GridSet::iterator it = leave_grid_set.begin(); it != leave_grid_set.end(); it++)
	{
		leave_proxy_set.insert((*it)->m_xProxySet.begin(), (*it)->m_xProxySet.end());
	}
	ProxyIDSet add_proxy_set;
	for (GridSet::iterator it = add_grid_set.begin(); it != add_grid_set.end(); it++)
	{
		add_proxy_set.insert((*it)->m_xProxySet.begin(), (*it)->m_xProxySet.end());
	}

	leave_proxy_set.erase(pid);
	add_proxy_set.erase(pid);

	/************************** **************************************/

	std::shared_ptr<AOIProxy> pTmpAOIProxy = nullptr;
	ProxyIDSet me;
	me.insert(self->GetProxyID());
	for (ProxyIDSet::iterator it = leave_proxy_set.begin(); it != leave_proxy_set.end(); ++it)
	{
		pTmpAOIProxy = GetProxy(*it);
		if (!pTmpAOIProxy)
		{
			continue;
		}
		pTmpAOIProxy->OnEntityLeaveMe(me);

	}

	if (!leave_proxy_set.empty())
	{
		self->OnEntityLeaveMe(leave_proxy_set);
	}

	for (ProxyIDSet::iterator it = add_proxy_set.begin(); it != add_proxy_set.end(); it++)
	{
		pTmpAOIProxy = GetProxy(*it);
		if (!pTmpAOIProxy)
		{
			continue;
		}
		pTmpAOIProxy->OnEntityEnter(me);
	}

	if (!add_proxy_set.empty())
	{
		self->OnEntityEnter(add_proxy_set);
	}

	return true;
}


void AOIScene::GetEntitiesInCircle(const Point3D & center, float radius, unsigned char targetTypeMask, ProxyID selfID, ProxyIDSet * out_vec)
{
	std::shared_ptr<AOIProxy> selfProxy = GetProxy(selfID);
	if (!selfProxy)
	{
		_xerror("Failed get proxyid %d", selfID);
		return;
	}

	float r2 = radius * radius;

	ExportAOIProxy(center, radius, targetTypeMask, out_vec);
	for (auto it = out_vec->begin(); it != out_vec->end(); ++it)
	{
		std::shared_ptr<AOIProxy> targetProxy = GetProxy(*it);
		if (!targetProxy)
		{
			_xerror("Failed get proxy");
			return;
		}

		if ((selfProxy->GetPosition() - targetProxy->GetPosition()).LengthSqr() > r2)
		{
			out_vec->erase(*it);
		}
	}
	if (out_vec->size() > 60)
	{
		_warn("ExportAOIProxy Count %d in AOIScene %d too many radis %d Total Count %d", out_vec->size(), m_sceneID, radius, m_AllProxys.size());
	}
}

void AOIScene::GetEntitiesInShape(neox::h12map::Shape * shape, unsigned char targetTypeMask, ProxyID selfID, ProxyIDSet * out_vec)
{
	std::shared_ptr<AOIProxy> selfProxy = GetProxy(selfID);
	if (!selfProxy)
	{
		_xerror("Failed find proxy");
		return;
	}
	neox::math3d::Point2F tmpPoint2d;
	shape->GetPosition(tmpPoint2d);
	Point3D shapeCenter(tmpPoint2d.x, 0, tmpPoint2d.y);
	ExportAOIProxy(shapeCenter, shape->GetArg1(), targetTypeMask, out_vec);
	for (auto it = out_vec->begin(); it != out_vec->end(); ++it)
	{
		std::shared_ptr<AOIProxy> targetProxy = GetProxy(*it);
		if (!targetProxy)
		{
			_xerror("Failed get proxy");
			return;
		}
		neox::math3d::Point2F point2d(targetProxy->GetPosition().x, targetProxy->GetPosition().z);
		if (!shape->IsPointIn(point2d))
		{
			out_vec->erase(*it);
		}
	}
}

WalkPath* AOIScene::GetPath(const Point3D & start_pos, const Point3D & end_pos, bool straight_line)
{
	int length;
	const float* p = m_detour.GetPath(start_pos.x, start_pos.y, start_pos.z, end_pos.x, end_pos.y, end_pos.z, length);

	if (length < 1)
	{
		//_xerror("GetPath return float number %d is less than 3 should nerver happen", length);
		//return nullptr;
	}

	WalkPath* w = new WalkPath;
	for (int i = 0; i < length; ++i)
	{
		w->push_back(Point3D(*(p + (i*3 + 0)), *(p + (i * 3 + 1)), *(p + (i * 3 + 2))));
		auto a = Point3D(*(p + ((i+1) * 3 + 0)), *(p + ((i + 1) * 3 + 1)), *(p + ((i + 1) * 3 + 2)));
	}

	return w;
}



bool AOIScene::GetHeight(float x, float z, float& y)
{
	return m_detour.GetHeight(x, z, y);
}

int AOIScene::GetSceneID()
{
	return m_sceneID;
}

int AOIScene::GetEntityCount()
{
	return m_AllProxys.size();
}

void AOIScene::OnLeaveGrid(ProxyID pid, ProxyIDSet lostFriends)
{
}

void AOIScene::OnEnterGrid(ProxyID pid, ProxyIDSet lostFriends)
{
}

void AOIScene::BroadcastToCareMe(AOIProxy* proxy, MESSAGEID messageID, IMessage* message)
{
	ProxyIDSet  viewMe;
	ExportAOIProxy(proxy->GetPosition(), m_radius, 0xffffffff, &viewMe);
	viewMe.erase(proxy->GetProxyID());
	for (auto it = viewMe.begin(); it != viewMe.end(); ++it)
	{
		std::shared_ptr<AOIProxy> tmp = GetProxy(*it);
		if (!tmp)
		{
			continue;
		}

		tmp->SendMessageToMe(messageID, message);
	}
}


void AOIScene::SetSuspendState(bool isSuspend)
{

}


void AOIScene::GetAllAOIProxy(const Point3D & center, const int radius, const uint32_t targetTypeMask, std::set<ENTITYID>& outProxySet)
{
	Grid* grid = GetGridByPoint(center);

	if (!grid)
	{
		_warn("Failed Get Grid of Scene %d Pos %f, %f, %f", m_sceneID, center.x, center.y, center.z);
		return;
	}

	uint32_t size = radius % m_radius == 0 ? radius / m_radius : radius / m_radius + 1;
	int32_t x = 0;
	int32_t z = 0;
	x = grid->m_x_row - size;
	x = grid->m_x_row + size;
	for (x = grid->m_x_row - size; x <= static_cast<int32_t>(grid->m_x_row + size); x++)
	{
		if (x < 0 || x >= static_cast<int32_t>(m_XSize))
		{
			continue;
		}
		for (z = grid->m_z_col - size; z <= static_cast<int32_t>(grid->m_z_col + size); z++)
		{
			if (z < 0 || z >= static_cast<int32_t>(m_ZSize))
			{
				continue;
			}
			ProxyIDSet* tmp = &(m_grids[x][z].m_xProxySet);
			for (auto it = tmp->begin(); it != tmp->end(); ++it)
			{
				//AOIProxy* proxy = GetProxy(*it);
				//if (!proxy)
				//{
				//	//assert(false);
				//	continue;
				//}
				//outProxySet.insert(proxy->EntityID());
			}
		}
	}
}

void AOIScene::ExportAOIProxy(const Point3D & center, const int radius, const uint32_t targetTypeMask, ProxyIDSet * outProxySet)
{
	if (!outProxySet || !outProxySet->empty())
	{
		return;
	}

	Grid* grid = GetGridByPoint(center);

	if (!grid)
	{
		_warn("Failed Get Grid of Scene %d Pos %f, %f, %f", m_sceneID, center.x, center.y, center.z);
		return;
	}

	uint32_t size = radius % m_radius == 0 ? radius / m_radius : radius / m_radius + 1;
	if (size > 2)
	{
		_warn("Size %d in aoi big", size);
	}

	int32_t x = 0;
	int32_t z = 0;
	x = grid->m_x_row - size;
	x = grid->m_x_row + size;
	int loop_count = 0;
	for (x = grid->m_x_row - size; x <= static_cast<int32_t>(grid->m_x_row + size); x++)
	{
		if (x < 0 || x >= static_cast<int32_t>(m_XSize))
		{
			continue;
		}
		for (z = grid->m_z_col - size; z <= static_cast<int32_t>(grid->m_z_col + size); z++)
		{
			if (z < 0 || z >= static_cast<int32_t>(m_ZSize))
			{
				continue;
			}
			ProxyIDSet* tmp = &(m_grids[x][z].m_xProxySet);
			outProxySet->insert(tmp->begin(), tmp->end());
			loop_count++;
			//for (auto it = tmp->begin(); it != tmp->end(); ++it)
			//{
			//	//TODO 不做验证，验证消耗比较大，而且外层会再做一层判断
			//	outProxySet->insert(*it);
			//	//AOIProxy* proxy = GetProxy(*it);
			//	//if (!proxy)
			//	//{
			//	//	//assert(false);
			//	//	continue;
			//	//}
			//	//if (proxy->EntityType() & targetTypeMask)
			//	//{
			//	//	outProxySet->insert(*it);
			//	//}
			//}
		}
	}
	if (loop_count > 20)
	{
		_warn("loop_count %d is larger", loop_count);
	}
	if (outProxySet->size() > 60)
	{
		_warn("AOIProxy Count %d in sight is more than 100", outProxySet->size());
	}
}


void AOIScene::OnShowDebugInfo(int a)
{
	_debug("Scene has %d proxy in Scene %d", m_AllProxys.size(), m_sceneID);
}

bool AOIScene::Register(ProxyID pid, AOIProxy* proxy, bool isOverride)
{
	if (m_AllProxys.find(pid) != m_AllProxys.end())
	{
		_xerror("repeat register scene of scene %d proxy %d", m_sceneID, pid);
		//assert("false");
		return false;
	}

	m_AllProxys.insert(pid);
	return true;
}

void AOIScene::Unregister(ProxyID pid)
{
	if (m_AllProxys.find(pid) == m_AllProxys.end())
	{
		_xerror("proxy %d not in scene %d", pid, m_sceneID);
		//assert(false);
	}
	m_AllProxys.erase(pid);
	return;
}

std::shared_ptr<AOIProxy> AOIScene::GetProxy(ProxyID pid)
{
	return GlobalProxyModule->GetAOIProxy(pid);
}

void AOIScene::GetNearestPoly(float posX, float posY, float posZ, float * NearestPos)
{
	return m_detour.findNearestPoly(posX, posY, posZ, NearestPos);
}
