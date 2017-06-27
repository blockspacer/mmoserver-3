#include "IGameServer.h"
#include <thread>
#include <memory>
#include "math3d/vectors.h"
#include "GameServer.h"
#include "LuaModule.h"

IGameServer* g_pGameServer;


#ifdef _LINUX
static void SigHandleKill(int32_t signal)
{
	if (signal == SIGTERM || signal == SIGINT)
	{
		if (g_pGameServer)
		{
			_info("Kill Signal and SetServerState SERVER_STATE_STOP");
			g_pGameServer->SetServerState(SERVER_STATE_STOP);
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

}
#endif // _LINUX

void InitDaemon()
{
#ifdef _LINUX
	daemon(1, 0);
#endif // _LINUX
}

class A
{
public:
	A():ff(0) { std::cout << "A create" << std::endl; }
	~A() { std::cout << "A Destory" << std::endl; }
	int ff;
};

std::vector<std::shared_ptr<A>> g_a;

std::shared_ptr<A> test()
{
	g_a.resize(100);
	auto aa = g_a[40];
	if (aa)
	{
		std::cout << aa.use_count() << std::endl;
	}
	std::cout << aa.use_count() << std::endl;

	auto e = std::make_shared<A>();
	e->ff = 100;
	std::cout << e.use_count() << std::endl;
	g_a[40] = e;
	std::cout << e.use_count() << e->ff << std::endl;
	std::cout << g_a[40].use_count() << std::endl;

	aa = g_a[40];
	if (aa)
	{
		std::cout << aa.use_count() << std::endl;
	}
	std::cout << aa.use_count() << std::endl;

	g_a[40].reset();
	auto bb = g_a[40];
	if (bb)
	{
		std::cout << bb.use_count() << std::endl;
	}
	std::cout << bb.use_count() << std::endl;


	if (aa)
	{
		std::cout << aa.use_count() << aa->ff << std::endl;
	}
	std::cout << aa.use_count() << aa->ff << std::endl;

	return nullptr;
}

void test1(std::shared_ptr<A> &a)
{
	A* s = new A();
	std::shared_ptr<A> dd(s);
	std::cout << dd.use_count() << std::endl;
	std::shared_ptr<A> ddd = dd;
	std::cout << dd.use_count() << std::endl;
	std::cout << ddd.use_count() << std::endl;
	dd = std::make_shared<A>();
	std::cout << dd.use_count() << std::endl;
	std::cout << ddd.use_count() << std::endl;
}

void test2()
{
	std::shared_ptr<std::list<int>> a = nullptr;
	a.reset();
	a.reset();
	a = std::make_shared<std::list<int>>();
	if (a)
	{
		a.reset();
	}
	a.reset();
}

int main(int argc, char* argv[])
{
	int32_t         iOpt;
	bool  bDaemon = false;

	std::string     strConfigPath;
	std::string     strServerName;

	//auto s = test();
	//std::cout << s.use_count() << std::endl;

	//test1(s);
	test2();

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
			printf("game:\n");
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

	GameServer* gameServer = new GameServer(strServerName);
	if (!gameServer ) {
		assert(!"Failed new GameServer");
		return -1;
	}
	g_pGameServer = gameServer;
	
	//void* ppl = new(gameServer) GameServer(strServerName);
	//auto sd = sinf(3.1415926);
	//auto sd1 = sinf(180);
	//auto sd2 = sinf(90);
	//auto sd3 = sinf(3.1415926 / 2);

	SetLogListen(gameServer->GetLogModule());

	if (!gameServer->Init(strConfigPath))
	{
		assert(!"Failed Init GameServer");
		return -1;
	}

	while (gameServer->IsWorking())    
	{
		try 
		{
			gameServer->Run();
		}
		catch(std::exception& e)
		{
			_xerror("Exception : %s", e.what());
			assert(false);
			continue;
		}
		catch (...) {
			_xerror("Unknown Exception");
			assert(false);
			continue;
		}
	}
	_fatal("GameServer Will Close");
	return 0;
}