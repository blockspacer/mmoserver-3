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

// 静态库的接口
bool Init(client::IInterfaceMgr *mgr);

// 为外部程序使用本模块提供的接口，引擎内不需要调用
IUtils* GetInterfaceUtils();

}  // namespace utils
}  // namespace neox


#endif
