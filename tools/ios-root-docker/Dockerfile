# Tools to build an iOS HFS+ root image from IPSW disk images (needs --privileged:
# FUSE for APFS, a loop-mounted HFS+ volume for rsync). See ../mkios-root.sh.
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential cmake git ca-certificates pkg-config \
        libfuse3-dev fuse3 libicu-dev zlib1g-dev libbz2-dev attr \
        hfsprogs rsync kmod util-linux python3 mount \
    && rm -rf /var/lib/apt/lists/*
# apfs-fuse reads the UDIF/APFS volumes and decompresses LZFSE/LZBITMAP files.
RUN git clone --recursive https://github.com/sgan81/apfs-fuse /src/apfs-fuse \
    && cd /src/apfs-fuse && git rev-parse HEAD > /apfs-fuse.rev \
    && cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DCMAKE_CXX_FLAGS="-include cstdint" \
    && cmake --build build -j"$(nproc)" \
    && install build/apfs-fuse build/apfs-dump-quick /usr/local/bin/
