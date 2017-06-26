#include "timemeter.h"
#include "common.h"

bool   TimeMeter::openTimeMeterFlag = true;
uint32_t TimeMeter::timeoutLimits = 40;

//////////////////////////////////////////////////////////////////////////

bool TimeMeter::IsOpenTimeMeter()
{
	return openTimeMeterFlag;
}

std::string TimeMeter::SwitchTimeMeter(bool f)
{
	openTimeMeterFlag = f;

	if (openTimeMeterFlag)
	{
		_info("[%s:%d]Close TimeMeter", MSG_MARK);
		return "Open TimeMeter";
	}
	else
	{
		_info("[%s:%d]Close TimeMeter", MSG_MARK);
		return "Close TimeMeter";
	}
}

std::string TimeMeter::SetTimeLimits(uint32_t limit)
{
	timeoutLimits = limit;

	std::stringstream sstr;
	sstr << "Set Time Limits to " << timeoutLimits;
	return sstr.str();
}

std::string TimeMeter::GetTimeLimits()
{
	std::stringstream sstr;
	sstr << "TimeMeterFlag=" << (openTimeMeterFlag ? "True" : "False") << ","
		<< "TimeLimits=" << timeoutLimits;
	return sstr.str();
}

TimeMeter::TimeMeter(uint32_t limit)
{
	//TODO  设置了一个全局最小值40ms
	//localTimeLimits = (limit < timeoutLimits) ? limit : timeoutLimits;
	localTimeLimits = limit;
	memset(slot, 0, sizeof(slot));
	cursor = 0;
}

TimeMeter::~TimeMeter()
{
	cursor = 0;
}

bool TimeMeter::Stamp(const char* name)
{
	if (openTimeMeterFlag && (cursor <= TimeMeter_MaxSlot - 1))
	{
		uint64_t dwCurTime = GetNowTimeMille();
		slotName[cursor] = name;
		slot[cursor++] = dwCurTime;

		return (dwCurTime - slot[0]) >= localTimeLimits;
	}
	else
	{
		return false;
	}
}

void TimeMeter::Check(const char* file, int line, const char* param1, const char* param2) const
{
	if (TimeDiff() >= localTimeLimits)
	{
		if (NULL != param1 && NULL != param2)
		{
			_xerror("[%s:%d][TimeOut][%s:%s][%s]", file, line, param1, param2, Dump().c_str());
		}
		else if (NULL != param1  && NULL == param2)
		{
			_xerror("[%s:%d][TimeOut][%s][%s]", file, line, param1, Dump().c_str());
		}
		else if (NULL == param1 && NULL == param2)
		{
			_xerror("[%s:%d][TimeOut][%s]", file, line, Dump().c_str());
		}
	}
}

uint64_t TimeMeter::TimeDiff() const
{
	if (openTimeMeterFlag && cursor > 0)
	{
		return (slot[cursor - 1] - slot[0]);
	}

	return 0;
}

void TimeMeter::Clear()
{
	memset(slot, 0, sizeof(slot));
	cursor = 0;
}

std::string TimeMeter::Dump() const
{
	if (!openTimeMeterFlag)
	{
		return "";
	}

	std::stringstream sstr;

	sstr << "-";

	for (uint32_t j = 0; j < cursor - 1; ++j)
	{
		sstr << "[";
		if (const char *szName = slotName[j + 1])
		{
			sstr << szName << ":";
		}
		sstr << (slot[j + 1] - slot[j]) << "]-";
	}

	return sstr.str();
}


