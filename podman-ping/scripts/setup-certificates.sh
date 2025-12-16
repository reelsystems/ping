#!/bin/bash
# Certificate generation script for Ping Identity Platform
# Generates self-signed certificates for development/testing

set -e

CERT_DIR="./certs"
VALIDITY_DAYS=365
CA_SUBJECT="/C=US/ST=State/L=City/O=Organization/CN=Ping Identity CA"
SERVER_SUBJECT="/C=US/ST=State/L=City/O=Organization/CN=*.ping.local"
KEYSTORE_PASSWORD="changeit"

echo "=========================================="
echo "Ping Identity Certificate Setup"
echo "=========================================="
echo ""
echo "WARNING: These certificates are self-signed and suitable"
echo "for DEVELOPMENT and TESTING only. For production, obtain"
echo "certificates from a trusted Certificate Authority."
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Create certificate directory
mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

echo ""
echo "Step 1: Generating CA private key..."
openssl genrsa -out ca.key 4096

echo "Step 2: Generating CA certificate..."
openssl req -x509 -new -nodes -key ca.key -sha256 -days $VALIDITY_DAYS \
    -out ca.crt -subj "$CA_SUBJECT"

echo "Step 3: Generating server private key..."
openssl genrsa -out server.key 2048

echo "Step 4: Generating server certificate signing request..."
openssl req -new -key server.key -out server.csr -subj "$SERVER_SUBJECT"

echo "Step 5: Creating server certificate extensions..."
cat > server.ext <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = *.ping.local
DNS.2 = ds-1.ping.local
DNS.3 = ds-2.ping.local
DNS.4 = ds-proxy.ping.local
DNS.5 = am.ping.local
DNS.6 = idm.ping.local
DNS.7 = ig.ping.local
DNS.8 = admin-ui.ping.local
DNS.9 = login-ui.ping.local
DNS.10 = localhost
IP.1 = 127.0.0.1
IP.2 = 172.28.0.20
IP.3 = 172.28.0.21
IP.4 = 172.28.0.22
IP.5 = 172.28.0.30
IP.6 = 172.28.0.40
IP.7 = 172.28.0.50
IP.8 = 172.28.0.60
IP.9 = 172.28.0.61
EOF

echo "Step 6: Signing server certificate..."
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
    -out server.crt -days $VALIDITY_DAYS -sha256 -extfile server.ext

echo "Step 7: Creating PKCS12 keystore..."
openssl pkcs12 -export -in server.crt -inkey server.key \
    -out server.p12 -name server -passout pass:$KEYSTORE_PASSWORD

echo "Step 8: Creating Java keystore (JKS)..."
keytool -importkeystore -srckeystore server.p12 -srcstoretype PKCS12 \
    -srcstorepass $KEYSTORE_PASSWORD -destkeystore keystore.jks \
    -deststorepass $KEYSTORE_PASSWORD -noprompt

echo "Step 9: Creating Java truststore with CA..."
keytool -import -trustcacerts -file ca.crt -alias ca \
    -keystore truststore.jks -storepass $KEYSTORE_PASSWORD -noprompt

echo "Step 10: Creating PEM bundle for DS..."
cat server.crt server.key > server.pem

echo "Step 11: Setting permissions..."
chmod 644 *.crt *.pem *.jks
chmod 600 *.key ca.key

cd ..

echo ""
echo "=========================================="
echo "Certificate generation complete!"
echo "=========================================="
echo ""
echo "Generated files in $CERT_DIR:"
ls -lh "$CERT_DIR"
echo ""
echo "Next steps:"
echo "1. Copy certificates to Podman volume:"
echo "   podman volume create shared-certs"
echo "   podman run --rm -v \$(pwd)/$CERT_DIR:/src -v shared-certs:/dest alpine sh -c 'cp -r /src/* /dest/ && chmod -R 755 /dest'"
echo ""
echo "2. Update podman-compose.yml to mount the shared-certs volume"
echo ""
echo "3. Configure each service to use the certificates"
echo ""
echo "Keystore password: $KEYSTORE_PASSWORD"
echo "WARNING: Change this password for production!"
