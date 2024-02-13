#!/usr/bin/env python3

import ssl
import socket
import logging
import asyncio
import datetime
import time
from threading import Thread

# N.B. values match what's in the Makefile by default

logging.basicConfig()

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

msg_size_b = 64

def _ts_msg() -> bytes:
    msg = str(datetime.datetime.now().timestamp())
    msg += "\0" * (msg_size_b - len(msg))

    return msg

def _handler(conn, addr) -> None:
    logger.info(f"Sending data to {conn}")
    conn.write(_ts_msg().encode())
    conn.close()


def server() -> None:
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)

    context.load_verify_locations('root-ca-cert.pem')
    context.minimum_version = ssl.TLSVersion.TLSv1_3
    context.verify_mode = ssl.CERT_REQUIRED # mTLS on

    with open('passphrase.txt') as inf:
        pass_text = inf.readline().strip()

    context.load_cert_chain(certfile='server-certchain.pem', keyfile='server-key.pem', password=pass_text)

    ip = "127.2.1.1"
    port = 8443

    logger.info(f"Listening on {ip}:{port}")
    sock = None

    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM, 0) as sock:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            sock.bind((ip, port))
            sock.listen(5)

            with context.wrap_socket(sock, server_side=True) as ssock:
                while True:
                    conn, addr = ssock.accept()
                    logger.info(f"Accepted connection from {conn}, peercert: {conn.getpeercert()}")
                    t = Thread(target=_handler, args=(conn, addr,))
                    t.start()
    finally:
        sock.close()


if __name__ == '__main__':
    server()
