# -*- coding: utf-8 -*-
import json
import redis
from struct import pack, unpack
import hashlib
from config import config


class LoginService(object):
    """ 屏蔽sdk细节"""

    def __init__(self):
        self.sdkinfo = {}
        self.handles = {}
        self.gameid = "hfhy00045"
        self.appkey = "069d9020a6343b009ada916fca3bf870"
        self.redisconn = None

    def init(self):
        ip = config["redis"]["address"]
        port = config["redis"]["port"]
        self.init_db(ip, port)

    def init_db(self, ip, port, enable_sentinel=False):
        if enable_sentinel:
            #TODO sentinel 模式
            pass
        else:
            self.redisconn = redis.StrictRedis(ip, port, 0)

    def process(self, conn, opcode, data):
        self.verify_login(conn, data)
        # handler = self.handles[opcode]
        # if handler:
        #     handler(conn, data)

    def verify_login(self, conn, message):
        import requests
        para = json.loads(message)
        token = para["token"]
        m = hashlib.md5()
        m.update(self.gameid + token + self.appkey)
        chk = m.hexdigest()
        postdata = {"gameid": self.gameid, "token": token, "chkvalue": chk}
        url = "https://sdk.ihfgame.com/validtoken"
        r = requests.post(url, data=postdata)
        r2 = r.json()
        # 返回值的形式 '{"result":"1","userid":"76440593"}'
        if r2["result"] == "1":
            uid = r2["userid"]
            self.redisconn.set("verifykey:" + uid, token)

        reply = r.text
        reply = reply.encode("utf8")
        self.send(conn, 666, reply)

    def send(self, conn, opcode, message):
        total_len = len(message) + 6
        conn.send_data(''.join([pack('<I', total_len), pack('<HHH', 0, 0, opcode), message]))
