# -*- coding: utf-8 -*-

import hashlib
import requests

gameid = "hfhy00045"
appkey = "069d9020a6343b009ada916fca3bf870"
token = "89c3ec4e6d6bafe06a3889393971d8b3"

m = hashlib.md5()
m.update(gameid + token + appkey)
chk = m.hexdigest()

postdata = {"gameid": gameid, "token": token, "chkvalue": chk}
url = "https://sdk.ihfgame.com/validtoken"
reply = requests.post(url, data=postdata)

print reply.text.decode("utf8")
