//#pragma once
//#include "common.h"
//
//#ifdef _LINUX
//#include <event2/bufferevent_ssl.h>
//#include <event2/buffer.h>
//#include <event2/listener.h>
//#include <event2/util.h>
//#include <event2/http.h>
//
//#include <openssl/ssl.h>
//#include <openssl/err.h>
//#include <openssl/rand.h>
//
//#endif
//
//#include "event2/bufferevent.h"
//#include "event2/event.h"
//#include "event2/util.h"
//#include "event2/buffer.h"
//#include <event2/http.h>  
//#include <event2/http_struct.h>  
//#include <event2/keyvalq_struct.h>
//#include <vector>
//#include <functional>
//#include <memory>
//#include <list>
//#include <vector>
//#include <assert.h>
//
//
////http 相关的宏定义
////////////////////////////////////////////////////////////////////////////
//#define REQUEST_POST_FLAG               2  
//#define REQUEST_GET_FLAG                3  
//#define HTTP_CONTENT_TYPE_URL_ENCODED   "application/x-www-form-urlencoded"
//
//uint32_t HttpNetwork(void * data);
//
//struct http_request
//{
//	struct  evhttp_uri *uri;
//	struct  event_base *base;
//	struct  evhttp_connection *cn;
//	struct  evhttp_request *req;
//	char*   content_type;
//	char*   post_data;
//	char    httpType;
//	uint16_t    operationType;
//	long long llPlayerID;
//};
//
//class HttpManager
//{
//public:
//	HttpManager();
//	~HttpManager();
//	void    Init(const char* http_addr, short http_port);
//	//默认为HTTP发送方式为get，如果要post需要填写postdata参数
//	void    http_requset(uint16_t operationType, long long llPlayerID, const char *url, const char* postdata = nullptr, int reqFlag = REQUEST_GET_FLAG);
//private:
//	void    http_request_free(struct http_request *http_req);
//	int     start_url_request(struct http_request *http_req);
//	void*   http_request_new(const char* url, const char* Parameters, int reqFlag);
//	static void http_requset_cb(struct evhttp_request *req, void *arg);
//	static void generic_handler(struct evhttp_request *req, void *arg);
//private:
//	struct event_base*  m_base;
//	struct evhttp *     m_httpServer;
//};
//
//
/////////////////////////////////////////////////////////////////////////////////////////
//
//typedef std::function<void(struct evhttp_request *req, const std::string& command, const std::string& url)> HTTPNET_RECEIVE_FUNCTOR;
//typedef std::shared_ptr<HTTPNET_RECEIVE_FUNCTOR> HTTPNET_RECEIVE_FUNCTOR_PTR;
//
//class NFCHttpNet
//{
//public:
//	template<typename BaseType>
//	NFCHttpNet(BaseType* baseType, void (BaseType::*handleRecieve)(struct evhttp_request *req, const std::string& command, const std::string& url))
//	{
//		base = NULL;
//		mRecvCB = std::bind(handleRecieve, baseType, std::placeholders::_1, std::placeholders::_2, std::placeholders::_3);
//		mPort = 0;
//	}
//	NFCHttpNet()
//	{
//
//	}
//	virtual ~NFCHttpNet() {};
//
//	virtual bool Tick();
//public:
//	virtual int InitServer(const unsigned short port);
//	static void listener_cb(struct evhttp_request *req, void *arg);
//	virtual bool SendMsg(struct evhttp_request *req, const char* strMsg);
//	virtual bool SendFile(evhttp_request * req, const int fd, struct stat st, const std::string& strType);
//	virtual bool Final();
//	static std::vector<std::string> Split(const std::string& str, std::string delim);
//	void http_requset_get(const char *url);
//	void https_request_get(const char *url);
//	void https_request_post();
//	void http_request_get_cb(struct evhttp_request *, void *);
//private:
//	int mPort;
//	struct event_base* base;
//
//	HTTPNET_RECEIVE_FUNCTOR mRecvCB;
//
//};