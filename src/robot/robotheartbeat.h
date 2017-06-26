#ifndef _ROBOTHEARTBEAT_H_
#define _ROBOTHEARTBEAT_H_

#include <stdint.h>

class RobotHeartbeat
{
public:
	RobotHeartbeat();
	~RobotHeartbeat();
public:
	void Reset();
	void SetRobotId(int nRobotId);
	void StartSyncTime();
	void StopSyncTime();
	uint64_t GetServerTime();
	void Tick(int param);
	void SendPingMessage();
	void OnPingBack(const uint64_t nServerTime,const uint64_t nClientTime);
	void SendPingBackMessage(const uint64_t nServerTime);

private:
	int m_nRobotId;
	int32_t m_nTimerId;
	uint64_t m_nDeltaTime;
	uint64_t m_nMinDelay;
};
#endif
