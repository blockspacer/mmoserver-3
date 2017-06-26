# -*- coding: utf-8 -*-
from struct import unpack


class request(object):
    """ 用来保存请求数据，请求解析是异步的，因此需要这个对象来保存已经收到的数据"""

    def __init__(self):
        super(request, self).__init__()
        self.size = ''
        self.data = ''

    def get_size(self):
        try:
            return unpack('<I', self.size)[0]
        except:
            return -1

    def reset(self):
        self.size = ''
        self.data = ''


class request_parser(object):
    """
    用来解析请求，解析是异步的，因此有状态
    请求格式就是一个头来存放数据的长度，然后后面跟着数据
    """
    SIZE_BYTES = 4

    ST_SIZE = 0
    ST_DATA = 1

    MAX_DATA_LEN = 0xFFFFFF

    def __init__(self):
        super(request_parser, self).__init__()
        self.max_data_len = self.MAX_DATA_LEN
        self.need_bytes = request_parser.SIZE_BYTES
        self.state = request_parser.ST_SIZE

    def reset(self):
        self.state = request_parser.ST_SIZE
        self.need_bytes = request_parser.SIZE_BYTES

    def set_max_data(self, size):
        self.max_data_len = size

    # return result(0,1, 2, 3) , consum( len )
    def parse(self, request, data, skip=0):
        l = len(data) - skip  #有效的数据包长度
        head_len = 0

        if self.state == request_parser.ST_SIZE:
            if l < self.need_bytes:
                request.size += data[skip:]
                self.need_bytes -= l
                return 2, l   #2 包没有收完整

            request.size += data[skip:skip + self.need_bytes]
            data_len = request.get_size()

            if data_len < 1:
                return 0, l  #0 有错误

            if data_len > self.max_data_len:
                return 3, l #3 超过最大包长度

            self.state = request_parser.ST_DATA
            head_len = self.need_bytes
            self.need_bytes += data_len

        if self.state == request_parser.ST_DATA:
            if self.need_bytes > l:
                request.data += data[skip + head_len:]
                self.need_bytes -= l
                return 2, l    #2 包没有收完整
            else:
                request.data += data[skip + head_len:skip + self.need_bytes]
                consum = self.need_bytes
                self.reset()
                return 1, consum  #1 完整的包

        return 0, 0
