#!/usr/bin/env python3

import sys
import serial
import threading
import logging
import time

BUFSIZ = 1

SLIP_END = 0o300
SLIP_ESC = 0o333
SLIP_ESC_END = 0o334
SLIP_ESC_ESC = 0o335

FRAME_IP4_START = 0x45
FRAME_IP4_END = 0x4f
FRAME_IP6_START = 0x60
FRAME_IP6_END = 0x6f
FRAME_DBG = 0x0a
FRAME_COAP = 0xA9

logging.basicConfig(filename='/tmp/slipmux.log', encoding='utf-8', level=logging.DEBUG)

class SLIPDecoder():
    def __init__(self, cb):
        self.cb = cb
        self.prev_esc = False
        self.buffer = bytearray()

    def process_byte(self, byte):
        if byte == SLIP_ESC:
            self.prev_esc = True
            return
        elif byte == SLIP_END:
            buf = self.buffer.lstrip(b'\x00')
            self.cb(bytes(buf))
            self.buffer.clear()
            return
        elif byte == SLIP_ESC_END or byte == SLIP_ESC_ESC:
            if self.prev_esc:
                if byte == SLIP_ESC_END:
                    byte = SLIP_END
                elif byte == SLIP_ESC_ESC:
                    byte = SLIP_ESC

        self.buffer.append(byte)

    def process(self, buf):
        for byte in buf:
            self.process_byte(byte)

def handle_frame(bytes):
    logging.debug(F"handle_frame: {bytes}")
    if len(bytes) <= 1:
        return

    id = bytes[0]
    if id >= FRAME_IP4_START and id <= FRAME_IP4_END:
        raise NotImplementedError('Support for IPv4 frames not implemented')
    elif id >= FRAME_IP6_START and id <= FRAME_IP6_END:
        raise NotImplementedError('Support for IPv6 frames not implemented')
    elif id == FRAME_DBG:
        msg = bytes[1:len(bytes)].decode('utf-8')
        sys.stdout.write(msg)
    elif id == FRAME_COAP:
        raise NotImplementedError('Support for CoAP farmes not implemented')
    else:
        raise RuntimeError('Unknown frame format')

def recv_thread(serial, input):
    while True:
        data = input.read(BUFSIZ)
        logging.debug(F"recv_thread: {data}")
        if len(data) == 0:
            break

        # The FTDI chip on the HiFive1 does not seem to do hardware flow
        # control, thus just use an oppertunistic sleep here to ensure
        # that the FIFO never becomes full.
        time.sleep(1)

        serial.write(data)

argv = sys.argv
if len(argv) <= 1:
    sys.stderr.write(F'USAGE: {argv[0]} TTY_DEVICE\n')
    sys.exit(1)

ttydev = sys.argv[1]
s = serial.Serial(ttydev, baudrate=115200)

thr = threading.Thread(target=recv_thread, args=(s, sys.stdin.buffer))
thr.start()

decoder = SLIPDecoder(handle_frame)
while True:
    while True:
        buf = s.read(BUFSIZ)
        decoder.process(buf)

thr.join()
