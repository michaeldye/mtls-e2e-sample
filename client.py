#!/usr/bin/env python3

# N.B. to use this successfully, you must have an entry like this in your
# hosts (with IP matching socket bind in server.py):
#
# 127.2.1.1  myserver.cluster.local othername.cluster.local

import ssl
import socket
import logging

logging.basicConfig()

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

msg_size_b = 64

context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)

context.load_verify_locations('root-ca-cert.pem')
context.minimum_version = ssl.TLSVersion.TLSv1_3

with open('passphrase.txt') as inf:
    pass_text = inf.readline().strip()

context.load_cert_chain(certfile='client-certchain.pem', keyfile='client-key.pem', password=pass_text)

# all of these should work b/c they're DNS and IP SANs in the x509 extension field
for hostname in [
        'myserver.cluster.local',
        '127.2.1.1',
        'othername.cluster.local',
        ]:
    logger.info(f"Attempting to connect to {hostname}")
    with socket.create_connection((hostname, 8443)) as sock:
        with context.wrap_socket(sock, server_hostname=hostname) as ssock:
            ssock.settimeout(2)

            logger.info(f"{ssock.version()}, peercert: {ssock.getpeercert()}")
            d = ssock.recv(msg_size_b)
            logger.info("ts from server: {}".format(d.rstrip(b"\0").decode()))
