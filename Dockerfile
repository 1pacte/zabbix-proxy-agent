# syntax=docker/dockerfile:1
ARG MAJOR_VERSION=6.0
ARG ZBX_VERSION=${MAJOR_VERSION}.21
ARG BUILD_BASE_IMAGE=zabbix/zabbix-build-sqlite3:ubuntu-${ZBX_VERSION}

FROM ${BUILD_BASE_IMAGE} as builder

FROM ubuntu:jammy

ARG MAJOR_VERSION
ARG ZBX_VERSION
ARG ZBX_SOURCES=https://git.zabbix.com/scm/zbx/zabbix.git

ENV TERM=xterm ZBX_VERSION=6.0.21 ZBX_SOURCES=https://git.zabbix.com/scm/zbx/zabbix.git MIBDIRS=/var/lib/mibs/ietf:/var/lib/mibs/iana:/usr/share/snmp/mibs:/var/lib/zabbix/mibs MIBS=+ALL ZBX_TLSPSKFILE=/etc/zabbix/zabbix_proxy.psk ZBX_TLSPSKIDENTITY=proxy1 ZBX_TLSCONNECT=psk ZBX_ENABLEREMOTECOMMANDS=1 ZBX_SERVER_HOST=90.85.33.105 ZBX_HOSTNAME=PSO-VEN-ZPROXY ZBX_PROXYOFFLINEBUFFER=96 ZBX_PROXYHEARTBEATFREQUENCY=900 ZBX_CONFIGFREQUENCY=7200 ZBX_DATASENDERFREQUENCY=900 ZBX_IPMIPOLLERS=3 ZBX_STARTVMWARECOLLECTORS=3 ZBX_VMWAREFREQUENCY=3600 ZBX_VMWAREPERFFREQUENCY=3600 ZBX_VMWARECACHESIZE=16M ZBX_CACHESIZE=16M

LABEL org.opencontainers.image.authors="Alexey Pustovalov <alexey.pustovalov@zabbix.com>" \
      org.opencontainers.image.description="Zabbix proxy with SQLite3 database support" \
      org.opencontainers.image.documentation="https://www.zabbix.com/documentation/${MAJOR_VERSION}/manual/installation/containers" \
      org.opencontainers.image.licenses="GPL v2.0" \
      org.opencontainers.image.source="${ZBX_SOURCES}" \
      org.opencontainers.image.title="Zabbix proxy (SQLite3)" \
      org.opencontainers.image.url="https://zabbix.com/" \
      org.opencontainers.image.vendor="Zabbix LLC" \
      org.opencontainers.image.version="${ZBX_VERSION}"

STOPSIGNAL SIGTERM

COPY --from=builder ["/tmp/zabbix-${ZBX_VERSION}/src/zabbix_proxy/zabbix_proxy", "/usr/sbin/zabbix_proxy"]
COPY --from=builder ["/tmp/zabbix-${ZBX_VERSION}/src/zabbix_get/zabbix_get", "/usr/bin/zabbix_get"]
COPY --from=builder ["/tmp/zabbix-${ZBX_VERSION}/src/zabbix_sender/zabbix_sender", "/usr/bin/zabbix_sender"]
COPY --from=builder ["/tmp/zabbix-${ZBX_VERSION}/conf/zabbix_proxy.conf", "/etc/zabbix/zabbix_proxy.conf"]

RUN set -eux && \
    echo "#!/bin/sh\nexit 101" > /usr/sbin/policy-rc.d && \
    INSTALL_PKGS="bash \
            tini \
            sudo \
            traceroute \
            nmap \
            ca-certificates \
            fping \
            libcurl4 \
            libevent-2.1 \
            libevent-pthreads-2.1 \
            libopenipmi0 \
            libpcre2-8-0 \
            libsnmp40 \
            libsqlite3-0 \
            libssh-4 \
            libssl3 \
            libxml2 \
            snmp-mibs-downloader \
            unixodbc" && \
    apt-get -y update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y \
            --no-install-recommends install \
        ${INSTALL_PKGS} && \
    groupadd \
            --system \
            --gid 1995 \
        zabbix && \
    useradd \
            --system \
            --comment "Zabbix monitoring system" \
            -g zabbix \
            -G root \
            --uid 1997 \
            --shell /sbin/nologin \
            --home-dir /var/lib/zabbix/ \
        zabbix && \
    echo "zabbix ALL=(root) NOPASSWD: /usr/bin/nmap" >> /etc/sudoers.d/zabbix && \
    mkdir -p /etc/zabbix && \
    mkdir -p /var/lib/zabbix && \
    mkdir -p /var/lib/zabbix/db_data && \
    mkdir -p /var/lib/zabbix/enc && \
    mkdir -p /usr/lib/zabbix/externalscripts && \
    mkdir -p /var/lib/zabbix/mibs && \
    mkdir -p /var/lib/zabbix/modules && \
    mkdir -p /var/lib/zabbix/snmptraps && \
    mkdir -p /var/lib/zabbix/ssh_keys && \
    mkdir -p /var/lib/zabbix/ssl && \
    mkdir -p /var/lib/zabbix/ssl/certs && \
    mkdir -p /var/lib/zabbix/ssl/keys && \
    mkdir -p /var/lib/zabbix/ssl/ssl_ca && \
    mkdir -p /run/zabbix && \
    chown --quiet -R zabbix:root /etc/zabbix/ /var/lib/zabbix/ /run/zabbix && \
    chgrp -R 0 /etc/zabbix/ /var/lib/zabbix/ && \
    chmod -R g=u /etc/zabbix/ /var/lib/zabbix/ && \
    apt-get -y autoremove

RUN apt-get install -y zabbix-agent

RUN rm -rf /var/lib/apt/lists/*

EXPOSE 10051/TCP

WORKDIR /var/lib/zabbix

VOLUME ["/var/lib/zabbix/snmptraps"]

COPY SNMPv2-PDU /var/lib/mibs/ietf/SNMPv2-PDU

COPY ["docker-entrypoint.sh", "/usr/bin/"]

RUN ["chmod", "+x", "/usr/bin/docker-entrypoint.sh"]

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/bin/docker-entrypoint.sh"]

USER 1997

CMD ["/usr/sbin/zabbix_proxy", "--foreground", "-c", "/etc/zabbix/zabbix_proxy.conf"]
