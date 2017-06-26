#include "common.h"
#include "GateServer.h"
#include <thread>

IGateServer* g_pGateServer = nullptr;

#ifdef _LINUX
static void SigHandleKill(int32_t signal)
{
	if (signal == SIGTERM || signal == SIGINT)
	{
		if (g_pGateServer)
		{
			g_pGateServer->SetServerState(SERVER_STATE_STOP);
		}
	}
}

static void SigHandleUser1(int32_t signal)
{
	// reloadscript
	_info("SigHandleUser1 Trigger");
	LuaModule::Instance()->Reload();
}

static void SigHandleUser2(int32_t signal)
{
	_info("SigHandleUser2 Trigger");
	g_pGateServer->GetGameClientModule()->BroadcastDataToAllGame(g_pGateServer->GetServerID(), game::GAMESERVICE_TEST_CONNECTION, nullptr, 0);
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
	int32_t         opt;
	bool  isDaemon = false;

	std::string     configPath;
	std::string     serverName;

	while (-1 != (opt = ::getopt(argc, argv, "dhvc:n:")))
	{
		switch (opt)
		{
		case 'd':
			isDaemon = true;
			break;
		case 'c':
			configPath = optarg;
			break;

		case 'n':
			serverName = optarg;
			break;

		case 'h':
			//PrintHelp();
			return  0;

		case 'v':
			printf("gateway:\n");
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
	if (isDaemon)
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

	int serverType = 0;
	if (serverName.find("fight") == 0)
	{
		serverType = SERVER_TYPE_FIGHT;
	}
	else if (serverName.find("gate") == 0)
	{
		serverType = SERVER_TYPE_GATE;
	}
	else
	{
		assert(!"Wrong serverType");
		return 1;
	}

	GateServer* gateServer = new GateServer(serverName, serverType);
	if (!gateServer)
	{
		_xerror("Failed new GateServer");
		assert(false);
		return -1;
	}
	// 为全局变量赋值
	g_pGateServer = gateServer;

	if (!gateServer->Init(configPath))
	{
		assert(!"Failed Init GateServer");
	}

	_info("Gateway Server %s Init Success", serverName.c_str());

	while (g_pGateServer->IsWorking())   
	{
		try
		{
			gateServer->Run();
		}
		catch (const std::exception& e)
		{
			_xerror("Exception Happen %s", e.what());
			assert(false);
			continue;
		}
		catch (...)
		{
			_xerror("Unknown Exception Happen");
			assert(false);
			continue;
		}
	}
	_fatal("Gateway Server %s Stop", serverName.c_str());
	return 0;
}
