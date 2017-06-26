# -*- coding: utf-8 -*-
from mobilelog.LogManager import LogManager
from RpcChannel import MobileRpcChannel


class RpcChannelCreator(object):
    def __init__(self, logic_service, channel_handler, processlagerbuf='True', max_data_len=0):
        super(RpcChannelCreator, self).__init__()
        self.logger = LogManager.get_logger("mobilerpc.RpcChannelCreator")
        # 保存rpc的service和stub
        self.rpc_service = logic_service
        self.channel_handler = channel_handler
        self.max_data_len = max_data_len
        self.processlagerbuf = processlagerbuf

    def set_max_data(self, size):
        self.max_data_len = size

    def handle_new_connection(self, con):
        """ called by Server or TcpClient when we have new socket connection """
        self.logger.info("handle new connection of rpcchannel %s", con.socket.getpeername())
        rpc_channel = MobileRpcChannel(self.rpc_service, con, self.processlagerbuf)
        if (self.max_data_len > 0):
            rpc_channel.set_max_data(self.max_data_len)

        self.channel_handler.handle_new_channel(rpc_channel)

    def handle_connection_failed(self, con):
        """ called by Server or TcpClient when we have new socket connection """
        self.logger.info("connection failed")


class RpcChannelHolder(object):
    """
    RpcChannelManager	管理多条RpcChannel，和ConnectionManager类似
    只是ConnectionManager管理的是普通的TcpConnection
    而RpcChannelManager管理所有的RpcChannel
    """

    def __init__(self):
        super(RpcChannelHolder, self).__init__()
        self.logger = LogManager.get_logger("mobilerpc.RpcChannelHolder")
        self.rpc_channel = None

    def handle_new_channel(self, rpc_channel):
        """ called by Server or TcpClient when we have new socket connection """
        print ("------------------------------------------------------")
        self.logger.debug("RpcChannelHolder handle_new_channel")
        self.rpc_channel = rpc_channel
        rpc_channel.reg_listener(self)

    def on_channel_disconnected(self, _rpc_channel):
        """ called by RpcChannel when the connection is closed"""
        self.rpc_channel = None

    def get_rpc_channel(self):
        """ return the rpc channel"""
        return self.rpc_channel


class RpcChannelManager(object):
    """
    RpcChannelManager	管理多条RpcChannel，和ConnectionManager类似
    只是ConnectionManager管理的是普通的TcpConnection
    而RpcChannelManager管理所有的RpcChannel
    """

    def __init__(self):
        super(RpcChannelManager, self).__init__()
        self.logger = LogManager.get_logger("mobilerpc.RpcChannelManager")
        self.rpc_channels = {}

    def handle_new_channel(self, rpc_channel):
        """ called by Server or TcpClient when we have new socket connection """
        self.logger.debug("RpcChannelManager handle_new_channel")
        self.rpc_channels[rpc_channel.getpeername()] = rpc_channel
        rpc_channel.reg_listener(self)

    def on_channel_disconnected(self, rpc_channel):
        """ called by RpcChannel when the connection is closed"""
        peername = rpc_channel.conn.getpeername()
        if self.rpc_channels.has_key(peername):
            self.logger.info("delete connection for %s", peername)
            del self.rpc_channels[peername]
        else:
            self.logger.info("didn't find disconnected connection  %s", peername)

    def get_rpc_channel(self, peername):
        """ return the rpc channel"""
        return self.rpc_channels.get(peername, None)

    def rpc_channel_num(self):
        """ return the rpc channel number"""
        return len(self.rpc_channels)
