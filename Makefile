SHELL := /usr/bin/env TZ=UTC bash

KEYPASS ?= foogoo
KEYSIZE ?= 2048
CERT_DAYS ?= 30

# N.B. see note in client.py about hosts entries to use TLS w/ the CN and SNI
SERVER_NAME ?= othername.cluster.local
SERVER_IP ?= 127.2.1.1

SERVER_CN ?= myserver.cluster.local
CLIENT_CN ?= myclient.cluster.local
ROOT_CA_CN ?= root-ca.cluster.local
INTERM_CA_CN ?= intermediate-ca.cluster.local

SUBJ = /C=US/ST=UT/L=Salt Lake City/O=OBS/OU=SRE/CN=
subj = $(addprefix $(SUBJ),$(1))

ifndef VERBOSE:
.SILENT:
endif

all: pki

pki: root-ca interm-ca server client
	@echo "$@"

passphrase.txt:
	@echo "$@"
	umask 077 && echo -e "$(KEYPASS)" > $@

# root CA (self-signed, needs to be in trust when verifying)

root-ca: root-ca-cert.pem
root-ca-cert.pem: passphrase.txt
	@echo "$@"
	openssl req -x509 -sha256 -newkey rsa:$(KEYSIZE) -days $(CERT_DAYS) -subj "$(call subj,$(ROOT_CA_CN))" -passout file:passphrase.txt -keyout root-ca-key.pem -out $@

# intermediate CA

interm-ca: interm-ca-cert.pem
interm-ca-cert.pem: interm-ca.csr.pem root-ca-cert.pem
	@echo "$@"
	openssl x509 -req -days $(CERT_DAYS) -extfile openssl.cnf -extensions ca_ext -passin file:passphrase.txt -in $< -CA root-ca-cert.pem -CAkey root-ca-key.pem -set_serial 01 -out $@

interm-ca.csr.pem: passphrase.txt
	@echo "$@"
	umask 077 && openssl req -newkey rsa:$(KEYSIZE) -subj "$(call subj,$(INTERM_CA_CN))" -passout file:passphrase.txt -keyout interm-ca-key.pem -out $@

# server cert signed by intermediate CA

server: server-certchain.pem
server.csr.pem: passphrase.txt
	@echo "$@"
	umask 077 && openssl req -newkey rsa:$(KEYSIZE) -subj "$(call subj,$(SERVER_CN))" -addext "subjectAltName=DNS:$(SERVER_NAME),DNS:$(SERVER_CN),IP:$(SERVER_IP)" -passout file:passphrase.txt -keyout server-key.pem -out $@

# N.B. the "-copy_extensions copy" part is what permits the CSR to specify the SAN and us to copy it into the issued cert
server-cert.pem: server.csr.pem interm-ca-cert.pem
	@echo "$@"
	openssl x509 -req -days $(CERT_DAYS) -extfile openssl.cnf -extensions server_ext -copy_extensions copy -passin file:passphrase.txt -in $< -CA interm-ca-cert.pem -CAkey interm-ca-key.pem -set_serial 02 -out $@

# apps want this; order: 1:server_cert; 2:intermediate (signed by CA), which is trusted and so there is no need to put it in the bundle
# more info: https://tools.ietf.org/html/rfc5246#page-47
server-certchain.pem: server-cert.pem interm-ca-cert.pem
	@echo "$@"
	cat $^ > $@

# client cert for mTLS checking

client: client-certchain.pem

client.csr.pem: passphrase.txt
	@echo "$@"
	umask 077 && openssl req -newkey rsa:$(KEYSIZE) -subj "$(call subj,$(CLIENT_CN))" -passout file:passphrase.txt -keyout client-key.pem -out $@

client-cert.pem: client.csr.pem interm-ca-cert.pem
	@echo "$@"
	openssl x509 -req -days $(CERT_DAYS) -extfile openssl.cnf -extensions client_ext -passin file:passphrase.txt -in $< -CA interm-ca-cert.pem -CAkey interm-ca-key.pem -set_serial 03 -out $@

client-certchain.pem: client-cert.pem interm-ca-cert.pem
	@echo "$@"
	cat $^ > $@

realclean:
	rm -f *.pem passphrase.txt

show: pki
	@echo "==== Root CA (trust this one) ===="
	openssl x509 -text -in root-ca-cert.pem -noout
	@echo "==== Server cert (verify this one with hostname verification) ===="
	openssl x509 -text -in server-cert.pem -noout
	@echo "==== Client cert (verify this one without hostname verification) ===="
	openssl x509 -text -in client-cert.pem -noout

validate: pki
	@echo "$@"
	@echo "++ This looks weird b/c the intermediate is marked 'untrusted', but it is right: we trust the root ca (specified with CAfile) and want to verify a chain of trust from the signed server cert back to our CA, which is trusted. We never want to give an untrusted intermediate cert as an arg to CAfile b/c that considers it trusted. More useful info at https://mail.python.org/pipermail/cryptography-dev/2016-August/000676.html"
	openssl verify -verbose -show_chain -CAfile root-ca-cert.pem -untrusted interm-ca-cert.pem server-cert.pem
	@echo "++ This looks even weirder but is still a valid alternative to the nasty business of trusting an intermediate CA you shouldn't trust"
	openssl verify -verbose -show_chain -CAfile root-ca-cert.pem -untrusted server-certchain.pem server-certchain.pem
	@echo "++ This is only as weird as the first"
	openssl verify -verbose -show_chain -CAfile root-ca-cert.pem -untrusted interm-ca-cert.pem client-cert.pem


.PHONY: all exec pki show validate server realclean
