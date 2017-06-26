
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

// TODO ���ڶ�ʱ����������������֮����ظ����ã�Ҳ���ǻᱣ֤���õĴ���
// ����300�������һ�Σ�Ȼ���м���������ˣ�������3000ms����ô������ʱ�����10���ص�
// �����о�Ҳ���Ǻ��б�Ҫ���൱��һ����ִ��10���ص��������ȵĻ�����֪���м�ļ���ͺ��ˣ����Ҳֻ����ĳ����ִ��10��
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