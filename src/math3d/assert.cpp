#if defined(_DEBUG) && defined(_WIN32)

#include <windows.h>
#include <cstdio>
#define MAX_STRING_LEN 512

#pragma warning(disable: 4800)

namespace neox
{

void DoAssert(bool success, char *file_name, int line)
{
	//if (success)
	//{
	//	return;
	//}
	//static char assert_str[MAX_STRING_LEN];
	//static char module_path[MAX_PATH];
	//::GetModuleFileName(NULL, module_path, MAX_PATH);
	//sprintf(assert_str, "Debug Assertion Failed! \n\nModule: %s \nFile: %s \nLine: %d \n\nTerminate or not? Press Cancel to enter debugger.\n", 
	//	module_path, file_name, line);
	//int result = ::MessageBox(NULL, assert_str, "NeoX 3D Engine", MB_ICONSTOP | MB_YESNOCANCEL);
	//if (result == IDYES)
	//{
	//	::ExitProcess(3);
	//}
	//else if (result == IDCANCEL)
	//{
	//	__asm int 3;
	//}
}

} // namespace neox

#endif // _DEBUG
