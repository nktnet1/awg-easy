# As a workaround we have to build on nodejs 18
# nodejs 20 hangs on build with armv6/armv7
FROM docker.io/library/node:18-alpine AS build_node_modules

# Copy Web UI
COPY src /app
WORKDIR /app
RUN npm ci --omit=dev &&\
    mv node_modules /node_modules

# Copy build result to a new image.
# This saves a lot of disk space.
FROM docker.io/library/node:lts-alpine
HEALTHCHECK CMD /usr/bin/timeout 5s /bin/sh -c "/usr/bin/wg show | /bin/grep -q interface || exit 1" --interval=1m --timeout=5s --retries=3
COPY --from=build_node_modules /app /app

# Move node_modules one directory up, so during development
# we don't have to mount it in a volume.
# This results in much faster reloading!
#
# Also, some node_modules might be native, and
# the architecture & OS of your development machine might differ
# than what runs inside of docker.
COPY --from=build_node_modules /node_modules /node_modules

# Copy the needed wg-password scripts
COPY --from=build_node_modules /app/wgpw.sh /bin/wgpw
RUN chmod +x /bin/wgpw

# Install Linux packages
RUN apk add --no-cache \
    dpkg \
    dumb-init \
    iptables \
    iptables-legacy \
    curl \
    bash

ARG AMNEZIAWG_VERSION=v1.0.20241018
ARG AMNEZIAWG_TOOL_VERSION=alpine-3.19-amneziawg-tools
ARG AMNEZIAWG_URL=https://github.com/amnezia-vpn/amneziawg-tools/releases/download/${AMNEZIAWG_VERSION}/${AMNEZIAWG_TOOL_VERSION}.zip

# Install amnezia-tools
RUN curl -L ${AMNEZIAWG_URL} -o /tmp/${AMNEZIAWG_TOOL_VERSION}.zip && \
    unzip /tmp/${AMNEZIAWG_TOOL_VERSION}.zip -d /tmp && \
    mv /tmp/${AMNEZIAWG_TOOL_VERSION}/awg /tmp/${AMNEZIAWG_TOOL_VERSION}/awg-quick /usr/local/bin/ && \
    chmod 755 /usr/local/bin/awg /usr/local/bin/awg-quick && \
    rm -rf /tmp/${AMNEZIAWG_TOOL_VERSION} /tmp/${AMNEZIAWG_TOOL_VERSION}.zip


# Use iptables-legacy
RUN update-alternatives --install /usr/sbin/iptables iptables /usr/sbin/iptables-legacy 10 --slave /usr/sbin/iptables-restore iptables-restore /usr/sbin/iptables-legacy-restore --slave /usr/sbin/iptables-save iptables-save /usr/sbin/iptables-legacy-save

# Set Environment
ENV DEBUG=Server,WireGuard

# Run Web UI
WORKDIR /app
CMD ["/usr/bin/dumb-init", "node", "server.js"]
