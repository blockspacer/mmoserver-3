#include "common.h"
#include <thread>
#include "gamemanager.h"

GameManager* g_GameManager = nullptr;

#ifdef _LINUX
static void SigHandleKill(int32_t signal)
{
	_info("Kill Signal");
	if (signal == SIGTERM || signal == SIGINT)
	{
		if (g_GameManager)
		{
			g_GameManager->SetServerState(SERVER_STATE_STOP);
		}
	}
}

static void SigHandleUser1(int32_t signal)
{}

static void SigHandleUser2(int32_t signal)
{

}
#endif // _LINUX

void InitDaemon()
{
#ifdef _LINUX
	daemon(1, 0);
#endif // _LINUX
}

int main(int argc, char* argv[])
{
	int32_t         iOpt;
	bool  bDaemon = false;

	std::string     strConfigPath;
	std::string     strServerName;

	while (-1 != (iOpt = ::getopt(argc, argv, "dhvc:n:")))
	{
		switch (iOpt)
		{
		case 'd':
			bDaemon = true;
			break;
		case 'c':
			strConfigPath = optarg;
			break;

		case 'n':
			strServerName = optarg;
			break;

		case 'h':
			//PrintHelp();
			return  0;

		case 'v':
			printf("gamemanager:\n");
#ifdef _DEBUG
			printf("Version Debug: Last Compile Time:%s %s\n", __DATE__, __TIME__);
#else
			printf("Version Release: Last Compile Time:%s %s\n", __DATE__, __TIME__);
#endif
			return  0;

		default:
			break;
		}
	}

	if (bDaemon)
	{
		InitDaemon();
	}

#ifdef _LINUX
	signal(SIGHUP, SIG_IGN); //终端挂起或者控制进程终止
	signal(SIGQUIT, SIG_IGN);//键盘的退出键被按下(Ctrl-4，默认产生coredump)
	signal(SIGTTOU, SIG_IGN);//后台进程企图从控制终端读
	signal(SIGTTIN, SIG_IGN);//后台进程企图从控制终端写
	signal(SIGPIPE, SIG_IGN);//对一个对端已经关闭的socket调用两次write, 第二次将会生成SIGPIPE信号, 该信号默认结束进程.
	signal(SIGCHLD, SIG_IGN);//子进程结束时, 父进程会收到这个信号.
	signal(SIGALRM, SIG_IGN);

	signal(SIGINT, SigHandleKill); //键盘中断（通常是Ctrl-C） 
	signal(SIGTERM, SigHandleKill);//kill缺省产生这个信号
	signal(SIGUSR1, SigHandleUser1);
	signal(SIGUSR2, SigHandleUser2);
#endif


	g_GameManager = new GameManager(strServerName);
	if (!g_GameManager) {
		assert(!"Failed new gamemanager");
		return -1;
	}

	SetLogListen(g_GameManager->GetLogModule());

	if (!g_GameManager->Init(strConfigPath))
	{
		assert(!"Failed Init GameServer");
		return -1;
	}

	//char a[200] = { 99,	114,	101,	97,	116,	101,	95,	97,
	//	  111,	105,	95,	112,	114,	111,	120,	121,
	//	  44,	101,	110,	116,	105,	116,	121,	105,
	//	  100,	58,	53,	56,	102,	97,	50,	53,
	//	  54,	101,	56,	53,	48,	99,	99,	52,
	//	  55,	57,	55,	55,	98,	100,	50,	49,
	//	  49,	101,	44,	101,	110,	116,	105,	116,
	//	  121,	116,	121,	112,	101,	58,	49,	50,
	//	  56,	44,	101,	110,	116,	105,	116,	121,
	//	  105,	110,	102,	111, 138, 167,	105,	115,
	//	  95,	116,	101,	97,	109, 194, 171,	101,
	//	  110,	116,	105,	116,	121,	95,	116,	121,
	//	  112,	101, 204, 128,	167,	105,	116,	101,
	//		109,	95,	105,	100,	205,	3,	244,	171,
	//	  99,	114,	101,	97,	116,	101,	95,	116,
	//	  105,	109,	101,	206,	88,	250,	37,	110,
	//	  165,	99,	111,	117,	110,	116,	205,	1,
	//	  244,	168,	99,	114,	101,	97,	116,	101,
	//	  95,	121,	205,	9,	229,	168,	99,	114,
	//	  101,	97,	116,	101,	95,	122,	205,	27,
	//	  109,	169,	101,	110,	116,	105,	116,	121,
	//	  95,	105,	100,	184,	53,	56,	102,	97,
	//	  50,	53,	54,	101,	56,	53,	48,	99,
	//	  99,	52,	55,	57,	55,	55,	98,	100,
	//	  50,	49,	49,	101,	168,	111,	119,	0
	//};


	//_debug(a);

	while (g_GameManager->IsWorking())   
	{
		try {
			g_GameManager->Run();
		}
		catch (std::exception& e)
		{
			_xerror("Exception : %s", e.what());
			continue;
		}
		catch (...) {
			_xerror("Unknown Exception");
			continue;
		}
	}
	_fatal("GameManager will close");
	return 0;
}