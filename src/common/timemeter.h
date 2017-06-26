/********************************************************************
created:	2012/03/13 10:06
filename: 	TimeMeter.h
author:		lcj
purpose:	测量执行时间的工具类
*********************************************************************/
#ifndef _TIMEMETER_H_INCLUDED_
#define _TIMEMETER_H_INCLUDED_

#include <string>
#include <sstream>
#include "common.h"

#define MSG_MARK __FUNCTION__,__LINE__

struct TimeMeter
{
	// 时间测量开关、超时限制变量
	static bool   openTimeMeterFlag;
	static uint32_t timeoutLimits;

	// 用console或gdcmd调用的设置函数
	static bool        IsOpenTimeMeter();
	static std::string SwitchTimeMeter(bool f);
	static std::string SetTimeLimits(uint32_t limit);
	static std::string GetTimeLimits();

	//////////////////////////////////////////////////////////////////////////

	enum
	{
		TimeMeter_MaxSlot = 12,
	};

	uint32_t localTimeLimits;

	// 记录时间的时间槽
	uint64_t slot[TimeMeter_MaxSlot];
	const char *slotName[TimeMeter_MaxSlot];

	// 记录时间的游标
	uint32_t  cursor;

	// 默认执行时间超过40ms的都记录下来
	TimeMeter(uint32_t limit = 40);

	~TimeMeter();

	// 获取当前时间的时间戳函数
	bool Stamp(const char* name = NULL);

	// 检测超时并打印信息
	void Check(const char* file, int line, const char* param1 = NULL, const char* param2 = NULL) const;

	// 清理计时槽
	void Clear();

	// 获取起始和终止的时间差
	uint64_t TimeDiff() const;

	// 打印信息
	std::string Dump() const;

};


#endif // _TIMEMETER_H_INCLUDED_

