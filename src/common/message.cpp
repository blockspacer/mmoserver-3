#include "message.h"

uint16_t GetPackServerMessageHeadLength()
{
	return SERVER_MESSAGE_HEAD_LENGTH + NET_HEAD_LENGTH;
}


