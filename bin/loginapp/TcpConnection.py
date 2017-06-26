# -*- coding: utf-8 -*-
import asyncore
import socket

from mobilelog.LogManager import LogManager
from StringIO import StringIO


class TcpConnection(asyncore.dispatcher):
    """
    TcpConnection， 对应一条建立好的连接，可能来自TcpServer的accept，也可能来自TcpClient的connect
    依赖于channel_interface_obj 来处理断开连接和数据读入
    依赖于channel_interface_obj必须有on_disconnected和input_data方法
    """
    DEFAULT_RECV_BUFFER = 4096
    ST_INIT = 0
    ST_ESTABLISHED = 1
    ST_DISCONNECTED = 2

    def __init__(self, sock, peername):
        # the connection has been established
        self.status = TcpConnection.ST_INIT
        self.w_buffer = StringIO()

        if sock:
            self.status = TcpConnection.ST_ESTABLISHED

        asyncore.dispatcher.__init__(self, sock)
        self.logger = LogManager.get_logger("mobilerpc.TcpConnection")
        self.recv_buffer_size = TcpConnection.DEFAULT_RECV_BUFFER
        self.channel_interface_obj = None
        self.peername = peername

        self.encrypter = None
        self.decrypter = None
        self.compressor = None

        if sock:
            self.setsockopt()

    def setsockopt(self):
        """设置socket参数"""
        # self.logger.info('__init__  connection  %s to %s',  self.socket.getsockname())
        self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_KEEPALIVE, 1)
        self.socket.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        # pylint: disable=E1101
        if hasattr(socket, 'TCP_KEEPCNT') and hasattr(socket, 'TCP_KEEPIDLE') and hasattr(socket, 'TCP_KEEPINTVL'):
            self.logger.debug('__init__ set TCP_KEEPCNT')
            self.socket.setsockopt(socket.SOL_TCP, socket.TCP_KEEPCNT, 3)
            self.logger.debug('__init__ set TCP_KEEPIDLE')
            self.socket.setsockopt(socket.SOL_TCP, socket.TCP_KEEPIDLE, 60)
            self.logger.debug('__init__ set TCP_KEEPINTVL')
            self.socket.setsockopt(socket.SOL_TCP, socket.TCP_KEEPINTVL, 60)

    def get_channel_interface_obj(self):
        return self.channel_interface_obj

    def set_channel_interface_obj(self, channel_obj):
        """设置channel_obj,用来接收收到的数据，实际上就是RpcChannel"""
        self.logger.debug(" set_channel_interface_obj ")
        self.channel_interface_obj = channel_obj

    def set_compressor(self, compressor):
        self.compressor = compressor

    def set_crypter(self, encrypter, decrypter):
        self.encrypter = encrypter
        self.decrypter = decrypter

    def established(self):
        """连接是否已经建立"""
        return self.status == TcpConnection.ST_ESTABLISHED

    def set_rcv_buffer(self, size):
        """设置接收缓存大小"""
        self.recv_buffer_size = size

    def disconnect(self, flush=True):
        """断开连接"""
        if self.status == TcpConnection.ST_DISCONNECTED:
            return
        # Disconnect之后，可能还会有函数用到w_buffer，导致出异常。先把这句注释掉
        # self.w_buffer = None
        if self.channel_interface_obj:
            self.channel_interface_obj.on_disconnected()
        self.channel_interface_obj = None
        if self.socket:
            if self.writable() and flush:
                self.handle_write()
            asyncore.dispatcher.close(self)
        self.status = TcpConnection.ST_DISCONNECTED
        self.logger.info(" disconnect with %s", self.getpeername())

    def getpeername(self):
        """	返回对端的(ip, port)	"""
        return self.peername

    def handle_close(self):
        """连接断开的时候回调"""
        asyncore.dispatcher.handle_close(self)
        self.disconnect(False)

    def handle_expt(self):
        """连接异常的时候回调"""
        asyncore.dispatcher.handle_expt(self)
        self.disconnect(False)

    def handle_error(self):
        """连接出错的时候回调"""
        asyncore.dispatcher.handle_error(self)
        self.disconnect(False)

    def handle_read(self):
        """读数据"""
        data = self.recv(self.recv_buffer_size)
        if data:
            if self.channel_interface_obj == None:
                return

            if self.decrypter:
                data = self.decrypter.decrypt(data)
            if self.compressor:
                data = self.compressor.decompress(data)

            #TODO 进行分包处理，进行逻辑处理
            rc = self.channel_interface_obj.input_data(data)

            if rc == 2:
                return
            elif rc == 3:
                self.logger.error("buf length error")
            elif rc == 0:
                # error, then close
                self.disconnect(False)
                return
            else:
                self.logger.warn("handle_read return %d, should not happen, close socket with %s", rc,
                                 self.getpeername())
                # should not happen
                self.disconnect(False)
                return

    # TODO 将来可以优化，减少字符串拼接
    def handle_write(self):
        """数据可写"""
        buff = self.w_buffer.getvalue()
        if buff:
            sent = self.send(buff)
            self.w_buffer = StringIO(buff[sent:])
            self.w_buffer.seek(0, 2)

    # TODO 将来可以优化，减少字符串拼接
    def send_data(self, data):
        """发送数据"""
        if self.compressor:
            data = self.compressor.compress(data)
        if self.encrypter:
            data = self.encrypter.encrypt(data)
        self.w_buffer.write(data)

    def writable(self):
        return (self.w_buffer and self.w_buffer.getvalue()) or self.status != TcpConnection.ST_ESTABLISHED
