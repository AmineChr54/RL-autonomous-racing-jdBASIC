# Self-hosted GitHub Actions runner for jdBasic CI: Ubuntu + official actions/runner tarball + Wine + Python.
# jdBasic itself is NOT baked in: mount the Windows install read-only at /opt/jdbasic.
FROM ubuntu:24.04
ARG RUNNER_VERSION=2.338.0
ENV DEBIAN_FRONTEND=noninteractive \
    WINEPREFIX=/home/runner/.wine WINEDEBUG=-all WINEARCH=win64 \
    JDBASIC=/opt/jdbasic/jdBasic.exe
RUN dpkg --add-architecture i386 && apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git jq sudo xvfb xauth cabextract \
      wine64 wine32:i386 \
      python3 python3-pip python3-venv python3-numpy \
    && rm -rf /var/lib/apt/lists/*
# CPU-only torch: the Python original's brain.py imports it
RUN pip3 install --no-cache-dir --break-system-packages torch --index-url https://download.pytorch.org/whl/cpu
RUN ln -sf /usr/lib/wine/wine64 /usr/local/bin/wine && ln -sf /usr/bin/python3 /usr/local/bin/python \
    && useradd -m -s /bin/bash runner && echo "runner ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/runner
USER runner
WORKDIR /home/runner/actions-runner
RUN curl -fsSL -o r.tgz "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" \
    && tar xzf r.tgz && rm r.tgz \
    && sudo ./bin/installdependencies.sh
COPY --chown=runner:runner entrypoint.sh /home/runner/entrypoint.sh
RUN chmod +x /home/runner/entrypoint.sh
ENTRYPOINT ["/home/runner/entrypoint.sh"]
