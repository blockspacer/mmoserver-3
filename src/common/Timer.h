#ifndef __BasicServerFramework_Timer_H_
#define __BasicServerFramework_Timer_H_

#include <unordered_map>
#include <functional>
#include <memory>
#include "common.h"
#include <queue>
#include "Singleton.h"



typedef std::function<void(const int timerid)> TIMER_CALLBACK_FUNCTOR;
typedef std::shared_ptr<TIMER_CALLBACK_FUNCTOR> TIMER_CALLBACK__FUNCTOR_PTR;



class CTimerMgr : public Singleton<CTimerMgr>
{
public:
	CTimerMgr();

	/// nTime, dwInterval in millsecond. dwInterval: 0 -> no repeat,
	template<typename BaseType>
	uint32_t CreateTimer(uint16_t wUserTimerID, BaseType *pBase, void(BaseType::*handleRecieve)(const int), uint32_t nTime, uint32_t dwInterval = 0)
	{
		TIMER_CALLBACK_FUNCTOR functor = std::bind(handleRecieve, pBase, std::placeholders::_1);
		//TIMER_CALLBACK__FUNCTOR_PTR functorPtr(new TIMER_CALLBACK_FUNCTOR(functor));

		uint32_t nTimerID = AllocTimerID();
		std::shared_ptr<TimerInfo> ti = std::make_shared<TimerInfo>();
		ti->timerID = nTimerID;
		ti->callback = functor;
		ti->loop = dwInterval;
		ti->operatorTime = GetNowTimeMille() + nTime;
		m_timerManager.push(ti);
		
		m_createCount++;
		return nTimerID;
	}

	void DestroyTimer(uint32_t nTimerID)
	{
		m_timerToDel.insert(nTimerID);
		m_deleteCount++;
	}

	uint64_t GetLatestTimerTime();

	bool Tick();

	void ShowDebugInfo();

private:
	int32_t AllocTimerID();

	uint32_t m_nTimerID;

	uint64_t m_now; // in ms
	uint64_t m_lastTickTime;
	int m_createCount;
	int m_deleteCount;

	struct TimerInfo
	{
		uint64_t operatorTime;
		uint32_t  timerID;
		uint32_t loop;
		TIMER_CALLBACK_FUNCTOR callback;
	};

	struct TimerInfoOp
	{
		bool operator()(std::shared_ptr<TimerInfo> p1, std::shared_ptr<TimerInfo> p2)
		{
			return p1->operatorTime > p2->operatorTime;
		}
	};
	std::priority_queue<std::shared_ptr<TimerInfo>, std::vector<std::shared_ptr<TimerInfo>>, TimerInfoOp> m_timerManager;
	std::set<uint32_t> m_timerToDel;
};

#endif//__BasicServerFramework_Timer_H_
