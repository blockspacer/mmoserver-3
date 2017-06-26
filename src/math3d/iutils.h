#pragma once

#ifndef __IUTILS_H__
#define __IUTILS_H__


namespace neox
{

namespace client
{
struct IInterfaceMgr;
}

namespace utils
{

struct ITimer;
struct IXmlDoc;

struct IUtils
{
	virtual ITimer* CreateTimer() = 0;
	virtual ITimer* CreateTimer2() = 0;
	virtual ITimer* CreateTimer3() = 0;
	virtual IXmlDoc* CreateXmlDocumentEx() = 0;
	virtual IXmlDoc* CreateTinyXmlDocument() = 0;
	virtual bool CPUCanDoSSE() = 0;
	virtual bool CPUCanDoSSE2() = 0;
	virtual const char* GetCPUVendorName() = 0;
	virtual const char* GetCPUModelName() = 0;
};

// ��̬��Ľӿ�
bool Init(client::IInterfaceMgr *mgr);

// Ϊ�ⲿ����ʹ�ñ�ģ���ṩ�Ľӿڣ������ڲ���Ҫ����
IUtils* GetInterfaceUtils();

}  // namespace utils
}  // namespace neox


#endif
