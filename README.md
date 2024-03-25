# `python-mtls-e2e-sample`

## Updates

### TODO

* Demonstrate cross-signed certs

## Use

### Monkeying with certs

Make the stuff:

```bash
make realclean && make -j4 verbose=y validate
```
Inspect certs:

```bash
make show
```

Clean up:

```bash
make realclean
```

### Testing mTLS

#### Using a python server and client

Make PKI:

```bash
make
```

Start a server:

```bash
./server.py
```

... then start a client:

```bash
./client.py
```

### Using openssl

Make PKI:

```bash
make
```

```bash
openssl s_client -CAfile ./root-ca-cert.pem -cert ./client-cert.pem -key ./client-key.pem -cert_chain ./client-certchain.pem -connect myserver.cluster.local:8443 -pass file:passphrase.txt
```

... or also functional ...

```bash
openssl s_client -CAfile ./root-ca-cert.pem -cert ./client-certchain.pem -key ./client-key.pem -cert_chain ./client-certchain.pem -connect myserver.cluster.local:8443 -pass file:passphrase.txt
```
