#include "dbtemplatethreadpool.h"

void DBThreadPool::BornThread()
{
	for (int i = 0; i < 10; ++i)
	{
		//TODO ����thread����������
	}
}

void DBThreadPool::Tick()
{
	//++mod;
	//int index = mod % 5;
	for (int i = 0; i < m_threadPool.size(); ++i)
	{
		ThreadInfo * threadInfo = m_threadPool[i];
		CFifoNoLock& outBuffer = threadInfo->m_oThreadOutputBuf;

		while (outBuffer.IsEmpty() == false)
		{
			uint16_t messageLength = 0;
			outBuffer.PeekData((const char*)&messageLength, sizeof(messageLength));
			char buffer[8012];
			outBuffer.GetData(buffer, messageLength);

			//��Ҫһ���µİ�ͷ����ͨ��
			//TODO sendToServer
		}
	}
}

void DBThreadPool::PushRequest(char* message, int messageLength)
{
	int index = 1;
	ThreadInfo* threadInfo = m_threadPool[index];

	threadInfo->m_oThreadInputBuf.PutData(message, messageLength);
}
