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
WORKDIR /opt
RUN git clone --depth 1 --branch main https://github.com/open-quantum-safe/liboqs.git && \
    cmake -S liboqs -B liboqs/build -GNinja \
        -DCMAKE_INSTALL_PREFIX=/opt/liboqs/install \
        -DOQS_USE_OPENSSL=OFF \
        -DBUILD_SHARED_LIBS=ON && \
    ninja -C liboqs/build install

# --- Build the OQS OpenSSL 3.x provider --------------------------------------
RUN git clone --depth 1 --branch main https://github.com/open-quantum-safe/oqs-provider.git && \
    cmake -S oqs-provider -B oqs-provider/build -GNinja \
        -Dliboqs_DIR=/opt/liboqs/install/lib/cmake/liboqs && \
    ninja -C oqs-provider/build

# Drop the compiled provider into OpenSSL's module directory so `openssl`
# picks it up via the config file below (no code changes needed elsewhere).
RUN OPENSSL_MODULES_DIR="$(openssl version -d | cut -d '"' -f2)/ossl-modules" && \
    mkdir -p "$OPENSSL_MODULES_DIR" && \
    cp /opt/oqs-provider/build/lib/oqsprovider.so "$OPENSSL_MODULES_DIR"/

COPY docker/openssl-oqs.cnf /etc/ssl/openssl-oqs.cnf
ENV OPENSSL_CONF=/etc/ssl/openssl-oqs.cnf

WORKDIR /app
ENTRYPOINT ["/bin/bash"]
