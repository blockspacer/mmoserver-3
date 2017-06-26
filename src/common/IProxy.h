#pragma once
#ifndef _I_PROXY_H_
#define _I_PROXY_H_

#include "common.h"
#include "common_define.h"
#include <string>
#include "IProxyModuel.h"
#include <functional>



class IScene;

enum ProxyStatus
{
	ProxyStatusStand = 0,     //静止状态
	ProxyStatusMove = 1,      //行走状态
};

// 依附在视野对象的IProxy
class IProxy
{
public:
	virtual ~IProxy() {}

	virtual const PROXYID GetProxyID() = 0;

	virtual bool Init(uint32_t viewRadius, std::string entityInfo, float speed) = 0;

	virtual bool Tick() = 0;

	virtual void Final() = 0;

	virtual bool EnterScene(std::shared_ptr<IScene> scene, const Point3D& pos) = 0;

	virtual void LeaveScene() = 0;

	// 获取个人信息
	virtual std::string& EntityInfo() = 0;

	virtual void   UpdateEntityInfo(std::string& info) = 0;

	virtual void SetScene(std::shared_ptr<IScene> scene) = 0;

	virtual std::shared_ptr<IScene> GetScene() = 0;

	virtual int GetSceneID() = 0;

	virtual void SetViewRadius(uint32_t radius) = 0;

	virtual uint32_t GetViewRadius() = 0;

	virtual ENTITYID EntityID() = 0;

	virtual void SetEntityID(ENTITYID eid) = 0;

	virtual Point3D&  GetPosition() = 0;

	virtual float GetDirection() = 0;

	virtual void SetDirection(float dire) = 0;

	virtual int EntityType() = 0;

	virtual void SetSpeed(float speed) = 0;

	virtual void SetPositionTime(uint64_t t) = 0;

	virtual uint64_t GetPositionTime() = 0;

	virtual float GetSpeed() = 0;

	virtual void SetStatus(int s) = 0;

	virtual int  GetStatus() = 0;

	// 丢弃视野中的多个对象
	virtual void OnEntityLeaveMe(ProxyIDSet& leaveProxySet) = 0;

	// 视野中增加多个对象
	virtual void OnEntityEnter(ProxyIDSet& addProxySet) = 0;

	virtual void  BroadcastMessageToCareMe(MESSAGEID messageID, IMessage* message) = 0;

	ENTITYT_SEND_MESSAGE_HANDLER  m_sendMessageHandler;

};

#endif