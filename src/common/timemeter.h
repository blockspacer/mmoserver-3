/********************************************************************
created:	2012/03/13 10:06
filename: 	TimeMeter.h
author:		lcj
purpose:	����ִ��ʱ��Ĺ�����
*********************************************************************/
#ifndef _TIMEMETER_H_INCLUDED_
#define _TIMEMETER_H_INCLUDED_

#include <string>
#include <sstream>
#include "common.h"

#define MSG_MARK __FUNCTION__,__LINE__

struct TimeMeter
{
	// ʱ��������ء���ʱ���Ʊ���
	static bool   openTimeMeterFlag;
	static uint32_t timeoutLimits;

	// ��console��gdcmd���õ����ú���
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

	// ��¼ʱ���ʱ���
	uint64_t slot[TimeMeter_MaxSlot];
	const char *slotName[TimeMeter_MaxSlot];

	// ��¼ʱ����α�
	uint32_t  cursor;

	// Ĭ��ִ��ʱ�䳬��40ms�Ķ���¼����
	TimeMeter(uint32_t limit = 40);

	~TimeMeter();

	// ��ȡ��ǰʱ���ʱ�������
	bool Stamp(const char* name = NULL);

	// ��ⳬʱ����ӡ��Ϣ
	void Check(const char* file, int line, const char* param1 = NULL, const char* param2 = NULL) const;

	// �����ʱ��
	void Clear();

	// ��ȡ��ʼ����ֹ��ʱ���
	uint64_t TimeDiff() const;

	// ��ӡ��Ϣ
	std::string Dump() const;

};


#endif // _TIMEMETER_H_INCLUDED_

