#pragma once
#include "fifonolock.h"

struct ThreadInfo
{
	int32_t              m_nThreadIndex;
	unsigned long int    m_llThreadID;
	CFifoNoLock          m_oThreadInputBuf;
	CFifoNoLock          m_oThreadOutputBuf;
};