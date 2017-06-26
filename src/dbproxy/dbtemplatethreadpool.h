#pragma once

#include "dbtemplatethread.h"
#include <vector>

class DBThreadPool
{
public:
	DBThreadPool() {}
	virtual ~DBThreadPool() {}

	void BornThread();

	// ���ս�����ݲ����з���
	// TODO����ͨ��callback��ȷ��
	void Tick();

	void PushRequest(char* message, int messageLength);

private:
	std::vector<ThreadInfo*>   m_threadPool;
};

