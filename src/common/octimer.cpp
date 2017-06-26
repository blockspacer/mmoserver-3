
#include "octimer.h"

void COCTimer::SetTimer(uint32_t nTimerID, uint32_t nTime, uint32_t dwInterval)
{
	STimer stTimer;

	stTimer.qwTime = m_cocNow + nTime;
	stTimer.dwInterval = dwInterval;
	m_mapTimer[nTimerID] = stTimer;

	_AddEvent(nTimerID, stTimer.qwTime);
}

void COCTimer::KillTimer(uint32_t nTimerID)
{
	m_mapTimer.erase(nTimerID);
}

uint64_t COCTimer::GetLatestTimerTime()
{
	if (!m_qTimer.empty())
	{
		return m_qTimer.top().qwTime;
	}
	return 0;
}

// TODO 现在定时器的问题在于阻塞之后会重复调用，也就是会保证调用的次数
// 比如300毫秒调用一次，然后中间出现阻塞了，阻塞了3000ms，那么触发的时候会有10个回调
// 这样感觉也不是很有必要，相当于一下子执行10个回调，不均匀的话不如知道中间的间隔就好了，如果也只是在某个点执行10次
void COCTimer::OnCheckTimer(uint64_t nMilliSeconds)
{
	std::vector<uint32_t> vecRaised;

	m_cocNow = nMilliSeconds;

	while (!m_qTimer.empty())
	{
		if (m_qTimer.top().qwTime > m_cocNow)
			break;

		const TimerInfo ti = m_qTimer.top();
		m_qTimer.pop();

		MapTimerIt it = m_mapTimer.find(ti.nTimerID);
		if (it != m_mapTimer.end() && it->second.qwTime == ti.qwTime)
		{
			vecRaised.push_back(ti.nTimerID);
			if (it->second.dwInterval == 0)
			{
				m_mapTimer.erase(it);
			}
			else
			{
				it->second.qwTime = it->second.dwInterval + ti.qwTime;
				_AddEvent(ti.nTimerID, it->second.qwTime);
			}
		}
	}

	for (size_t i = 0; i < vecRaised.size(); ++i)
	{
		OnTimer(vecRaised[i]);
	}
}