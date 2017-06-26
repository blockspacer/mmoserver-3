#include "OftDetour.h"
#include <string.h>

static const int NAVMESHSET_MAGIC = 'M' << 24 | 'S' << 16 | 'E' << 8 | 'T'; //'MSET';
static const int NAVMESHSET_VERSION = 1;

struct NavMeshSetHeader
{
	int magic;
	int version;
	int numTiles;
	dtNavMeshParams params;
};

struct NavMeshTileHeader
{
	dtTileRef tileRef;
	int dataSize;
};

/// These are just sample areas to use consistent values across the samples.
/// The use should specify these base on his needs.
enum SamplePolyAreas
{
	SAMPLE_POLYAREA_GROUND,
	SAMPLE_POLYAREA_WATER,
	SAMPLE_POLYAREA_ROAD,
	SAMPLE_POLYAREA_DOOR,
	SAMPLE_POLYAREA_GRASS,
	SAMPLE_POLYAREA_JUMP,
};
enum SamplePolyFlags
{
	SAMPLE_POLYFLAGS_WALK = 0x01,		// Ability to walk (ground, grass, road)
	SAMPLE_POLYFLAGS_SWIM = 0x02,		// Ability to swim (water).
	SAMPLE_POLYFLAGS_DOOR = 0x04,		// Ability to move through doors.
	SAMPLE_POLYFLAGS_JUMP = 0x08,		// Ability to jump.
	SAMPLE_POLYFLAGS_DISABLED = 0x10,		// Disabled polygon
	SAMPLE_POLYFLAGS_ALL = 0xffff	// All abilities.
};

OftDetour::OftDetour():
m_startRef(0),
m_endRef(0),
m_npolys(0),
m_nstraightPath(0),
m_straightPathOptions(0)
{
	m_navMesh = NULL;
	m_navQuery = new dtNavMeshQuery;
	m_filter.setIncludeFlags(SAMPLE_POLYFLAGS_ALL ^ SAMPLE_POLYFLAGS_DISABLED);
	m_filter.setExcludeFlags(0);

	m_polyPickExt[0] = 2;
	m_polyPickExt[1] = 20;
	m_polyPickExt[2] = 2;
}

bool OftDetour::Init(const char* path)
{
	if (m_navMesh != NULL)
	{
		dtFreeNavMesh(m_navMesh);
	}
	
	m_navMesh = LoadNavMesh(path);

	if (!m_navMesh)
	{
		return false;
	}

	dtStatus status = m_navQuery->init(m_navMesh, 2048);
	if (!dtStatusSucceed(status))
	{
		return false;
	}

	if (m_navQuery)
	{
		// Change costs.
		m_filter.setAreaCost(SAMPLE_POLYAREA_GROUND, 1.0f);
		m_filter.setAreaCost(SAMPLE_POLYAREA_WATER, 10.0f);
		m_filter.setAreaCost(SAMPLE_POLYAREA_ROAD, 1.0f);
		m_filter.setAreaCost(SAMPLE_POLYAREA_DOOR, 1.0f);
		m_filter.setAreaCost(SAMPLE_POLYAREA_GRASS, 2.0f);
		m_filter.setAreaCost(SAMPLE_POLYAREA_JUMP, 1.5f);
	}
	return true;
}


dtNavMesh* OftDetour::LoadNavMesh(const char* path)
{
	FILE* fp = fopen(path, "rb");
	if (!fp) return 0;


	// Read header.
	NavMeshSetHeader header;
	size_t readLen = fread(&header, sizeof(NavMeshSetHeader), 1, fp);
	if (readLen != 1)
	{
		fclose(fp);
		return 0;
	}
	if (header.magic != NAVMESHSET_MAGIC)
	{
		fclose(fp);
		return 0;
	}
	if (header.version != NAVMESHSET_VERSION)
	{
		fclose(fp);
		return 0;
	}

	dtNavMesh* mesh = dtAllocNavMesh();
	if (!mesh)
	{
		fclose(fp);
		return 0;
	}
	dtStatus status = mesh->init(&header.params);
	if (dtStatusFailed(status))
	{
		fclose(fp);
		return 0;
	}

	// Read tiles.
	for (int i = 0; i < header.numTiles; ++i)
	{
		NavMeshTileHeader tileHeader;
		readLen = fread(&tileHeader, sizeof(tileHeader), 1, fp);
		if (readLen != 1)
		{
			fclose(fp);
			return 0;
		}

		if (!tileHeader.tileRef || !tileHeader.dataSize)
			break;

		unsigned char* data = (unsigned char*)dtAlloc(tileHeader.dataSize, DT_ALLOC_PERM);
		if (!data) break;
		memset(data, 0, tileHeader.dataSize);
		readLen = fread(data, tileHeader.dataSize, 1, fp);
		if (readLen != 1)
		{
			fclose(fp);
			return 0;
		}

		mesh->addTile(data, tileHeader.dataSize, DT_TILE_FREE_DATA, tileHeader.tileRef, 0);
	}

	fclose(fp);

	return mesh;
}

const float* OftDetour::GetPath(float startX, float startY, float startZ, float endX, float endY, float endZ, int& pathLength)
{
	pathLength = 0;
	memset(&m_straightPath, 0, sizeof(m_straightPath));
	if (!m_navMesh)
		return nullptr;

	m_spos[0] = startX;
	m_spos[1] = startY;
	m_spos[2] = startZ;

	m_epos[0] = endX;
	m_epos[1] = endY;
	m_epos[2] = endZ;

	dtStatus status = m_navQuery->findNearestPoly(m_spos, m_polyPickExt, &m_filter, &m_startRef, 0);
	if (!dtStatusSucceed(status) || m_startRef == 0)
	{
		//throw std::exception("Failed find start poly");
		return nullptr;
	}

	status = m_navQuery->findNearestPoly(m_epos, m_polyPickExt, &m_filter, &m_endRef, 0);
	if (!dtStatusSucceed(status) || m_endRef == 0)
	{
		//throw std::exception("Failed find end poly");
		return nullptr;
	}

	status = m_navQuery->findPath(m_startRef, m_endRef, m_spos, m_epos, &m_filter, m_polys, &m_npolys, MAX_POLYS);
	if (!dtStatusSucceed(status) || !m_npolys)
	{
		//throw std::exception("Failed findPath");
		return nullptr;
	}
	m_nstraightPath = 0;

	// In case of partial path, make sure the end point is clamped to the last polygon.
	float epos[3];
	memcpy(epos, m_epos, sizeof(float) * 3);
	if (m_polys[m_npolys - 1] != m_endRef)
		m_navQuery->closestPointOnPoly(m_polys[m_npolys - 1], m_epos, epos, 0);

	m_navQuery->findStraightPath(m_spos, epos, m_polys, m_npolys,
		m_straightPath, m_straightPathFlags,
		m_straightPathPolys, &m_nstraightPath, MAX_POLYS, m_straightPathOptions);

	pathLength = m_nstraightPath;
	return m_straightPath;
}

const float* OftDetour::GetPath(std::vector<float> startPos, std::vector<float> endPos, int& pathLength)
{
	if (startPos.size() < 3 || endPos.size() < 3)
	{
		assert(false);
		return nullptr;
	}
	return GetPath(startPos[0], startPos[1], startPos[2], endPos[0], endPos[1], endPos[2], pathLength);
}

void OftDetour::findNearestPoly(float posX, float posY, float posZ, float* NearestPos)
{
	return findNearestPoly(posX, posY, posZ, NearestPos, nullptr);
}


void OftDetour::findNearestPoly(float posX, float posY, float posZ, float* NearestPos, float* t_polyPickExt)
{
	if (!m_navMesh)
	{
		return;
	}
	float pos[3];
	pos[0] = posX;
	pos[1] = posY;
	pos[2] = posZ;

	float* polyPickExt = t_polyPickExt;
	if (polyPickExt == nullptr)
	{
		polyPickExt = m_polyPickExt;
	}

	m_navQuery->findNearestPoly(pos, polyPickExt, &m_filter, &m_startRef, NearestPos);
}

bool OftDetour::GetHeight(float x, float z, float & y)
{
	dtStatus ret = m_navQuery->GetHeight(x, z, 3, &m_filter, &y);
	if (dtStatusSucceed(ret))
	{
		return true;
	}
	return false;
}
