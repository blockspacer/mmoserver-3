# -*- coding: utf-8 -*-

import struct
import socket
import sys

SERVER_IP = "127.0.0.1"
HOST_PORT = 4050

args = sys.argv
if len(args) > 1:
    HOST_PORT = int(args[1])
    
print HOST_PORT
client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
client.connect((SERVER_IP, HOST_PORT))

def encrypt(data):
    data_length = len(data)
    rst = bytearray(data_length)

    offset = 2
    for i in range(0, offset):
        rst[i] = ord(data[i])
    for i in range(offset, data_length - 1):
        rst[i] = ord(data[i]) ^ ord(data[i + 1])
    rst[data_length - 1] = ord(data[data_length - 1]) ^ 58

    '''print "encrypt",
    for c in rst:
        print c,
    print "encrypt end"'''
    #print "send len ", data_length
    return rst


def send_msg(action, data):
    global serial_number

    #add head
    head_size = 3
    size = head_size + len(data)
    head = struct.pack("<HBH", size, 0, action)

    '''print "head",
    for c in head:
        print ord(c),
    print "head end"
    print "data",
    for c in data:
        print ord(c),
    print "data end"'''

    client.send(encrypt(head + data))

send_msg(8888, "")
