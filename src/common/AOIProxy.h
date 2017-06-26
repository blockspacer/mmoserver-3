#include <set>
#include <vector>
#include <map>
#include <list>
#include <stdint.h>
#include <math.h>
#include "IProxyModuel.h"
#include "common.h"
#include "IScene.h"
#include "IProxy.h"

// ��������Ұ�����IProxy
class AOIProxy:public IProxy
{
public:
	// ������Ұ��entity��Ӧ��proxy
	AOIProxy(ProxyID proxyID) :m_proxyID(proxyID), m_grid(nullptr), m_scene2(nullptr), m_wholePath2(nullptr), m_deltaTime(300), m_status(ProxyStatusStand), m_pos_time(0), m_test(0){}

	~AOIProxy() 
	{
	}

	bool Init(uint32_t viewRadius, std::string entityInfo, float speed);

	bool Init(ENTITYID  m_entityID, uint32_t  m_entityType, uint32_t  ViewRadius, std::string  entityInfo, SESSIONID sessionID, float speed);

	const ProxyID GetProxyID();

	bool Tick();

	void Final();

	bool UpdatePos(const Point3D& pos);

	void SetPos(const Point3D& pos);

	bool EnterScene(std::shared_ptr<IScene> scene, const Point3D& pos);

	void LeaveScene();

	int GetSceneID();

	void OnEntityLeaveMe(ProxyIDSet& leaveProxySet);

	void OnEntityEnter(ProxyIDSet& addProxySet);

	std::string& EntityInfo();

	void   UpdateEntityInfo(std::string& info);

	void SetScene(std::shared_ptr<IScene> scene);

	std::shared_ptr<IScene> GetScene();

	void SetGrid(Grid* g);

	Grid* GetGrid();

	void SetViewRadius(uint32_t radius);

	uint32_t GetViewRadius();

	ENTITYID EntityID();

	void SetEntityID(ENTITYID eid);

	void AddPositionChanged(ProxyID proxy);

	Point3D&  GetPosition();

	float GetDirection();

	void SetDirection(float dire);

	void SetSessionID(SESSIONID sid);

	SESSIONID GetSessionID();

	void BroadcastMessageToCareMe(MESSAGEID messageID, IMessage* message);

	void SendMessageToMe(MESSAGEID messageID, IMessage* message);

	int EntityType();

	bool WalkTo(Point3D& destPosition, Point3D* outPostion);
	
	void MoveToDirectly(Point3D& destPosition);

	// ǿ���ƶ�
	void MoveTo(Point3D& pos, float rotation);

	void MoveTo(const ProxyID pid, Point3D& pos, float rotation, uint64_t servertime, float speed);

	void StopWalk();

	void StopMove(Point3D& pos, float rotation);

	void SetSpeed(float speed)
	{
		m_speed = speed;
	}

	void DeletePositionChanged(ProxyID proxyid);

	void ForcePostion(Point3D& pos);

	void NotifyPositionChange();

	void CancelNotifyPositionChange();

	void SetPositionTime(uint64_t t);

	uint64_t GetPositionTime();

	float GetSpeed();

	void SetStatus(int s) { m_status = s; }

	int  GetStatus() { return m_status; }

	void BroadcastMoveMessage(bool predict=false);

	void BroadcastStopMoveMessage();

	void BroadcastForceMoveMessage();

	void BroadcastTurnDirectionMessage();

	void NotifyClientCreateEntity(ProxyIDSet & addProxySet);

	void NotifyClientDestroyEntity(ProxyIDSet & leaveProxySet);

	void GetNextTickPostion(Point3D& outPredictPosition, float& outDirection);

	void AddToInsightEntities(ProxyID pid);

	void DeleteFromInsightEntities(ProxyID pid);

	void SetPredictPos(Point3D& pos);

	const Point3D& GetPredictPos();

	void SetPredictTime(uint64_t t);

	uint64_t GetPredictTime();

private:

	AOIProxy() {}

	void WalkTowardNextWayPoint(Point3D & selfPosition, float & remainTime, float& outDirection, bool& outNeedSetDirection);

	void WalkTick();



private:
	ProxyID              m_proxyID;
	SESSIONID            m_sessionID;
	ENTITYID             m_entityID;
	std::string          m_entityInfo;
	uint32_t             m_entityType;

	uint32_t             m_ViewRadius;      // ��Ұ�뾶

	Grid*                m_grid;            // ��ǰ���ڸ���
	Point3D              m_pos;             // ��ǰλ��
	float                m_rotation;        // ��ǰ����
	uint64_t             m_pos_time;        // ����ǿͻ��˷����Ķ�Ӧ��λ�õ�ʱ��
	Point3D m_predictPos;
	uint64_t m_predictTime;

	std::shared_ptr<IScene>  m_scene2;

	ProxyIDSet           m_enter;           // һ֡�н�����Ұ��AOIProxy
											//ProxyIDSet           m_leave;           // һ֡���뿪��Ұ��AOIProxy
	std::set<ENTITYID>   m_leave;
	ProxyIDSet           m_view;            // Ŀǰ��Ұ�ڵ�AOIProxy
	ProxyIDSet           m_watchMe;         // �����ҵ��� 
	ProxyIDSet           m_posChange;       // һ֡���ҹ��ĵ�λ�øı��AOIProxy
	ProxyIDSet           m_entityInfoChange;// һ֡���ҹ��ĵ��û���Ϣ�ĸı䣨Ѫ������ۣ��ȼ��ȣ�

	bool                 m_isFirstWalkTick;
	std::shared_ptr<WalkPath> m_wholePath2;
	float                m_speed;
	float                m_deltaTime;      // ��λ�Ǻ���
	int                  m_status;         // ״̬�����߻�ֹͣ

	uint64_t             m_test;
	ProxyIDSet m_insightEntities; 
};