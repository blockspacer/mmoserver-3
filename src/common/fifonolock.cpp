
#include    "fifonolock.h"

//#define min(x,y) ({ typeof(x) _x = (x); typeof(y) _y = (y); (void) (&_x == &_y); _x < _y ? _x : _y; })

#define min(x,y) ({ auto _x = (x); auto _y = (y); (void) (&_x == &_y); _x < _y ? _x : _y; })

void min_ex(uint32_t x, uint32_t y)
{
	auto _x = (x); auto _y = (y); (void)(&_x == &_y); _x < _y ? _x : _y;
}

static inline int fls(int x)
{
	int position;
	int i;
	if (0 != x)
	{
		for (i = (x >> 1), position = 0; i != 0; ++position)
			i >>= 1;
	}
	else
	{
		position = -1;
	}
	return position + 1;
}

static inline unsigned int roundup_pow_of_two(unsigned int x)
{
	return 1UL << fls(x - 1);
}

CFifoNoLock::CFifoNoLock()
{
	m_pBuf = NULL;
	m_dwSize = 0;
	m_dwIn = 0;
	m_dwOut = 0;
}

CFifoNoLock::~CFifoNoLock()
{
	Release();
}


int32_t CFifoNoLock::Initialize(uint32_t dwBufSize)
{
	if (dwBufSize > 0x80000000)
	{
		return -1;
	}
	if (dwBufSize == 0)
	{
		return 0;
	}

	m_dwSize = roundup_pow_of_two(dwBufSize);

	m_pBuf = (char *)malloc(m_dwSize);
	if (!m_pBuf)
	{
		return -2;
	}

	m_dwIn = 0;
	m_dwOut = 0;

	return 0;
}

int32_t CFifoNoLock::PutData(char *pDataBuf, uint32_t dwDataSize)
{
	if (!pDataBuf || dwDataSize == 0)
	{
		return -1;
	}
	if (GetBufRemainSize() < dwDataSize)
	{
		return -1;
	}

	//#define min(x,y) ({ auto _x = (x); auto _y = (y); (void) (&_x == &_y); _x < _y ? _x : _y; })
	//uint32_t dwInputLen = min((dwDataSize), (m_dwSize - (m_dwIn & (m_dwSize - 1))));

	auto _x = dwDataSize;
	auto _y = m_dwSize - (m_dwIn & (m_dwSize - 1));
	(void)(&_x == &_y);
	uint32_t dwInputLen = _x < _y ? _x : _y;

	memcpy(m_pBuf + (m_dwIn & (m_dwSize - 1)), pDataBuf, dwInputLen);

	memcpy(m_pBuf, pDataBuf + dwInputLen, dwDataSize - dwInputLen);

	m_dwIn += dwDataSize;

	return 0;
}

bool CFifoNoLock::IsEmpty()
{
	return m_dwIn == m_dwOut;
}

int32_t CFifoNoLock::GetData(char *pOutBuf, uint32_t dwDataSize)
{
	if (GetDataSize() < dwDataSize || !pOutBuf)
	{
		return -1;
	}

	//uint32_t    dwOutputLen = min(dwDataSize, m_dwSize - (m_dwOut & (m_dwSize - 1)));
	auto _x = dwDataSize;
	auto _y = m_dwSize - (m_dwOut & (m_dwSize - 1));
	(void)(&_x == &_y);
	uint32_t dwOutputLen = _x < _y ? _x : _y;
	
	memcpy(pOutBuf, m_pBuf + (m_dwOut & (m_dwSize - 1)), dwOutputLen);
	memcpy(pOutBuf + dwOutputLen, m_pBuf, dwDataSize - dwOutputLen);

	m_dwOut += dwDataSize;
	return 0;
}

uint32_t CFifoNoLock::GetDataSize()
{
	return m_dwIn - m_dwOut;
}

uint32_t CFifoNoLock::GetBufRemainSize()
{
	return m_dwSize - GetDataSize();
}

int32_t CFifoNoLock::PeekData(const char *pOutBuf, uint32_t dwDataSize)
{
	if (!pOutBuf)
	{
		return -1;
	}

	//uint32_t    dwPeekDataLen = min(dwDataSize, GetDataSize());
	auto _x = dwDataSize;
	auto _y = GetDataSize();
	(void)(&_x == &_y);
	uint32_t dwPeekDataLen = _x < _y ? _x : _y;
	//uint32_t    dwOutputLen = min(dwPeekDataLen, m_dwSize - (m_dwOut & (m_dwSize - 1)));
	auto _x1 = dwPeekDataLen;
	auto _y1 = m_dwSize - (m_dwOut & (m_dwSize - 1));
	(void)(&_x1 == &_y1);
	uint32_t dwOutputLen = _x1 < _y1 ? _x1 : _y1;

	memcpy((void*)pOutBuf, m_pBuf + (m_dwOut & (m_dwSize - 1)), dwOutputLen);
	memcpy((void*)(pOutBuf + dwOutputLen), m_pBuf, dwPeekDataLen - dwOutputLen);

	return dwPeekDataLen;
}

int32_t CFifoNoLock::DelData(uint32_t dwDataSize)
{
	m_dwOut += dwDataSize;

	return 0;
}

void CFifoNoLock::Clear()
{
	m_dwOut = m_dwIn;
}

int32_t CFifoNoLock::Release()
{
	if (m_pBuf)
	{
		free(m_pBuf);
	}

	m_pBuf = NULL;
	m_dwSize = 0;
	m_dwIn = 0;
	m_dwOut = 0;

	return 0;
}

int32_t CFifoNoLock::FindDyeOffset(int32_t nDye)
{
	int nDataStartOffset = (m_dwOut & (m_dwSize - 1));
	//int nBufLen = min(GetDataSize(), m_dwSize - nDataStartOffset);
	auto _x = GetDataSize();
	auto _y = m_dwSize - nDataStartOffset;
	(void)(&_x == &_y);
	uint32_t nBufLen = _x < _y ? _x : _y;

	int nCurOffset = nDataStartOffset;

	while ((m_dwSize - nCurOffset) >= sizeof(int32_t))
	{
		// 如果buflen < int32_t，说明内存要翻过，和后续的地方一起处理
		// 此处为buflen > int32_t的处理
		if (*(int*)(m_pBuf + nCurOffset) == nDye)
		{
			// 找到，计算offset
			return nCurOffset - nDataStartOffset;
		}
		// 没找到
		++nCurOffset;
	}

	char szLocalMem[sizeof(uint32_t) * 2] = { 0 };
	// 走到这里，说明上面没找到，需要处理翻过的流程
	// 先拷贝内存尾和头部的数据，尾4头4一共八个字节(最大8字节)
	// 复制队尾元素
	int32_t nTailElemCount = ((m_dwSize - nDataStartOffset) >= sizeof(int32_t)) ? sizeof(int32_t) : (m_dwSize - nDataStartOffset);
	memcpy(szLocalMem, m_pBuf + m_dwSize - nTailElemCount, nTailElemCount);
	// 复制队首元素
	int32_t nHeadRemainElemCount = (m_dwIn & (m_dwSize - 1));
	int32_t nStartElemCount = (nHeadRemainElemCount > (int32_t)sizeof(int32_t)) ? sizeof(int32_t) : nHeadRemainElemCount;
	memcpy(szLocalMem + nTailElemCount, m_pBuf, nStartElemCount);
	int32_t nCopyLen = nTailElemCount + nStartElemCount;
	for (int i = 0; nCopyLen - i >= (int32_t)sizeof(int32_t); ++i)
	{
		if (*(int*)(szLocalMem + i) == nDye)
		{
			// 找到
			return m_dwSize - nDataStartOffset - nTailElemCount + i;
		}
	}
	// 翻过队尾临界处理也没找到，直接从队首开始找
	for (int i = 0; nHeadRemainElemCount - i >= (int32_t)sizeof(int32_t); ++i)
	{
		if (*(int*)(m_pBuf + i) == nDye)
		{
			// 找到
			return nBufLen + i;
		}

	}

	// 没找到
	return -1;
}