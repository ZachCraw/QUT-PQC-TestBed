FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# ---- tooling (no libssl-dev on purpose: we build our own OpenSSL below) ----
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential perl cmake ninja-build git ca-certificates pkg-config python3 \
    iproute2 iputils-ping iperf3 tcpdump tshark \
    && rm -rf /var/lib/apt/lists/*

# ---- Versions: oqs-provider 0.11.0 is documented as in sync with liboqs 0.15.0.
# OpenSSL must be >= 3.2 for PQ signatures in TLS 1.3, and < 3.5 so that
# oqs-provider does not disable its own ML-KEM/ML-DSA in favour of native ones.
ARG OPENSSL_VERSION=3.4.0
ARG LIBOQS_VERSION=0.15.0
ARG OQS_PROVIDER_VERSION=0.11.0
# Limit parallel compile jobs: -j$(nproc) can exhaust RAM on many-core machines.
ARG MAKE_JOBS=4

WORKDIR /opt

# ---- OpenSSL (source build) ----
# Source goes in /opt/openssl-src, NOT /opt/openssl (that is the install prefix).
RUN git clone --depth 1 --branch openssl-${OPENSSL_VERSION} https://github.com/openssl/openssl.git openssl-src && \
    cd openssl-src && \
    ./Configure --prefix=/opt/openssl --libdir=lib && \
    make -j${MAKE_JOBS} build_sw && make install_sw && \
    cd /opt && rm -rf openssl-src

# ---- liboqs ----
RUN git clone --depth 1 --branch ${LIBOQS_VERSION} https://github.com/open-quantum-safe/liboqs.git && \
    cmake -S liboqs -B liboqs/build -GNinja \
        -DCMAKE_INSTALL_PREFIX=/opt/liboqs/install \
        -DOQS_USE_OPENSSL=OFF -DBUILD_SHARED_LIBS=ON \
        -DOQS_BUILD_ONLY_LIB=ON -DBUILD_TESTING=OFF && \
    ninja -j${MAKE_JOBS} -C liboqs/build install

# ---- oqs-provider (built against OUR OpenSSL) ----
RUN git clone --depth 1 --branch ${OQS_PROVIDER_VERSION} https://github.com/open-quantum-safe/oqs-provider.git && \
    cmake -S oqs-provider -B oqs-provider/build -GNinja \
        -DOPENSSL_ROOT_DIR=/opt/openssl \
        -Dliboqs_DIR=/opt/liboqs/install/lib/cmake/liboqs \
        -DBUILD_TESTING=OFF && \
    ninja -j${MAKE_JOBS} -C oqs-provider/build && \
    mkdir -p /opt/openssl/lib/ossl-modules && \
    cp "$(find oqs-provider/build -name oqsprovider.so | head -1)" /opt/openssl/lib/ossl-modules/

# Added late on purpose (keeps the long compile layers above cached)
RUN apt-get update && apt-get install -y --no-install-recommends ethtool \
    && rm -rf /var/lib/apt/lists/*

COPY openssl-oqs.cnf /opt/openssl-oqs.cnf
ENV PATH=/opt/openssl/bin:$PATH \
    LD_LIBRARY_PATH=/opt/openssl/lib:/opt/liboqs/install/lib \
    OPENSSL_CONF=/opt/openssl-oqs.cnf \
    OPENSSL_MODULES=/opt/openssl/lib/ossl-modules

WORKDIR /app
