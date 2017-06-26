#include "Timer.h"



CTimerMgr::CTimerMgr()
	: m_nTimerID(0), m_now(0), m_lastTickTime(0), m_createCount(0), m_deleteCount(0)
{
}

uint64_t CTimerMgr::GetLatestTimerTime()
{
	if (m_timerManager.empty())
	{
		return 0;
	}
	return (m_timerManager.top())->operatorTime;
}

bool CTimerMgr::Tick()
{
	uint64_t nowtime = GetNowTimeMille();	
	if (m_lastTickTime + 3600000 < nowtime)
	{
		ShowDebugInfo();
		m_lastTickTime = nowtime;
	}
	while (!m_timerManager.empty())
	{
		std::shared_ptr<TimerInfo> timer = m_timerManager.top();
		auto it = m_timerToDel.find(timer->timerID);
		if (it != m_timerToDel.end())
		{
			m_timerManager.pop();
			m_timerToDel.erase(it);
			continue;
		}

		if (timer->operatorTime <= nowtime)
		{
			m_timerManager.pop();
			timer->callback(timer->timerID);
			if (timer->loop > 0)
			{
				//timer->operatorTime +=  timer->loop;
				timer->operatorTime = GetNowTimeMille() + timer->loop;
				m_timerManager.push(timer);
			}
		}
		else
		{
			break;
		}
	}
	m_now = nowtime;
	return true;
}

void CTimerMgr::ShowDebugInfo()
{
	_info("Timer total count %d And ToDelCount %d", m_timerManager.size(), m_timerToDel.size());
	_info("Timer add count %d and del count %d", m_createCount, m_deleteCount);
}

int32_t CTimerMgr::AllocTimerID()
{
	return ++m_nTimerID;
}