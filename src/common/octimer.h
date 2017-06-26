#ifndef  __OCTIMER_H__
#define  __OCTIMER_H__

#include <map>
#include <queue>
#include "common.h"

class COCTimer
{
	typedef struct tagTimer
	{
		uint64_t       qwTime;
		uint32_t      dwInterval; // in milliseconds, 0: one time timer event
	}STimer;

	//COCTimer():m_cocNow(GetNowTimeMille())
	//{}

	typedef std::map<uint32_t, STimer>          MapTimer;
	typedef MapTimer::iterator          MapTimerIt;
	MapTimer    m_mapTimer;
	uint64_t  m_cocNow;

	struct TimerInfo
	{
		uint64_t qwTime;
		uint32_t  nTimerID;
		bool operator < (const TimerInfo &o) const
		{
			return qwTime > o.qwTime;
		}
	};
	std::priority_queue<TimerInfo> m_qTimer;

public:
	void SetTimer(uint32_t nTimerID, uint32_t nTime, uint32_t dwInterval = 0);
	void KillTimer(uint32_t nTimerID);
	void OnCheckTimer(uint64_t nMilliSeconds);
	inline void KillAllTimer() { m_mapTimer.clear(); }

	void SetNowTimeMill(uint64_t milliSeconds)
	{
		m_cocNow = milliSeconds;
	}

	uint64_t GetLatestTimerTime();

protected:
	virtual void OnTimer(int32_t nTimerID) = 0;
private:
	void _AddEvent(uint32_t  nTimerID, uint64_t qwTime)
	{
		TimerInfo ti;
		ti.nTimerID = nTimerID;
		ti.qwTime = qwTime;
		m_qTimer.push(ti);
	}
};

#endif  // __OCTIMER_H__

