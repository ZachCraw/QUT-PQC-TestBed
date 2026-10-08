FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# --- Base build tooling -----------------------------------------------------
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    ninja-build \
    git \
    python3 \
    python3-pip \
    libssl-dev \
    pkg-config \
    ca-certificates \
    iproute2 \
    iputils-ping \
    net-tools \
    tcpdump \
    && rm -rf /var/lib/apt/lists/*

# --- Build liboqs ------------------------------------------------------------
# Pinned to a tagged release rather than `main`: liboqs and oqs-provider's
# `main` branches are NOT guaranteed to be in sync with each other at any
# given moment (they're developed in parallel). Use the matched release pair
# documented in oqs-provider's release notes instead. Check
# https://github.com/open-quantum-safe/oqs-provider/releases for the current
# "guaranteed in sync with liboqs vX.Y.Z" pairing before bumping these.
ARG LIBOQS_VERSION=0.15.0
ARG OQS_PROVIDER_VERSION=0.11.0

WORKDIR /opt
RUN git clone --depth 1 --branch ${LIBOQS_VERSION} https://github.com/open-quantum-safe/liboqs.git && \
    cmake -S liboqs -B liboqs/build -GNinja \
        -DCMAKE_INSTALL_PREFIX=/opt/liboqs/install \
        -DOQS_USE_OPENSSL=OFF \
        -DBUILD_SHARED_LIBS=ON \
        -DBUILD_TESTING=OFF && \
    ninja -C liboqs/build install

# --- Build the OQS OpenSSL 3.x provider --------------------------------------
RUN git clone --depth 1 --branch ${OQS_PROVIDER_VERSION} https://github.com/open-quantum-safe/oqs-provider.git && \
    cmake -S oqs-provider -B oqs-provider/build -GNinja \
        -Dliboqs_DIR=/opt/liboqs/install/lib/cmake/liboqs \
        -DBUILD_TESTING=OFF && \
    ninja -C oqs-provider/build

RUN MODDIR="$(openssl version -m | cut -d '"' -f2)" && \
    mkdir -p "$MODDIR" && \
    cp "$(find /opt/oqs-provider/build -name oqsprovider.so | head -1)" "$MODDIR"/ && \
    ls -l "$MODDIR"/oqsprovider.so

COPY docker/openssl-oqs.cnf /etc/ssl/openssl-oqs.cnf
ENV OPENSSL_CONF=/etc/ssl/openssl-oqs.cnf

WORKDIR /app
ENTRYPOINT ["/bin/bash"]
