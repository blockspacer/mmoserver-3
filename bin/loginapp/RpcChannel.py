# -*- coding: utf-8 -*-

import MobileRequest
from struct import pack, unpack
from mobilelog.LogManager import LogManager


class MobileRpcChannel(object):
    """
    Protocol buffer RPC channel，负责序列化和反序列化RPC调用
    内部封装了一个底层的连接（如TcpConnection)
    """

    def __init__(self, logic_service, conn, processlagerbuf='True'):
        super(MobileRpcChannel, self).__init__()
        # 负责把Rpc请求传递给上层
        # Rpc请求异步解析
        self.logic_service = logic_service
        self.rpc_request = MobileRequest.request()
        self.rpc_request_parser = MobileRequest.request_parser()
        # 底层的网络连接,比如TcpConnection
        self.conn = conn
        self.conn.set_channel_interface_obj(self)
        # controller 用来传递channel给上层
        self.con_listeners = set()
        # LogManager
        self.logger = LogManager.get_logger("mobilerpc.MobileRpcChannel")
        self.logger.info('__init__: a new connection')
        # user data
        self.user_data = None
        # self.encrypted = False
        # self.compressed = False
        self.session_seed = None
        self.processlagerbuf = processlagerbuf

    def set_max_data(self, size):
        self.rpc_request_parser.set_max_data(size)

    def reg_listener(self, listener):
        """注册listener，连接断开的时候会回调listner的"""
        self.logger.debug("MobileRpcChannel reg_listener")
        self.con_listeners.add(listener)

    def unreg_listener(self, listener):
        self.con_listeners.remove(listener)

    def getpeername(self):
        """ 	返回对端的一个(ip, port)tuple	"""
        if self.conn:
            return self.conn.getpeername()
        return "No connection attached"

    def set_compressor(self, compressor):
        self.conn.set_compressor(compressor)

    def set_crypter(self, encrypter, decrypter):
        """通过decorator切换"""
        self.conn.set_crypter(encrypter, decrypter)

    def set_user_data(self, user_data):
        """可以让上层保存和这个RpcChannel绑定的一些用户数据，"""
        self.user_data = user_data

    def get_user_data(self):
        """返回用户数据"""
        return self.user_data

    def set_session_seed(self, seed):
        self.session_seed = seed

    def get_session_seed(self):
        return self.session_seed

    def on_disconnected(self):
        """"底层的连接(如TcpConnection)断开的时候回调"""
        self.logger.info("on_disconnected'")
        # notify all the listeners
        for listener in list(self.con_listeners):
            if listener in self.con_listeners:
                listener.on_channel_disconnected(self)
        self.rpc_request.reset()
        self.rpc_request_parser.reset()
        self.con_listeners = None
        self.conn = None
        self.user_data = None

    def disconnect(self):
        """主动断开连接"""
        if self.conn:
            self.conn.disconnect()

    def parse(self, data, skip):
        result, consum = self.rpc_request_parser.parse(self.rpc_request, data, skip)
        assert (consum > 0)

        if result == 1:
            l = len(self.rpc_request.data)
            # 6个字节的包头
            if l < 6:
                self.logger.error("Got error request size: %d", l)
                return 0, consum, None, None

            dd = bytearray(l)
            dd[-1] = ord(self.rpc_request.data[-1]) ^ 0x3A
            for i in range(l - 2, 0, -1):
                dd[i] = ord(self.rpc_request.data[i]) ^ dd[i + 1]
            self.rpc_request.data = str(dd)

            # #dd = self.rpc_request.data
            # self.rpc_request.data[-1] = ord(self.rpc_request.data[-1]) ^ 0x3A
            # for i in range(l - 2, 0, -1):
            #     self.rpc_request.data[i] = ord(self.rpc_request.data[i]) ^ ord(self.rpc_request.data[i + 1])

            serialnumber, servicetype, opcode = unpack("<HHH", self.rpc_request.data[0:6])
            # result, consum, method, request11
            return 1, consum, opcode, self.rpc_request.data[6:]
        elif result == 2:
            return 2, consum, None, None
        elif result == 0:
            return 0, consum, None, None
        elif result == 3:
            return 0, consum, None, None

    def request(self, method, request):
        try:
            self.logic_service.process(self.conn, method, request)
        except:
            pass
            # self.logger.info("_______opcode %d _________ %s",method, request)
            # import json
            # a = json.loads(request)
            # self.logger.info("json string is %s", a["linux"])
            # pass

    def input_data(self, data):
        total = len(data)
        skip = 0
        while skip < total:
            result, consum, method, request11 = self.parse(data, skip)

            skip += consum

            if result == 0:
                return 0
            elif result == 1:
                # true, already got a complete request
                self.request(method, request11)
                self.rpc_request.reset()
                continue
            elif result == 2:
                # need more data
                break
            elif result == 3:
                if self.processlagerbuf == 'True':
                    return 0
                else:
                    return 3
            else:
                continue
        # need more data
        return 2
