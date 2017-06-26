#pragma once

#include "dbtemplatethread.h"
#include <vector>

class DBThreadPool
{
public:
	DBThreadPool() {}
	virtual ~DBThreadPool() {}

	void BornThread();

	// 回收结果数据并进行发送
	// TODO可以通过callback来确定
	void Tick();

	void PushRequest(char* message, int messageLength);

private:
	std::vector<ThreadInfo*>   m_threadPool;
};

