#include <stdint.h>
#include <time.h>
#include <string>
#include <iostream>
#include <chrono>

#if defined(_WIN32) || defined(_WIN64)
#include <windows.h>
#include <sys/timeb.h>
#include "Singleton.h"
#else
#include <sys/time.h>
#include <utime.h>
#include <stddef.h>
#include <string.h>
#endif

#include "common.h"

#ifdef _MSC_VER
class CurrentTimeProvider : public Singleton<CurrentTimeProvider>
{
public:
	CurrentTimeProvider() : highResolutionAvailable(false), countPerMilliSecond(0), beginCount(0)
	{
		static LARGE_INTEGER systemFrequency;
		if (0 != QueryPerformanceFrequency(&systemFrequency))
		{
			highResolutionAvailable = true;
			countPerMilliSecond = systemFrequency.QuadPart / 1000;
			_timeb tb;
			_ftime_s(&tb);
			unsigned short currentMilli = tb.millitm;
			LARGE_INTEGER now;
			QueryPerformanceCounter(&now);
			beginCount = now.QuadPart - (currentMilli * countPerMilliSecond);
		}
	};
	int64_t getCurrentTime()
	{
		int64_t millisecond = 0;
		if (highResolutionAvailable)
		{
			LARGE_INTEGER qfc;
			QueryPerformanceCounter(&qfc);
			millisecond = (int)((qfc.QuadPart - beginCount) / countPerMilliSecond) % 1000;
		}
		time_t tt;
		::time(&tt);
		// TODO 计算的毫秒可能出现1s的误差，就是millisecond已经过了1000了，但是tt中还是上一秒的时间戳
		return tt * 1000 + millisecond;
	}

private:
	bool highResolutionAvailable;
	int64_t countPerMilliSecond;
	int64_t beginCount;
};

#endif

int gTimeOffset = 0;

//获取当前毫秒时间
uint64_t GetNowTimeMille()
{
//#ifdef _MSC_VER
//	//return CurrentTimeProvider::GetSingletonPtr()->getCurrentTime();
	return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count() + gTimeOffset*1000;
//#else
//	struct timeval start;
//	gettimeofday(&start, NULL);
//	uint64_t nSec = start.tv_sec;
//	uint64_t nUSec = start.tv_usec;
//	return nSec * 1000 + nUSec / 1000;
//#endif
}

uint64_t GetNowTimeSecond()
{
	time_t tt;
	::time(&tt);
	return tt + gTimeOffset;
}

void SetTimeOffset(int o)
{
	gTimeOffset = o;
}


