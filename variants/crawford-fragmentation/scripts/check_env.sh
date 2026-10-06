#!/bin/bash
# Quick sanity check that OpenSSL 3.4 + oqsprovider expose what Variant 1 needs.
echo "== openssl =="; openssl version
echo "== providers =="; openssl list -providers
echo "== hybrid KEM group present? =="
openssl list -kem-algorithms -provider oqsprovider | grep -i "x25519_mlkem768\|X25519MLKEM768" || echo "!! X25519MLKEM768 NOT FOUND"
echo "== ML-DSA-65 present? =="
openssl list -signature-algorithms -provider oqsprovider | grep -i mldsa65 || echo "!! mldsa65 NOT FOUND"
