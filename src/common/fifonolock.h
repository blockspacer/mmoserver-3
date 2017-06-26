
/**
@defgroup fifonolock funcs
@{

@details 单生产者消费者无锁循环fifo数组缓冲区

@section _ 使用说明

*/

#ifndef __FIFO_NO_LOCK_H__
#define __FIFO_NO_LOCK_H__

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

class CFifoNoLock
{
public:
	CFifoNoLock();
	~CFifoNoLock();

	/*!
	@brief 初始化函数
	@param[in]  dwBufSize      缓冲区长度
	@return 正确初始化返回0，错误<0
	*/
	int32_t Initialize(uint32_t dwBufSize);

	/*!
	@brief 将数据放入缓冲区，仅在空间足以放下所有数据的时候才会放入
	@param[in]  pDataBuf        数据缓冲区
	@param[in]  dwDataSize      数据长度
	@return 空间够返回0，空间不够返回-1，数据不放入
	*/
	int32_t PutData(char *pDataBuf, uint32_t dwDataSize);
	/*!
	@brief 判断缓冲区是否为空
	@return 为空返回true，不为空返回false
	*/
	bool    IsEmpty();

	/*!
	@brief 取出指定长度数据，仅在数据长度满足传入参数Size才会取出，返回数据拷贝pDataBuf中，进否则返回错误
	@param[in,out]  pDataBuf    数据传出指针
	@param[in]  dwDataSize      取出数据长度
	@return 队列中数据>= dwDataSize，返回0，否则<0
	*/
	int32_t GetData(char *pOutBuf, uint32_t dwDataSize);

	/*!
	@brief 查看队列中还有多少数据
	@return 队列中数据Size
	*/
	uint32_t GetDataSize();

	/*!
	@brief 获取空余容量
	@return 空余容量
	*/
	uint32_t GetBufRemainSize();

	/*!
	@brief 取出指定长度数据，仅在数据长度满足传入参数Size才会取出，返回数据拷贝pDataBuf中,否则返回错误
	@param[in,out] pDataBuf     数据首地址
	@param[in]  dwDataSize      取出数据长度
	@return 队列中数据>= dwDataSize，返回0，否则<0
	*/
	int32_t PeekData(const char *pOutBuf, uint32_t dwDataSize);

	/*!
	@brief 从队首指定长度数据
	@param[in]  dwDataSize       删除数据长度
	@return 无错返回0，否则<0
	*/
	int32_t DelData(uint32_t dwDataSize);

	/*!
	@brief 在缓存中查找指定染色int的offset
	@param[in]  nDye       染色数据
	@return 找到返回距离队首的offset，否则<0
	*/
	int32_t FindDyeOffset(int32_t nDye);

	/*!
	@brief 清空队列
	@return 无返回值
	*/
	void Clear();

	/*!
	@brief 清除此缓冲区一切信息
	@return 无错返回0，否则<0
	*/
	int32_t Release();
private:
	char*       m_pBuf;
	uint32_t    m_dwSize;
	uint32_t    m_dwIn;
	uint32_t    m_dwOut;

};

#endif

