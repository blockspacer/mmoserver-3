#ifndef __UTIL_H__
#define __UTIL_H__
#include <string>


void toHexLower(const void* inRaw, int len, char* out) {

	static const char hexchars[] = "0123456789abcdef";

	//StringBuilder out;
	//std::stringstream out;
	int index = 0;
	const char* in = reinterpret_cast<const char*>(inRaw);
	for (int i = 0; i < len; ++i) {
		char c = in[i];
		char hi = hexchars[(c & 0xF0) >> 4];
		char lo = hexchars[(c & 0x0F)];

		out[index] = hi;
		index++;
		out[index] = lo;
		index++;
		//out	<< hi << lo;
	}
	
	//return out.str();
}
#endif




