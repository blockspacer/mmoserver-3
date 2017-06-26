#pragma once
#ifndef _I_SCENE_
#define _I_SCENE_

#include <set>
#include <vector>
#include <map>
#include <list>
#include <stdint.h>
#include <math.h>
#include "IProxyModuel.h"
#include "common.h"
#include "shape.h"
#include "detour/OftDetour.h"


class IScene
{
public:
	virtual ~IScene() {}

	virtual int GetSceneType() = 0;

	virtual int GetSceneID() = 0;

	virtual void Tick(int timerid) = 0;

	virtual void	GetEntitiesInCircle(const Point3D& center, float radius, unsigned char target_type_mask, ProxyID selfID, ProxyIDSet* out_vec) = 0;

	virtual void	GetEntitiesInShape(neox::h12map::Shape* shape, unsigned char target_type_mask, ProxyID selfID, ProxyIDSet* out_vec) = 0;

	virtual void ExportAOIProxy(const Point3D & center, const int radius, const uint32_t targetTypeMask, ProxyIDSet * outProxySet) = 0;

	virtual void GetAllAOIProxy(const Point3D & center, const int radius, const uint32_t targetTypeMask, std::set<ENTITYID>& outProxySet) = 0;

	virtual WalkPath*    GetPath(const Point3D& start_pos, const Point3D& end_pos, bool straight_line) = 0;
	virtual bool GetHeight(float x, float z, float& y) = 0;

	virtual bool    OnEnter(AOIProxy* proxy, const Point3D& pos) = 0;

	virtual void    OnLeave(AOIProxy* proxy) = 0;

	virtual bool    Move(AOIProxy* proxy, const Point3D& pos) = 0;

	virtual void ForcePosition(AOIProxy *proxy, const Point3D& pos) = 0;

	virtual void GetNearestPoly(float posX, float posY, float posZ, float* NearestPos) = 0;

	virtual void BroadcastToCareMe(AOIProxy *proxy, MESSAGEID messageID, IMessage* message) = 0;

	virtual void Final() = 0;

	virtual void SetSuspendState(bool isSuspend) = 0;

	virtual int GetSceneProxyCount() = 0;
};

class BaseScene :public IScene
{
public:
	WalkPath*    GetPath(const Point3D& start_pos, const Point3D& end_pos, bool straight_line);

	int     GetSceneID()
	{
		return m_sceneID;
	}

	int    GetEntityCount();

	int GetSceneType()
	{
		return m_sceneType;
	}

	void GetNearestPoly(float posX, float posY, float posZ, float* NearestPos);

private:
	int  m_sceneID;
	int  m_sceneType;
	std::set<ProxyID>                   m_AllProxys;
	OftDetour                           m_detour;
};


#endif // !_I_SCENE_