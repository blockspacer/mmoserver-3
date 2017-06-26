# -*- coding: utf-8 -*-
import sys
import asyncore
import asyncore_with_timer
import socket
import time
import inspect
import json

from mobilelog.LogManager import LogManager
from TcpConnection import TcpConnection
from RpcChannelManager import RpcChannelCreator, RpcChannelManager
from loginservice import LoginService
from config import config


class TcpServer(asyncore.dispatcher):
    """
    TCPServer，就是负责监听TCP连接，创建连接
    一个TcpServer可以创建多条Tcp连接，创建之后交给上层的con_handler继续管理
    con_handler有一个方法，handleNewConnection 处理新连接
    self.server = TcpServer(gateip, gateport, RpcChannelCreator(gateservice, RpcChannelManager(), gateconfig.get('processlagerbuf', 'True'), 512 * 1024) , True)
    """

    def __init__(self, ip, port, con_handler=None, reuse_addr=False):
        self.ip = ip
        self.port = port
        self.con_handler = con_handler
        asyncore.dispatcher.__init__(self)

        # log
        self.logger = LogManager.get_logger("mobilerpc.TcpServer")
        # begin to listen
        self.create_socket(socket.AF_INET, socket.SOCK_STREAM)
        if reuse_addr:
            self.set_reuse_addr()
        self.started = False
        self.try_bind()
        self.logger.info('__init__: Server Listen on: %s, %d', self.ip, self.port)
        self.listen(50)

    def listen_port(self):
        return (self.ip, self.port)

    def try_bind(self):
        while 1:
            try:
                self.bind((self.ip, self.port))
                break
            except:
                self.logger.info('try_bind: Server failed to bind: %s, %d, try next port', self.ip, self.port)
                self.port += 1
                if self.port > 65535:
                    self.logger.error('try_bind: Server failed to find a usable port to bind: %s, %d', self.ip,
                                      self.port)
                    raise StandardError(' Server failed to find a usable port to bind!')
        self.started = True

    def set_connection_handler(self, con_handler):
        """"设置连接管理器，有新连接的时候注册进去"""
        self.con_handler = con_handler

    def handle_accept(self):
        """"处理连接事件"""
        try:
            sock, addr = self.accept()
        except socket.error:
            self.logger.warn('server accept() threw an exception')
            self.logger.log_last_except()
            return
        except TypeError:
            self.logger.warn('warning: server accept() threw EWOULDBLOCK')
            self.logger.log_last_except()
            return
        self.logger.info('TcpServer.handle_accept with peer :%s', sock.getpeername())
        # creates TcpConnection
        if self.con_handler:
            con = TcpConnection(sock, addr)
            self.con_handler.handle_new_connection(con)
        else:
            self.logger.warn('no connection Manager to handle new connection')

    def handle_error(self):
        self.logger.error("handle_error - uncaptured python exception")
        self.logger.error(str(inspect.stack()))

    def handle_close(self):
        # asyncore.dispatcher.handle_close(self)
        self.logger.info("handle_close - called from: %s", str(inspect.stack()))

    def stop(self):
        """close的alias"""
        self.logger.info("stop")
        self.close()
        self.started = False

    def close(self):
        asyncore.dispatcher.close(self)
        self.logger.info("close - called from: %s", str(inspect.stack()))


def main(config_file, server_name):
    config.from_json(config_file)
    loginconfig = config["login"][server_name]
    host = loginconfig["listen_ip"]
    port = loginconfig["port"]

    service = LoginService()
    service.init()
    TcpServer(host, port, RpcChannelCreator(service, RpcChannelManager(), 'True', 512 * 1024), True)

    while True:
        asyncore_with_timer.loop(1, True, None, 1)
        time.sleep(0.001)


if __name__ == '__main__':
    import getopt
    config_file = None
    server_name = None

    opts, _ = getopt.getopt(sys.argv[1:], 'c:n:')
    print opts
    for item in opts:
        if item[0] == "-c":
            config_file = item[1]
        if item[0] == "-n":
            server_name = item[1]

    if not (config_file and server_name):
        print "Wrong input"
        raise

    main(config_file, server_name)
