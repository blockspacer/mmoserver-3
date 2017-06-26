#pragma once

#ifndef __ASSERT_H__
#define __ASSERT_H__

// TODO : 这个头文件的名字和gcc下的同名文件会冲突，要改名

#ifdef _WIN32

#ifdef _DEBUG

	#define Assert(s) neox::DoAssert(s, __FILE__, __LINE__)

	namespace neox
	{
		void DoAssert(bool success, char *file_name, int line);
	}

#else

	#define Assert(s)

#endif	// _DEBUG

#else

#include <cassert>
#ifdef Assert
	#undef Assert
#endif
#define Assert(s) assert(s)

#endif //_WIN32

#endif	// __ASSERT_H__
