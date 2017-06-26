#include "dbtemplatethread.h"
#include <thread>

void DBTemplateThread::OnThreadExit()
{

}

void DBTemplateThread::Run()
{
	m_mongo.Init();

	while (true)
	{
		Tick();
	}

	OnThreadExit();
	return;
}

void DBTemplateThread::Tick()
{
	CFifoNoLock &inBuffer = m_threadInfo->m_oThreadInputBuf;
	if (inBuffer.IsEmpty())
	{
		std::this_thread::sleep_for(std::chrono::milliseconds(10));
		return;
	}
	uint16_t messageLength = 0;
	inBuffer.PeekData((const char*)&messageLength, sizeof(messageLength));

	inBuffer.GetData(m_tmpSendBuffer, messageLength);

	ProcessInput();
}

bool DBTemplateThread::CreateIOBuf()
{
	if (m_threadInfo->m_oThreadOutputBuf.Initialize(8192) != 0)
	{
		assert(!"Failed Initialize out buffer");
		return false;
	}

	if (m_threadInfo->m_oThreadInputBuf.Initialize(8192) != 0)
	{
		assert(!"Failed Initialize input buffer");
		return false;
	}

	return true;
}

void DBTemplateThread::ProcessInput()
{
}

void DBTemplateThread::SendBackToMainThread(const SERVERID dstServerID, const uint16_t messageID, IMessage * message)
{
	//if (NULL == message)
	//{
	//	return;
	//}

	//uint32_t headLength = GetPackInnerMessageHeadLength();
	//if (!message->SerializeToArray(m_tmpSendBuffer + headLength, sizeof(m_tmpSendBuffer) - headLength))
	//{
	//	_xerror("DBServerModule::SerializeToArray failed messageID is %d reason is %s��%s", messageID, message->Utf8DebugString());
	//	return;
	//}

	////TODO ������ͷ
	////PackInnerMessageHead(dstServerID, messageID, message->ByteSize());

	//m_threadInfo->m_oThreadOutputBuf.PutData(m_tmpSendBuffer, headLength + message->ByteSize());
}
