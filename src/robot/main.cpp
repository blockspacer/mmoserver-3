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
	signal(SIGHUP, SIG_IGN); //�ն˹�����߿��ƽ�����ֹ
	signal(SIGQUIT, SIG_IGN);//���̵��˳���������(Ctrl-4��Ĭ�ϲ���coredump)
	signal(SIGTTOU, SIG_IGN);//��̨������ͼ�ӿ����ն˶�
	signal(SIGTTIN, SIG_IGN);//��̨������ͼ�ӿ����ն�д
	signal(SIGPIPE, SIG_IGN);//��һ���Զ��Ѿ��رյ�socket��������write, �ڶ��ν�������SIGPIPE�ź�, ���ź�Ĭ�Ͻ�������.
	signal(SIGCHLD, SIG_IGN);//�ӽ��̽���ʱ, �����̻��յ�����ź�.
	signal(SIGALRM, SIG_IGN);

	signal(SIGINT, SigHandleKill); //�����жϣ�ͨ����Ctrl-C�� 
	signal(SIGTERM, SigHandleKill);//killȱʡ��������ź�
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