#include "AOIProxy.h"
#include "AOIModule.h"
#include "message/LuaMessage.pb.h"


bool AOIProxy::Init(uint32_t viewRadius, std::string entityInfo, float speed)
{
	return false;
}

bool AOIProxy::Init(ENTITYID entityID, uint32_t entityType, uint32_t viewRadius, std::string entityInfo, SESSIONID sessionID, float speed)
{
	m_entityID = entityID;
	m_entityType = entityType;
	m_ViewRadius = viewRadius;
	m_entityInfo = entityInfo;
	m_sessionID = sessionID;
	m_speed = speed;
	m_wholePath2 = nullptr;
	m_scene2 = nullptr;
	m_grid = nullptr;
	return true;
}

const ProxyID AOIProxy::GetProxyID()
{
	return m_proxyID;
}

bool AOIProxy::Tick()
{
	if (!m_scene2)
	{
		return true;
	}
	//TODO  tick中因为已经过了一段时间，所以是允许出现proxyid找不到proxy的
	
	if (m_test == 0)
	{
		m_deltaTime = 300;
	}
	else
	{
		m_deltaTime = GetNowTimeMille() - m_test;
	}
	//_info("Proxy %d Tick Time is %f and speed is %f",GetProxyID(), m_deltaTime, GetSpeed());
	m_test = GetNowTimeMille();
	WalkTick();
	
	if (m_entityType != ENTITY_TYPE_HERO)
	{
		m_enter.clear();
		m_leave.clear();
		m_posChange.clear();
		return true;
	}
	//// 玩家操作的英雄会收到网络数据
	//// 怪物会收到回调? (on_entity_in. on_entity_out)
	//bool need_notify_flag = false;
	//if (!m_enter.empty() || !m_leave.empty())
	//{
	//	//SC_AOI_SYNC  aoiMessage;
	//	//aoiMessage.set_sceneid(m_scene->GetSceneID());
	//	SC_CREATE_ENTITY createMessage;
	//	need_notify_flag = true;
	//	// 获取所有的进入玩家的基本信息，和所有离开玩家的ID
	//	// 将这些信息发给客户端
	//	AOIProxy* tmpProxy = nullptr;
	//	for (auto it = m_enter.begin(); it != m_enter.end();)
	//	{
	//		tmpProxy = GlobalAOIModule->GetAOIProxy(*it);
	//		if (!tmpProxy)
	//		{
	//			_warn("ProxyTick EntityEnter failed find proxy %d", *it);
	//			m_enter.erase(it++);
	//			continue;
	//		}
	//		++it;
	//		SC_CREATE_ENTITY_Entity  *entityMessage = createMessage.mutable_entitiescreate()->Add();
	//		entityMessage->set_entityid(tmpProxy->EntityID());
	//		entityMessage->set_entityinfo(tmpProxy->EntityInfo());
	//		Position *pos = entityMessage->mutable_entitypos();
	//		pos->set_destx(tmpProxy->GetPostion().x);
	//		pos->set_desty(tmpProxy->GetPostion().y);
	//		pos->set_destz(tmpProxy->GetPostion().z);
	//		pos->set_orientation(tmpProxy->GetDirection());
	//		pos->set_entityid(tmpProxy->EntityID());
	//		pos->set_speed(m_speed);
	//	}
	//	GlobalGameServerModule->SendMessageToGate(GetSessionID(), SERVER_MESSAGE_OPCODE_CREATE_ENTITY, &createMessage);

	//	if (!m_leave.empty())
	//	{
	//		SC_DESTROY_ENTITY destroyMessage;
	//		destroyMessage.set_sceneid(this->m_scene->GetSceneID());
	//		for (auto it = m_leave.begin(); it != m_leave.end(); it++)
	//		{
	//			destroyMessage.add_entitiesdestroy(*it);
	//		}
	//		GlobalGameServerModule->SendMessageToGate(GetSessionID(), SERVER_MESSAGE_OPCODE_DESTROY_ENTITY, &destroyMessage);
	//	}
	//}

	//if (!m_posChange.empty())
	//{
	//	SC_MOVE_SYNC moveMessage;
	//	need_notify_flag = true;
	//	AOIProxy* tmpProxy = nullptr;
	//	for (auto it = m_posChange.begin(); it != m_posChange.end(); )
	//	{
	//		tmpProxy = GlobalAOIModule->GetAOIProxy(*it);
	//		if (!tmpProxy)
	//		{
	//			// 可能改变了位置然后下线了
	//			auto pid = *it;
	//			m_posChange.erase(it++);
	//			_warn("ProxyTick PositionChange failed find proxy %d", pid);
	//			continue;
	//		}
	//		++it;
	//		Position *pos = moveMessage.mutable_syncpostion()->Add();
	//		pos->set_entityid(tmpProxy->EntityID());
	//		pos->set_destx(tmpProxy->GetPostion().x);
	//		pos->set_desty(tmpProxy->GetPostion().y);
	//		pos->set_destz(tmpProxy->GetPostion().z);
	//		pos->set_orientation(tmpProxy->GetDirection());
	//		pos->set_speed(tmpProxy->GetSpeed());
	//		moveMessage.set_servertime(GetNowTimeMille());
	//	}
		//GlobalGameServerModule->SendMessageToGate(GetSessionID(), CLIENT_MESSAGE_MOVE, &moveMessage);
	//}

	//if (!m_entityInfoChange.empty())
	//{
	//	AOIProxy* tmpProxy;
	//	for (auto it = m_entityInfoChange.begin(); it != m_entityInfoChange.end(); it++)
	//	{
	//		tmpProxy = GlobalAOIModule->GetAOIProxy(*it);
	//		if (!tmpProxy)
	//		{
	//			_warn("");
	//			continue;
	//		}
	//		_info("I'm proxy %d. The entity %d change info is %s", m_proxyID, tmpProxy->GetProxyID(), tmpProxy->EntityInfo().c_str());
	//	}
	//}

	m_enter.clear();
	m_leave.clear();
	m_posChange.clear();
	return true;
}

void AOIProxy::Final()
{
	LeaveScene();
}

bool AOIProxy::UpdatePos(const Point3D& pos)
{
	if (!m_scene2)
	{
		//assert(!"UpdatePos must in scene");
		return false;
	}

	if (pos == m_pos)
	{
		return true;
	}

	m_scene2->Move(this, pos);

	SetPos(pos);
	NotifyPositionChange();

	return true;
}


void AOIProxy::SetPos(const Point3D& pos)
{
	m_pos = pos;
}


void AOIProxy::OnEntityLeaveMe(ProxyIDSet & leaveProxySet)
{
	for (auto it = m_insightEntities.begin(); it != m_insightEntities.end(); ++it)
	{
		leaveProxySet.erase(*it);
	}
	NotifyClientDestroyEntity(leaveProxySet);
}

void AOIProxy::OnEntityEnter(ProxyIDSet& addProxySet)
{
	for (auto it = m_insightEntities.begin(); it != m_insightEntities.end(); ++it)
	{
		addProxySet.erase(*it);
	}

	if (addProxySet.empty() || EntityType() != ENTITY_TYPE_HERO)
	{
		return;
	}

	NotifyClientCreateEntity(addProxySet);
}


std::string& AOIProxy::EntityInfo()
{
	return m_entityInfo;
}

void AOIProxy::UpdateEntityInfo(std::string& info)
{
	m_entityInfo = info;
}

bool AOIProxy::EnterScene(std::shared_ptr<IScene> scene, const Point3D& pos)
{
	if (!scene)
	{
		return false;
	}
	LeaveScene();
	SetScene(scene);
	SetPos(pos);
	if (!scene->OnEnter( this, pos))
	{
		_xerror("Failed Enter Scene %d", scene->GetSceneID());
		SetScene(nullptr);
		return false;
	}
	UpdatePos(pos);
	SetStatus(ProxyStatusStand);
	return true;
}

void AOIProxy::LeaveScene()
{
	if (!m_scene2)
	{
		return;
	}
	
	m_scene2->OnLeave(this);

	SetScene(nullptr);
	SetGrid(nullptr);
	SetStatus(ProxyStatusStand);
}

void AOIProxy::SetScene(std::shared_ptr<IScene> scene)
{
	if (m_scene2 && scene)
	{
		// 还拥有scene，可能是没从场景退出
		// assert(!"enter scene without leave scene");
		m_scene2->OnLeave(this);
	}
	m_scene2 = scene;
}

std::shared_ptr<IScene> AOIProxy::GetScene()
{
	return m_scene2;
}

void AOIProxy::SetGrid(Grid* g)
{
	m_grid = g;
}

Grid* AOIProxy::GetGrid()
{
	return m_grid;
}

void AOIProxy::SetViewRadius(uint32_t radius)
{
	m_ViewRadius = radius;
}

uint32_t AOIProxy::GetViewRadius()
{
	return m_ViewRadius;
}

ENTITYID AOIProxy::EntityID()
{
	return m_entityID;
}

void AOIProxy::SetEntityID(ENTITYID eid)
{
	m_entityID = eid;
}

void AOIProxy::AddPositionChanged(ProxyID proxy)
{
	if (m_view.find(proxy) == m_view.end())
	{
		_warn("Failed find proxy %d in UpdatePosition", proxy);
		return;
	}
	m_posChange.insert(proxy);
}

Point3D& AOIProxy::GetPosition()
{
	if (m_status == ProxyStatusStand || m_entityType != ENTITY_TYPE_HERO)
	{
		return m_pos;
	}

	uint64_t now = GetNowTimeMille();
	int delta_time = static_cast<int>(now - m_pos_time);
	if (delta_time < 10)
	{
		//TODO 10ms以内认为是同步
		return m_pos;
	}
	// 根据速度进行预测

	//float speed = GetSpeed();
	//float delta_x = speed * cos(m_rotation*Py_MATH_PI / 180) * delta_time /1000;
	//float delta_z = speed * sin(m_rotation*Py_MATH_PI / 180) * delta_time /1000;

	//m_pos.x += delta_x;
	//m_pos.z += delta_z;
	//m_deltaTime = now;
	//_info("GetPostion m_speed is %f delta_time is %d and delta_x is %f delta_z is %f ",m_speed, delta_time, delta_x, delta_z);
	return m_pos;
}


float AOIProxy::GetDirection()
{
	return m_rotation;
}

void AOIProxy::DeletePositionChanged(ProxyID proxy)
{
	m_posChange.erase(proxy);
}

int AOIProxy::GetSceneID()
{
	if (m_scene2)
	{
		return m_scene2->GetSceneID();
	}
	return 0;
}

void AOIProxy::ForcePostion(Point3D & pos)
{
	StopWalk();

	if (!m_scene2)
	{
		return ;
	}

	m_scene2->Move(this, pos);

	SetPos(pos);
	SetStatus(ProxyStatusMove);

	BroadcastForceMoveMessage();
}




void AOIProxy::BroadcastMessageToCareMe(MESSAGEID messageID, IMessage* message)
{
	if (m_scene2)
	{
		m_scene2->BroadcastToCareMe(this, messageID, message);
	}
}

void AOIProxy::SendMessageToMe(MESSAGEID messageID, IMessage* message)
{
	if (m_entityType != ENTITY_TYPE_HERO)
	{
		return;
	}

	if (GetSessionID() <= 0)
	{
		_trace("PlayerProxy sessionID %lld in SendMessageToMe Error", GetSessionID());
		return;
	}

	GlobalProxyModule->SendMessageToClient(GetSessionID(), messageID, message);
}

int AOIProxy::EntityType()
{
	return m_entityType;
}

bool AOIProxy::WalkTo(Point3D & destPosition, Point3D* outPosition)
{
	StopWalk();
	if (!m_scene2)
	{
		return false;
	}
	WalkPath* path = nullptr;
	try
	{
		path = m_scene2->GetPath(m_pos, destPosition, false);
	}
	catch (const std::exception& e)
	{
		_xerror("Failed GetPath of src %f %f %f  to end %f %f %f because of %s", m_pos.x, m_pos.y, m_pos.z, destPosition.x, destPosition.y, destPosition.z, e.what());
		SAFE_DELETE(path);
	}
	catch (...)
	{
		SAFE_DELETE(path);
	}
	
	if (!path)
	{
		return false;
	}
	if (path->size() == 1)
	{
		//寻不到路就走直线过去
		//path->push_back(destPosition);
	}
		
	// 去掉起始点
	path->pop_front();
	if (path->size() == 0)
	{
		SAFE_DELETE(path);
		return false;
	}
	
	*outPosition = path->back();
	m_wholePath2.reset(path);	
	m_isFirstWalkTick = true;
	SetStatus(ProxyStatusMove);
	return true;
}

void AOIProxy::MoveToDirectly(Point3D& destPosition)
{
	StopWalk();
	if (!m_scene2)
	{
		return;
	}

	m_wholePath2 = std::make_shared<WalkPath>();
	m_wholePath2->push_back(destPosition);
	m_isFirstWalkTick = true;
	SetStatus(ProxyStatusMove);
	return;
}

// 移动到这里
void AOIProxy::MoveTo(Point3D & pos, float rotation)
{
	UpdatePos(pos);
	SetDirection(rotation);
}

// Proxy只维护状态，AOI和广播交给Scene
void AOIProxy::MoveTo(const ProxyID pid, Point3D& pos, float rotation, uint64_t servertime, float speed)
{
	if (!m_scene2)
	{
		//assert(!"UpdatePos must in scene");
		return ;
	}

	if (pos == m_pos)
	{
		return ;
	}
	SetDirection(rotation);
	SetPositionTime(servertime);
	SetSpeed(speed);
	SetPositionTime(servertime);
	m_scene2->Move(this, pos);
	SetPos(pos);

	BroadcastMoveMessage(false);
}

void AOIProxy::StopWalk()
{
	m_wholePath2.reset();
}


void AOIProxy::StopMove(Point3D& pos, float rotation)
{
	if (!m_scene2 || m_status == ProxyStatusStand)
	{
		return;
	}
	
	StopWalk();

	//TODO 两次可以合并为一次
	UpdatePos(pos);
	SetDirection(rotation);
	SetStatus(ProxyStatusStand);

	BroadcastStopMoveMessage();
}

void AOIProxy::WalkTowardNextWayPoint(Point3D & selfPosition, float & remainTime, float& outDirection, bool& outNeedSetDirection)
{
	SetStatus(ProxyStatusMove);

	outNeedSetDirection = false;
	Point3D  nextWayPoint = m_wholePath2->front();
	// 
	float deltaDistance = (GetSpeed()/ 100) * remainTime / 1000 ;
	//_info("WalkTowardNextWayPoint the speed is %f and deltaDistance is %f", GetSpeed(), deltaDistance);
	Point3D  difference = nextWayPoint - selfPosition;
	float nextDistance = difference.Length();
	if (deltaDistance > nextDistance)
	{
		remainTime = remainTime * (1 - nextDistance / deltaDistance);
		m_wholePath2->pop_front();
		selfPosition = nextWayPoint;
		if (difference.IsZero())
		{
			m_isFirstWalkTick = true;
		}
		else
		{
			outNeedSetDirection = true;
			//outDirection.Normalize();
			outDirection = atan2f(difference.x, difference.z) * 180 / Py_MATH_PI;
		}
	}
	else
	{
		difference.Normalize();
		difference = difference * deltaDistance;
		outDirection = atan2f(difference.x, difference.z) * 180 / Py_MATH_PI;
		selfPosition = selfPosition + difference;
		remainTime = 0;
	}
}

void AOIProxy::WalkTick()
{
	if (!m_wholePath2 || m_wholePath2->size() == 0 || !m_scene2 || m_status == ProxyStatusStand)
	{
		return;
	}
	SetStatus(ProxyStatusMove);

	float remain_time = m_deltaTime;
	bool needSetDirection = m_isFirstWalkTick;
	float direction = 0;
	Point3D new_pos = m_pos;
	while (remain_time > 0 && m_wholePath2 && m_wholePath2->size() > 0)
	{
		bool thisNeedSetDirection = false;
		//new_pos = m_pos;
		WalkTowardNextWayPoint(new_pos, remain_time, direction, thisNeedSetDirection);
		//m_pos = new_pos;
		needSetDirection = needSetDirection || thisNeedSetDirection;
	}

	UpdatePos(new_pos);

	if (needSetDirection)
	{
		SetDirection(direction);
	}

	BroadcastMoveMessage(true);

	if (m_wholePath2->empty())
	{
		m_wholePath2.reset();
		StopMove(m_pos, m_rotation);
	}
}


void AOIProxy::SetDirection(float dire)
{
	if (m_rotation == dire)
	{
		return;
	}
	m_rotation = dire;
	NotifyPositionChange();
}

void AOIProxy::SetSessionID(SESSIONID sid)
{
	m_sessionID = sid;
}

SESSIONID AOIProxy::GetSessionID()
{
	return m_sessionID;
}

void AOIProxy::NotifyPositionChange()
{
	std::shared_ptr<AOIProxy> tmpProxy = nullptr;
	for (auto it = m_watchMe.begin(); it != m_watchMe.end(); )
	{
		tmpProxy = GlobalProxyModule->GetAOIProxy(*it);
		if (!tmpProxy)
		{	
			m_watchMe.erase(it++);
			continue;
		}
		else
		{
			++it;
			tmpProxy->AddPositionChanged(m_proxyID);
		}
	}
}

void AOIProxy::CancelNotifyPositionChange()
{
	for (auto it = m_watchMe.begin(); it != m_watchMe.end(); )
	{
		std::shared_ptr<AOIProxy> proxy = g_proxyModule->GetAOIProxy(*it);
		if (!proxy)
		{
			m_watchMe.erase(it++);
			continue;
		}
		++it;
		proxy->DeletePositionChanged(m_proxyID);
	}
}

void AOIProxy::SetPositionTime(uint64_t t)
{
	m_pos_time = t;
}

uint64_t AOIProxy::GetPositionTime()
{
	return m_pos_time;
}

float AOIProxy::GetSpeed()
{
	return m_speed;
}

void AOIProxy::BroadcastMoveMessage(bool predict)
{
	//SC_MOVE_SYNC moveMessage;
	//Position *positon = moveMessage.mutable_syncpostion()->Add();
	//positon->set_entityid(EntityID());
	//
	//if (predict)
	//{
	//	// need predict
	//	Point3D predictPosition;
	//	float predictDirection;
	//	GetNextTickPostion(predictPosition, predictDirection);
	//	positon->set_destx(predictPosition.x);
	//	positon->set_desty(predictPosition.y);
	//	positon->set_destz(predictPosition.z);
	//	positon->set_orientation(predictDirection);
	//}
	//else
	//{
	//	Point3D& pos = GetPosition();
	//	positon->set_destx(pos.x);
	//	positon->set_desty(pos.y);
	//	positon->set_destz(pos.z);
	//	positon->set_orientation(GetDirection());
	//}

	//
	//positon->set_speed(GetSpeed());

	uint64_t now = GetNowTimeMille();

	SC_MOVE_SYNC moveMessage;
	Position *positon = moveMessage.mutable_syncpostion();
	positon->set_entityid(EntityID());
	positon->set_destx(m_pos.x);
	positon->set_desty(m_pos.y);
	positon->set_destz(m_pos.z);
	positon->set_speed(GetSpeed());
	positon->set_orientation(m_rotation);
	if (m_pos_time == 0)
	{
		moveMessage.set_servertime(GetNowTimeMille());
	}
	else
	{
		moveMessage.set_servertime(m_pos_time);
	}
	

	//Position *predictpos = moveMessage.mutable_predictpostion();
	//if (predict)
	//{
	//	moveMessage.set_servertime(now);
	//	// need predict
	//	Point3D predictPosition;
	//	float predictDirection;
	//	GetNextTickPostion(predictPosition, predictDirection);
	//	predictpos->set_entityid(EntityID());
	//	predictpos->set_destx(predictPosition.x);
	//	predictpos->set_desty(predictPosition.y);
	//	predictpos->set_destz(predictPosition.z);
	//	predictpos->set_orientation(predictDirection);
	//	predictpos->set_speed(GetSpeed());
	//	moveMessage.set_predicttime(now + 300);
	//}
	//else
	//{
	//	predictpos->set_entityid(EntityID());
	//	predictpos->set_destx(m_predictPos.x);
	//	predictpos->set_desty(m_predictPos.y);
	//	predictpos->set_destz(m_predictPos.z);
	//	predictpos->set_speed(GetSpeed());
	//	predictpos->set_orientation(m_rotation);
	//	moveMessage.set_predicttime(m_predictTime);
	//}

	moveMessage.set_sceneid(GetSceneID());
	BroadcastMessageToCareMe(SERVER_MESSAGE_OPCODE_MOVE, &moveMessage);
	SendMessageToMe(SERVER_MESSAGE_OPCODE_MOVE, &moveMessage);
}

void AOIProxy::BroadcastStopMoveMessage()
{
	SC_STOP_MOVE_SYNC reply;
	Position* syncPos = reply.mutable_syncpostion()->Add();
	syncPos->set_destx(m_pos.x);
	syncPos->set_desty(m_pos.y);
	syncPos->set_destz(m_pos.z);
	syncPos->set_orientation(m_rotation);
	syncPos->set_entityid(EntityID());
	syncPos->set_speed(0);

	reply.set_servertime(GetNowTimeMille());
	reply.set_sceneid(GetSceneID());
	BroadcastMessageToCareMe(SERVER_MESSAGE_OPCODE_STOP_MOVE, &reply);
	SendMessageToMe(SERVER_MESSAGE_OPCODE_STOP_MOVE, &reply);
}

void AOIProxy::BroadcastForceMoveMessage()
{
	SC_FORCE_MOVE reply;
	reply.set_entityid(EntityID());
	reply.set_destx(GetPosition().x);
	reply.set_desty(GetPosition().y);
	reply.set_destz(GetPosition().z);
	reply.set_sceneid(GetSceneID());
	BroadcastMessageToCareMe(SERVER_MESSAGE_FORCE_POSITION, &reply);
}

void AOIProxy::BroadcastTurnDirectionMessage()
{
	SC_TURN_DIRECTION reply;
	reply.set_entityid(EntityID());
	reply.set_destx(GetPosition().x);
	reply.set_desty(GetPosition().y);
	reply.set_destz(GetPosition().z);
	reply.set_sceneid(GetSceneID());
	reply.set_direction(GetDirection());
	BroadcastMessageToCareMe(SERVER_MESSAGE_OPCODE_TURN_DIRECTION, &reply);
}

void AOIProxy::NotifyClientCreateEntity(ProxyIDSet & addProxySet)
{
	SC_CREATE_ENTITY  createMessage;
	createMessage.set_sceneid(GetSceneID());

	for (auto it = addProxySet.begin(); it != addProxySet.end(); ++it)
	{
		std::shared_ptr<AOIProxy> createProxy = GlobalProxyModule->GetAOIProxy(*it);
		//FIX 注意是否有createProxy
		if (!createProxy)
		{
			continue;;
		}
		SC_CREATE_ENTITY_Entity  *entityMessage = createMessage.mutable_entitiescreate()->Add();
		entityMessage->set_entityid(createProxy->EntityID());
		entityMessage->set_entityinfo(createProxy->EntityInfo());
		Position *pos = entityMessage->mutable_entitypos();
		pos->set_destx(createProxy->GetPosition().x);
		pos->set_desty(createProxy->GetPosition().y);
		pos->set_destz(createProxy->GetPosition().z);
		pos->set_orientation(createProxy->GetDirection());
		pos->set_entityid(createProxy->EntityID());
		pos->set_speed(createProxy->GetSpeed());
	}
	_debug("The AOICreateEntityMessage Length is %d in scene %d", createMessage.ByteSize(), GetSceneID());
	SendMessageToMe(SERVER_MESSAGE_OPCODE_CREATE_ENTITY, &createMessage);
}

void AOIProxy::NotifyClientDestroyEntity(ProxyIDSet & leaveProxySet)
{
	// 通知客户端销毁离开的entity
	SC_DESTROY_ENTITY  destroyMessage;
	destroyMessage.set_sceneid(GetSceneID());

	for (auto it = leaveProxySet.begin(); it != leaveProxySet.end(); ++it)
	{
		std::shared_ptr<AOIProxy> destoryProxy = GlobalProxyModule->GetAOIProxy(*it);
		if (!destoryProxy)
		{
			//assert(!"Failed find destoryProxy in OnEntityLeaveMe");
			continue;
		}
		destroyMessage.add_entitiesdestroy(destoryProxy->EntityID());
	}
	SendMessageToMe(SERVER_MESSAGE_OPCODE_DESTROY_ENTITY, &destroyMessage);
}

void AOIProxy::GetNextTickPostion(Point3D& outPredictPosition, float& outDirection)
{
	if (!m_wholePath2 || m_wholePath2->size() == 0 || !m_scene2 || m_status == ProxyStatusStand)
	{
		outPredictPosition = m_pos;
		outDirection = m_rotation;
		return;
	}

	float remain_time = m_deltaTime;
	float direction = 0;
	Point3D new_pos = m_pos;
	bool thisNeedSetDirection = true;
	while (remain_time > 0 && m_wholePath2 && m_wholePath2->size() > 0)
	{
		WalkTowardNextWayPoint(new_pos, remain_time, direction, thisNeedSetDirection);
	}
	outPredictPosition = new_pos;
	outDirection = direction;
}

void AOIProxy::AddToInsightEntities(ProxyID pid)
{
	m_insightEntities.insert(pid);
}

void AOIProxy::DeleteFromInsightEntities(ProxyID pid)
{
	m_insightEntities.erase(pid);
}

void AOIProxy::SetPredictPos(Point3D& pos)
{
	m_predictPos = pos;
}

const Point3D & AOIProxy::GetPredictPos()
{
	return m_predictPos;
}

void AOIProxy::SetPredictTime(uint64_t t)
{
	m_predictTime = t;
}

uint64_t AOIProxy::GetPredictTime()
{
	return m_predictTime;
}

