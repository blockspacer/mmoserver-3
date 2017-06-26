//#include "http.h"
//#include <iostream>
//
////uint32_t HttpNetwork(void * data)
////{
////	struct event_base* base = (struct event_base*)data;
////	while (NetEngine::Instance()->IsRun())
////	{
////		JySleep(10);
////		event_base_loop(base, EVLOOP_NONBLOCK);
////	}
////	return 0;
////}
////
////HttpManager::HttpManager()
////{
////
////}
////
////HttpManager::~HttpManager()
////{
////	event_base_free(m_base);
////	evhttp_free(m_httpServer);
////}
////
////void HttpManager::Init(const char* http_addr, short http_port)
////{
////	m_base = event_base_new();
////	if (http_addr)
////	{
////		m_httpServer = evhttp_new(m_base);
////
////		int ret = evhttp_bind_socket(m_httpServer, http_addr, http_port);
////		if (ret != 0)
////		{
////			return;
////		}
////		evhttp_set_gencb(m_httpServer, generic_handler, NULL);
////	}
////	JyCreateThread(&tid, 0, HttpNetwork, m_base);
////}
////
////void HttpManager::http_request_free(struct http_request *http_req)
////{
////	evhttp_connection_free(http_req->cn);
////	evhttp_uri_free(http_req->uri);
////	SAFE_DELETE(http_req);
////}
////
////int HttpManager::start_url_request(struct http_request *http_req)
////{
////	if (http_req == NULL)
////	{
////		return -1;
////	}
////
////	if (http_req->cn)
////		evhttp_connection_free(http_req->cn);
////
////	int port = evhttp_uri_get_port(http_req->uri);
////	http_req->cn = evhttp_connection_base_new(http_req->base, NULL, evhttp_uri_get_host(http_req->uri), (port == -1 ? 80 : port));
////
////	/**
////	* Request will be released by evhttp connection
////	* See info of evhttp_make_request()
////	*/
////	http_req->req = evhttp_request_new(http_requset_cb, http_req);
////
////	if (http_req->httpType == REQUEST_POST_FLAG)
////	{
////		const char *path = evhttp_uri_get_path(http_req->uri);
////		evhttp_make_request(http_req->cn, http_req->req, EVHTTP_REQ_POST, path ? path : "/");
////		/** Set the post data */
////		evbuffer_add(http_req->req->output_buffer, http_req->post_data, strlen(http_req->post_data));
////		evhttp_add_header(http_req->req->output_headers, "Content-Type", http_req->content_type);
////	}
////	else if (http_req->httpType == REQUEST_GET_FLAG)
////	{
////		const char *query = evhttp_uri_get_query(http_req->uri);
////		const char *path = evhttp_uri_get_path(http_req->uri);
////		size_t len = (query ? strlen(query) : 0) + (path ? strlen(path) : 0) + 1;
////		char *path_query = NULL;
////		if (len > 1)
////		{
////			path_query = (char*)calloc(len, sizeof(char));
////			sprintf(path_query, "%s?%s", path, query);
////		}
////		evhttp_make_request(http_req->cn, http_req->req, EVHTTP_REQ_GET, path_query ? path_query : "/");
////	}
////	/** Set the header properties */
////	evhttp_add_header(http_req->req->output_headers, "Host", evhttp_uri_get_host(http_req->uri));
////
////	return 0;
////}
////
////void HttpManager::http_requset_cb(struct evhttp_request *req, void *arg)
////{
////	struct http_request *http_req = (struct http_request *)arg;
////	if (req->response_code == HTTP_OK)
////	{
////		struct evbuffer* buf = evhttp_request_get_input_buffer(req);
////		size_t len = evbuffer_get_length(buf);
////		char *tmp = (char*)malloc(len + 1);
////		memcpy(tmp, evbuffer_pullup(buf, -1), len);
////		tmp[len] = '\0';
////		NetEngine::Instance()->GetSessionManager()->OnDispacthHttp(http_req->llPlayerID, http_req->operationType, tmp);
////		free(tmp);
////	}
////	else
////	{
////		LOG_ERROR("%s error code:%d", __FUNCTION__, req->response_code);
////	}
////	evhttp_connection_free(http_req->cn);
////	evhttp_uri_free(http_req->uri);
////	SAFE_DELETE(http_req);
////}
////
////
////void* HttpManager::http_request_new(const char* url, const char* Parameters, int reqFlag)
////{
////	http_request *http_req = new http_request();
////	http_req->uri = evhttp_uri_parse(url);
////	if (NULL == http_req->uri)
////	{
////		GenExp("d");
////		return NULL;
////	}
////	http_req->base = m_base;
////	http_req->content_type = strdup(HTTP_CONTENT_TYPE_URL_ENCODED);
////	http_req->httpType = reqFlag;
////	if (Parameters)
////	{
////		http_req->post_data = strdup(Parameters);
////	}
////	return http_req;
////}
////
////void HttpManager::http_requset(uint16 operationType, long long llPlayerID, const char *url, const char* postdata, int reqFlag)
////{
////	struct http_request* http_req = (struct http_request*)http_request_new(url, postdata, reqFlag);
////	http_req->llPlayerID = llPlayerID;
////	http_req->operationType = operationType;
////	start_url_request(http_req);
////}
////
////void HttpManager::generic_handler(struct evhttp_request *req, void *arg)
////{
////	NetEngine::Instance()->GetSessionManager()->OnDispacthHttpRcv(req);
////}
//
//
/////////////////////////////////////////////////////////////////////////////////
//
//bool NFCHttpNet::Tick()
//{
//	if (base)
//	{
//		event_base_loop(base, EVLOOP_ONCE | EVLOOP_NONBLOCK);
//	}
//
//	return true;
//}
//
//
//int NFCHttpNet::InitServer(const unsigned short port)
//{
//	mPort = port;
//	//struct event_base *base;
//	struct evhttp *http;
//	struct evhttp_bound_socket *handle;
//
//#ifdef _WIN32
//	WSADATA WSAData;
//	WSAStartup(0x101, &WSAData);
//#else
//	if (signal(SIGPIPE, SIG_IGN) == SIG_ERR)
//		return (1);
//#endif
//
//	base = event_base_new();
//	if (!base)
//	{
//		std::cout << "create event_base fail" << std::endl;;
//		return 1;
//	}
//
//	http = evhttp_new(base);
//	if (!http) {
//		std::cout << "create evhttp fail" << std::endl;;
//		return 1;
//	}
//
//	evhttp_set_gencb(http, listener_cb, (void*)this);
//	handle = evhttp_bind_socket_with_handle(http, "0.0.0.0", mPort);
//	if (!handle) {
//		std::cout << "bind port :" << mPort << " fail" << std::endl;;
//		return 1;
//	}
//	return 0;
//}
//
//
//void NFCHttpNet::listener_cb(struct evhttp_request *req, void *arg)
//{
//	NFCHttpNet* pNet = (NFCHttpNet*)arg;
//
//	//uri
//	const char *uri = evhttp_request_get_uri(req);
//	//std::cout << "Got a GET request:" << uri << std::endl;
//
//	//get decodeUri
//	struct evhttp_uri *decoded = evhttp_uri_parse(uri);
//	if (!decoded) {
//		printf("It's not a good URI. Sending BADREQUEST\n");
//		evhttp_send_error(req, HTTP_BADREQUEST, 0);
//		return;
//	}
//	const char *decode1 = evhttp_uri_get_path(decoded);
//	if (!decode1) decode1 = "/";
//
//	//The returned string must be freed by the caller.
//	const char* decodeUri = evhttp_uridecode(decode1, 0, NULL);
//
//	if (decodeUri == NULL)
//	{
//		printf("uri decode error\n");
//		evhttp_send_error(req, HTTP_BADREQUEST, "uri decode error");
//		return;
//	}
//	std::string strUri;
//	if (decodeUri[0] == '/')
//	{
//		strUri = decodeUri;
//		strUri.erase(0, 1);
//		decodeUri = strUri.c_str();
//	}
//	//get strCommand
//	auto cmdList = Split(strUri, "/");
//	std::string strCommand = "";
//	if (cmdList.size() > 0)
//	{
//		strCommand = cmdList[0];
//	}
//
//	// call cb
//	if (pNet->mRecvCB)
//	{
//		pNet->mRecvCB(req, strCommand, decodeUri);
//	}
//	else
//	{
//		pNet->SendMsg(req, "mRecvCB empty");
//	}
//
//
//
//	//close
//	/*{
//	if (decoded)
//	evhttp_uri_free(decoded);
//	if (decodeUri)
//	free(decodeUri);
//	if (eventBuffer)
//	evbuffer_free(eventBuffer);
//	}*/
//}
//bool NFCHttpNet::SendMsg(struct evhttp_request *req, const char* strMsg)
//{
//	//create buffer
//	struct evbuffer *eventBuffer = evbuffer_new();
//	//send data
//	evbuffer_add_printf(eventBuffer, strMsg);
//	evhttp_add_header(evhttp_request_get_output_headers(req), "Content-Type", "text/html");
//	evhttp_send_reply(req, 200, "OK", eventBuffer);
//
//	//free
//	evbuffer_free(eventBuffer);
//	return true;
//}
//
//bool NFCHttpNet::SendFile(evhttp_request * req, const int fd, struct stat st, const std::string& strType)
//{
//	//create buffer
//	struct evbuffer *eventBuffer = evbuffer_new();
//	//send data
//	evbuffer_add_file(eventBuffer, fd, 0, st.st_size);
//	evhttp_add_header(evhttp_request_get_output_headers(req), "Content-Type", strType.c_str());
//	evhttp_send_reply(req, 200, "OK", eventBuffer);
//
//	//free
//	evbuffer_free(eventBuffer);
//	return true;
//}
//
//
//bool NFCHttpNet::Final()
//{
//	if (base)
//	{
//		event_base_free(base);
//		base = NULL;
//	}
//	return true;
//}
//
//std::vector<std::string> NFCHttpNet::Split(const std::string& str, std::string delim)
//{
//	std::vector<std::string> result;
//	if (str.empty() || delim.empty())
//	{
//		return result;
//	}
//
//	std::string tmp;
//	size_t pos_begin = str.find_first_not_of(delim);
//	size_t pos = 0;
//	while (pos_begin != std::string::npos)
//	{
//		pos = str.find(delim, pos_begin);
//		if (pos != std::string::npos)
//		{
//			tmp = str.substr(pos_begin, pos - pos_begin);
//			pos_begin = pos + delim.length();
//		}
//		else
//		{
//			tmp = str.substr(pos_begin);
//			pos_begin = pos;
//		}
//
//		if (!tmp.empty())
//		{
//			result.push_back(tmp);
//			tmp.clear();
//		}
//	}
//	return result;
//}
//
//void NFCHttpNet::http_requset_get(const char * url)
//{
//	auto uri = evhttp_uri_parse(url);
//	auto req = evhttp_request_new(nullptr, nullptr);
//	const char *query = evhttp_uri_get_query(uri);
//	const char *path = evhttp_uri_get_path(uri);
//	size_t len = (query ? strlen(query) : 0) + (path ? strlen(path) : 0) + 1;
//	char *path_query = NULL;
//	if (len > 1)
//	{
//		path_query = (char*)calloc(len, sizeof(char));
//		sprintf(path_query, "%s?%s", path, query);
//	}
//	int port = evhttp_uri_get_port(uri);
//	/**
//	* A connection object that can be used to for making HTTP requests.  The
//	* connection object tries to resolve address and establish the connection
//	* when it is given an http request object.
//	*
//	* @param base the event_base to use for handling the connection
//	* @param dnsbase the dns_base to use for resolving host names; if not
//	*     specified host name resolution will block.
//	* @param address the address to which to connect
//	* @param port the port to connect to
//	* @return an evhttp_connection object that can be used for making requests
//	*/
//	auto cn = evhttp_connection_base_new(base, NULL, evhttp_uri_get_host(uri), (port == -1 ? 80 : port));
//
//	/**
//	Make an HTTP request over the specified connection.
//
//	The connection gets ownership of the request.  On failure, the
//	request object is no longer valid as it has been freed.
//
//	@param evcon the evhttp_connection object over which to send the request
//	@param req the previously created and configured request object
//	@param type the request type EVHTTP_REQ_GET, EVHTTP_REQ_POST, etc.
//	@param uri the URI associated with the request
//	@return 0 on success, -1 on failure
//	@see evhttp_cancel_request()
//	*/
//	evhttp_make_request(cn, req, EVHTTP_REQ_GET, path_query ? path_query : "/");
//}
//
////static void
////http_request_done(struct evhttp_request *req, void *ctx)
////{
////	char buffer[256];
////	int nread;
////
////	if (req == NULL) {
////		/* If req is NULL, it means an error occurred, but
////		* sadly we are mostly left guessing what the error
////		* might have been.  We'll do our best... */
////		struct bufferevent *bev = (struct bufferevent *) ctx;
////		unsigned long oslerr;
////		int printed_err = 0;
////		int errcode = EVUTIL_SOCKET_ERROR();
////		fprintf(stderr, "some request failed - no idea which one though!\n");
////		/* Print out the OpenSSL error queue that libevent
////		* squirreled away for us, if any. */
////		while ((oslerr = bufferevent_get_openssl_error(bev))) {
////			ERR_error_string_n(oslerr, buffer, sizeof(buffer));
////			fprintf(stderr, "%s\n", buffer);
////			printed_err = 1;
////		}
////		/* If the OpenSSL error queue was empty, maybe it was a
////		* socket error; let's try printing that. */
////		if (!printed_err)
////			fprintf(stderr, "socket error = %s (%d)\n",
////				evutil_socket_error_to_string(errcode),
////				errcode);
////		return;
////	}
////
////	fprintf(stderr, "Response line: %d %s\n",
////		evhttp_request_get_response_code(req),
////		evhttp_request_get_response_code_line(req));
////
////	while ((nread = evbuffer_remove(evhttp_request_get_input_buffer(req),
////		buffer, sizeof(buffer)))
////			   > 0) {
////		/* These are just arbitrary chunks of 256 bytes.
////		* They are not lines, so we can't treat them as such. */
////		fwrite(buffer, nread, 1, stdout);
////	}
////}
////
////
////void NFCHttpNet::https_request_get(const char *url)
////{
////	int r;
////
////	const char *scheme, *host, *path, *query;
////	char uri[256];
////	int port;
////	int retries = 0;
////	int timeout = -1;
////
////	SSL *ssl = NULL;
////	struct bufferevent *bev;
////	
////	struct evhttp_request *req;
////	struct evkeyvalq *output_headers;
////	struct evbuffer *output_buffer;
////
////	int i;
////	int ret = 0;
////	enum { HTTP, HTTPS } type = HTTP;
////
////	struct evhttp_uri *http_uri = evhttp_uri_parse(url);
////	if (http_uri == NULL) {
////		_xerror("malformed url");
////		return;
////	}
////
////	scheme = evhttp_uri_get_scheme(http_uri);
////	if (scheme == NULL || (strcasecmp(scheme, "https") != 0 &&
////		strcasecmp(scheme, "http") != 0)) {
////		_xerror("url must be http or https");
////		return;
////	}
////
////	host = evhttp_uri_get_host(http_uri);
////	if (host == NULL) {
////		_xerror("url must have a host");
////		return;
////	}
////
////	port = evhttp_uri_get_port(http_uri);
////	if (port == -1) {
////		port = (strcasecmp(scheme, "http") == 0) ? 80 : 443;
////	}
////
////	path = evhttp_uri_get_path(http_uri);
////	if (strlen(path) == 0) {
////		path = "/";
////	}
////
////	query = evhttp_uri_get_query(http_uri);
////	if (query == NULL) {
////		snprintf(uri, sizeof(uri) - 1, "%s", path);
////	}
////	else {
////		snprintf(uri, sizeof(uri) - 1, "%s?%s", path, query);
////	}
////	uri[sizeof(uri) - 1] = '\0';
////
////#if OPENSSL_VERSION_NUMBER < 0x10100000L
////	// Initialize OpenSSL
////	SSL_library_init();
////	ERR_load_crypto_strings();
////	SSL_load_error_strings();
////	OpenSSL_add_all_algorithms();
////#endif
////
////	/* Create a new OpenSSL context */
////	SSL_CTX *ssl_ctx = SSL_CTX_new(SSLv23_method());
////	if (!ssl_ctx) {
////		_xerror("SSL_CTX_new");
////		return;
////	}
////
////	// Create OpenSSL bufferevent and stack evhttp on top of it
////	ssl = SSL_new(ssl_ctx);
////	if (ssl == NULL) {
////		_xerror("SSL_new()");
////		return;
////	}
////
////#ifdef SSL_CTRL_SET_TLSEXT_HOSTNAME
////	// Set hostname for SNI extension
////	SSL_set_tlsext_host_name(ssl, host);
////#endif
////
////	if (strcasecmp(scheme, "http") == 0) {
////		bev = bufferevent_socket_new(base, -1, BEV_OPT_CLOSE_ON_FREE);
////	}
////	else {
////		type = HTTPS;
////		bev = bufferevent_openssl_socket_new(base, -1, ssl,
////			BUFFEREVENT_SSL_CONNECTING,
////			BEV_OPT_CLOSE_ON_FREE | BEV_OPT_DEFER_CALLBACKS);
////	}
////
////	if (bev == NULL) {
////		_xerror("bufferevent_openssl_socket_new() failed");
////		return;
////	}
////
////	bufferevent_openssl_set_allow_dirty_shutdown(bev, 1);
////
////	// For simplicity, we let DNS resolution block. Everything else should be
////	// asynchronous though.
////	struct evhttp_connection *evcon = evhttp_connection_base_bufferevent_new(base, NULL, bev, host, port);
////	if (evcon == NULL) {
////		_xerror("evhttp_connection_base_bufferevent_new() failed\n");
////		return;
////	}
////
////	if (retries > 0) {
////		evhttp_connection_set_retries(evcon, retries);
////	}
////	if (timeout >= 0) {
////		evhttp_connection_set_timeout(evcon, timeout);
////	}
////
////	// Fire off the request
////	req = evhttp_request_new(http_request_done, bev);
////	if (req == NULL) {
////		fprintf(stderr, "evhttp_request_new() failed\n");
////		goto error;
////	}
////
////	output_headers = evhttp_request_get_output_headers(req);
////	evhttp_add_header(output_headers, "Host", host);
////	evhttp_add_header(output_headers, "Connection", "close");
////
////	r = evhttp_make_request(evcon, req, data_file ? EVHTTP_REQ_POST : EVHTTP_REQ_GET, uri);
////	if (r != 0) {
////		fprintf(stderr, "evhttp_make_request() failed\n");
////		goto error;
////	}
////}
