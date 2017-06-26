// -------------------------------------------------------------------------
//    @FileName         ��    IProxyModule.h
//    @Author           ��    hou(houontherun@gmail.com)
//    @Date             ��    2017-02-24
//    @Module           ��    ProxyModule
//    @Desc             :     ά��lua��entity��Ӧ��C++�е�proxy
// -------------------------------------------------------------------------

#ifndef __I_PROXYMODULE_H__
#define __I_PROXYMODULE_H__

#include <stdint.h>
#include <iostream>
#include <string>
#include <list>
#include "common.h"
#include "message.h"
#include "math3d/vectors.h"
#include <functional>

#define MAX_PROXY_ID 100000  

class Grid;
class AOIProxy;

typedef  neox::math3d::Vector3  Point3D;

typedef std::set<ProxyID>  ProxyIDSet;
typedef std::set<Grid* >  GridSet;
//typedef std::set<AOIProxy*>    AOIProxySet;
typedef std::list<Point3D> WalkPath;

class Grid
{
public:
	ProxyIDSet     m_xProxySet;
	Point3D        m_position;
	uint32_t       m_index;
	float		   m_minX;
	float		   m_minZ;
	float		   m_maxX;
	float		   m_maxZ;
	uint32_t       m_x_row;
	uint32_t       m_z_col;
};

class AOIProxy;
class AOIScene;
class IScene;
typedef std::function<void(const SESSIONID clientSessionID, const uint16_t messageID, IMessage * message)> ENTITYT_SEND_MESSAGE_HANDLER;
class IProxyModule
{
public:

	virtual bool Init() = 0;

	virtual bool AddAOIScene(uint32_t sceneID, uint32_t radius, float minX, float maxX, float minZ, float maxZ, std::string mapName) = 0;
	
	virtual bool CreateDungeonScene(uint32_t sceneID, std::string mapName) = 0;

	virtual void DestroyAOIScene(uint32_t sceneID) = 0;

	virtual void Tick(int) = 0;

	virtual ProxyID CreateAOIProxy(ENTITYID entityID, uint32_t entityType, std::string& entityInfo, SESSIONID sessionID, uint32_t viewRadius, float speed) = 0;

	virtual void    DestroyAOIProxy(ENTITYID entityID) = 0;

	virtual void    DestroyAOIProxy(ProxyID pid) = 0;

	virtual std::shared_ptr<AOIProxy> GetAOIProxy(ProxyID pid) = 0;

	virtual std::shared_ptr<IScene> GetScene(uint32_t sceneID) = 0;
	
	virtual void ProcessPing(const SESSIONID clientSessionID, const char * message, const DATA_LENGTH_TYPE messageLength) = 0;

	virtual void ProcessPingBack(const SESSIONID clientSessionID, const char * message, const DATA_LENGTH_TYPE messageLength) = 0;

	virtual void  SendMessageToClient(const SESSIONID clientSessionID, const uint16_t messageID, IMessage * message) = 0;
};
typedef std::function<void(const SESSIONID clientSessionID, const uint16_t messageID, IMessage * message)> SEND_MESSAGE_HANDLER;

extern IProxyModule*  g_proxyModule;
#define GlobalProxyModule g_proxyModule

void SetGlobalProxyModuel(IProxyModule* p);
#endif