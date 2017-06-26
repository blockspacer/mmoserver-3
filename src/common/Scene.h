#pragma once
#ifndef _SCENE_H_
#define _SCENE_H_

#include <set>
#include <vector>
#include <map>
#include <list>
#include <stdint.h>
#include <math.h>
#include "IProxyModuel.h"
#include "common.h"
#include "shape.h"
#include "IScene.h"


// ���в������̹㲥�����ڻ��棬Ҳ�������ָ���
// ���������壬��ͬ������Ӧ��ͬ��proxy�ȽϺ�
class DungeonScene :public IScene
{
public:
	DungeonScene(int sceneID): m_sceneID(sceneID), m_isSuspend(false), m_debugTimerID(0){}
	virtual ~DungeonScene() {}

	bool Init(std::string mapName);

	// ����ProxyTick���������е�AOIProxy����������ص�notify_change
	void Tick(int timerid);

	// ���ٴ���
	void Final();

	// ����һ������
	bool    OnEnter(AOIProxy* proxy, const Point3D& pos);

	// �뿪һ������
	void    OnLeave(AOIProxy * proxy);

	bool Move(AOIProxy* proxy, const Point3D& pos);

	// ��ȡԲ�������е�entity����
	void	GetEntitiesInCircle(const Point3D& center, float radius, unsigned char target_type_mask, ProxyID selfID, ProxyIDSet* out_vec);

	void	GetEntitiesInShape(neox::h12map::Shape* shape, unsigned char target_type_mask, ProxyID selfID, ProxyIDSet* out_vec);

	WalkPath*    GetPath(const Point3D& start_pos, const Point3D& end_pos, bool straight_line);

	int     GetSceneID();

	int    GetEntityCount();

	int GetSceneType() 
	{
		return SCENE_TYPE_DUNGEON;
	}

	void BroadcastToCareMe(AOIProxy *proxy, MESSAGEID messageID, IMessage* message);

	void ForcePosition(AOIProxy *proxy, const Point3D& pos) {}

	void GetNearestPoly(float posX, float posY, float posZ, float* NearestPos);

	bool GetHeight(float x, float z, float& y);

	void SetSuspendState(bool isSuspend);

	void ExportAOIProxy(const Point3D & center, const int radius, const uint32_t targetTypeMask, ProxyIDSet * outProxySet);
	void GetAllAOIProxy(const Point3D & center, const int radius, const uint32_t targetTypeMask, std::set<ENTITYID>& outProxySet);
	int GetSceneProxyCount();

	void OnShowDebugInfo(int a);

private:
	int  m_sceneID;

	std::set<ProxyID>                   m_AllProxys;
	OftDetour                           m_detour;
	bool m_isSuspend;
	uint32_t m_debugTimerID;
};

class CityScene : public IScene
{
public:
	CityScene() {}
	virtual ~CityScene() {}

	// �ƶ�
	bool    MoveTo(ProxyID pid, const Point3D& pos);

private:
};

#endif