#pragma once

#include "MongoModule.h"
#include "threaddefine.h"

class DBTemplateThread
{
public:
	DBTemplateThread() {}
	virtual ~DBTemplateThread() {}

	void OnThreadExit();

	void Run();

	void Tick();

	bool CreateIOBuf();

	void ProcessInput();

	//�ȴ�����m_tmpSendBuffer����memcpy��m_threadInfo
	void SendBackToMainThread(const SERVERID dstServerID, const uint16_t messageID, IMessage * message);

private:
	ThreadInfo   *m_threadInfo;

	char         m_tmpSendBuffer[8092];

	MongoModule  m_mongo;
};