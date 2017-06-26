#ifndef __AOI_SCENE_H__
#define __AOI_SCENE_H__

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
#include "IScene.h"

class Grid;

class AOIScene:public IScene
{
public:
	AOIScene(uint32_t sceneID);
	~AOIScene() {};

	int GetSceneType() { return SCENE_TYPE_CITY; }

	bool Init(uint32_t radius, float minX, float maxX, float minZ, float maxZ, std::string mapName);

	void Tick(int timerid);

	void Final();

	Grid*   GetGridByPoint(const Point3D& pos);

	int GetSceneProxyCount();

	bool    OnEnter(AOIProxy* proxy, const Point3D& pos);

	void    OnLeave(AOIProxy* proxy);

	bool  Move(AOIProxy *proxy, const Point3D& pos);

	void ForcePosition(AOIProxy *proxy, const Point3D& pos);

	bool    UpdateGrid(ProxyID pid, Grid *pOldGrid, Grid* new_grid);

	void	GetEntitiesInCircle(const Point3D& center, float radius, unsigned char target_type_mask, ProxyID selfID, ProxyIDSet* out_vec);

	void	GetEntitiesInShape(neox::h12map::Shape* shape, unsigned char target_type_mask, ProxyID selfID, ProxyIDSet* out_vec);

	WalkPath*    GetPath(const Point3D& start_pos, const Point3D& end_pos, bool straight_line);

	bool GetHeight(float x, float z, float& y);

	int     GetSceneID();

	int    GetEntityCount();

	void OnLeaveGrid(ProxyID pid, ProxyIDSet lostFriends);

	void OnEnterGrid(ProxyID pid, ProxyIDSet lostFriends);
	void BroadcastToCareMe(AOIProxy *proxy, MESSAGEID messageID, IMessage* message);
	void SetSuspendState(bool isSuspend);
	void GetAllAOIProxy(const Point3D & center, const int radius, const uint32_t targetTypeMask, std::set<ENTITYID>& outProxySet);
	void  ExportAOIProxy(const Point3D& center, const int radius, const uint32_t mask, ProxyIDSet* outProxySet);

	void OnShowDebugInfo(int a);

private:
	bool  Register(ProxyID pid, AOIProxy* proxy, bool isOverride = false);

	void  Unregister(ProxyID pid);

	std::shared_ptr<AOIProxy> GetProxy(ProxyID pid);

	void GetNearestPoly(float posX, float posY, float posZ, float* NearestPos);

private:
	uint32_t                            m_sceneID;
	uint32_t                            m_radius;
	float                               m_minX;
	float                               m_maxX;
	float                               m_minZ;
	float                               m_maxZ;
	uint32_t                            m_XSize; //
	uint32_t                            m_ZSize; //

	std::set<ProxyID>                   m_AllProxys;
	typedef	std::vector<Grid>	        GridRow;
	std::vector<GridRow>			    m_grids;

	bool                                m_useAOI;
	OftDetour                           m_detour;
	uint32_t m_debugTimerID;
};

#endif // !__AOI_SCENE_H__