# Self-hosted GitHub Actions runner for jdBasic CI: Ubuntu + official actions/runner tarball + Python +
# jdBasic built natively on Linux from upstream source, pinned by JDBASIC_REF (no Wine).
# Build with a memory limit: docker build --memory 6g --memory-swap 6g (ci/start-runner.sh does).
FROM ubuntu:24.04 AS jdbasic-build
ARG JDBASIC_REF=70c1b7b0
ARG JOBS=4
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates git g++ make llvm-18-dev libssl-dev zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*
RUN git clone https://github.com/AtomiJD/jdBasic /src && cd /src && git checkout "$JDBASIC_REF" && git log -1 --format=%H%n%s > /src/.ref
WORKDIR /src
# minimal module set: no GFX/HTTP/IMGUI/MCP; NATIVEC adds the LLVM backend behind `jdbasic -c`
RUN HTTP=0 GFX=0 NATIVEC=1 JOBS=$JOBS ./build.sh
RUN mkdir -p /opt/jdbasic && cp -rL build /opt/jdbasic/build && cp -rL lib /opt/jdbasic/lib && cp .ref /opt/jdbasic/REF \
    && rm -rf /opt/jdbasic/build/obj /opt/jdbasic/build/obj_pic

FROM ubuntu:24.04
ARG RUNNER_VERSION=2.338.0
ENV DEBIAN_FRONTEND=noninteractive \
    JDBASIC=/opt/jdbasic/build/jdbasic
# g++ + llvm-18-dev: `jdbasic -c` generates IR and links with the system toolchain
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git jq sudo time g++ llvm-18-dev libssl3 zlib1g \
      python3 python3-pip python3-venv python3-numpy \
    && rm -rf /var/lib/apt/lists/*
# CPU-only torch: the Python original's brain.py imports it
RUN pip3 install --no-cache-dir --break-system-packages torch --index-url https://download.pytorch.org/whl/cpu
COPY --from=jdbasic-build /opt/jdbasic /opt/jdbasic
RUN ln -sf /usr/bin/python3 /usr/local/bin/python \
    && useradd -m -s /bin/bash runner && echo "runner ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/runner
USER runner
WORKDIR /home/runner/actions-runner
RUN curl -fsSL -o r.tgz "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" \
    && tar xzf r.tgz && rm r.tgz \
    && sudo ./bin/installdependencies.sh
COPY --chown=runner:runner entrypoint.sh /home/runner/entrypoint.sh
RUN chmod +x /home/runner/entrypoint.sh
ENTRYPOINT ["/home/runner/entrypoint.sh"]
