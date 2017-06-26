
/**
@defgroup fifonolock funcs
@{

@details ������������������ѭ��fifo���黺����

@section _ ʹ��˵��

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
	@brief ��ʼ������
	@param[in]  dwBufSize      ����������
	@return ��ȷ��ʼ������0������<0
	*/
	int32_t Initialize(uint32_t dwBufSize);

	/*!
	@brief �����ݷ��뻺���������ڿռ����Է����������ݵ�ʱ��Ż����
	@param[in]  pDataBuf        ���ݻ�����
	@param[in]  dwDataSize      ���ݳ���
	@return �ռ乻����0���ռ䲻������-1�����ݲ�����
	*/
	int32_t PutData(char *pDataBuf, uint32_t dwDataSize);
	/*!
	@brief �жϻ������Ƿ�Ϊ��
	@return Ϊ�շ���true����Ϊ�շ���false
	*/
	bool    IsEmpty();

	/*!
	@brief ȡ��ָ���������ݣ��������ݳ������㴫�����Size�Ż�ȡ�����������ݿ���pDataBuf�У������򷵻ش���
	@param[in,out]  pDataBuf    ���ݴ���ָ��
	@param[in]  dwDataSize      ȡ�����ݳ���
	@return ����������>= dwDataSize������0������<0
	*/
	int32_t GetData(char *pOutBuf, uint32_t dwDataSize);

	/*!
	@brief �鿴�����л��ж�������
	@return ����������Size
	*/
	uint32_t GetDataSize();

	/*!
	@brief ��ȡ��������
	@return ��������
	*/
	uint32_t GetBufRemainSize();

	/*!
	@brief ȡ��ָ���������ݣ��������ݳ������㴫�����Size�Ż�ȡ�����������ݿ���pDataBuf��,���򷵻ش���
	@param[in,out] pDataBuf     �����׵�ַ
	@param[in]  dwDataSize      ȡ�����ݳ���
	@return ����������>= dwDataSize������0������<0
	*/
	int32_t PeekData(const char *pOutBuf, uint32_t dwDataSize);

	/*!
	@brief �Ӷ���ָ����������
	@param[in]  dwDataSize       ɾ�����ݳ���
	@return �޴���0������<0
	*/
	int32_t DelData(uint32_t dwDataSize);

	/*!
	@brief �ڻ����в���ָ��Ⱦɫint��offset
	@param[in]  nDye       Ⱦɫ����
	@return �ҵ����ؾ�����׵�offset������<0
	*/
	int32_t FindDyeOffset(int32_t nDye);

	/*!
	@brief ��ն���
	@return �޷���ֵ
	*/
	void Clear();

	/*!
	@brief ����˻�����һ����Ϣ
	@return �޴���0������<0
	*/
	int32_t Release();
private:
	char*       m_pBuf;
	uint32_t    m_dwSize;
	uint32_t    m_dwIn;
	uint32_t    m_dwOut;

};

#endif

