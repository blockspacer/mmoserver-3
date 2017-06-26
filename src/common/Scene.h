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


// 所有操作立刻广播，不在缓存，也不再区分格子
// 场景是主体，不同场景对应不同的proxy比较好
class DungeonScene :public IScene
{
public:
	DungeonScene(int sceneID): m_sceneID(sceneID), m_isSuspend(false), m_debugTimerID(0){}
	virtual ~DungeonScene() {}

	bool Init(std::string mapName);

	// 进行ProxyTick，遍历所有的AOIProxy，并调用相关的notify_change
	void Tick(int timerid);

	// 销毁处理
	void Final();

	// 进入一个场景
	bool    OnEnter(AOIProxy* proxy, const Point3D& pos);

	// 离开一个场景
	void    OnLeave(AOIProxy * proxy);

	bool Move(AOIProxy* proxy, const Point3D& pos);

	// 获取圆形区域中的entity集合
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

	// 移动
	bool    MoveTo(ProxyID pid, const Point3D& pos);

private:
};

#endif