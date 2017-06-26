#ifndef _OFT_DETOUR_H_
#define _OFT_DETOUR_H_

#include <iostream>
#include <string>
#include "DetourNavMesh.h"
#include "DetourNavMeshQuery.h"
#include <vector>
#include <assert.h>

class OftDetour
{
public:
	OftDetour();
	bool Init(const char* filePath);
	const float* GetPath(float startX, float startY, float startZ, float endX, float endY, float endZ, int& pathLength);
	const float* GetPath(std::vector<float> startPos, std::vector<float> endPos, int& pathLength);
	void findNearestPoly(float posX, float posY, float posZ, float* NearestPos);
	void findNearestPoly(float posX, float posY, float posZ, float* NearestPos, float* t_polyPickExt);
	bool GetHeight(float x, float z, float& y);

private:
	static const int MAX_POLYS = 256;
	static const int MAX_SMOOTH = 2048;

	dtNavMesh* m_navMesh;
	dtNavMeshQuery* m_navQuery;
	float m_spos[3];
	float m_epos[3];
	dtPolyRef m_startRef;
	dtPolyRef m_endRef;
	dtQueryFilter m_filter;
	float m_polyPickExt[3];
	dtPolyRef m_polys[MAX_POLYS];
	int m_npolys;
	int m_nstraightPath;
	float m_straightPath[MAX_POLYS * 3];
	unsigned char m_straightPathFlags[MAX_POLYS];
	dtPolyRef m_straightPathPolys[MAX_POLYS];
	int m_straightPathOptions;


	dtNavMesh* LoadNavMesh(const char* path);
};

#endif