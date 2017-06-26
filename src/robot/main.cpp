#include "common.h"
#include "robotmanager.h"

RobotManager* g_pRobotManager = nullptr;

#ifdef _LINUX
static void SigHandleKill(int32_t signal)
{
	//if (signal == SIGTERM || signal == SIGINT)
	//{
	//	if (g_pRobotManager)
	//	{
	//		g_pRobotManager->SetServerState(SERVER_STATE_STOP);
	//	}
	//}
}

static void SigHandleUser1(int32_t signal)
{
	//// reloadscript
	//_info("SigHandleUser1 Trigger");
	//LuaModule::Instance()->Reload();
}

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
			printf("RobotManager:\n");
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

	g_pRobotManager = new RobotManager(strServerName);
	if (!g_pRobotManager)
	{
		_xerror("Failed new RobotManager");
		assert(false);
		return -1;
	}

	if (!g_pRobotManager->Init(strConfigPath))
	{
		assert(!"Failed Init GateServer");
	}

	_info("RobotManager Init Success");

	bool bExitApp = false;
	while (!bExitApp)    
	{
		try
		{
			g_pRobotManager->Run();
		}
		catch (const std::exception& e)
		{
			_xerror("Exception Happen %s", e.what());
			continue;
		}
		catch (...)
		{
			_xerror("Unknown Exception Happen");
			continue;
		}
	}
	_fatal("RobotManager Stop");
	return 0;
}